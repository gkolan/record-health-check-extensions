@IsTest
private class RHCRunManagerUninstallHandlerTest {
  private static Integer noOpExecutions = 0;
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldAbortOnlyOwnedScheduledAndAsyncJobsWhenUninstalled() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
      Record_Health_Check_Schedule__c scheduleRecord = new Record_Health_Check_Schedule__c(
        RunDefinition__c = definition.Id,
        Active__c = true,
        Frequency__c = 'DAILY',
        PreferredStartTime__c = '03:00'
      );
      insert scheduleRecord;
      String cron = '0 0 0 1 1 ? 2099';
      Id ownedScheduleId = System.schedule(
        'RHC Run Manager ' + scheduleRecord.Id + ' uninstall test',
        cron,
        new RHCRunManagerScheduled(scheduleRecord.Id)
      );
      Id foreignScheduleId = System.schedule('Customer-owned uninstall test', cron, new NoOpScheduled());
      Id ownedQueueableId = System.enqueueJob(new RHCRunManagerCoalescerQueueable(definition.Id));
      Id foreignQueueableId = System.enqueueJob(new NoOpQueueable());

      Test.startTest();
      new RHCRunManagerUninstallHandler().onUninstall(null);

      Assert.areEqual(0, activeCronCount(ownedScheduleId), 'The package-owned schedule should be aborted.');
      Assert.areEqual(1, activeCronCount(foreignScheduleId), 'A customer-owned schedule must remain untouched.');
      Assert.areEqual(0, activeAsyncCount(ownedQueueableId), 'The package-owned Queueable should be aborted.');
      Assert.areEqual(1, activeAsyncCount(foreignQueueableId), 'A customer-owned Queueable must remain untouched.');
      Test.stopTest();
    }
  }

  private static Integer activeCronCount(Id jobId) {
    return [
      SELECT COUNT()
      FROM CronTrigger
      WHERE Id = :jobId AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING', 'PAUSED', 'BLOCKED', 'PAUSED_BLOCKED')
    ];
  }

  private static Integer activeAsyncCount(Id jobId) {
    return [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Id = :jobId AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
    ];
  }

  private class NoOpScheduled implements Schedulable {
    /**
     * Records an unexpected scheduled execution.
     * @param context Platform schedule context.
     */
    public void execute(SchedulableContext context) {
      noOpExecutions++;
    }
  }

  @SuppressWarnings('PMD.QueueableWithoutFinalizer')
  private class NoOpQueueable implements Queueable {
    /**
     * Records an unexpected queueable execution.
     * @param context Platform queueable context.
     */
    public void execute(QueueableContext context) {
      noOpExecutions++;
    }
  }
}
