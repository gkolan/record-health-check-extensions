@IsTest
private class RHCReportsIngestionServiceTest {
    @IsTest
    static void shouldDeduplicateRunsWhenBulkDeliveryRepeatsEventIds() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.rundedup');
        System.runAs(principal) {
        List<Record_Health_Check_Set_Run__e> events =
            new List<Record_Health_Check_Set_Run__e>();
        Datetime occurredAt = Datetime.newInstanceGMT(2026, 8, 20, 12, 0, 0);
        for (Integer index = 0; index < 251; index++) {
            events.add(
                RHCReportsTestDataFactory.runEvent(
                    'run-event-' + index,
                    occurredAt
                )
            );
        }
        events.add(events[0]);
        Test.startTest();
        RHCReportsIngestionService.ingestRuns(events);
        RHCReportsIngestionService.ingestRuns(events);
        Test.stopTest();
        Assert.areEqual(
            251,
            [SELECT COUNT() FROM Record_Health_Check_Report_Run__c],
            'Unique Event IDs must create one Run Fact each across repeated deliveries.'
        );
        }
    }
    @IsTest
    static void shouldDeduplicateResultsWhenPlatformEventIsDeliveredTwice() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.resultdedup');
        System.runAs(principal) {
        Record_Health_Check_Result__e eventRecord =
            RHCReportsTestDataFactory.resultEvent(
                'result-event-1',
                'FAIL',
                Datetime.now()
            );
        Test.startTest();
        EventBus.publish(
            new List<Record_Health_Check_Result__e>{
                eventRecord,
                RHCReportsTestDataFactory.resultEvent(
                    'result-event-1',
                    'FAIL',
                    eventRecord.OccurredAt__c
                )
            }
        );
        Test.getEventBus().deliver();
        Test.stopTest();
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Report_Result__c],
            'Duplicate Result Event IDs must create one Result Fact.'
        );
        }
    }

    @IsTest
    static void shouldPersistRunWhenPlatformEventSubscriberExecutes() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.subscriber');
        System.runAs(principal) {
        Test.startTest();
        EventBus.publish(
            RHCReportsTestDataFactory.runEvent(
                'subscriber-run-event',
                Datetime.now()
            )
        );
        Test.getEventBus().deliver();
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Report_Run__c],
            'The Set Run subscriber must persist the delivered core event.'
        );
        }
    }
    @IsTest
    static void shouldIgnoreRestrictedAndUnsupportedResultsWhenReceived() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.restricted');
        System.runAs(principal) {
        Record_Health_Check_Result__e restricted =
            RHCReportsTestDataFactory.resultEvent(
                'restricted-event',
                'ERROR',
                Datetime.now()
            );
        restricted.ContainsRestrictedDetail__c = true;
        Record_Health_Check_Result__e unsupported =
            RHCReportsTestDataFactory.resultEvent(
                'unsupported-event',
                'FAIL',
                Datetime.now()
            );
        unsupported.ContractVersion__c = '2.0';
        Test.startTest();
        RHCReportsIngestionService.ingestResults(
            new List<Record_Health_Check_Result__e>{ restricted, unsupported }
        );
        Test.stopTest();
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Report_Result__c],
            'Restricted detail and unsupported contracts must not be retained.'
        );
        }
    }
    @IsTest
    static void shouldIgnoreNullAndEmptyInputsWhenCalled() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.empty');
        System.runAs(principal) {
        Test.startTest();
        RHCReportsIngestionService.ingestRuns(null);
        RHCReportsIngestionService.ingestRuns(
            new List<Record_Health_Check_Set_Run__e>()
        );
        RHCReportsIngestionService.ingestResults(null);
        RHCReportsIngestionService.ingestResults(
            new List<Record_Health_Check_Result__e>()
        );
        Test.stopTest();
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Report_Run__c],
            'Empty calls must not write facts.'
        );
        }
    }

    @IsTest
    static void shouldRecordEvidenceAndContinueWhenRequiredFactFieldIsMissing() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.evidence');
        System.runAs(principal) {
        Record_Health_Check_Result__e invalidEvent =
            RHCReportsTestDataFactory.resultEvent(
                'invalid-result-event',
                'FAIL',
                Datetime.now()
            );
        invalidEvent.FrameworkVersion__c = null;
        Record_Health_Check_Result__e validEvent =
            RHCReportsTestDataFactory.resultEvent('valid-result-event', 'FAIL', Datetime.now());

        Test.startTest();
        RHCReportsIngestionService.ingestResults(
            new List<Record_Health_Check_Result__e>{ invalidEvent, validEvent }
        );
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Report_Result__c],
            'The valid fact is kept; the invalid one is dropped without suspending the subscriber.'
        );
        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        Assert.isNotNull(setting.LastIngestionFailureAt__c, 'The failure time is recorded.');
        Assert.isTrue(
            setting.LastIngestionErrorCodes__c.contains('REQUIRED_FIELD_MISSING'),
            'The sanitized status code is recorded: ' + setting.LastIngestionErrorCodes__c
        );
        }
    }

    @IsTest
    static void shouldStopRetryingWhenRedeliveriesAreExhausted() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.retrycap');
        System.runAs(principal) {
        RHCReportsIngestionService.retryCountOverride = 2;
        Assert.isTrue(RHCReportsIngestionService.shouldRetry(), 'Redelivery two is within the bound');
        RHCReportsIngestionService.retryCountOverride = 3;
        Assert.isFalse(RHCReportsIngestionService.shouldRetry(), 'Redelivery three must stop retrying');
        RHCReportsIngestionService.retryCountOverride = null;
        Assert.isTrue(RHCReportsIngestionService.shouldRetry(), 'No trigger context means no retries yet');
        }
    }

    @IsTest
    static void shouldClassifyOnlyTransientStatusSetsAsRetryable() {
        User principal = RHCReportsTestDataFactory.createStandardUser('reports.retrytype');
        System.runAs(principal) {
        Assert.isTrue(
            RHCReportsIngestionService.areAllRetryable(
                new Set<String>{ 'UNABLE_TO_LOCK_ROW', 'SERVER_UNAVAILABLE' }
            ),
            'A batch containing only transient failures should request redelivery.'
        );
        Assert.isFalse(
            RHCReportsIngestionService.areAllRetryable(
                new Set<String>{ 'UNABLE_TO_LOCK_ROW', 'REQUIRED_FIELD_MISSING' }
            ),
            'A permanent validation failure must not enter a futile retry loop.'
        );
        Assert.isFalse(
            RHCReportsIngestionService.areAllRetryable(new Set<String>()),
            'An empty status set is not a retry signal.'
        );
        }
    }
}
