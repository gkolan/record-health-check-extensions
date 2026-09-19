/**
 * Performs post-commit Named Credential callouts for a bounded slice of deliveries per hop,
 * then chains the remaining work with bounded retry delays.
 */
public with sharing class RHCIntegrationDeliveryQueueable implements Queueable, Finalizer, Database.AllowsCallouts {
    /** Callouts per hop: far below the 100-callout transaction limit, small enough that an unhandled failure resends little. */
    @TestVisible private static final Integer DELIVERIES_PER_HOP = 10;
    private List<Id> deliveryIds;
    @TestVisible private List<Id> currentDeliveryIds = new List<Id>();

    /** @param deliveryIds Ordered ledger rows to deliver. */
    public RHCIntegrationDeliveryQueueable(List<Id> deliveryIds) {
        this.deliveryIds = deliveryIds == null ? new List<Id>() : new List<Id>(deliveryIds);
    }

    /** @param context Queueable execution context. */
    public void execute(QueueableContext context) {
        if (deliveryIds.isEmpty()) {
            return;
        }
        takeCurrentSlice();
        if (context != null) {
            System.attachFinalizer(this);
        }
        // Every callout happens before the single update below: Salesforce forbids a callout
        // after uncommitted DML in the same transaction.
        List<Record_Health_Check_Integration_Delivery__c> processed = new List<Record_Health_Check_Integration_Delivery__c>();
        Integer waitingCount = 0;
        Integer minimumDelay = null;
        for (Record_Health_Check_Integration_Delivery__c delivery : lockCurrentSlice()) {
            if (!isDeliverable(delivery)) {
                continue;
            }
            if (isWaitingForRetry(delivery)) {
                deliveryIds.add(delivery.Id);
                waitingCount++;
                minimumDelay = minimum(minimumDelay, 1);
                continue;
            }
            RHCIntegrationDeliveryPolicy.process(delivery);
            processed.add(delivery);
            if (delivery.Status__c == 'RETRY_WAIT') {
                deliveryIds.add(delivery.Id);
                waitingCount++;
                minimumDelay = minimum(minimumDelay, RHCIntegrationDeliveryPolicy.nextDelayMinutes(
                    delivery.Route__r.RetryPolicy__c,
                    Integer.valueOf(delivery.AttemptCount__c)
                ));
            }
        }
        if (!processed.isEmpty()) {
            Database.update(processed, AccessLevel.SYSTEM_MODE);
        }
        // Delay only when nothing left is deliverable now; otherwise fresh rows keep the chain moving.
        chain(waitingCount == deliveryIds.size() && minimumDelay != null ? minimumDelay : 0);
    }

    private void takeCurrentSlice() {
        currentDeliveryIds = new List<Id>();
        while (!deliveryIds.isEmpty() && currentDeliveryIds.size() < DELIVERIES_PER_HOP) {
            currentDeliveryIds.add(deliveryIds.remove(0));
        }
    }

    private List<Record_Health_Check_Integration_Delivery__c> lockCurrentSlice() {
        Map<Id, Record_Health_Check_Integration_Delivery__c> byId = new Map<Id, Record_Health_Check_Integration_Delivery__c>([
            SELECT Id, EventId__c, Payload__c, Status__c, AttemptCount__c,
                NextAttemptAt__c, Route__r.Active__c, Route__r.NamedCredential__c,
                Route__r.RelativeEndpoint__c, Route__r.RetryPolicy__c
            FROM Record_Health_Check_Integration_Delivery__c
            WHERE Id IN :currentDeliveryIds
            FOR UPDATE
        ]);
        List<Record_Health_Check_Integration_Delivery__c> ordered = new List<Record_Health_Check_Integration_Delivery__c>();
        for (Id deliveryId : currentDeliveryIds) {
            if (byId.containsKey(deliveryId)) {
                ordered.add(byId.get(deliveryId));
            }
        }
        return ordered;
    }

    private static Boolean isDeliverable(Record_Health_Check_Integration_Delivery__c delivery) {
        return delivery.Status__c == 'PENDING' || delivery.Status__c == 'RETRY_WAIT';
    }

    private static Boolean isWaitingForRetry(Record_Health_Check_Integration_Delivery__c delivery) {
        return delivery.NextAttemptAt__c != null && delivery.NextAttemptAt__c > System.now();
    }

    private static Integer minimum(Integer current, Integer candidate) {
        return current == null ? candidate : Math.min(current, candidate);
    }

    /**
     * Records an unhandled worker failure for the in-flight slice and continues independent remaining work.
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
        if (!currentDeliveryIds.isEmpty()) {
            recoverCurrentSlice();
        }
        chain(0);
    }

    // Rows already sent in the failed hop are resent on replay; the Idempotency-Key header keeps
    // the endpoint from creating duplicates.
    private void recoverCurrentSlice() {
        List<Record_Health_Check_Integration_Delivery__c> failedDeliveries = new List<Record_Health_Check_Integration_Delivery__c>();
        for (Record_Health_Check_Integration_Delivery__c delivery : [
            SELECT Id, Status__c
            FROM Record_Health_Check_Integration_Delivery__c
            WHERE Id IN :currentDeliveryIds
            FOR UPDATE
        ]) {
            if (isDeliverable(delivery)) {
                RHCIntegrationDeliveryPolicy.markUnhandled(delivery);
                failedDeliveries.add(delivery);
            }
        }
        if (!failedDeliveries.isEmpty()) {
            Database.update(failedDeliveries, AccessLevel.SYSTEM_MODE);
        }
    }

    private void chain(Integer delayMinutes) {
        if (deliveryIds.isEmpty() || Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new RHCIntegrationDeliveryQueueable(deliveryIds), delayMinutes);
    }
}
