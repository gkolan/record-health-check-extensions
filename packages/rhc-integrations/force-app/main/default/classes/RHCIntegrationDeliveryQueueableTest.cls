@isTest
private class RHCIntegrationDeliveryQueueableTest {
    @TestSetup
    static void setupTestData() {
        RHCIntegrationTestDataFactory.createExampleRoute();
    }

    @isTest
    static void shouldSendEventIdAndSucceedWhenEndpointReturns202() {
        Record_Health_Check_Integration_Delivery__c delivery = createPendingDelivery();
        Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(202, '{"ignored":"body"}'));
        Test.startTest();
        System.enqueueJob(new RHCIntegrationDeliveryQueueable(new List<Id>{ delivery.Id }));
        Test.stopTest();
        Record_Health_Check_Integration_Delivery__c actual = deliveryById(delivery.Id);
        Assert.areEqual('SUCCEEDED', actual.Status__c, '2xx should mark the delivery successful');
        Assert.areEqual('event-callout', RHCIntegrationHttpMock.capturedRequest.getHeader('Idempotency-Key'),
            'The canonical Event ID should be the external idempotency key');
        Assert.areEqual('callout:Service_Management/api/incidents', RHCIntegrationHttpMock.capturedRequest.getEndpoint(),
            'The endpoint should use only the selected Named Credential plus relative path');
    }

    @isTest
    static void shouldScheduleBoundedRetryWhenEndpointReturns503() {
        Record_Health_Check_Integration_Delivery__c delivery = createPendingDelivery();
        Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(503, '{"secret":"must not persist"}'));
        Test.startTest();
        System.enqueueJob(new RHCIntegrationDeliveryQueueable(new List<Id>{ delivery.Id }));
        Test.stopTest();
        Record_Health_Check_Integration_Delivery__c actual = deliveryById(delivery.Id);
        Assert.areEqual('RETRY_WAIT', actual.Status__c, '503 should be retryable within policy');
        Assert.areEqual(1, actual.AttemptCount__c, 'The first callout should count as one attempt');
        Assert.isNotNull(actual.NextAttemptAt__c, 'A bounded next-attempt time should be stored');
        Assert.isFalse(actual.ErrorDetail__c.contains('secret'), 'Response bodies must never be retained');
    }

    @isTest
    static void shouldDeadLetterImmediatelyWhenEndpointReturnsPermanent400() {
        Record_Health_Check_Integration_Delivery__c delivery = createPendingDelivery();
        Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(400, 'unrestricted response body'));
        Test.startTest();
        System.enqueueJob(new RHCIntegrationDeliveryQueueable(new List<Id>{ delivery.Id }));
        Test.stopTest();
        Record_Health_Check_Integration_Delivery__c actual = deliveryById(delivery.Id);
        Assert.areEqual('DEAD_LETTER', actual.Status__c, 'A permanent 400 should enter the dead-letter queue');
        Assert.areEqual('HTTP_400', actual.ErrorCode__c, 'Only the bounded status classification should persist');
        Assert.isFalse(actual.ErrorDetail__c.contains('unrestricted'), 'The response body should be discarded');
    }

    @isTest
    static void shouldDeadLetterWhenRetryPolicyIsExhausted() {
        Record_Health_Check_Integration_Delivery__c delivery = createPendingDelivery();
        delivery.AttemptCount__c = 2;
        update delivery;
        Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(503, '{}'));
        Test.startTest();
        System.enqueueJob(new RHCIntegrationDeliveryQueueable(new List<Id>{ delivery.Id }));
        Test.stopTest();
        Record_Health_Check_Integration_Delivery__c actual = deliveryById(delivery.Id);
        Assert.areEqual('DEAD_LETTER', actual.Status__c, 'The third Standard attempt should exhaust the policy');
        Assert.areEqual(3, actual.AttemptCount__c, 'Attempts should remain bounded');
    }

    @isTest
    static void shouldDeadLetterCurrentDeliveryWhenWorkerFailsUnhandled() {
        Record_Health_Check_Integration_Delivery__c delivery = createPendingDelivery();
        RHCIntegrationDeliveryQueueable queueable = new RHCIntegrationDeliveryQueueable(new List<Id>());
        queueable.currentDeliveryId = delivery.Id;

        Test.startTest();
        queueable.handleFinalizerResult(ParentJobResult.UNHANDLED_EXCEPTION);
        Test.stopTest();

        Record_Health_Check_Integration_Delivery__c actual = deliveryById(delivery.Id);
        Assert.areEqual('DEAD_LETTER', actual.Status__c,
            'An unhandled worker failure should leave durable terminal evidence');
        Assert.areEqual('QUEUEABLE_UNHANDLED', actual.ErrorCode__c,
            'The finalizer should persist a bounded internal classification');
    }

    @isTest
    static void shouldRejectAuthorityStyleRelativeEndpointWhenRuntimeChecksRoute() {
        Record_Health_Check_Integration_Route__c route = new Record_Health_Check_Integration_Route__c(
            Active__c = true,
            NamedCredential__c = 'Service_Management',
            RelativeEndpoint__c = '//unapproved.example/path'
        );

        Test.startTest();
        Boolean safe = RHCIntegrationDeliveryPolicy.isSafeRoute(route);
        Test.stopTest();

        Assert.isFalse(safe, 'A double-slash authority-style endpoint must fail closed');
    }

    private static Record_Health_Check_Integration_Delivery__c createPendingDelivery() {
        Id routeId = [SELECT Id FROM Record_Health_Check_Integration_Route__c LIMIT 1].Id;
        Record_Health_Check_Integration_Delivery__c delivery = RHCIntegrationTestDataFactory.createDelivery(routeId, 'PENDING');
        delivery.EventId__c = 'event-callout';
        delivery.RouteEventKey__c = String.valueOf(routeId) + ':event-callout';
        update delivery;
        return delivery;
    }

    private static Record_Health_Check_Integration_Delivery__c deliveryById(Id deliveryId) {
        return [
            SELECT Status__c, AttemptCount__c, NextAttemptAt__c,
                ErrorCode__c, ErrorDetail__c
            FROM Record_Health_Check_Integration_Delivery__c WHERE Id = :deliveryId
        ];
    }
}
