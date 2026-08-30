@isTest
private class RHCIntegrationPayloadBuilderTest {
    @isTest
    static void shouldBuildAllowListedErrorProfileWhenCanonicalErrorProvided() {
        RHCIntegrationEventDTO eventRecord = resultEvent();
        Test.startTest();
        String payload = RHCIntegrationPayloadBuilder.build('RHC Error v1', eventRecord);
        Test.stopTest();
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(payload);
        Assert.areEqual('event-001', body.get('eventId'), 'Event ID should be included');
        Assert.areEqual('CRITICAL', body.get('severity'), 'Canonical severity should be included');
        Assert.isFalse(body.containsKey('stackTrace'), 'Stack traces must never be emitted');
        Assert.isFalse(body.containsKey('detailsJson'), 'Diagnostic payloads must never be emitted');
    }

    @isTest
    static void shouldReturnNullWhenProfileIsNotCompatible() {
        RHCIntegrationEventDTO eventRecord = resultEvent();
        Test.startTest();
        String payload = RHCIntegrationPayloadBuilder.build('RHC Run v1', eventRecord);
        Test.stopTest();
        Assert.isNull(payload, 'An incompatible profile should fail closed');
    }

    private static RHCIntegrationEventDTO resultEvent() {
        RHCIntegrationEventDTO eventRecord = new RHCIntegrationEventDTO();
        eventRecord.eventType = 'RESULT';
        eventRecord.eventId = 'event-001';
        eventRecord.runId = 'run-001';
        eventRecord.checkSetQualifiedApiName = 'Opportunity_Close_Readiness';
        eventRecord.checkQualifiedApiName = 'Close_Date_Is_Ready';
        eventRecord.status = 'ERROR';
        eventRecord.severity = 'CRITICAL';
        eventRecord.contractVersion = '1.0';
        eventRecord.frameworkVersion = '2.0.4';
        eventRecord.occurredAt = System.now();
        return eventRecord;
    }
}
