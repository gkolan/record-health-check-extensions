/**
 * Persists canonical core lifecycle events as minimal, idempotent reporting facts.
 */
public inherited sharing class RHCReportsIngestionService {
    public static final String SUPPORTED_CONTRACT_VERSION = '1.0';
    /** Platform Event redeliveries requested before a transient failure is recorded as permanent. */
    private static final Integer MAX_RETRIES = 3;
    @TestVisible private static Integer retryCountOverride;
    private static final Set<String> RETRYABLE_STATUS_CODES = new Set<String>{
        'REQUEST_RUNNING_TOO_LONG',
        'SERVER_UNAVAILABLE',
        'UNABLE_TO_LOCK_ROW'
    };
    /**
     * Persists Set Run events in bulk. Unsupported contracts are ignored safely.
     * @param events Set Run events delivered by the core package
     */
    public static void ingestRuns(List<Record_Health_Check_Set_Run__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }
        Map<String, Record_Health_Check_Report_Run__c> factsByEventId =
            new Map<String, Record_Health_Check_Report_Run__c>();
        for (Record_Health_Check_Set_Run__e eventRecord : events) {
            if (!isSupported(eventRecord.ContractVersion__c, eventRecord.EventId__c)) {
                continue;
            }
            factsByEventId.put(
                eventRecord.EventId__c,
                new Record_Health_Check_Report_Run__c(
                    EventId__c = eventRecord.EventId__c,
                    RunId__c = eventRecord.RunId__c,
                    CheckSetQualifiedApiName__c = eventRecord.CheckSetQualifiedApiName__c,
                    RecordId__c = eventRecord.RecordId__c,
                    OccurredAt__c = eventRecord.OccurredAt__c,
                    Source__c = eventRecord.Source__c,
                    ContractVersion__c = eventRecord.ContractVersion__c,
                    FrameworkVersion__c = eventRecord.FrameworkVersion__c,
                    Phase__c = eventRecord.Phase__c,
                    SubmittedRecordCount__c = eventRecord.SubmittedRecordCount__c,
                    ProcessedRecordCount__c = eventRecord.ProcessedRecordCount__c,
                    EligibleCheckCount__c = eventRecord.EligibleCheckCount__c,
                    EvaluatedCheckCount__c = eventRecord.EvaluatedCheckCount__c,
                    PassedCount__c = eventRecord.PassedCount__c,
                    FailedCount__c = eventRecord.FailedCount__c,
                    SkippedCount__c = eventRecord.SkippedCount__c,
                    UnableCount__c = eventRecord.UnableCount__c,
                    SystemErrorCount__c = eventRecord.SystemErrorCount__c
                )
            );
        }
        if (!factsByEventId.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(
                factsByEventId.values(),
                Record_Health_Check_Report_Run__c.Fields.EventId__c,
                false
            );
            assertSuccessful(results, 'Run Facts');
        }
    }
    /**
     * Persists Check Result events in bulk without restricted detail.
     * @param events Result events delivered by the core package
     */
    public static void ingestResults(List<Record_Health_Check_Result__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }
        Map<String, Record_Health_Check_Report_Result__c> factsByEventId =
            new Map<String, Record_Health_Check_Report_Result__c>();
        for (Record_Health_Check_Result__e eventRecord : events) {
            if (
                !isSupported(eventRecord.ContractVersion__c, eventRecord.EventId__c) ||
                eventRecord.ContainsRestrictedDetail__c == true
            ) {
                continue;
            }
            factsByEventId.put(
                eventRecord.EventId__c,
                new Record_Health_Check_Report_Result__c(
                    EventId__c = eventRecord.EventId__c,
                    RunId__c = eventRecord.RunId__c,
                    CheckSetQualifiedApiName__c = eventRecord.CheckSetQualifiedApiName__c,
                    CheckQualifiedApiName__c = eventRecord.CheckQualifiedApiName__c,
                    RecordId__c = eventRecord.RecordId__c,
                    Status__c = eventRecord.Status__c,
                    Severity__c = eventRecord.Severity__c,
                    ReasonCode__c = eventRecord.ReasonCode__c,
                    OccurredAt__c = eventRecord.OccurredAt__c,
                    Source__c = eventRecord.Source__c,
                    ContractVersion__c = eventRecord.ContractVersion__c,
                    FrameworkVersion__c = eventRecord.FrameworkVersion__c
                )
            );
        }
        if (!factsByEventId.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(
                factsByEventId.values(),
                Record_Health_Check_Report_Result__c.Fields.EventId__c,
                false
            );
            assertSuccessful(results, 'Result Facts');
        }
    }

    // A non-retryable exception here would move the subscription into the error state and
    // silently stop all reporting, so permanent failures are recorded and the delivery continues.
    private static void assertSuccessful(
        Database.UpsertResult[] results,
        String factLabel
    ) {
        Integer failureCount = 0;
        Set<String> statusCodes = new Set<String>();
        for (Database.UpsertResult result : results) {
            if (result.isSuccess()) {
                continue;
            }
            failureCount++;
            for (Database.Error error : result.getErrors()) {
                statusCodes.add(String.valueOf(error.getStatusCode()));
            }
        }
        if (failureCount == 0) {
            return;
        }
        if (areAllRetryable(statusCodes)) {
            if (shouldRetry()) {
                throw new EventBus.RetryableException(
                    'Unable to persist ' + failureCount + ' ' + factLabel + '. Status codes: '
                    + String.join(new List<String>(statusCodes), ', ')
                );
            }
            statusCodes.add('RETRY_EXHAUSTED');
        }
        recordFailureEvidence(statusCodes);
    }

    @TestVisible
    private static Boolean shouldRetry() {
        EventBus.TriggerContext context = EventBus.TriggerContext.currentContext();
        Integer retries = retryCountOverride != null
            ? retryCountOverride
            : (context == null ? 0 : context.retries);
        return retries < MAX_RETRIES;
    }

    // The subscriber runs as Automated Process, which cannot hold CRUD on the hierarchy setting;
    // the same system-mode write the aggregation Finalizer already performs.
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void recordFailureEvidence(Set<String> statusCodes) {
        try {
            Record_Health_Check_Report_Setting__c setting =
                Record_Health_Check_Report_Setting__c.getOrgDefaults();
            if (setting == null) {
                setting = new Record_Health_Check_Report_Setting__c(
                    SetupOwnerId = UserInfo.getOrganizationId()
                );
            }
            List<String> sortedCodes = new List<String>(statusCodes);
            sortedCodes.sort();
            setting.LastIngestionFailureAt__c = Datetime.now();
            setting.LastIngestionErrorCodes__c = String.join(sortedCodes, ',').left(255);
            upsert setting;
        } catch (Exception evidenceFailure) {
            // Evidence is best effort; it must never take the subscriber down with it.
            return;
        }
    }

    @TestVisible
    private static Boolean areAllRetryable(Set<String> statusCodes) {
        return !statusCodes.isEmpty() && RETRYABLE_STATUS_CODES.containsAll(statusCodes);
    }

    private static Boolean isSupported(String contractVersion, String eventId) {
        return contractVersion == SUPPORTED_CONTRACT_VERSION && String.isNotBlank(eventId);
    }
}
