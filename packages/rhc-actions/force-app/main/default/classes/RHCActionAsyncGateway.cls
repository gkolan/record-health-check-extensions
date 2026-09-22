/**
 * Centralizes Queueable submission so asynchronous boundaries are testable.
 */
public virtual with sharing class RHCActionAsyncGateway {
  /**
   * Submits corrective actions for immediate or delayed Queueable execution.
   * @param pendingIds Pending actions to execute
   * @param delayMinutes Minimum Queueable delay; zero enqueues immediately
   * @return Submitted Queueable job ID
   */
  public virtual Id enqueue(List<Id> pendingIds, Integer delayMinutes) {
    RHCActionExecutionQueueable job = new RHCActionExecutionQueueable(
      pendingIds
    );
    if (delayMinutes != null && delayMinutes > 0) {
      return System.enqueueJob(job, delayMinutes);
    }
    return System.enqueueJob(job);
  }
}
