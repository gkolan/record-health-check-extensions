/**
 * Permission-gated dead-letter read, replay, and retention API for the operations LWC.
 */
public with sharing class RHCIntegrationDeadLetterController {
    private static final String REPLAY_PERMISSION = 'RHC_Integration_Replay';
    private static final Integer MAX_BULK_REPLAY = 50;
    private static final Set<String> REPLAY_UPDATE_FIELDS = new Set<String>{
        'Status__c',
        'AttemptCount__c',
        'ReplayCount__c',
        'NextAttemptAt__c',
        'CompletedAt__c',
        'HttpStatus__c',
        'HttpClassification__c',
        'ErrorCode__c',
        'ErrorDetail__c'
    };

    /**
     * Returns the newest accessible dead-letter deliveries for operational review.
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
        validateReplayRequest(deliveryIds);
        List<Record_Health_Check_Integration_Delivery__c> deliveries = loadReplayDeliveries(deliveryIds);
        if (deliveries.isEmpty()) {
            throw new AuraHandledException('Only an accessible dead-letter delivery can be replayed.');
        }
        List<Id> replayIds = prepareReplayDeliveries(deliveries);
        update as user sanitizeReplayDeliveries(deliveries);
        System.enqueueJob(new RHCIntegrationDeliveryQueueable(replayIds));
        return replayIds.size();
    }

    private static void validateReplayRequest(List<Id> deliveryIds) {
        if (!FeatureManagement.checkPermission(REPLAY_PERMISSION)) {
            throw new AuraHandledException('You do not have permission to replay deliveries.');
        }
        if (deliveryIds == null || deliveryIds.isEmpty() || deliveryIds.contains(null)) {
            throw new AuraHandledException('Select a delivery to replay.');
        }
        if (deliveryIds.size() > MAX_BULK_REPLAY) {
            throw new AuraHandledException('Replay at most ' + MAX_BULK_REPLAY + ' deliveries at once.');
        }
    }

    private static List<Record_Health_Check_Integration_Delivery__c> loadReplayDeliveries(
        List<Id> deliveryIds
    ) {
        return [
            SELECT Id, Route__c, Route__r.Active__c, Status__c, AttemptCount__c, ReplayCount__c,
                NextAttemptAt__c, CompletedAt__c, HttpStatus__c,
                HttpClassification__c, ErrorCode__c, ErrorDetail__c
            FROM Record_Health_Check_Integration_Delivery__c
            WHERE Id IN :deliveryIds AND Status__c = 'DEAD_LETTER'
            WITH USER_MODE
            FOR UPDATE
        ];
    }

    private static List<Id> prepareReplayDeliveries(
        List<Record_Health_Check_Integration_Delivery__c> deliveries
    ) {
        List<Id> replayIds = new List<Id>();
        for (Record_Health_Check_Integration_Delivery__c delivery : deliveries) {
            if (!delivery.Route__r.Active__c) {
                throw new AuraHandledException('Activate and correct the route before replay.');
            }
            resetForReplay(delivery);
            replayIds.add(delivery.Id);
        }
        return replayIds;
    }

    private static List<Record_Health_Check_Integration_Delivery__c> sanitizeReplayDeliveries(
        List<Record_Health_Check_Integration_Delivery__c> deliveries
    ) {
        SObjectAccessDecision accessDecision = Security.stripInaccessible(
            AccessType.UPDATABLE,
            deliveries
        );
        Set<String> removedFields = new Set<String>();
        Map<String, Set<String>> removedFieldsByType = accessDecision.getRemovedFields();
        for (Set<String> fieldsForType : removedFieldsByType.values()) {
            removedFields.addAll(fieldsForType);
        }
        if (containsReplayUpdateField(removedFields)) {
            throw new AuraHandledException('You do not have permission to update replay state.');
        }

        List<Record_Health_Check_Integration_Delivery__c> accessibleDeliveries =
            new List<Record_Health_Check_Integration_Delivery__c>();
        for (SObject record : accessDecision.getRecords()) {
            accessibleDeliveries.add((Record_Health_Check_Integration_Delivery__c) record);
        }
        return accessibleDeliveries;
    }

    private static Boolean containsReplayUpdateField(Set<String> removedFields) {
        for (String replayField : REPLAY_UPDATE_FIELDS) {
            for (String removedField : removedFields) {
                if (removedField == replayField || removedField.endsWith('__' + replayField)) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Loads the package-owned retention policy and the current user's management capability.
     * @return retention settings for the operations interface
     */
    @AuraEnabled
    public static RHCIntegrationRetentionService.Settings getRetentionSettings() {
        return RHCIntegrationRetentionService.getSettings();
    }

    /**
     * Saves the package-owned retention window.
     * @param retentionDays whole days from 1 through 3,650
     */
    @AuraEnabled
    public static void saveRetentionSettings(Integer retentionDays) {
        RHCIntegrationRetentionService.saveSettings(retentionDays);
    }

    /**
     * Deletes one bounded batch of completed terminal deliveries outside the saved window.
     * @return number of Integration Deliveries deleted
     */
    @AuraEnabled
    public static Integer purgeDeliveries() {
        return RHCIntegrationRetentionService.purgeDeliveries();
    }

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
        /** Delivery record identifier. */
        @AuraEnabled public Id id { get; set; }
        /** Human-readable delivery number. */
        @AuraEnabled public String deliveryNumber { get; set; }
        /** Route name associated with the delivery. */
        @AuraEnabled public String routeName { get; set; }
        /** Canonical external idempotency identifier. */
        @AuraEnabled public String eventId { get; set; }
        /** Canonical event type. */
        @AuraEnabled public String eventType { get; set; }
        /** Attempts made in the current delivery sequence. */
        @AuraEnabled public Decimal attemptCount { get; set; }
        /** Number of authorized replay sequences. */
        @AuraEnabled public Decimal replayCount { get; set; }
        /** Last HTTP response status, when available. */
        @AuraEnabled public Decimal httpStatus { get; set; }
        /** Package-owned response classification. */
        @AuraEnabled public String classification { get; set; }
        /** Package-owned bounded error code. */
        @AuraEnabled public String errorCode { get; set; }
        /** Package-owned bounded operator guidance. */
        @AuraEnabled public String errorDetail { get; set; }
        /** Most recent delivery attempt timestamp. */
        @AuraEnabled public Datetime lastAttemptAt { get; set; }
        /** Terminal completion timestamp. */
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
