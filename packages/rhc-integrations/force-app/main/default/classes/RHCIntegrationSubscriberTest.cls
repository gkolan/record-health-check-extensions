@IsTest
private class RHCIntegrationSubscriberTest {
    @IsTest
    static void shouldSubscribeDirectlyToCanonicalRunResultAndLogEvents() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<Record_Health_Check_Integration_Route__c>{
                route('Result Route', 'RESULT', 'CHECK', 'Check_One', 'ERROR', 'CRITICAL', 'RHC Error v1'),
                route('Run Route', 'RUN', 'CHECK_SET', 'Set_One', 'ERROR', null, 'RHC Run v1'),
                route('Log Route', 'LOG', 'CHECK_SET', 'Set_One', 'ERROR', null, 'RHC Log v1')
            };
            Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(200, '{}'));
            Test.startTest();
            EventBus.publish(new Record_Health_Check_Result__e(
                EventId__c = 'result-event', RunId__c = 'run-001',
                CheckSetQualifiedApiName__c = 'Set_One', CheckQualifiedApiName__c = 'Check_One',
                Status__c = 'ERROR', Severity__c = 'CRITICAL', OccurredAt__c = System.now(),
                Source__c = 'APEX_API', ContractVersion__c = '1.0', FrameworkVersion__c = '2.0.4'
            ));
            EventBus.publish(new Record_Health_Check_Set_Run__e(
                EventId__c = 'run-event', RunId__c = 'run-001', Phase__c = 'COMPLETED',
                CheckSetQualifiedApiName__c = 'Set_One', OccurredAt__c = System.now(),
                Source__c = 'APEX_API', ContractVersion__c = '1.0', FrameworkVersion__c = '2.0.4',
                EligibleCheckCount__c = 1, EvaluatedCheckCount__c = 1, PassedCount__c = 0,
                FailedCount__c = 0, SkippedCount__c = 0, UnableCount__c = 0, SystemErrorCount__c = 1
            ));
            EventBus.publish(new Record_Health_Check_Log__e(
                EventId__c = 'log-event', RunId__c = 'run-001', OccurredAt__c = System.now(),
                Level__c = 'ERROR', Code__c = 'TEST_ERROR', CheckSetDeveloperName__c = 'Set_One',
                ContractVersion__c = '1.0', FrameworkVersion__c = '2.0.4',
                Message__c = 'must not leave Salesforce', StackTrace__c = 'must not leave Salesforce',
                DetailsJson__c = '{"restricted":true}'
            ));
            Test.getEventBus().deliver();
            Test.stopTest();

            List<Record_Health_Check_Integration_Delivery__c> deliveries = [
                SELECT EventType__c, Status__c, Payload__c FROM Record_Health_Check_Integration_Delivery__c
            ];
            Assert.areEqual(3, deliveries.size(), 'Each canonical core event should be subscribed directly');
            for (Record_Health_Check_Integration_Delivery__c delivery : deliveries) {
                Assert.areEqual('SUCCEEDED', delivery.Status__c, 'Each mocked callout should succeed');
                Assert.isFalse(delivery.Payload__c.contains('must not leave Salesforce'),
                    'Raw Log diagnostics must be excluded from all profiles');
                Assert.isFalse(delivery.Payload__c.contains('restricted'),
                    'Structured diagnostic payloads must be excluded');
            }
        }
    }

    @IsTest
    static void shouldCheckpointAndPersistAcrossResultChunkBoundary() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert route(
                'Chunked Result Route',
                'RESULT',
                'CHECK',
                'Check_One',
                'ERROR',
                'CRITICAL',
                'RHC Error v1'
            );
            List<Record_Health_Check_Result__e> events = new List<Record_Health_Check_Result__e>();
            for (Integer index = 0; index < 51; index++) {
                events.add(new Record_Health_Check_Result__e(
                    EventId__c = 'chunk-event-' + index,
                    RunId__c = 'chunk-run',
                    CheckSetQualifiedApiName__c = 'Set_One',
                    CheckQualifiedApiName__c = 'Check_One',
                    Status__c = 'ERROR',
                    Severity__c = 'CRITICAL',
                    OccurredAt__c = System.now(),
                    Source__c = 'APEX_API',
                    ContractVersion__c = '1.0',
                    FrameworkVersion__c = '2.0.4'
                ));
            }
            Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(200, '{}'));

            Test.startTest();
            EventBus.publish(events);
            Test.getEventBus().deliver();
            Test.stopTest();

            Assert.areEqual(
                51,
                [SELECT COUNT() FROM Record_Health_Check_Integration_Delivery__c],
                'A subscriber batch crossing the 50-event boundary must retain every idempotent claim'
            );
        }
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static Record_Health_Check_Integration_Route__c route(
        String name,
        String eventType,
        String selectionType,
        String identity,
        String status,
        String minimumSeverity,
        String profile
    ) {
        return new Record_Health_Check_Integration_Route__c(
            Name = name, Active__c = true, EventTypes__c = eventType,
            SelectionType__c = selectionType, QualifiedApiName__c = identity,
            Statuses__c = status, MinimumSeverity__c = minimumSeverity,
            NamedCredential__c = 'Service_Management', RelativeEndpoint__c = '/api/incidents',
            PayloadProfile__c = profile, RetryPolicy__c = 'STANDARD'
        );
    }
}
