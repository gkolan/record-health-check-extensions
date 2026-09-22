/**
 * Recomputes one local reporting day and upserts deterministic daily snapshots.
 */
public inherited sharing class RHCReportsAggregationService {
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
        AggregationWindow window = new AggregationWindow(snapshotDate, timeZoneId);
        List<Record_Health_Check_Report_Run__c> runs =
            RHCReportsAggregationRepository.selectRuns(window.startAt, window.endAt);
        List<Record_Health_Check_Report_Result__c> results =
            RHCReportsAggregationRepository.selectResults(window.startAt, window.endAt);
        ResultKeyIndex resultKeys = new ResultKeyIndex(results);
        resultKeys.priorStatusByRecordCheck =
            RHCReportsAggregationRepository.selectPriorStatuses(
                window.startAt,
                resultKeys.recordIds,
                resultKeys.checkNames
            );
        Map<String, SnapshotAccumulator> accumulators =
            new Map<String, SnapshotAccumulator>();
        accumulateRuns(accumulators, window, runs);
        accumulateResults(
            accumulators,
            window,
            resultKeys
        );
        RHCReportsAggregationRepository.replaceSnapshotPartition(
            window.snapshotDate,
            window.timeZoneId,
            recordsFrom(accumulators.values())
        );
    }

    private static void accumulateRuns(
        Map<String, SnapshotAccumulator> accumulators,
        AggregationWindow window,
        List<Record_Health_Check_Report_Run__c> runs
    ) {
        for (Record_Health_Check_Report_Run__c run : runs) {
            SnapshotDimension dimension = dimensionForRun(run);
            SnapshotAccumulator accumulator = getAccumulator(
                accumulators,
                window,
                dimension
            );
            accumulator.runCount++;
            accumulator.recordIds.add(run.RecordId__c);
            accumulator.passedCount += integerValue(run.PassedCount__c);
            accumulator.failedCount += integerValue(run.FailedCount__c);
            accumulator.skippedCount += integerValue(run.SkippedCount__c);
            accumulator.unableCount += integerValue(run.UnableCount__c);
            accumulator.systemErrorCount += integerValue(run.SystemErrorCount__c);
        }
    }

    private static void accumulateResults(
        Map<String, SnapshotAccumulator> accumulators,
        AggregationWindow window,
        ResultKeyIndex resultKeys
    ) {
        for (Record_Health_Check_Report_Result__c result : resultKeys.results) {
            SnapshotDimension dimension = dimensionForResult(result);
            SnapshotAccumulator accumulator = getAccumulator(
                accumulators,
                window,
                dimension
            );
            accumulator.resultCount++;
            accumulator.recordIds.add(result.RecordId__c);
            addStatusCount(accumulator, result.Status__c);
            String recordCheckKey = recordCheckKey(
                result.RecordId__c,
                result.CheckQualifiedApiName__c
            );
            String priorStatus = resultKeys.priorStatusByRecordCheck.get(
                recordCheckKey
            );
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
            resultKeys.priorStatusByRecordCheck.put(
                recordCheckKey,
                result.Status__c
            );
        }
    }

    private static List<Record_Health_Check_Daily_Snapshot__c> recordsFrom(
        List<SnapshotAccumulator> accumulators
    ) {
        List<Record_Health_Check_Daily_Snapshot__c> snapshots =
            new List<Record_Health_Check_Daily_Snapshot__c>();
        for (SnapshotAccumulator accumulator : accumulators) {
            snapshots.add(accumulator.toRecord());
        }
        return snapshots;
    }

    private static SnapshotAccumulator getAccumulator(
        Map<String, SnapshotAccumulator> accumulators,
        AggregationWindow window,
        SnapshotDimension dimension
    ) {
        String groupKey = dimension.key();
        if (!accumulators.containsKey(groupKey)) {
            accumulators.put(
                groupKey,
                new SnapshotAccumulator(window, dimension)
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
    private static SnapshotDimension dimensionForRun(
        Record_Health_Check_Report_Run__c run
    ) {
        SnapshotDimension dimension = new SnapshotDimension();
        dimension.grain = 'RUN';
        dimension.checkSetName = run.CheckSetQualifiedApiName__c;
        dimension.source = run.Source__c;
        return dimension;
    }
    private static SnapshotDimension dimensionForResult(
        Record_Health_Check_Report_Result__c result
    ) {
        SnapshotDimension dimension = new SnapshotDimension();
        dimension.grain = 'RESULT';
        dimension.checkSetName = result.CheckSetQualifiedApiName__c;
        dimension.checkName = result.CheckQualifiedApiName__c;
        dimension.status = result.Status__c;
        dimension.severity = result.Severity__c;
        dimension.source = result.Source__c;
        return dimension;
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

    private class AggregationWindow {
        private Date snapshotDate;
        private String timeZoneId;
        private Datetime startAt;
        private Datetime endAt;

        private AggregationWindow(Date snapshotDate, String timeZoneId) {
            this.snapshotDate = snapshotDate;
            this.timeZoneId = timeZoneId;
            this.startAt = localMidnightUtc(snapshotDate, timeZoneId);
            this.endAt = localMidnightUtc(snapshotDate.addDays(1), timeZoneId);
        }
    }

    private class ResultKeyIndex {
        private List<Record_Health_Check_Report_Result__c> results;
        private Set<String> recordIds = new Set<String>();
        private Set<String> checkNames = new Set<String>();
        private Map<String, String> priorStatusByRecordCheck =
            new Map<String, String>();

        private ResultKeyIndex(
            List<Record_Health_Check_Report_Result__c> results
        ) {
            this.results = results;
            for (Record_Health_Check_Report_Result__c result : results) {
                if (String.isNotBlank(result.RecordId__c)) {
                    recordIds.add(result.RecordId__c);
                }
                checkNames.add(result.CheckQualifiedApiName__c);
            }
        }
    }

    private class SnapshotDimension {
        private String grain;
        private String checkSetName;
        private String checkName;
        private String status;
        private String severity;
        private String source;

        private String key() {
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
    }

    private class SnapshotAccumulator {
        private AggregationWindow window;
        private SnapshotDimension dimension;
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
            AggregationWindow window,
            SnapshotDimension dimension
        ) {
            this.window = window;
            this.dimension = dimension;
        }
        private Record_Health_Check_Daily_Snapshot__c toRecord() {
            String identity = String.valueOf(window.snapshotDate) +
                '|' +
                window.timeZoneId +
                '|' +
                dimension.key();
            String snapshotKey = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(identity))
            );
            return new Record_Health_Check_Daily_Snapshot__c(
                SnapshotKey__c = snapshotKey,
                SnapshotDate__c = window.snapshotDate,
                AggregationTimeZone__c = window.timeZoneId,
                Grain__c = dimension.grain,
                CheckSetQualifiedApiName__c = dimension.checkSetName,
                CheckQualifiedApiName__c = dimension.checkName,
                Status__c = dimension.status,
                Severity__c = dimension.severity,
                Source__c = dimension.source,
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
    /** Signals a bounded, retry-safe aggregation failure. */
    public class RHCReportsAggregationException extends Exception {}
}
