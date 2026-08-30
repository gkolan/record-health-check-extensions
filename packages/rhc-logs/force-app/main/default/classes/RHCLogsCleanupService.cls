/**
 * Performs bounded, retry-safe retention cleanup only on package-owned diagnostic Logs.
 */
public with sharing class RHCLogsCleanupService {
    /** Maximum deletes that leave room for lock acquisition and result persistence. */
    public static final Integer MAX_CLEANUP_BATCH_SIZE = 9998;
    private static final String SETTINGS_KEY = 'Default';
    private static final Integer STALE_LOCK_MINUTES = 60;
    @TestVisible private static Datetime nowOverride;

    /** Identifies whether cleanup was explicitly requested or schedule-driven. */
    public enum CleanupMode { MANUAL, AUTOMATED }

    /** Result returned to administrators and tests. */
    public class CleanupResult {
        @AuraEnabled public String status;
        @AuraEnabled public Integer deletedCount;
        @AuraEnabled public Integer failureCount;
        @AuraEnabled public Datetime cutoff;
    }

    /**
     * Runs one bounded cleanup transaction.
     * @param mode manual or automation-policy-enforced execution
     * @return observable cleanup result
     */
    public static CleanupResult run(CleanupMode mode) {
        CleanupResult result = newResult();
        if (mode == null) {
            result.status = 'INVALID_MODE';
            return result;
        }
        if (!hasRequiredAccess()) {
            result.status = 'INSUFFICIENT_ACCESS';
            return result;
        }
        List<Record_Health_Check_Log_Settings__c> rows = loadSettingsWithLock();
        if (rows.isEmpty() || !isValidPolicy(rows[0])) {
            result.status = 'DISABLED_OR_UNCONFIGURED';
            return result;
        }

        Record_Health_Check_Log_Settings__c settingsRecord = rows[0];
        if (mode == CleanupMode.AUTOMATED && !settingsRecord.AutomatedCleanupEnabled__c) {
            result.status = 'DISABLED';
            recordResult(settingsRecord, result);
            return result;
        }
        if (isActiveLock(settingsRecord)) {
            result.status = 'SKIPPED_OVERLAP';
            recordOverlapSkip(settingsRecord, result);
            return result;
        }
        acquireLease(settingsRecord);
        result.cutoff = currentTime().addDays(-settingsRecord.RetentionDays__c.intValue());
        deleteExpiredLogs(settingsRecord, result);
        result.status = result.failureCount == 0 ? 'SUCCESS' : 'PARTIAL_FAILURE';
        recordResult(settingsRecord, result);
        return result;
    }

    private static CleanupResult newResult() {
        CleanupResult result = new CleanupResult();
        result.deletedCount = 0;
        result.failureCount = 0;
        return result;
    }

    private static Boolean hasRequiredAccess() {
        return Schema.SObjectType.Record_Health_Check_Log_Settings__c.isAccessible()
            && Schema.SObjectType.Record_Health_Check_Log_Settings__c.isUpdateable()
            && Schema.SObjectType.Record_Health_Check_Diagnostic_Log__c.isAccessible()
            && Schema.SObjectType.Record_Health_Check_Diagnostic_Log__c.isDeletable();
    }

    // Object read/update CRUD is enforced by hasRequiredAccess(); FOR UPDATE cannot use USER_MODE.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static List<Record_Health_Check_Log_Settings__c> loadSettingsWithLock() {
        return [
            SELECT Id, RetentionDays__c, AutomatedCleanupEnabled__c, CleanupBatchSize__c,
                   CleanupInProgress__c, CleanupLockAcquiredAt__c
            FROM Record_Health_Check_Log_Settings__c
            WHERE SettingsKey__c = :SETTINGS_KEY
            LIMIT 1
            FOR UPDATE
        ];
    }

    // Object CRUD is enforced by hasRequiredAccess(); lease fields are package-owned state.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void acquireLease(Record_Health_Check_Log_Settings__c settingsRecord) {
        settingsRecord.CleanupInProgress__c = true;
        settingsRecord.CleanupRunToken__c = String.valueOf(currentTime().getTime())
            + '-' + String.valueOf(Crypto.getRandomInteger());
        settingsRecord.CleanupLockAcquiredAt__c = currentTime();
        Database.update(settingsRecord, AccessLevel.SYSTEM_MODE);
    }

    private static void deleteExpiredLogs(
        Record_Health_Check_Log_Settings__c settingsRecord,
        CleanupResult result
    ) {
        Datetime cutoff = result.cutoff;
        Integer batchSize = settingsRecord.CleanupBatchSize__c.intValue();
        List<Record_Health_Check_Diagnostic_Log__c> expired = [
            SELECT Id
            FROM Record_Health_Check_Diagnostic_Log__c
            WHERE OccurredAt__c < :cutoff
            WITH USER_MODE
            ORDER BY OccurredAt__c ASC, Id ASC
            LIMIT :batchSize
        ];
        if (expired.isEmpty()) {
            return;
        }
        for (Database.DeleteResult deleteResult : Database.delete(expired, false, AccessLevel.USER_MODE)) {
            if (deleteResult.isSuccess()) {
                result.deletedCount++;
            } else {
                result.failureCount++;
            }
        }
    }

    private static Boolean isValidPolicy(Record_Health_Check_Log_Settings__c settingsRecord) {
        return settingsRecord.RetentionDays__c != null
            && settingsRecord.RetentionDays__c >= 1
            && settingsRecord.RetentionDays__c <= 365
            && settingsRecord.CleanupBatchSize__c != null
            && settingsRecord.CleanupBatchSize__c >= 1
            && settingsRecord.CleanupBatchSize__c <= MAX_CLEANUP_BATCH_SIZE;
    }

    private static Boolean isActiveLock(Record_Health_Check_Log_Settings__c settingsRecord) {
        return settingsRecord.CleanupInProgress__c
            && settingsRecord.CleanupLockAcquiredAt__c != null
            && settingsRecord.CleanupLockAcquiredAt__c >
                currentTime().addMinutes(-STALE_LOCK_MINUTES);
    }

    private static void recordResult(
        Record_Health_Check_Log_Settings__c settingsRecord,
        CleanupResult result
    ) {
        settingsRecord.CleanupInProgress__c = false;
        settingsRecord.CleanupRunToken__c = null;
        settingsRecord.CleanupLockAcquiredAt__c = null;
        settingsRecord.LastCleanupAt__c = currentTime();
        settingsRecord.LastCleanupDeletedCount__c = result.deletedCount;
        settingsRecord.LastCleanupFailureCount__c = result.failureCount;
        settingsRecord.LastCleanupStatus__c = result.status;
        Database.update(settingsRecord, AccessLevel.SYSTEM_MODE);
    }

    private static void recordOverlapSkip(
        Record_Health_Check_Log_Settings__c settingsRecord,
        CleanupResult result
    ) {
        settingsRecord.LastCleanupAt__c = currentTime();
        settingsRecord.LastCleanupDeletedCount__c = result.deletedCount;
        settingsRecord.LastCleanupFailureCount__c = result.failureCount;
        settingsRecord.LastCleanupStatus__c = result.status;
        Database.update(settingsRecord, AccessLevel.SYSTEM_MODE);
    }

    private static Datetime currentTime() {
        return nowOverride == null ? System.now() : nowOverride;
    }
}
