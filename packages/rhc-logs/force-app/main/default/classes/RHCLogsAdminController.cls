/**
 * Security-enforced setup, monitoring, retention, and scheduling API for RHC Logs administrators.
 */
// The controller's aggregate complexity is 52 because it exposes one cohesive administration API;
// its highest individual method complexity is 10 and orchestration is delegated to focused helpers.
@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class RHCLogsAdminController {
    public static final String MINIMUM_CORE_VERSION = '2.0.4.2';
    private static final String SETTINGS_KEY = 'Default';

    /** One visible core Check Set publication finding. */
    public class CheckSetFinding {
        @AuraEnabled public String developerName;
        @AuraEnabled public Boolean publishesLogEvents;
    }

    /** Setup and operations snapshot for the administration UI. */
    public class SetupStatus {
        @AuraEnabled public Boolean coreLogEventInstalled;
        @AuraEnabled public Boolean coreContractCompatible;
        @AuraEnabled public Boolean currentUserCanReadCoreEvent;
        @AuraEnabled public Boolean currentUserCanPublishCoreEvent;
        @AuraEnabled public Boolean canInspectCheckSets;
        @AuraEnabled public String minimumCoreVersion;
        @AuraEnabled public String sourceFilterAvailability;
        @AuraEnabled public List<CheckSetFinding> checkSets;
        @AuraEnabled public Record_Health_Check_Log_Settings__c settings;
        @AuraEnabled public Boolean cleanupScheduled;
        @AuraEnabled public Integer retainedCount;
        @AuraEnabled public Integer unsupportedContractCount;
        @AuraEnabled public Datetime oldestOccurredAt;
        @AuraEnabled public Datetime newestOccurredAt;
    }

    /** Administrator-owned retention policy input. */
    public class SettingsInput {
        @AuraEnabled public Integer retentionDays;
        @AuraEnabled public Integer cleanupBatchSize;
        @AuraEnabled public Boolean automatedCleanupEnabled;
    }

    /**
     * Returns evidence-based setup and operational findings.
     * @return current package and visible core configuration status
     */
    @AuraEnabled
    public static SetupStatus getStatus() {
        assertSettingsReadable();
        SetupStatus status = new SetupStatus();
        status.minimumCoreVersion = MINIMUM_CORE_VERSION;
        status.sourceFilterAvailability =
            'Unavailable: core Log contract 1.0 does not publish Execution Source.';
        status.checkSets = new List<CheckSetFinding>();
        populateCoreStatus(status);
        populateCheckSets(status);
        status.settings = loadSettings();
        status.cleanupScheduled = RHCLogsCleanupScheduler.isScheduled();
        populateLogSummary(status);
        return status;
    }

    /**
     * Saves the bounded singleton retention configuration.
     * @param settingsInput bounded retention and scheduling input
     * @return refreshed setup status
     */
    @AuraEnabled
    public static SetupStatus saveSettings(SettingsInput settingsInput) {
        assertSettingsWritable();
        validateSettingsInput(settingsInput);
        Record_Health_Check_Log_Settings__c settingsRecord = loadSettingsForUpdate();
        settingsRecord.RetentionDays__c = settingsInput.retentionDays;
        settingsRecord.CleanupBatchSize__c = settingsInput.cleanupBatchSize;
        settingsRecord.AutomatedCleanupEnabled__c = settingsInput.automatedCleanupEnabled == true;

        try {
            persistSettings(settingsRecord);
            synchronizeSchedule(settingsRecord);
        } catch (Exception exceptionRecord) {
            throw sanitized('RHC Logs settings could not be saved. Check your access and configuration.');
        }
        return getStatus();
    }

    /**
     * Runs one explicit bounded cleanup regardless of schedule enablement.
     * @return cleanup outcome
     */
    @AuraEnabled
    public static RHCLogsCleanupService.CleanupResult runCleanup() {
        assertSettingsWritable();
        if (!Schema.SObjectType.Record_Health_Check_Diagnostic_Log__c.isDeletable()) {
            throw sanitized('You do not have permission to delete expired RHC Diagnostic Logs.');
        }
        return RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.MANUAL);
    }

    private static void populateCoreStatus(SetupStatus status) {
        Schema.DescribeSObjectResult eventDescribe =
            Record_Health_Check_Log__e.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED);
        status.coreLogEventInstalled = true;
        status.coreContractCompatible = hasRequiredEventFields(eventDescribe);
        status.currentUserCanReadCoreEvent = eventDescribe.isAccessible();
        status.currentUserCanPublishCoreEvent = eventDescribe.isCreateable();
    }

    private static void populateCheckSets(SetupStatus status) {
        status.canInspectCheckSets = Schema.SObjectType.Record_Health_Check_Set__mdt.isAccessible();
        if (!status.canInspectCheckSets) {
            return;
        }
        Map<String, Boolean> publicationByDeveloperName = new Map<String, Boolean>();
        for (Record_Health_Check_Set__mdt checkSet : Record_Health_Check_Set__mdt.getAll().values()) {
            publicationByDeveloperName.put(
                checkSet.DeveloperName,
                checkSet.PublishErrorLogEvent__c == true
            );
        }
        List<String> developerNames = new List<String>(publicationByDeveloperName.keySet());
        developerNames.sort();
        for (String developerName : developerNames) {
            CheckSetFinding finding = new CheckSetFinding();
            finding.developerName = developerName;
            finding.publishesLogEvents = publicationByDeveloperName.get(developerName);
            status.checkSets.add(finding);
        }
    }

    private static Record_Health_Check_Log_Settings__c loadSettings() {
        List<Record_Health_Check_Log_Settings__c> settingsRows = [
            SELECT Id, Name, SettingsKey__c, RetentionDays__c,
                   AutomatedCleanupEnabled__c, CleanupBatchSize__c,
                   LastIngestionAt__c, LastIngestionCount__c,
                   LastDuplicateCount__c, LastIngestionFailureCount__c,
                   LastIngestionStatus__c, LastIngestionErrorCodes__c,
                   LastCleanupAt__c, LastCleanupDeletedCount__c,
                   LastCleanupFailureCount__c, LastCleanupStatus__c,
                   CleanupInProgress__c, CleanupLockAcquiredAt__c
            FROM Record_Health_Check_Log_Settings__c
            WHERE SettingsKey__c = :SETTINGS_KEY
            WITH USER_MODE
            LIMIT 1
        ];
        return settingsRows.isEmpty() ? null : settingsRows[0];
    }

    // The setup dashboard intentionally aggregates the full retained-log table;
    // Salesforce rejects LIMIT on a non-grouped aggregate query.
    @SuppressWarnings('PMD.AvoidNonRestrictiveQueries')
    private static void populateLogSummary(SetupStatus status) {
        if (!Schema.SObjectType.Record_Health_Check_Diagnostic_Log__c.isAccessible()) {
            return;
        }
        AggregateResult summary = [
            SELECT COUNT(Id) retainedCount, MIN(OccurredAt__c) oldestAt,
                   MAX(OccurredAt__c) newestAt
            FROM Record_Health_Check_Diagnostic_Log__c
            WITH USER_MODE
        ];
        status.retainedCount = (Integer) summary.get('retainedCount');
        status.oldestOccurredAt = (Datetime) summary.get('oldestAt');
        status.newestOccurredAt = (Datetime) summary.get('newestAt');
        if (Schema.SObjectType.Record_Health_Check_Diagnostic_Log__c.fields.ContractVersion__c
                .isAccessible()) {
            status.unsupportedContractCount = [
                SELECT COUNT()
                FROM Record_Health_Check_Diagnostic_Log__c
                WHERE ContractVersion__c != '1.0'
                WITH USER_MODE
            ];
        }
    }

    private static void validateSettingsInput(SettingsInput settingsInput) {
        if (settingsInput == null || settingsInput.retentionDays == null
            || settingsInput.retentionDays < 1 || settingsInput.retentionDays > 365) {
            throw sanitized('Retention Days must be from 1 through 365.');
        }
        if (settingsInput.cleanupBatchSize == null || settingsInput.cleanupBatchSize < 1
            || settingsInput.cleanupBatchSize > RHCLogsCleanupService.MAX_CLEANUP_BATCH_SIZE) {
            throw sanitized('Cleanup Batch Size must be from 1 through 9,998.');
        }
    }

    private static Record_Health_Check_Log_Settings__c loadSettingsForUpdate() {
        List<Record_Health_Check_Log_Settings__c> rows = [
            SELECT Id, Name, SettingsKey__c
            FROM Record_Health_Check_Log_Settings__c
            WHERE SettingsKey__c = :SETTINGS_KEY
            WITH USER_MODE
            LIMIT 1
        ];
        return rows.isEmpty()
            ? new Record_Health_Check_Log_Settings__c(Name = SETTINGS_KEY, SettingsKey__c = SETTINGS_KEY)
            : rows[0];
    }

    private static void persistSettings(Record_Health_Check_Log_Settings__c settingsRecord) {
        if (settingsRecord.Id == null) {
            // The singleton key is package-owned and deliberately not user-editable.
            Database.insert(settingsRecord, AccessLevel.SYSTEM_MODE);
            return;
        }
        Database.update(settingsRecord, AccessLevel.USER_MODE);
    }

    private static void synchronizeSchedule(Record_Health_Check_Log_Settings__c settingsRecord) {
        if (settingsRecord.AutomatedCleanupEnabled__c) {
            RHCLogsCleanupScheduler.scheduleDaily();
            return;
        }
        RHCLogsCleanupScheduler.disable();
    }

    private static void assertSettingsReadable() {
        if (!Schema.SObjectType.Record_Health_Check_Log_Settings__c.isAccessible()) {
            throw sanitized('You do not have access to RHC Logs settings.');
        }
    }

    private static void assertSettingsWritable() {
        if (!Schema.SObjectType.Record_Health_Check_Log_Settings__c.isCreateable()
            || !Schema.SObjectType.Record_Health_Check_Log_Settings__c.isUpdateable()) {
            throw sanitized('You do not have permission to configure RHC Logs.');
        }
        for (Schema.DescribeFieldResult fieldDescribe : new List<Schema.DescribeFieldResult>{
            Schema.SObjectType.Record_Health_Check_Log_Settings__c.fields.RetentionDays__c,
            Schema.SObjectType.Record_Health_Check_Log_Settings__c.fields.CleanupBatchSize__c,
            Schema.SObjectType.Record_Health_Check_Log_Settings__c.fields.AutomatedCleanupEnabled__c
        }) {
            if (!fieldDescribe.isCreateable() || !fieldDescribe.isUpdateable()) {
                throw sanitized('You do not have permission to configure RHC Logs.');
            }
        }
    }

    private static Boolean hasRequiredEventFields(Schema.DescribeSObjectResult eventDescribe) {
        Set<String> required = new Set<String>{
            'EventId__c', 'RunId__c', 'OccurredAt__c', 'ContractVersion__c',
            'FrameworkVersion__c', 'Level__c', 'Code__c', 'Message__c',
            'DetailsJson__c', 'ExceptionType__c', 'RecordId__c',
            'CheckSetDeveloperName__c', 'CheckDeveloperName__c', 'UserId__c'
        };
        Set<String> available = eventDescribe.fields.getMap().keySet();
        for (String fieldName : required) {
            if (!hasLocalOrQualifiedField(available, fieldName)) {
                return false;
            }
        }
        return true;
    }

    private static Boolean hasLocalOrQualifiedField(Set<String> available, String fieldName) {
        String normalizedFieldName = fieldName.toLowerCase();
        for (String apiName : available) {
            String normalizedApiName = apiName.toLowerCase();
            if (normalizedApiName == normalizedFieldName
                || normalizedApiName.endsWith('__' + normalizedFieldName)) {
                return true;
            }
        }
        return false;
    }

    private static AuraHandledException sanitized(String message) {
        AuraHandledException exceptionRecord = new AuraHandledException(message);
        exceptionRecord.setMessage(message);
        return exceptionRecord;
    }
}
