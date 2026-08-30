@isTest
private class RHCReportsMaintenanceTest {
    @isTest
    static void shouldRecordCompletedDate_WhenAggregationQueueableRuns() {
        Date snapshotDate = Date.today().addDays(-1);

        Test.startTest();
        System.enqueueJob(
            new RHCReportsDailyAggregationQueueable(snapshotDate, 'GMT')
        );
        Test.stopTest();

        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        Assert.areEqual(
            snapshotDate,
            setting.LastAggregatedDate__c,
            'A completed retry-safe aggregation must record its local date.'
        );
        Assert.areEqual(
            'SUCCESS',
            setting.LastAggregationStatus__c,
            'The Queueable Finalizer must persist a durable success outcome.'
        );
        Assert.isNotNull(
            setting.LastAggregationAttemptAt__c,
            'The Queueable Finalizer must record the latest attempt time.'
        );
    }

    @isTest
    static void shouldExitWithoutAsyncWork_WhenMaintenanceIsDisabled() {
        upsert new Record_Health_Check_Report_Setting__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            DailyAggregationEnabled__c = false,
            RetentionCleanupEnabled__c = false,
            AggregationTimeZone__c = 'GMT'
        );

        Test.startTest();
        new RHCReportsMaintenanceScheduled().execute(null);
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT COUNT() FROM AsyncApexJob WHERE JobType IN ('BatchApex', 'Queueable')],
            'Disabled maintenance must not consume asynchronous-job limits.'
        );
    }

    @isTest
    static void shouldNotRegressCompletedWatermark_WhenOlderDayIsRecomputed() {
        Date currentWatermark = Date.today().addDays(-1);
        upsert new Record_Health_Check_Report_Setting__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            LastAggregatedDate__c = currentWatermark,
            RetentionCleanupEnabled__c = false
        );

        Test.startTest();
        System.enqueueJob(
            new RHCReportsDailyAggregationQueueable(
                currentWatermark.addDays(-7),
                'GMT'
            )
        );
        Test.stopTest();

        Assert.areEqual(
            currentWatermark,
            Record_Health_Check_Report_Setting__c.getOrgDefaults().LastAggregatedDate__c,
            'A manual historical recompute must not move the catch-up watermark backward.'
        );
    }

    @isTest
    static void shouldResumeAfterLastCompletedDate_WhenMaintenanceHasGap() {
        Date latestCompletedDate = Date.valueOf(
            Datetime.now().format('yyyy-MM-dd', 'GMT')
        ).addDays(-1);
        Date lastCompletedDate = Date.valueOf(
            Datetime.now().format('yyyy-MM-dd', 'GMT')
        ).addDays(-4);
        upsert new Record_Health_Check_Report_Setting__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            DailyAggregationEnabled__c = true,
            RetentionCleanupEnabled__c = true,
            AggregationTimeZone__c = 'GMT',
            LastAggregatedDate__c = lastCompletedDate
        );

        Test.startTest();
        new RHCReportsMaintenanceScheduled().execute(null);
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex'],
            'Retention must not be queued before missed-day aggregation completes.'
        );
        Test.stopTest();

        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        Assert.areEqual(
            latestCompletedDate,
            setting.LastAggregatedDate__c,
            'Catch-up must advance through every missed day to the latest completed date.'
        );
    }

    @isTest
    static void shouldRejectUnknownRetentionTarget_WhenBatchStarts() {
        Test.startTest();
        try {
            new RHCReportsRetentionBatch(
                'UNKNOWN',
                Datetime.now(),
                Date.today()
            ).start(null);
            Assert.fail('Unknown retention target should be rejected.');
        } catch (RHCReportsRetentionBatch.RHCReportsRetentionException error) {
            Assert.isTrue(
                error.getMessage().contains('Unknown retention target'),
                'The error must identify the invalid cleanup target.'
            );
        }
        Test.stopTest();
    }
}
