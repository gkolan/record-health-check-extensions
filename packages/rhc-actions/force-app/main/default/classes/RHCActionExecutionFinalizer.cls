/**
 * Recovers package state when a Queueable ends with an unhandled exception.
 */
public without sharing class RHCActionExecutionFinalizer implements Finalizer {
  @TestVisible
  private static RHCActionAsyncGateway asyncGateway = new RHCActionAsyncGateway();
  private final List<Id> pendingIds;

  /**
   * Creates recovery state for one parent Queueable.
   * @param pendingIds Pending actions owned by the parent Queueable
   */
  public RHCActionExecutionFinalizer(List<Id> pendingIds) {
    this.pendingIds = pendingIds == null
      ? new List<Id>()
      : new List<Id>(pendingIds);
  }

  /**
   * Reconciles pending-action state after an unsuccessful parent execution.
   * @param context Parent Queueable outcome
   */
  public void execute(FinalizerContext context) {
    if (String.valueOf(context.getResult()) == 'SUCCESS') {
      return;
    }
    recoverAfterFailure();
  }

  @TestVisible
  // Recovery must reconcile retry limits and terminal states atomically; splitting
  // this short state machine would obscure the single-lock transaction boundary.
  @SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
  private void recoverAfterFailure() {
    if (pendingIds.isEmpty()) {
      return;
    }
    List<RHC_Pending_Action__c> actions = [
      SELECT
        Id,
        Queue_Status__c,
        Attempt_Count__c,
        Policy__r.Retry_Limit__c
      FROM RHC_Pending_Action__c
      WHERE
        Id IN :pendingIds
        AND Queue_Status__c IN ('QUEUED', 'RUNNING', 'RETRY_WAIT')
      WITH SYSTEM_MODE
      FOR UPDATE
    ];
    List<Id> retryIds = new List<Id>();
    Datetime nowValue = System.now();
    for (RHC_Pending_Action__c action : actions) {
      Integer attemptCount = action.Attempt_Count__c == null
        ? 0
        : action.Attempt_Count__c.intValue();
      Integer retryLimit = action.Policy__r == null ||
        action.Policy__r.Retry_Limit__c == null
        ? 0
        : action.Policy__r.Retry_Limit__c.intValue();
      Boolean retryable = attemptCount <= retryLimit;
      action.Queue_Status__c = retryable
        ? RHCActionConstants.STATUS_RETRY_WAIT
        : RHCActionConstants.STATUS_FAILED;
      action.Available_At__c = retryable ? nowValue.addMinutes(1) : null;
      action.Completed_At__c = retryable ? null : nowValue;
      action.Last_Error_Code__c = retryable
        ? 'ASYNC_EXECUTION_RETRYABLE'
        : 'ASYNC_EXECUTION_FAILED';
      action.Last_Error_Summary__c = 'The execution job ended unexpectedly. Review Apex Jobs and subscriber permissions.';
      if (retryable) {
        retryIds.add(action.Id);
      }
    }
    if (actions.isEmpty()) {
      return;
    }
    Database.update(actions, AccessLevel.SYSTEM_MODE);
    enqueueRecovery(retryIds, actions);
  }

  private static void enqueueRecovery(
    List<Id> retryIds,
    List<RHC_Pending_Action__c> actions
  ) {
    if (retryIds.isEmpty()) {
      return;
    }
    Set<Id> retryIdSet = new Set<Id>(retryIds);
    try {
      asyncGateway.enqueue(retryIds, 1);
    } catch (Exception enqueueFailure) {
      Datetime failedAt = System.now();
      for (RHC_Pending_Action__c action : actions) {
        if (!retryIdSet.contains(action.Id)) {
          continue;
        }
        action.Queue_Status__c = RHCActionConstants.STATUS_FAILED;
        action.Available_At__c = null;
        action.Completed_At__c = failedAt;
        action.Last_Error_Code__c = 'ASYNC_RECOVERY_ENQUEUE_FAILED';
        action.Last_Error_Summary__c = 'The recovery job could not be submitted. Review Apex Jobs and async capacity.';
      }
      Database.update(actions, AccessLevel.SYSTEM_MODE);
    }
  }
}
