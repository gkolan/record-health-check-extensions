@isTest
private class RHCReportsAggregationServiceTest {
    @isTest
    static void shouldUpsertRetrySafeSnapshots_WithRecoveryAndRecurringFailure() {
        Date targetDate = Date.newInstance(2026, 8, 20);
        Datetime prior = Datetime.newInstanceGMT(2026, 8, 19, 12, 0, 0);
        Datetime current = Datetime.newInstanceGMT(2026, 8, 20, 12, 0, 0);
        insert new List<Record_Health_Check_Report_Result__c>{
            RHCReportsTestDataFactory.resultFact(
                'prior-recovery', 'FAIL', prior, RHCReportsTestDataFactory.fakeId(Opportunity.SObjectType, 1), 'Close_Date_Complete'
            ),
            RHCReportsTestDataFactory.resultFact(
                'prior-recurring', 'FAIL', prior, RHCReportsTestDataFactory.fakeId(Opportunity.SObjectType, 2), 'Close_Date_Complete'
            ),
            RHCReportsTestDataFactory.resultFact(
                'current-recovery', 'PASS', current, RHCReportsTestDataFactory.fakeId(Opportunity.SObjectType, 1), 'Close_Date_Complete'
            ),
            RHCReportsTestDataFactory.resultFact(
                'current-recurring', 'FAIL', current, RHCReportsTestDataFactory.fakeId(Opportunity.SObjectType, 2), 'Close_Date_Complete'
            )
        };
        insert RHCReportsTestDataFactory.runFact('target-run', current);
        insert new Record_Health_Check_Daily_Snapshot__c(
            SnapshotKey__c = 'obsolete-snapshot-key',
            SnapshotDate__c = targetDate,
            AggregationTimeZone__c = 'GMT',
            Grain__c = 'RESULT',
            CheckSetQualifiedApiName__c = 'Obsolete_Check_Set',
            CheckQualifiedApiName__c = 'Obsolete_Check',
            Status__c = 'FAIL',
            Severity__c = 'WARNING',
            Source__c = 'BATCH'
        );
        Test.startTest();
        RHCReportsAggregationService.aggregateDate(targetDate, 'GMT');
        RHCReportsAggregationService.aggregateDate(targetDate, 'GMT');
        Test.stopTest();
        List<Record_Health_Check_Daily_Snapshot__c> snapshots = [
            SELECT Grain__c, Status__c, RunCount__c, ResultCount__c,
                RecoveryCount__c, RecurringFailureCount__c,
                FailedCount__c, UnableCount__c
            FROM Record_Health_Check_Daily_Snapshot__c
            WHERE SnapshotDate__c = :targetDate
        ];
        Assert.areEqual(
            3,
            snapshots.size(),
            'Retrying the same date must replace the partition and remove obsolete rows.'
        );
        Map<String, Record_Health_Check_Daily_Snapshot__c> byGrainStatus =
            new Map<String, Record_Health_Check_Daily_Snapshot__c>();
        for (Record_Health_Check_Daily_Snapshot__c snapshot : snapshots) {
            byGrainStatus.put(
                snapshot.Grain__c + ':' + String.valueOf(snapshot.Status__c),
                snapshot
            );
        }
        Assert.areEqual(
            1,
            byGrainStatus.get('RESULT:PASS').RecoveryCount__c,
            'A PASS after an actionable prior outcome is one recovery.'
        );
        Assert.areEqual(
            1,
            byGrainStatus.get('RESULT:FAIL').RecurringFailureCount__c,
            'An actionable result after an actionable prior outcome is recurring.'
        );
        Assert.areEqual(
            1,
            byGrainStatus.get('RUN:null').RunCount__c,
            'The run summary aggregate must not double on retry.'
        );
    }
    @isTest
    static void shouldRejectUnknownTimeZone_WhenAggregating() {
        Test.startTest();
        try {
            RHCReportsAggregationService.aggregateDate(
                Date.newInstance(2026, 8, 20),
                'Not/A_Time_Zone'
            );
            Assert.fail('Unknown time zone should be rejected.');
        } catch (RHCReportsAggregationService.RHCReportsAggregationException error) {
            Assert.isTrue(
                error.getMessage().contains('Unknown time zone'),
                'The error must identify the invalid time zone.'
            );
        }
        Test.stopTest();
    }
    @isTest
    static void shouldRejectNullDate_WhenAggregating() {
        Test.startTest();
        try {
            RHCReportsAggregationService.aggregateDate(null, 'GMT');
            Assert.fail('Null date should be rejected.');
        } catch (RHCReportsAggregationService.RHCReportsAggregationException error) {
            Assert.isTrue(
                error.getMessage().contains('required'),
                'The error must explain required aggregation inputs.'
            );
        }
        Test.stopTest();
    }

    @isTest
    static void shouldUseExactLocalDayBoundaries_WhenZoneHasDaylightOffset() {
        Date targetDate = Date.newInstance(2026, 8, 20);
        insert new List<Record_Health_Check_Report_Run__c>{
            RHCReportsTestDataFactory.runFact(
                'before-local-day',
                Datetime.newInstanceGMT(2026, 8, 20, 4, 59, 59)
            ),
            RHCReportsTestDataFactory.runFact(
                'at-local-day-start',
                Datetime.newInstanceGMT(2026, 8, 20, 5, 0, 0)
            ),
            RHCReportsTestDataFactory.runFact(
                'before-next-local-day',
                Datetime.newInstanceGMT(2026, 8, 21, 4, 59, 59)
            ),
            RHCReportsTestDataFactory.runFact(
                'at-next-local-day',
                Datetime.newInstanceGMT(2026, 8, 21, 5, 0, 0)
            )
        };

        Test.startTest();
        RHCReportsAggregationService.aggregateDate(targetDate, 'America/Chicago');
        Test.stopTest();

        Record_Health_Check_Daily_Snapshot__c runSnapshot = [
            SELECT RunCount__c
            FROM Record_Health_Check_Daily_Snapshot__c
            WHERE SnapshotDate__c = :targetDate AND Grain__c = 'RUN'
            LIMIT 1
        ];
        Assert.areEqual(
            2,
            runSnapshot.RunCount__c,
            'Only events inside the exact Chicago local day should be aggregated.'
        );
    }

    @isTest
    static void shouldFailClosed_WhenAQueryReachesItsSafetyBoundary() {
        Test.startTest();
        try {
            RHCReportsAggregationService.assertQueryComplete(20000, 20000, 'Result Fact');
            Assert.fail('A boundary-sized result must not produce a partial snapshot.');
        } catch (RHCReportsAggregationService.RHCReportsAggregationException error) {
            Assert.isTrue(
                error.getMessage().contains('No partial snapshot was written'),
                'The failure must state that the partition was preserved.'
            );
        }
        RHCReportsAggregationService.assertQueryComplete(19999, 20000, 'Result Fact');
        Test.stopTest();
    }
}
