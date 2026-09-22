/** Safely cancels an active Run Manager Batch Run and its owned platform job. */
public with sharing class RHCRunManagerCancellationService {
  /**
   * Cancels one visible queued or processing Batch Run.
   * @param batchRunId Batch Run to cancel.
   * @return Cancelled Batch Run ID.
   * @throws CancellationException when the row is unavailable, terminal, or cannot be cancelled.
   */
  public static Id cancel(Id batchRunId) {
    if (batchRunId == null) {
      throw new CancellationException('Choose a Batch Run.');
    }
    try {
      Record_Health_Check_Batch_Run__c batchRun = loadBatchRun(batchRunId);
      if (!isActive(batchRun.Status__c)) {
        throw new CancellationException('Only a queued or processing Batch Run can be cancelled.');
      }
      abortActiveJob(batchRun.AsyncApexJobId__c);
      markCancelled(batchRun.Id);
      return batchRun.Id;
    } catch (CancellationException error) {
      throw error;
    } catch (Exception error) {
      throw new CancellationException('The Batch Run could not be cancelled.', error);
    }
  }

  private static Record_Health_Check_Batch_Run__c loadBatchRun(Id batchRunId) {
    List<Record_Health_Check_Batch_Run__c> rows = [
      SELECT Id, Status__c, AsyncApexJobId__c
      FROM Record_Health_Check_Batch_Run__c
      WHERE Id = :batchRunId
      WITH USER_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new CancellationException('The Batch Run is not visible to you.');
    }
    return rows[0];
  }

  private static Boolean isActive(String status) {
    return status == 'QUEUED' || status == 'PROCESSING';
  }

  private static void abortActiveJob(String asyncApexJobId) {
    if (String.isBlank(asyncApexJobId)) {
      return;
    }
    // A job that finishes between the Batch Run read and this query needs no abort.
    List<AsyncApexJob> jobs = [
      SELECT Id
      FROM AsyncApexJob
      WHERE Id = :asyncApexJobId AND Status IN ('Queued', 'Holding', 'Preparing', 'Processing')
      WITH USER_MODE
      LIMIT 1
    ];
    if (!jobs.isEmpty()) {
      System.abortJob(jobs[0].Id);
    }
  }

  private static void markCancelled(Id batchRunId) {
    Database.update(new Record_Health_Check_Batch_Run__c(
      Id = batchRunId,
      Status__c = 'CANCELLED',
      CompletedAt__c = System.now(),
      ErrorSummary__c = 'Cancelled by ' + UserInfo.getName()
    ), AccessLevel.USER_MODE);
  }

  /** Signals that a requested Batch Run cancellation could not be completed safely. */
  public class CancellationException extends Exception {}
}
