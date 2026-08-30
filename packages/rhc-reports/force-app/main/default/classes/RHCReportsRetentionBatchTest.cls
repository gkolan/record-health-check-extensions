@isTest
private class RHCReportsRetentionBatchTest {
    @isTest
    static void shouldDeleteExpiredResults_WhenBatchRuns() {
        insert RHCReportsTestDataFactory.resultFact(
            'expired-result',
            'FAIL',
            Datetime.now().addDays(-100),
            '006000000000001AAA',
            'Close_Date_Complete'
        );
        insert RHCReportsTestDataFactory.resultFact(
            'current-result',
            'PASS',
            Datetime.now(),
            '006000000000001AAA',
            'Close_Date_Complete'
        );
        Test.startTest();
        Database.executeBatch(
            new RHCReportsRetentionBatch(
                'RESULT',
                Datetime.now().addDays(-90),
                Date.today().addDays(-730),
                RHCReportsRetentionBatch.ContinuationMode.DISABLED
            ),
            200
        );
        Test.stopTest();
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Report_Result__c],
            'Only the current Result Fact should remain.'
        );
    }
    @isTest
    static void shouldDeleteExpiredRuns_WhenBatchRuns() {
        insert RHCReportsTestDataFactory.runFact(
            'expired-run',
            Datetime.now().addDays(-100)
        );
        insert RHCReportsTestDataFactory.runFact('current-run', Datetime.now());
        Test.startTest();
        Database.executeBatch(
            new RHCReportsRetentionBatch(
                'RUN',
                Datetime.now().addDays(-90),
                Date.today().addDays(-730),
                RHCReportsRetentionBatch.ContinuationMode.DISABLED
            ),
            200
        );
        Test.stopTest();
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Report_Run__c],
            'Only the current Run Fact should remain.'
        );
    }
    @isTest
    static void shouldDeleteExpiredSnapshots_WhenBatchRuns() {
        insert new List<Record_Health_Check_Daily_Snapshot__c>{
            snapshot('expired-snapshot', Date.today().addDays(-800)),
            snapshot('current-snapshot', Date.today())
        };
        Test.startTest();
        Database.executeBatch(
            new RHCReportsRetentionBatch(
                'SNAPSHOT',
                Datetime.now().addDays(-90),
                Date.today().addDays(-730),
                RHCReportsRetentionBatch.ContinuationMode.DISABLED
            ),
            200
        );
        Test.stopTest();
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Daily_Snapshot__c],
            'Only the current snapshot should remain.'
        );
    }
    @isTest
    static void shouldDefineCompleteRetentionChain() {
        Assert.areEqual(
            'RUN',
            RHCReportsRetentionBatch.nextTargetName('RESULT'),
            'Result cleanup must continue to Run cleanup.'
        );
        Assert.areEqual(
            'SNAPSHOT',
            RHCReportsRetentionBatch.nextTargetName('RUN'),
            'Run cleanup must continue to Snapshot cleanup.'
        );
        Assert.isNull(
            RHCReportsRetentionBatch.nextTargetName('SNAPSHOT'),
            'Snapshot cleanup must terminate the chain.'
        );
    }
    private static Record_Health_Check_Daily_Snapshot__c snapshot(
        String key,
        Date snapshotDate
    ) {
        return new Record_Health_Check_Daily_Snapshot__c(
            SnapshotKey__c = key,
            SnapshotDate__c = snapshotDate,
            AggregationTimeZone__c = 'GMT',
            Grain__c = 'RUN',
            CheckSetQualifiedApiName__c = 'Opportunity_Close_Readiness',
            Source__c = 'BATCH'
        );
    }
}
