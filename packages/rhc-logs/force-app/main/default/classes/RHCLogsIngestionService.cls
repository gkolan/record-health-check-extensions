/**
 * Retains allow-listed fields from canonical Record Health Check Log events.
 * This system-context service is invoked only by the package Platform Event trigger.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class RHCLogsIngestionService {
    private static final Integer MESSAGE_LIMIT = 8000;
    private static final Integer DETAILS_LIMIT = 8000;
    private static final String SETTINGS_KEY = 'Default';
    @TestVisible private static Boolean snapshotPersistenceFailed = false;

    private class IngestionOutcome {
        private Integer insertedCount = 0;
        private Integer duplicateCount = 0;
        private Integer failedCount = 0;
        private Boolean hasRetryableFailure = false;
        private Set<String> permanentErrorCodes = new Set<String>();
    }

    /**
     * Maps and inserts a bulk delivery of canonical Log events.
     * @param events Canonical Record Health Check Log events delivered by Salesforce
     */
    public static void ingest(List<Record_Health_Check_Log__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }

        IngestionOutcome outcome = new IngestionOutcome();
        List<Record_Health_Check_Diagnostic_Log__c> logs = mapValidEvents(events, outcome);
        if (!logs.isEmpty()) {
            processSaveResults(Database.insert(logs, false), outcome);
        }
        if (outcome.hasRetryableFailure) {
            // Throwing rolls back this trigger transaction so already-successful rows can be
            // delivered again safely; EventId__c uniqueness makes the retry idempotent.
            throw new EventBus.RetryableException('Transient RHC Logs ingestion failure.');
        }
        updateOperationalSnapshot(outcome);
    }

    private static List<Record_Health_Check_Diagnostic_Log__c> mapValidEvents(
        List<Record_Health_Check_Log__e> events,
        IngestionOutcome outcome
    ) {
        List<Record_Health_Check_Diagnostic_Log__c> logs =
            new List<Record_Health_Check_Diagnostic_Log__c>();
        for (Record_Health_Check_Log__e sourceEvent : events) {
            if (hasRequiredContractFields(sourceEvent)) {
                logs.add(mapEvent(sourceEvent));
            } else {
                outcome.failedCount++;
                outcome.permanentErrorCodes.add('MALFORMED_CONTRACT');
            }
        }
        return logs;
    }

    private static void processSaveResults(
        List<Database.SaveResult> saveResults,
        IngestionOutcome outcome
    ) {
        for (Database.SaveResult saveResult : saveResults) {
            if (saveResult.isSuccess()) {
                outcome.insertedCount++;
            } else {
                processSaveErrors(saveResult.getErrors(), outcome);
            }
        }
    }

    private static void processSaveErrors(
        List<Database.Error> errors,
        IngestionOutcome outcome
    ) {
        Boolean duplicate = false;
        for (Database.Error error : errors) {
            StatusCode errorCode = error.getStatusCode();
            duplicate = duplicate || errorCode == StatusCode.DUPLICATE_VALUE;
            outcome.hasRetryableFailure = outcome.hasRetryableFailure || isRetryable(errorCode);
            if (errorCode != StatusCode.DUPLICATE_VALUE && !isRetryable(errorCode)) {
                outcome.permanentErrorCodes.add(String.valueOf(errorCode));
            }
        }
        if (duplicate) {
            outcome.duplicateCount++;
        } else {
            outcome.failedCount++;
        }
    }

    private static Boolean hasRequiredContractFields(Record_Health_Check_Log__e sourceEvent) {
        return sourceEvent != null
            && !String.isBlank(sourceEvent.EventId__c)
            && !String.isBlank(sourceEvent.RunId__c)
            && sourceEvent.OccurredAt__c != null
            && !String.isBlank(sourceEvent.ContractVersion__c)
            && !String.isBlank(sourceEvent.Level__c);
    }

    private static Record_Health_Check_Diagnostic_Log__c mapEvent(Record_Health_Check_Log__e sourceEvent) {
        return new Record_Health_Check_Diagnostic_Log__c(
            EventId__c = bound(sourceEvent.EventId__c, 80),
            RunId__c = bound(sourceEvent.RunId__c, 120),
            OccurredAt__c = sourceEvent.OccurredAt__c,
            ContractVersion__c = bound(sourceEvent.ContractVersion__c, 10),
            FrameworkVersion__c = bound(sourceEvent.FrameworkVersion__c, 20),
            Severity__c = bound(sourceEvent.Level__c, 10),
            Code__c = bound(sourceEvent.Code__c, 120),
            Message__c = bound(sourceEvent.Message__c, MESSAGE_LIMIT),
            StructuredDetails__c = bound(sourceEvent.DetailsJson__c, DETAILS_LIMIT),
            ExceptionType__c = bound(sourceEvent.ExceptionType__c, 120),
            RecordId__c = bound(sourceEvent.RecordId__c, 18),
            CheckSetDeveloperName__c = bound(sourceEvent.CheckSetDeveloperName__c, 120),
            CheckDeveloperName__c = bound(sourceEvent.CheckDeveloperName__c, 120),
            RunningUserId__c = bound(sourceEvent.UserId__c, 18),
            IngestedAt__c = System.now()
        );
    }

    @TestVisible
    private static String bound(String value, Integer maximumLength) {
        if (value == null || value.length() <= maximumLength) {
            return value;
        }
        return value.left(maximumLength);
    }

    @TestVisible
    private static Boolean isRetryable(StatusCode errorCode) {
        return errorCode == StatusCode.UNABLE_TO_LOCK_ROW
            || errorCode == StatusCode.UNKNOWN_EXCEPTION;
    }

    private static void updateOperationalSnapshot(IngestionOutcome outcome) {
        try {
            List<Record_Health_Check_Log_Settings__c> existing = [
                SELECT Id
                FROM Record_Health_Check_Log_Settings__c
                WHERE SettingsKey__c = :SETTINGS_KEY
                LIMIT 1
            ];
            Record_Health_Check_Log_Settings__c settingsRecord = existing.isEmpty()
                ? new Record_Health_Check_Log_Settings__c(Name = SETTINGS_KEY, SettingsKey__c = SETTINGS_KEY)
                : existing[0];
            settingsRecord.LastIngestionAt__c = System.now();
            settingsRecord.LastIngestionCount__c = outcome.insertedCount;
            settingsRecord.LastDuplicateCount__c = outcome.duplicateCount;
            settingsRecord.LastIngestionFailureCount__c = outcome.failedCount;
            settingsRecord.LastIngestionStatus__c = outcome.failedCount == 0
                ? 'SUCCESS'
                : 'PARTIAL_FAILURE';
            List<String> sortedErrorCodes = new List<String>(outcome.permanentErrorCodes);
            sortedErrorCodes.sort();
            settingsRecord.LastIngestionErrorCodes__c = bound(String.join(sortedErrorCodes, ','), 255);
            Database.SaveResult snapshotResult = settingsRecord.Id == null
                ? Database.insert(settingsRecord, false)
                : Database.update(settingsRecord, false);
            if (!snapshotResult.isSuccess()) {
                recordSnapshotFailure();
            }
        } catch (Exception snapshotFailure) {
            // Operational snapshots are best effort and never roll back retained diagnostic logs.
            recordSnapshotFailure();
        }
    }

    private static void recordSnapshotFailure() {
        snapshotPersistenceFailed = true;
    }
}
