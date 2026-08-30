/**
 * Persists idempotent delivery claims and classifies subscriber-side platform failures.
 */
public with sharing class RHCIntegrationIngestionService {
    /** Raised when a non-duplicate delivery-ledger insert fails permanently. */
    public class IngestionException extends Exception {}

    /** Raised when subscriber work should be redelivered after a transient platform failure. */
    public class TransientIngestionException extends Exception {}

    /** @param deliveries Bounded delivery claims produced from one subscriber chunk. */
    public static void persistAndEnqueue(List<Record_Health_Check_Integration_Delivery__c> deliveries) {
        if (deliveries.isEmpty()) {
            return;
        }
        assertDmlCapacity(deliveries.size());
        InsertOutcomes outcomes = new InsertOutcomes();
        Database.SaveResult[] results = Database.insert(deliveries, false);
        for (Integer index = 0; index < results.size(); index++) {
            collectInsertOutcome(results[index], deliveries[index], outcomes);
        }
        enforceInsertOutcomes(outcomes);
    }

    private static void enforceInsertOutcomes(InsertOutcomes outcomes) {
        if (outcomes.hasTransientFailure) {
            throw new TransientIngestionException(
                'RHC Integrations encountered a transient delivery-ledger failure that requires redelivery.'
            );
        }
        if (!outcomes.permanentFailureCodes.isEmpty()) {
            List<String> orderedFailureCodes = new List<String>(outcomes.permanentFailureCodes);
            orderedFailureCodes.sort();
            throw new IngestionException(
                'RHC Integrations could not persist delivery work. Failure categories: '
                + String.join(orderedFailureCodes, ',')
            );
        }
        if (!outcomes.pendingDeliveryIds.isEmpty()) {
            assertQueueCapacity();
            System.enqueueJob(new RHCIntegrationDeliveryQueueable(outcomes.pendingDeliveryIds));
        }
    }

    private static void assertDmlCapacity(Integer deliveryCount) {
        Integer remainingRows = Limits.getLimitDmlRows() - Limits.getDmlRows();
        Integer remainingStatements = Limits.getLimitDmlStatements() - Limits.getDmlStatements();
        if (deliveryCount > remainingRows || remainingStatements < 1) {
            throw new TransientIngestionException(
                'RHC Integrations reached a safe subscriber DML capacity boundary.'
            );
        }
    }

    private static void assertQueueCapacity() {
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            throw new TransientIngestionException(
                'RHC Integrations reached a safe subscriber asynchronous capacity boundary.'
            );
        }
    }

    private static void collectInsertOutcome(
        Database.SaveResult result,
        Record_Health_Check_Integration_Delivery__c delivery,
        InsertOutcomes outcomes
    ) {
        if (result.isSuccess()) {
            if (delivery.Status__c == 'PENDING') {
                outcomes.pendingDeliveryIds.add(result.getId());
            }
            return;
        }
        if (containsOnlyDuplicateErrors(result.getErrors())) {
            return;
        }
        for (Database.Error errorRecord : result.getErrors()) {
            StatusCode errorStatus = errorRecord.getStatusCode();
            if (errorStatus == StatusCode.DUPLICATE_VALUE) {
                continue;
            }
            if (isRetryable(errorStatus)) {
                outcomes.hasTransientFailure = true;
            } else {
                outcomes.permanentFailureCodes.add(String.valueOf(errorStatus));
            }
        }
    }

    private class InsertOutcomes {
        private List<Id> pendingDeliveryIds = new List<Id>();
        private Set<String> permanentFailureCodes = new Set<String>();
        private Boolean hasTransientFailure = false;
    }

    @TestVisible
    private static Boolean isRetryable(StatusCode errorStatus) {
        return errorStatus == StatusCode.UNABLE_TO_LOCK_ROW
            || errorStatus == StatusCode.UNKNOWN_EXCEPTION;
    }

    private static Boolean containsOnlyDuplicateErrors(Database.Error[] errors) {
        if (errors == null || errors.isEmpty()) {
            return false;
        }
        for (Database.Error errorRecord : errors) {
            if (errorRecord.getStatusCode() != StatusCode.DUPLICATE_VALUE) {
                return false;
            }
        }
        return true;
    }
}
