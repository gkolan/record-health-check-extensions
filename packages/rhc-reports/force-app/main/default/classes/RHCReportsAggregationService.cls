/**
 * Recomputes one local reporting day and upserts deterministic daily snapshots.
 */
public inherited sharing class RHCReportsAggregationService {
    private static final Integer RUN_QUERY_SAFETY_LIMIT = 15000;
    private static final Integer RESULT_QUERY_SAFETY_LIMIT = 20000;
    private static final Integer PRIOR_RESULT_QUERY_SAFETY_LIMIT = 5000;
    private static final Integer SNAPSHOT_PARTITION_SAFETY_LIMIT = 5001;
    private static final Set<String> ACTIONABLE_STATUSES =
        new Set<String>{ 'FAIL', 'UNABLE_TO_EVALUATE', 'ERROR' };
    /**
     * Recomputes a daily snapshot in the supplied Salesforce time-zone ID.
     * @param snapshotDate local reporting date
     * @param timeZoneId explicit time-zone ID used for date assignment
     */
    public static void aggregateDate(Date snapshotDate, String timeZoneId) {
        if (snapshotDate == null || String.isBlank(timeZoneId)) {
            throw new RHCReportsAggregationException('Snapshot date and time zone are required.');
        }
        validateTimeZone(timeZoneId);
        Datetime windowStart = localMidnightUtc(snapshotDate, timeZoneId);
        Datetime windowEnd = localMidnightUtc(snapshotDate.addDays(1), timeZoneId);
        List<Record_Health_Check_Report_Run__c> runs = [
            SELECT CheckSetQualifiedApiName__c, RecordId__c, Source__c,
                PassedCount__c, FailedCount__c, SkippedCount__c,
                UnableCount__c, SystemErrorCount__c, OccurredAt__c
            FROM Record_Health_Check_Report_Run__c
            WHERE OccurredAt__c >= :windowStart AND OccurredAt__c < :windowEnd
            WITH SYSTEM_MODE
            ORDER BY OccurredAt__c ASC
            LIMIT :RUN_QUERY_SAFETY_LIMIT
        ];
        assertQueryComplete(runs.size(), RUN_QUERY_SAFETY_LIMIT, 'Run Fact candidate');
        List<Record_Health_Check_Report_Result__c> results = [
            SELECT CheckSetQualifiedApiName__c, CheckQualifiedApiName__c,
                RecordId__c, Status__c, Severity__c, Source__c, OccurredAt__c
            FROM Record_Health_Check_Report_Result__c
            WHERE OccurredAt__c >= :windowStart AND OccurredAt__c < :windowEnd
            WITH SYSTEM_MODE
            ORDER BY OccurredAt__c ASC
            LIMIT :RESULT_QUERY_SAFETY_LIMIT
        ];
        assertQueryComplete(
            results.size(),
            RESULT_QUERY_SAFETY_LIMIT,
            'Result Fact candidate'
        );
        List<Record_Health_Check_Report_Result__c> targetResults =
            new List<Record_Health_Check_Report_Result__c>();
        Set<String> recordIds = new Set<String>();
        Set<String> checkNames = new Set<String>();
        for (Record_Health_Check_Report_Result__c result : results) {
            targetResults.add(result);
            if (String.isNotBlank(result.RecordId__c)) {
                recordIds.add(result.RecordId__c);
            }
            checkNames.add(result.CheckQualifiedApiName__c);
        }
        Map<String, String> priorStatusByRecordCheck =
            selectPriorStatuses(snapshotDate, timeZoneId, recordIds, checkNames);
        Map<String, SnapshotAccumulator> accumulators =
            new Map<String, SnapshotAccumulator>();
        for (Record_Health_Check_Report_Run__c run : runs) {
            String groupKey = groupKey(
                'RUN',
                run.CheckSetQualifiedApiName__c,
                null,
                null,
                null,
                run.Source__c
            );
            SnapshotAccumulator accumulator = getAccumulator(
                accumulators,
                groupKey,
                snapshotDate,
                timeZoneId,
                'RUN',
                run.CheckSetQualifiedApiName__c,
                null,
                null,
                null,
                run.Source__c
            );
            accumulator.runCount++;
            accumulator.recordIds.add(run.RecordId__c);
            accumulator.passedCount += integerValue(run.PassedCount__c);
            accumulator.failedCount += integerValue(run.FailedCount__c);
            accumulator.skippedCount += integerValue(run.SkippedCount__c);
            accumulator.unableCount += integerValue(run.UnableCount__c);
            accumulator.systemErrorCount += integerValue(run.SystemErrorCount__c);
        }
        for (Record_Health_Check_Report_Result__c result : targetResults) {
            String groupKey = groupKey(
                'RESULT',
                result.CheckSetQualifiedApiName__c,
                result.CheckQualifiedApiName__c,
                result.Status__c,
                result.Severity__c,
                result.Source__c
            );
            SnapshotAccumulator accumulator = getAccumulator(
                accumulators,
                groupKey,
                snapshotDate,
                timeZoneId,
                'RESULT',
                result.CheckSetQualifiedApiName__c,
                result.CheckQualifiedApiName__c,
                result.Status__c,
                result.Severity__c,
                result.Source__c
            );
            accumulator.resultCount++;
            accumulator.recordIds.add(result.RecordId__c);
            addStatusCount(accumulator, result.Status__c);
            String recordCheckKey = recordCheckKey(
                result.RecordId__c,
                result.CheckQualifiedApiName__c
            );
            String priorStatus = priorStatusByRecordCheck.get(recordCheckKey);
            if (
                ACTIONABLE_STATUSES.contains(result.Status__c) &&
                ACTIONABLE_STATUSES.contains(priorStatus)
            ) {
                accumulator.recurringFailureCount++;
            } else if (
                result.Status__c == 'PASS' &&
                ACTIONABLE_STATUSES.contains(priorStatus)
            ) {
                accumulator.recoveryCount++;
            }
            priorStatusByRecordCheck.put(recordCheckKey, result.Status__c);
        }
        List<Record_Health_Check_Daily_Snapshot__c> snapshots =
            new List<Record_Health_Check_Daily_Snapshot__c>();
        for (SnapshotAccumulator accumulator : accumulators.values()) {
            snapshots.add(accumulator.toRecord());
        }
        replaceSnapshotPartition(snapshotDate, timeZoneId, snapshots);
    }

    private static void replaceSnapshotPartition(
        Date snapshotDate,
        String timeZoneId,
        List<Record_Health_Check_Daily_Snapshot__c> snapshots
    ) {
        if (snapshots.size() > Limits.getLimitDmlRows()) {
            throw new RHCReportsAggregationException(
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
            throw new RHCReportsAggregationException(
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

    @TestVisible
    private static void assertQueryComplete(
        Integer rowCount,
        Integer safetyLimit,
        String queryLabel
    ) {
        if (rowCount == safetyLimit) {
            throw new RHCReportsAggregationException(
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
        if (failureCount > 0) {
            throw new RHCReportsAggregationException(
                'Unable to ' + operation + ': ' + failureCount + ' row(s) failed.'
            );
        }
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
        if (failureCount > 0) {
            throw new RHCReportsAggregationException(
                'Unable to ' + operation + ': ' + failureCount + ' row(s) failed.'
            );
        }
    }
    private static Map<String, String> selectPriorStatuses(
        Date snapshotDate,
        String timeZoneId,
        Set<String> recordIds,
        Set<String> checkNames
    ) {
        Map<String, String> statuses = new Map<String, String>();
        if (recordIds.isEmpty() || checkNames.isEmpty()) {
            return statuses;
        }
        Datetime upperBound = localMidnightUtc(snapshotDate, timeZoneId);
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
    private static SnapshotAccumulator getAccumulator(
        Map<String, SnapshotAccumulator> accumulators,
        String groupKey,
        Date snapshotDate,
        String timeZoneId,
        String grain,
        String checkSetName,
        String checkName,
        String status,
        String severity,
        String source
    ) {
        if (!accumulators.containsKey(groupKey)) {
            accumulators.put(
                groupKey,
                new SnapshotAccumulator(
                    groupKey,
                    snapshotDate,
                    timeZoneId,
                    grain,
                    checkSetName,
                    checkName,
                    status,
                    severity,
                    source
                )
            );
        }
        return accumulators.get(groupKey);
    }
    private static void addStatusCount(
        SnapshotAccumulator accumulator,
        String status
    ) {
        if (status == 'PASS') {
            accumulator.passedCount++;
        } else if (status == 'FAIL') {
            accumulator.failedCount++;
        } else if (status == 'SKIPPED') {
            accumulator.skippedCount++;
        } else if (status == 'UNABLE_TO_EVALUATE') {
            accumulator.unableCount++;
        } else if (status == 'ERROR') {
            accumulator.systemErrorCount++;
        }
    }
    private static Integer integerValue(Decimal value) {
        return value == null ? 0 : value.intValue();
    }
    private static Datetime localMidnightUtc(Date localDate, String timeZoneId) {
        TimeZone zone = TimeZone.getTimeZone(timeZoneId);
        Datetime wallClockAsUtc = Datetime.newInstanceGMT(
            localDate,
            Time.newInstance(0, 0, 0, 0)
        );
        Datetime candidate = wallClockAsUtc.addSeconds(
            -zone.getOffset(wallClockAsUtc) / 1000
        );
        Integer correctedOffset = zone.getOffset(candidate);
        return wallClockAsUtc.addSeconds(-correctedOffset / 1000);
    }
    private static String recordCheckKey(String recordId, String checkName) {
        return String.valueOf(recordId) + '|' + String.valueOf(checkName);
    }
    private static String groupKey(
        String grain,
        String checkSetName,
        String checkName,
        String status,
        String severity,
        String source
    ) {
        return String.join(
            new List<String>{
                value(grain),
                value(checkSetName),
                value(checkName),
                value(status),
                value(severity),
                value(source)
            },
            '|'
        );
    }
    private static String value(String input) {
        return input == null ? '' : input;
    }
    private static void validateTimeZone(String timeZoneId) {
        TimeZone zone = TimeZone.getTimeZone(timeZoneId);
        if (zone == null || (zone.getID() == 'GMT' && timeZoneId != 'GMT')) {
            throw new RHCReportsAggregationException('Unknown time zone: ' + timeZoneId);
        }
    }
    private class SnapshotAccumulator {
        private String groupKeyValue;
        private Date snapshotDate;
        private String timeZoneId;
        private String grain;
        private String checkSetName;
        private String checkName;
        private String status;
        private String severity;
        private String source;
        private Integer runCount = 0;
        private Integer resultCount = 0;
        private Integer passedCount = 0;
        private Integer failedCount = 0;
        private Integer skippedCount = 0;
        private Integer unableCount = 0;
        private Integer systemErrorCount = 0;
        private Integer recurringFailureCount = 0;
        private Integer recoveryCount = 0;
        private Set<String> recordIds = new Set<String>();
        private SnapshotAccumulator(
            String groupKeyValue,
            Date snapshotDate,
            String timeZoneId,
            String grain,
            String checkSetName,
            String checkName,
            String status,
            String severity,
            String source
        ) {
            this.groupKeyValue = groupKeyValue;
            this.snapshotDate = snapshotDate;
            this.timeZoneId = timeZoneId;
            this.grain = grain;
            this.checkSetName = checkSetName;
            this.checkName = checkName;
            this.status = status;
            this.severity = severity;
            this.source = source;
        }
        private Record_Health_Check_Daily_Snapshot__c toRecord() {
            String identity = String.valueOf(snapshotDate) + '|' + timeZoneId + '|' + groupKeyValue;
            String snapshotKey = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(identity))
            );
            return new Record_Health_Check_Daily_Snapshot__c(
                SnapshotKey__c = snapshotKey,
                SnapshotDate__c = snapshotDate,
                AggregationTimeZone__c = timeZoneId,
                Grain__c = grain,
                CheckSetQualifiedApiName__c = checkSetName,
                CheckQualifiedApiName__c = checkName,
                Status__c = status,
                Severity__c = severity,
                Source__c = source,
                RunCount__c = runCount,
                ResultCount__c = resultCount,
                RecordCount__c = recordIds.size(),
                PassedCount__c = passedCount,
                FailedCount__c = failedCount,
                SkippedCount__c = skippedCount,
                UnableCount__c = unableCount,
                SystemErrorCount__c = systemErrorCount,
                RecurringFailureCount__c = recurringFailureCount,
                RecoveryCount__c = recoveryCount
            );
        }
    }
    public class RHCReportsAggregationException extends Exception {}
}
