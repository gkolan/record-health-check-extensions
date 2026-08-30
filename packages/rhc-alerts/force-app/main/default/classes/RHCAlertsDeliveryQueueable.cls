/** Executes bounded human delivery, chains remaining work, and recovers unhandled failures. */
public inherited sharing class RHCAlertsDeliveryQueueable implements Queueable, Finalizer {
  private static final Integer DELIVERY_SLICE_SIZE = 10;
  private static final Integer MAX_RECOVERY_ROWS = 2000;
  private List<Id> deliveryIds;

  /**
   * Creates a bounded delivery worker.
   * @param deliveryIds Claimed delivery ledger rows.
   */
  public RHCAlertsDeliveryQueueable(List<Id> deliveryIds) {
    this.deliveryIds = deliveryIds == null
      ? new List<Id>()
      : new List<Id>(deliveryIds);
  }

  /**
   * Delivers claims and schedules the package's only retry chain when needed.
   * @param context Queueable execution context used to attach the Finalizer.
   */
  public void execute(QueueableContext context) {
    if (deliveryIds.isEmpty()) {
      return;
    }
    if (context != null) {
      System.attachFinalizer(this);
    }
    Integer finish = Math.min(DELIVERY_SLICE_SIZE, deliveryIds.size());
    List<Id> currentIds = new List<Id>();
    List<Id> nextIds = new List<Id>();
    for (Integer index = 0; index < deliveryIds.size(); index++) {
      if (index < finish) {
        currentIds.add(deliveryIds[index]);
      } else {
        nextIds.add(deliveryIds[index]);
      }
    }
    List<Id> retryIds = RHCAlertsDeliveryService.deliver(currentIds);
    nextIds.addAll(retryIds);
    if (!nextIds.isEmpty()) {
      if (retryIds.isEmpty()) {
        System.enqueueJob(new RHCAlertsDeliveryQueueable(nextIds));
      } else {
        AsyncOptions options = new AsyncOptions();
        options.MinimumQueueableDelayInMinutes = 1;
        System.enqueueJob(new RHCAlertsDeliveryQueueable(nextIds), options);
      }
    }
  }

  /**
   * Converts claims left pending by an unhandled Queueable failure into bounded terminal evidence.
   * @param context Finalizer outcome for the parent Queueable job.
   */
  public void execute(FinalizerContext context) {
    if (context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
      recoverUnhandledFailure(deliveryIds);
    }
  }

  @TestVisible
  private static void recoverUnhandledFailure(List<Id> failedDeliveryIds) {
    if (failedDeliveryIds == null || failedDeliveryIds.isEmpty()) {
      return;
    }
    List<Record_Health_Check_Alert_Delivery__c> pendingRows = [
      SELECT Id, AttemptCount__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id IN :failedDeliveryIds AND Outcome__c = 'PENDING'
      ORDER BY Id
      LIMIT :MAX_RECOVERY_ROWS
    ];
    Datetime attemptedAt = System.now();
    for (Record_Health_Check_Alert_Delivery__c row : pendingRows) {
      row.AttemptCount__c =
        (row.AttemptCount__c == null ? 0 : row.AttemptCount__c) + 1;
      row.AttemptedAt__c = attemptedAt;
      row.Outcome__c = 'FAILED';
      row.FailureClass__c = 'PERMANENT';
      row.ErrorCode__c = 'QUEUEABLE_UNHANDLED_FAILURE';
      row.NextRetryAt__c = null;
      row.SuppressionReason__c = null;
    }
    assertAllSucceeded(Database.update(pendingRows, false));
  }

  private static void assertAllSucceeded(List<Database.SaveResult> results) {
    for (Database.SaveResult result : results) {
      if (!result.isSuccess()) {
        throw new RecoveryException('QUEUEABLE_RECOVERY_UPDATE_FAILED');
      }
    }
  }

  /** Bounded internal signal used when the Finalizer cannot persist recovery state. */
  private class RecoveryException extends Exception {
  }
}
