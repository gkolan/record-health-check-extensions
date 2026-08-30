@isTest
private class RHCReportsIngestionServiceTest {
    @isTest
    static void shouldDeduplicateRuns_WhenBulkDeliveryRepeatsEventIds() {
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
    @isTest
    static void shouldDeduplicateResults_WhenPlatformEventIsDeliveredTwice() {
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

    @isTest
    static void shouldPersistRun_WhenPlatformEventSubscriberExecutes() {
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
    @isTest
    static void shouldIgnoreRestrictedAndUnsupportedResults_WhenReceived() {
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
    @isTest
    static void shouldIgnoreNullAndEmptyInputs_WhenCalled() {
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

    @isTest
    static void shouldRejectAcceptedEvent_WhenRequiredFactFieldIsMissing() {
        Record_Health_Check_Result__e invalidEvent =
            RHCReportsTestDataFactory.resultEvent(
                'invalid-result-event',
                'FAIL',
                Datetime.now()
            );
        invalidEvent.FrameworkVersion__c = null;

        Test.startTest();
        try {
            RHCReportsIngestionService.ingestResults(
                new List<Record_Health_Check_Result__e>{ invalidEvent }
            );
            Assert.fail('A failed fact upsert must not be treated as successful ingestion.');
        } catch (RHCReportsIngestionService.RHCReportsIngestionException error) {
            Assert.isTrue(
                error.getMessage().contains('Unable to persist 1 Result Facts'),
                'The exception must identify the failed fact type and count.'
            );
        }
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Report_Result__c],
            'A failed accepted event must not leave a partial fact behind.'
        );
    }

    @isTest
    static void shouldClassifyOnlyTransientStatusSetsAsRetryable() {
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
