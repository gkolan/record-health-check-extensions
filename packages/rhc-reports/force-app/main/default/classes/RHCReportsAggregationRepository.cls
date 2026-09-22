/**
 * Owns bounded system-mode reads and atomic snapshot-partition replacement for daily aggregation.
 */
public inherited sharing class RHCReportsAggregationRepository {
    private static final Integer RUN_QUERY_SAFETY_LIMIT = 15000;
    private static final Integer RESULT_QUERY_SAFETY_LIMIT = 20000;
    private static final Integer PRIOR_RESULT_QUERY_SAFETY_LIMIT = 5000;
    private static final Integer SNAPSHOT_PARTITION_SAFETY_LIMIT = 5001;

    /**
     * Selects Run facts inside one half-open aggregation window.
     * @param windowStart inclusive UTC window boundary
     * @param windowEnd exclusive UTC window boundary
     * @return bounded Run facts in event order
     */
    public static List<Record_Health_Check_Report_Run__c> selectRuns(
        Datetime windowStart,
        Datetime windowEnd
    ) {
        List<Record_Health_Check_Report_Run__c> runs = [
            SELECT CheckSetQualifiedApiName__c, RecordId__c, Source__c,
                PassedCount__c, FailedCount__c, SkippedCount__c,
                UnableCount__c, SystemErrorCount__c, OccurredAt__c
            FROM Record_Health_Check_Report_Run__c
            WHERE OccurredAt__c >= :windowStart
                AND OccurredAt__c < :windowEnd
            WITH SYSTEM_MODE
            ORDER BY OccurredAt__c ASC
            LIMIT :RUN_QUERY_SAFETY_LIMIT
        ];
        assertQueryComplete(runs.size(), RUN_QUERY_SAFETY_LIMIT, 'Run Fact candidate');
        return runs;
    }

    /**
     * Selects Result facts inside one half-open aggregation window.
     * @param windowStart inclusive UTC window boundary
     * @param windowEnd exclusive UTC window boundary
     * @return bounded Result facts in event order
     */
    public static List<Record_Health_Check_Report_Result__c> selectResults(
        Datetime windowStart,
        Datetime windowEnd
    ) {
        List<Record_Health_Check_Report_Result__c> results = [
            SELECT CheckSetQualifiedApiName__c, CheckQualifiedApiName__c,
                RecordId__c, Status__c, Severity__c, Source__c, OccurredAt__c
            FROM Record_Health_Check_Report_Result__c
            WHERE OccurredAt__c >= :windowStart
                AND OccurredAt__c < :windowEnd
            WITH SYSTEM_MODE
            ORDER BY OccurredAt__c ASC
            LIMIT :RESULT_QUERY_SAFETY_LIMIT
        ];
        assertQueryComplete(
            results.size(),
            RESULT_QUERY_SAFETY_LIMIT,
            'Result Fact candidate'
        );
        return results;
    }

    /**
     * Selects the latest pre-window status for every requested record/check pair.
     * @param upperBound exclusive event-time boundary
     * @param recordIds record identities present in the current window
     * @param checkNames Check identities present in the current window
     * @return latest prior status keyed by record and Check identity
     */
    public static Map<String, String> selectPriorStatuses(
        Datetime upperBound,
        Set<String> recordIds,
        Set<String> checkNames
    ) {
        Map<String, String> statuses = new Map<String, String>();
        if (recordIds.isEmpty() || checkNames.isEmpty()) {
            return statuses;
        }
        List<Record_Health_Check_Report_Result__c> priorResults = [
            SELECT RecordId__c, CheckQualifiedApiName__c, Status__c, OccurredAt__c
            FROM Record_Health_Check_Report_Result__c
            WHERE RecordId__c IN :recordIds
                AND CheckQualifiedApiName__c IN :checkNames
                AND OccurredAt__c < :upperBound
            WITH SYSTEM_MODE
            ORDER BY OccurredAt__c DESC
            LIMIT :PRIOR_RESULT_QUERY_SAFETY_LIMIT
        ];
        assertQueryComplete(
            priorResults.size(),
            PRIOR_RESULT_QUERY_SAFETY_LIMIT,
            'Prior Result Fact'
        );
        for (Record_Health_Check_Report_Result__c result : priorResults) {
            String key = recordCheckKey(
                result.RecordId__c,
                result.CheckQualifiedApiName__c
            );
            if (!statuses.containsKey(key)) {
                statuses.put(key, result.Status__c);
            }
        }
        return statuses;
    }

    /**
     * Replaces one date/time-zone snapshot partition within one transaction.
     * @param snapshotDate local reporting date
     * @param timeZoneId aggregation time-zone identity
     * @param snapshots complete replacement rows
     */
    public static void replaceSnapshotPartition(
        Date snapshotDate,
        String timeZoneId,
        List<Record_Health_Check_Daily_Snapshot__c> snapshots
    ) {
        if (snapshots.size() > Limits.getLimitDmlRows()) {
            throw new RHCReportsAggregationService.RHCReportsAggregationException(
                'Snapshot partition exceeds the transaction DML row limit.'
            );
        }
        List<Record_Health_Check_Daily_Snapshot__c> existingSnapshots = [
            SELECT Id
            FROM Record_Health_Check_Daily_Snapshot__c
            WHERE SnapshotDate__c = :snapshotDate
                AND AggregationTimeZone__c = :timeZoneId
            WITH SYSTEM_MODE
            LIMIT :SNAPSHOT_PARTITION_SAFETY_LIMIT
        ];
        if (
            existingSnapshots.size() >= SNAPSHOT_PARTITION_SAFETY_LIMIT ||
            existingSnapshots.size() + snapshots.size() > Limits.getLimitDmlRows()
        ) {
            throw new RHCReportsAggregationService.RHCReportsAggregationException(
                'Existing snapshot partition exceeds the transaction DML row limit.'
            );
        }
        if (!existingSnapshots.isEmpty()) {
            Database.DeleteResult[] deleteResults = Database.delete(
                existingSnapshots,
                false,
                AccessLevel.SYSTEM_MODE
            );
            assertSuccessful(deleteResults, 'replace existing snapshots');
        }
        if (!snapshots.isEmpty()) {
            Database.UpsertResult[] upsertResults = Database.upsert(
                snapshots,
                Record_Health_Check_Daily_Snapshot__c.Fields.SnapshotKey__c,
                false,
                AccessLevel.SYSTEM_MODE
            );
            assertSuccessful(upsertResults, 'persist replacement snapshots');
        }
    }

    /**
     * Fails closed when a bounded query reaches its limit because completeness is unknown.
     * @param rowCount rows returned by the bounded query
     * @param safetyLimit configured query limit
     * @param queryLabel safe query description for the exception
     */
    @TestVisible
    public static void assertQueryComplete(
        Integer rowCount,
        Integer safetyLimit,
        String queryLabel
    ) {
        if (rowCount == safetyLimit) {
            throw new RHCReportsAggregationService.RHCReportsAggregationException(
                queryLabel + ' query reached its transaction safety boundary. ' +
                'No partial snapshot was written.'
            );
        }
    }

    private static void assertSuccessful(
        Database.DeleteResult[] results,
        String operation
    ) {
        Integer failureCount = 0;
        for (Database.DeleteResult result : results) {
            if (!result.isSuccess()) {
                failureCount++;
            }
        }
        assertNoFailures(failureCount, operation);
    }

    private static void assertSuccessful(
        Database.UpsertResult[] results,
        String operation
    ) {
        Integer failureCount = 0;
        for (Database.UpsertResult result : results) {
            if (!result.isSuccess()) {
                failureCount++;
            }
        }
        assertNoFailures(failureCount, operation);
    }

    private static void assertNoFailures(Integer failureCount, String operation) {
        if (failureCount > 0) {
            throw new RHCReportsAggregationService.RHCReportsAggregationException(
                'Unable to ' + operation + ': ' + failureCount + ' row(s) failed.'
            );
        }
    }

    private static String recordCheckKey(String recordId, String checkName) {
        return String.valueOf(recordId) + '|' + String.valueOf(checkName);
    }
}
