/** Removes only Run Manager-owned scheduled and active asynchronous work during uninstall. */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class RHCRunManagerUninstallHandler implements UninstallHandler {
  private static final String SCHEDULE_NAME_PREFIX = 'RHC Run Manager ';
  private static final Set<String> ASYNC_CLASS_NAMES = new Set<String>{
    'RHCRunManagerBatch',
    'RHCRunManagerCoalescerQueueable'
  };

  /**
   * Runs in the platform package-lifecycle context, where cross-owner visibility is
   * required to remove jobs that would otherwise block package uninstall.
   * @param context Platform uninstall context.
   */
  global void onUninstall(UninstallContext context) {
    abortOwnedJobs();
  }

  @TestVisible
  // Platform job views do not expose object CRUD/FLS and are scoped by owned names/classes.
  @SuppressWarnings('PMD.ApexCRUDViolation')
  private static void abortOwnedJobs() {
    String schedulePattern = SCHEDULE_NAME_PREFIX + '%';
    List<CronTrigger> scheduledJobs = [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE :schedulePattern
        AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING', 'PAUSED', 'BLOCKED', 'PAUSED_BLOCKED')
    ];
    List<AsyncApexJob> asynchronousJobs = [
      SELECT Id
      FROM AsyncApexJob
      WHERE ApexClass.Name IN :ASYNC_CLASS_NAMES
        AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
    ];
    for (CronTrigger scheduledJob : scheduledJobs) {
      System.abortJob(scheduledJob.Id);
    }
    for (AsyncApexJob asynchronousJob : asynchronousJobs) {
      System.abortJob(asynchronousJob.Id);
    }
  }
}
