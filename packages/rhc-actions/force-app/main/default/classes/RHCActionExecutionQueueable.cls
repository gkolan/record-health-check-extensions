/**
 * Runs asynchronous corrective Flow attempts and bounded delayed retries.
 */
public with sharing class RHCActionExecutionQueueable implements Queueable {
  @TestVisible
  private static RHCActionAsyncGateway asyncGateway = new RHCActionAsyncGateway();
  private final List<Id> pendingIds;

  /**
   * Creates a Queueable for the supplied pending actions.
   * @param pendingIds Pending action identities
   */
  public RHCActionExecutionQueueable(List<Id> pendingIds) {
    this.pendingIds = pendingIds == null
      ? new List<Id>()
      : new List<Id>(pendingIds);
  }

  /**
   * Executes the action slice and submits any bounded retries.
   * @param context Queueable context
   */
  public void execute(QueueableContext context) {
    if (context != null) {
      System.attachFinalizer(new RHCActionExecutionFinalizer(pendingIds));
    }
    List<Id> retryIds = RHCActionExecutionService.execute(pendingIds);
    if (!retryIds.isEmpty()) {
      asyncGateway.enqueue(retryIds, 1);
    }
  }
}
