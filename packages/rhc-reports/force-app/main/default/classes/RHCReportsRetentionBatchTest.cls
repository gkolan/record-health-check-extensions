@IsTest
private class RHCReportsRetentionBatchTest {
    @IsTest
    static void shouldDeleteExpiredResultsWhenBatchRuns() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.resultret');
        System.runAs(principal) {
        insert RHCReportsTestDataFactory.resultFact(
            new RHCReportsTestDataFactory.ResultFactRequest(
                'expired-result',
                'FAIL',
                Datetime.now().addDays(-100)
            )
        );
        insert RHCReportsTestDataFactory.resultFact(
            new RHCReportsTestDataFactory.ResultFactRequest(
                'current-result',
                'PASS',
                Datetime.now()
            )
        );
        Test.startTest();
        Database.executeBatch(
            RHCReportsRetentionBatch.withoutContinuation(
                'RESULT',
                Datetime.now().addDays(-90),
                Date.today().addDays(-730)
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
    }
    @IsTest
    static void shouldDeleteExpiredRunsWhenBatchRuns() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.runret');
        System.runAs(principal) {
        insert RHCReportsTestDataFactory.runFact(
            'expired-run',
            Datetime.now().addDays(-100)
        );
        insert RHCReportsTestDataFactory.runFact('current-run', Datetime.now());
        Test.startTest();
        Database.executeBatch(
            RHCReportsRetentionBatch.withoutContinuation(
                'RUN',
                Datetime.now().addDays(-90),
                Date.today().addDays(-730)
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
    }
    @IsTest
    static void shouldDeleteExpiredSnapshotsWhenBatchRuns() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.snapshotret');
        System.runAs(principal) {
        insert new List<Record_Health_Check_Daily_Snapshot__c>{
            snapshot('expired-snapshot', Date.today().addDays(-800)),
            snapshot('current-snapshot', Date.today())
        };
        Test.startTest();
        Database.executeBatch(
            RHCReportsRetentionBatch.withoutContinuation(
                'SNAPSHOT',
                Datetime.now().addDays(-90),
                Date.today().addDays(-730)
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
    }
    @IsTest
    static void shouldDefineCompleteRetentionChain() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.chain');
        System.runAs(principal) {
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
