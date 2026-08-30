/**
 * Performs post-commit Named Credential callouts and bounded retry chaining.
 */
public with sharing class RHCIntegrationDeliveryQueueable implements Queueable, Finalizer, Database.AllowsCallouts {
    private List<Id> deliveryIds;
    @TestVisible private Id currentDeliveryId;

    /** @param deliveryIds Ordered ledger rows to deliver. */
    public RHCIntegrationDeliveryQueueable(List<Id> deliveryIds) {
        this.deliveryIds = deliveryIds == null ? new List<Id>() : new List<Id>(deliveryIds);
    }

    /** @param context Queueable execution context. */
    public void execute(QueueableContext context) {
        if (deliveryIds.isEmpty()) {
            return;
        }
        prepareCurrentDelivery();
        if (context != null) {
            System.attachFinalizer(this);
        }
        Record_Health_Check_Integration_Delivery__c delivery = lockCurrentDelivery();
        if (delivery == null || !isDeliverable(delivery)) {
            chain(0);
            return;
        }
        if (isWaitingForRetry(delivery)) {
            deliveryIds.add(delivery.Id);
            chain(deliveryIds.size() == 1 ? 1 : 0);
            return;
        }
        RHCIntegrationDeliveryPolicy.process(delivery);
        finishDelivery(delivery);
    }

    private void prepareCurrentDelivery() {
        currentDeliveryId = deliveryIds[0];
        deliveryIds.remove(0);
    }

    private Record_Health_Check_Integration_Delivery__c lockCurrentDelivery() {
        List<Record_Health_Check_Integration_Delivery__c> records = [
            SELECT Id, EventId__c, Payload__c, Status__c, AttemptCount__c,
                NextAttemptAt__c, Route__r.Active__c, Route__r.NamedCredential__c,
                Route__r.RelativeEndpoint__c, Route__r.RetryPolicy__c
            FROM Record_Health_Check_Integration_Delivery__c
            WHERE Id = :currentDeliveryId
            LIMIT 1
            FOR UPDATE
        ];
        return records.isEmpty() ? null : records[0];
    }

    private static Boolean isDeliverable(Record_Health_Check_Integration_Delivery__c delivery) {
        return delivery.Status__c == 'PENDING' || delivery.Status__c == 'RETRY_WAIT';
    }

    private static Boolean isWaitingForRetry(Record_Health_Check_Integration_Delivery__c delivery) {
        return delivery.NextAttemptAt__c != null && delivery.NextAttemptAt__c > System.now();
    }

    private void finishDelivery(Record_Health_Check_Integration_Delivery__c delivery) {
        if (delivery.Status__c == 'RETRY_WAIT') {
            deliveryIds.add(delivery.Id);
        }
        chain(deliveryIds.size() == 1 && delivery.Status__c == 'RETRY_WAIT'
            ? RHCIntegrationDeliveryPolicy.nextDelayMinutes(
                delivery.Route__r.RetryPolicy__c,
                Integer.valueOf(delivery.AttemptCount__c)
            )
            : 0);
    }

    /**
     * Records an unhandled worker failure and continues independent remaining work.
     * @param context Finalizer execution context supplied by Salesforce.
     */
    public void execute(FinalizerContext context) {
        handleFinalizerResult(context.getResult());
    }

    @TestVisible
    private void handleFinalizerResult(ParentJobResult result) {
        if (result != ParentJobResult.UNHANDLED_EXCEPTION) {
            return;
        }
        if (currentDeliveryId != null) {
            recoverCurrentDelivery();
        }
        chain(0);
    }

    private void recoverCurrentDelivery() {
        List<Record_Health_Check_Integration_Delivery__c> failedDeliveries = [
            SELECT Id, Status__c
            FROM Record_Health_Check_Integration_Delivery__c
            WHERE Id = :currentDeliveryId
            LIMIT 1
            FOR UPDATE
        ];
        if (failedDeliveries.isEmpty() || !isDeliverable(failedDeliveries[0])) {
            return;
        }
        Record_Health_Check_Integration_Delivery__c failedDelivery = failedDeliveries[0];
        RHCIntegrationDeliveryPolicy.markUnhandled(failedDelivery);
        Database.update(failedDelivery, AccessLevel.SYSTEM_MODE);
    }

    private void chain(Integer delayMinutes) {
        if (deliveryIds.isEmpty() || Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new RHCIntegrationDeliveryQueueable(deliveryIds), delayMinutes);
    }
}
