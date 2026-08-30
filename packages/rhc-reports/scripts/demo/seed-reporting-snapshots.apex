// Seeds deterministic historical aggregates so packaged reports and dashboards are useful immediately.
// These are explicitly synthetic snapshots; this script does not test the aggregation engine.
String checkSetName = 'Opportunity_Close_Readiness';
String timeZoneId = 'America/Chicago';
List<String> sources = new List<String>{
    'USER_INITIATED', 'FLOW', 'BATCH', 'QUEUEABLE', 'SCHEDULED', 'APEX_API'
};
List<rhc__Record_Health_Check_Daily_Snapshot__c> snapshots =
    new List<rhc__Record_Health_Check_Daily_Snapshot__c>();

for (Integer weekIndex = 5; weekIndex >= 0; weekIndex--) {
    // Keep seeded report-only days separate from yesterday's real aggregation test.
    Date snapshotDate = Date.today().addDays(-(weekIndex * 7 + 2));
    String source = sources[Math.mod(weekIndex, sources.size())];
    Integer passed = 14 - weekIndex;
    Integer failed = 4 + weekIndex;
    Integer unable = weekIndex % 2;
    Integer systemError = weekIndex == 4 || weekIndex == 1 ? 1 : 0;

    String runGroup = 'RUN|' + checkSetName + '||||' + source;
    String runIdentity = String.valueOf(snapshotDate) + '|' + timeZoneId + '|' + runGroup;
    snapshots.add(new rhc__Record_Health_Check_Daily_Snapshot__c(
        rhc__SnapshotKey__c = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(runIdentity))
        ),
        rhc__SnapshotDate__c = snapshotDate,
        rhc__AggregationTimeZone__c = timeZoneId,
        rhc__Grain__c = 'RUN',
        rhc__CheckSetQualifiedApiName__c = checkSetName,
        rhc__Source__c = source,
        rhc__RunCount__c = 4,
        rhc__RecordCount__c = 4,
        rhc__PassedCount__c = passed,
        rhc__FailedCount__c = failed,
        rhc__SkippedCount__c = 0,
        rhc__UnableCount__c = unable,
        rhc__SystemErrorCount__c = systemError,
        rhc__ResultCount__c = 0,
        rhc__RecurringFailureCount__c = 0,
        rhc__RecoveryCount__c = 0
    ));

    List<Map<String, Object>> resultShapes = new List<Map<String, Object>>{
        new Map<String, Object>{
            'check' => 'Opportunity_Close_Date_Current', 'status' => 'FAIL',
            'severity' => 'WARNING', 'count' => 2 + weekIndex,
            'recurring' => 1 + Math.mod(weekIndex, 2), 'recovery' => 0
        },
        new Map<String, Object>{
            'check' => 'Opportunity_Amount_Positive', 'status' => 'PASS',
            'severity' => null, 'count' => 3,
            'recurring' => 0, 'recovery' => weekIndex < 3 ? 1 : 0
        },
        new Map<String, Object>{
            'check' => 'Opportunity_Probability_Meaningful', 'status' => 'ERROR',
            'severity' => null, 'count' => systemError,
            'recurring' => 0, 'recovery' => 0
        },
        new Map<String, Object>{
            'check' => 'Opportunity_Next_Step_Documented',
            'status' => 'UNABLE_TO_EVALUATE', 'severity' => null,
            'count' => unable, 'recurring' => 0, 'recovery' => 0
        }
    };
    for (Map<String, Object> shape : resultShapes) {
        Integer resultCount = (Integer) shape.get('count');
        if (resultCount == 0) continue;
        String status = (String) shape.get('status');
        String severity = (String) shape.get('severity');
        String resultGroup = String.join(new List<String>{
            'RESULT', checkSetName, (String) shape.get('check'), status,
            severity == null ? '' : severity, source
        }, '|');
        String resultIdentity = String.valueOf(snapshotDate) + '|' +
            timeZoneId + '|' + resultGroup;
        rhc__Record_Health_Check_Daily_Snapshot__c resultSnapshot =
            new rhc__Record_Health_Check_Daily_Snapshot__c(
                rhc__SnapshotKey__c = EncodingUtil.convertToHex(
                    Crypto.generateDigest('SHA-256', Blob.valueOf(resultIdentity))
                ),
                rhc__SnapshotDate__c = snapshotDate,
                rhc__AggregationTimeZone__c = timeZoneId,
                rhc__Grain__c = 'RESULT',
                rhc__CheckSetQualifiedApiName__c = checkSetName,
                rhc__CheckQualifiedApiName__c = (String) shape.get('check'),
                rhc__Status__c = status,
                rhc__Severity__c = severity,
                rhc__Source__c = source,
                rhc__RunCount__c = 0,
                rhc__ResultCount__c = resultCount,
                rhc__RecordCount__c = Math.min(4, resultCount),
                rhc__PassedCount__c = status == 'PASS' ? resultCount : 0,
                rhc__FailedCount__c = status == 'FAIL' ? resultCount : 0,
                rhc__SkippedCount__c = 0,
                rhc__UnableCount__c = status == 'UNABLE_TO_EVALUATE' ? resultCount : 0,
                rhc__SystemErrorCount__c = status == 'ERROR' ? resultCount : 0,
                rhc__RecurringFailureCount__c = (Integer) shape.get('recurring'),
                rhc__RecoveryCount__c = (Integer) shape.get('recovery')
            );
        snapshots.add(resultSnapshot);
    }
}

List<Database.UpsertResult> results = Database.upsert(
    snapshots,
    rhc__Record_Health_Check_Daily_Snapshot__c.Fields.rhc__SnapshotKey__c,
    false
);
Integer failures = 0;
for (Database.UpsertResult result : results) {
    if (!result.isSuccess()) failures++;
}
if (failures > 0) {
    throw new IllegalArgumentException('One or more synthetic snapshots could not be seeded.');
}
System.debug(LoggingLevel.INFO, 'Synthetic RHC Reports snapshots upserted=' + snapshots.size());
