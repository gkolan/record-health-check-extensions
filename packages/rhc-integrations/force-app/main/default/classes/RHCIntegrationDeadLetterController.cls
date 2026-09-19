/**
 * Permission-gated dead-letter read and replay API for the administrator LWC.
 */
public with sharing class RHCIntegrationDeadLetterController {
    private static final String REPLAY_PERMISSION = 'RHC_Integration_Replay';

    /**
     * @return Up to 200 recent dead-letter rows without payload content.
     */
    @AuraEnabled
    public static List<DeadLetterRow> getDeadLetters() {
        List<DeadLetterRow> rows = new List<DeadLetterRow>();
        for (Record_Health_Check_Integration_Delivery__c delivery : [
            SELECT Id, Name, Route__r.Name, EventId__c, EventType__c,
                AttemptCount__c, ReplayCount__c, HttpStatus__c,
                HttpClassification__c, ErrorCode__c, ErrorDetail__c,
                LastAttemptAt__c, CompletedAt__c
            FROM Record_Health_Check_Integration_Delivery__c
            WHERE Status__c = 'DEAD_LETTER'
            WITH USER_MODE
            ORDER BY CompletedAt__c DESC NULLS LAST
            LIMIT 200
        ]) {
            rows.add(new DeadLetterRow(delivery));
        }
        return rows;
    }

    /**
     * Requeues a dead letter with its original Event ID idempotency key.
     * @param deliveryId Delivery ledger row to replay.
     * @throws AuraHandledException when permission or state checks fail.
    */
    @AuraEnabled
    public static void replay(Id deliveryId) {
        if (deliveryId == null) {
            throw new AuraHandledException('Select a delivery to replay.');
        }
        replayAll(new List<Id>{ deliveryId });
    }

    /**
     * Requeues up to 50 dead letters whose routes are active, in one delivery chain. Rows that are
     * no longer dead letters are skipped; an inactive route in the selection rejects the whole
     * request so nothing is half-replayed against an unfixed endpoint.
     * @param deliveryIds Delivery ledger rows to replay.
     * @return number of deliveries requeued
     */
    @AuraEnabled
    public static Integer replayAll(List<Id> deliveryIds) {
        if (!FeatureManagement.checkPermission(REPLAY_PERMISSION)) {
            throw new AuraHandledException('You do not have permission to replay deliveries.');
        }
        if (deliveryIds == null || deliveryIds.isEmpty() || deliveryIds.contains(null)) {
            throw new AuraHandledException('Select a delivery to replay.');
        }
        if (deliveryIds.size() > MAX_BULK_REPLAY) {
            throw new AuraHandledException('Replay at most ' + MAX_BULK_REPLAY + ' deliveries at once.');
        }
        List<Record_Health_Check_Integration_Delivery__c> deliveries = [
            SELECT Id, Route__c, Route__r.Active__c, Status__c, AttemptCount__c, ReplayCount__c,
                NextAttemptAt__c, CompletedAt__c, HttpStatus__c,
                HttpClassification__c, ErrorCode__c, ErrorDetail__c
            FROM Record_Health_Check_Integration_Delivery__c
            WHERE Id IN :deliveryIds AND Status__c = 'DEAD_LETTER'
            WITH USER_MODE
            FOR UPDATE
        ];
        if (deliveries.isEmpty()) {
            throw new AuraHandledException('Only an accessible dead-letter delivery can be replayed.');
        }
        List<Id> replayIds = new List<Id>();
        for (Record_Health_Check_Integration_Delivery__c delivery : deliveries) {
            if (!delivery.Route__r.Active__c) {
                throw new AuraHandledException('Activate and correct the route before replay.');
            }
            resetForReplay(delivery);
            replayIds.add(delivery.Id);
        }
        // User-mode DML is the explicit CRUD/FLS and sharing sanitizer for the Aura entry point.
        update as user deliveries;
        System.enqueueJob(new RHCIntegrationDeliveryQueueable(replayIds));
        return replayIds.size();
    }

    private static final Integer MAX_BULK_REPLAY = 50;

    private static void resetForReplay(Record_Health_Check_Integration_Delivery__c delivery) {
        delivery.Status__c = 'PENDING';
        delivery.AttemptCount__c = 0;
        delivery.ReplayCount__c = (delivery.ReplayCount__c ?? 0) + 1;
        delivery.NextAttemptAt__c = null;
        delivery.CompletedAt__c = null;
        delivery.HttpStatus__c = null;
        delivery.HttpClassification__c = null;
        delivery.ErrorCode__c = null;
        delivery.ErrorDetail__c = null;
    }

    /** Dead-letter projection deliberately excludes the retained request payload. */
    public class DeadLetterRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String deliveryNumber { get; set; }
        @AuraEnabled public String routeName { get; set; }
        @AuraEnabled public String eventId { get; set; }
        @AuraEnabled public String eventType { get; set; }
        @AuraEnabled public Decimal attemptCount { get; set; }
        @AuraEnabled public Decimal replayCount { get; set; }
        @AuraEnabled public Decimal httpStatus { get; set; }
        @AuraEnabled public String classification { get; set; }
        @AuraEnabled public String errorCode { get; set; }
        @AuraEnabled public String errorDetail { get; set; }
        @AuraEnabled public Datetime lastAttemptAt { get; set; }
        @AuraEnabled public Datetime completedAt { get; set; }

        private DeadLetterRow(Record_Health_Check_Integration_Delivery__c delivery) {
            id = delivery.Id;
            deliveryNumber = delivery.Name;
            routeName = delivery.Route__r.Name;
            eventId = delivery.EventId__c;
            eventType = delivery.EventType__c;
            attemptCount = delivery.AttemptCount__c;
            replayCount = delivery.ReplayCount__c;
            httpStatus = delivery.HttpStatus__c;
            classification = delivery.HttpClassification__c;
            errorCode = delivery.ErrorCode__c;
            errorDetail = delivery.ErrorDetail__c;
            lastAttemptAt = delivery.LastAttemptAt__c;
            completedAt = delivery.CompletedAt__c;
        }
    }
}
