@IsTest
private class RHCRunManagerExecutionTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldPersistPartialFailure_WhenScopeThrows() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    Record_Health_Check_Batch_Run__c batchRun = RHCRunManagerTestDataFactory.createBatchRun(definition.Id);
    RHCRunManagerCoreMetadataGateway.DefinitionInfo info = RHCRunManagerCoreMetadataGateway.resolve('CHECK_SET', definition.QualifiedApiName__c);
    List<Account> accounts = RHCRunManagerTestDataFactory.createAccounts(2, true);
    RHCRunManagerBatch batch = new RHCRunManagerBatch(batchRun.Id, definition, info, 'RUN_NOW', null);

    Test.startTest();
    RHCRunManagerBatch.forceScopeFailure = false;
    batch.execute(null, new List<SObject>{ accounts[0] });
    RHCRunManagerBatch.forceScopeFailure = true;
    batch.execute(null, new List<SObject>{ accounts[1] });
    batch.finish(null);
    Test.stopTest();

    Record_Health_Check_Batch_Run__c captured = [SELECT Status__c, FailedScopeCount__c, ProcessedRecordCount__c FROM Record_Health_Check_Batch_Run__c WHERE Id = :batchRun.Id];
    Assert.areEqual('PARTIAL_FAILURE', captured.Status__c, 'Scope failure should remain visible after finish.');
    Assert.areEqual(1, captured.FailedScopeCount__c, 'Exactly one failed scope should be counted.');
    Assert.areEqual(1, captured.ProcessedRecordCount__c, 'The successful earlier scope must remain committed and counted.');
    Assert.areEqual(2, [SELECT COUNT() FROM Record_Health_Check_Run__c WHERE BatchRun__c = :batchRun.Id], 'Both independently committed scope envelopes must remain visible.');
    }
  }

  @IsTest
  static void shouldFinalizeBatchAsError_WhenPopulationStartupFails() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    RHCRunManagerBatch.forceStartFailure = true;

    Test.startTest();
    Id batchRunId = RHCRunManagerExecutionService.runNow(definition.Id);
    Test.stopTest();

    Record_Health_Check_Batch_Run__c batchRun = [
      SELECT Status__c, CompletedAt__c, ErrorSummary__c
      FROM Record_Health_Check_Batch_Run__c
      WHERE Id = :batchRunId
    ];
    Assert.areEqual('ERROR', batchRun.Status__c, 'A failed population/query startup must not remain QUEUED or PROCESSING.');
    Assert.isNotNull(batchRun.CompletedAt__c, 'Startup failure should receive a terminal timestamp.');
    Assert.isTrue(batchRun.ErrorSummary__c.contains('Forced start failure'), 'The sanitized startup failure should be observable.');
    }
  }

  @IsTest
  static void shouldRollbackMonitoringEnvelope_WhenBatchCannotBeQueued() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    RHCRunManagerExecutionService.forceLaunchFailure = true;
    Boolean launchFailed = false;

    try {
      RHCRunManagerExecutionService.runNow(definition.Id);
    } catch (RHCRunManagerExecutionService.ExecutionException error) {
      launchFailed = true;
    }

    Assert.isTrue(launchFailed, 'Launch failure should be returned as a stable domain exception.');
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c], 'A job that was never queued must not leave a stale monitoring record.');
    }
  }

  @IsTest
  static void shouldGenerateHumanScheduleCron_WithoutAdminCronInput() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Assert.areEqual('0 30 2 ? * MON-FRI', RHCRunManagerScheduleService.cronExpression('WEEKDAYS', '02:30', null), 'Weekday recurrence should be packaged CRON.');
    Assert.areEqual('0 0 6 ? * MON', RHCRunManagerScheduleService.cronExpression('WEEKLY', '06:00', 'MON'), 'Weekly recurrence should include selected day.');
    Assert.areEqual('0 15 4 * * ?', RHCRunManagerScheduleService.cronExpression('DAILY', '04:15', null), 'Daily recurrence should be packaged CRON.');
    Boolean invalidTimeRejected = false;
    try {
      RHCRunManagerScheduleService.cronExpression('DAILY', '25:00', null);
    } catch (RHCRunManagerScheduleService.ScheduleException error) {
      invalidTimeRejected = true;
    }
    Assert.isTrue(invalidTimeRejected, 'Invalid time must be rejected.');
    Boolean invalidDayRejected = false;
    try {
      RHCRunManagerScheduleService.cronExpression('WEEKLY', '06:00', 'FUNDAY');
    } catch (RHCRunManagerScheduleService.ScheduleException error) {
      invalidDayRejected = true;
    }
    Assert.isTrue(invalidDayRejected, 'Invalid weekly day must be rejected.');
    }
  }

  @IsTest
  static void shouldSaveDisabledSchedule_WithoutCronJob() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');

    Test.startTest();
    Id scheduleId = RHCRunManagerScheduleService.save(null, definition.Id, false, 'DAILY', '03:00', null, Date.today(), Date.today().addDays(30));
    Test.stopTest();

    Record_Health_Check_Schedule__c scheduleRecord = [SELECT Active__c, CronTriggerId__c, Frequency__c, StartDate__c, EndDate__c FROM Record_Health_Check_Schedule__c WHERE Id = :scheduleId];
    Assert.isFalse(scheduleRecord.Active__c, 'Disabled schedule should remain a saved human configuration.');
    Assert.isNull(scheduleRecord.CronTriggerId__c, 'Disabled schedule must not own a CronTrigger.');
    Assert.areEqual('DAILY', scheduleRecord.Frequency__c, 'Human recurrence should be retained.');
    Assert.areEqual(Date.today(), scheduleRecord.StartDate__c, 'The optional first eligible date should be retained.');
    Assert.areEqual(Date.today().addDays(30), scheduleRecord.EndDate__c, 'The optional last eligible date should be retained.');
    }
  }

  @IsTest
  static void shouldRejectSuppliedIdsDefinition_WhenScheduled() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    Boolean rejected = false;
    try {
      RHCRunManagerScheduleService.save(null, definition.Id, true, 'DAILY', '03:00', null, null, null);
    } catch (RHCRunManagerScheduleService.ScheduleException error) {
      rejected = true;
    }
    Assert.isTrue(rejected, 'Flow-driven supplied-ID definitions cannot be scheduled without IDs.');
    }
  }

  @IsTest
  static void shouldAbortOnlyOwnedCron_WhenScheduleDisabled() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');

    Test.startTest();
    Id scheduleId = RHCRunManagerScheduleService.save(null, definition.Id, true, 'DAILY', '03:00', null, null, null);
    Record_Health_Check_Schedule__c activeSchedule = [
      SELECT CronTriggerId__c FROM Record_Health_Check_Schedule__c WHERE Id = :scheduleId
    ];
    Assert.isNotNull(activeSchedule.CronTriggerId__c, 'Active schedule should retain its exact owned CronTrigger.');
    RHCRunManagerScheduleService.save(scheduleId, definition.Id, false, 'DAILY', '03:00', null, null, null);
    Test.stopTest();

    Record_Health_Check_Schedule__c disabledSchedule = [
      SELECT Active__c, CronTriggerId__c FROM Record_Health_Check_Schedule__c WHERE Id = :scheduleId
    ];
    Assert.isFalse(disabledSchedule.Active__c, 'The human schedule should be disabled.');
    Assert.isNull(disabledSchedule.CronTriggerId__c, 'The removed owned job identity must be cleared.');
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c], 'An aborted scheduled job must not launch Batch work.');
    }
  }

  @IsTest
  static void shouldIgnoreInactiveSchedule_WhenFired() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    Record_Health_Check_Schedule__c scheduleRecord = new Record_Health_Check_Schedule__c(
      RunDefinition__c = definition.Id,
      Active__c = false,
      Frequency__c = 'DAILY',
      PreferredStartTime__c = '03:00'
    );
    insert scheduleRecord;

    new RHCRunManagerScheduled(scheduleRecord.Id).execute(null);

    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c], 'An inactive schedule must never launch Batch work.');
    Boolean missingIdRejected = false;
    try {
      new RHCRunManagerScheduled(null);
    } catch (IllegalArgumentException error) {
      missingIdRejected = true;
    }
    Assert.isTrue(missingIdRejected, 'Schedule identity is required.');
    }
  }

  @IsTest
  static void shouldHonorScheduleDateWindow_WhenFired() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    List<Record_Health_Check_Schedule__c> schedules = new List<Record_Health_Check_Schedule__c>{
      new Record_Health_Check_Schedule__c(
        RunDefinition__c = definition.Id,
        Active__c = true,
        Frequency__c = 'DAILY',
        PreferredStartTime__c = '03:00',
        StartDate__c = Date.today().addDays(1)
      ),
      new Record_Health_Check_Schedule__c(
        RunDefinition__c = definition.Id,
        Active__c = true,
        Frequency__c = 'DAILY',
        PreferredStartTime__c = '03:00',
        EndDate__c = Date.today().addDays(-1)
      )
    };
    insert schedules;

    new RHCRunManagerScheduled(schedules[0].Id).execute(null);
    new RHCRunManagerScheduled(schedules[1].Id).execute(null);

    schedules = [SELECT Active__c FROM Record_Health_Check_Schedule__c ORDER BY CreatedDate, Id];
    Assert.isTrue(schedules[0].Active__c, 'A future-start schedule should remain active without launching early.');
    Assert.isFalse(schedules[1].Active__c, 'A schedule past its end date should deactivate itself.');
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c], 'Neither out-of-window schedule should launch work.');
    }
  }

  @IsTest
  static void shouldRejectSchedule_WhenDateWindowReversed() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    Boolean rejected = false;
    try {
      RHCRunManagerScheduleService.save(null, definition.Id, false, 'DAILY', '03:00', null, Date.today().addDays(1), Date.today());
    } catch (RHCRunManagerScheduleService.ScheduleException error) {
      rejected = true;
    }
    Assert.isTrue(rejected, 'Start Date after End Date must be rejected before scheduling.');
    }
  }

  @IsTest
  static void shouldDelegateActiveSchedule_ToSharedExecutionPath() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    RHCRunManagerTestDataFactory.createAccounts(1, true);
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    Record_Health_Check_Schedule__c scheduleRecord = new Record_Health_Check_Schedule__c(
      RunDefinition__c = definition.Id,
      Active__c = true,
      Frequency__c = 'DAILY',
      PreferredStartTime__c = '03:00'
    );
    insert scheduleRecord;

    Test.startTest();
    new RHCRunManagerScheduled(scheduleRecord.Id).execute(null);
    Test.stopTest();

    scheduleRecord = [SELECT LastFiredAt__c FROM Record_Health_Check_Schedule__c WHERE Id = :scheduleRecord.Id];
    Assert.isNotNull(scheduleRecord.LastFiredAt__c, 'The schedule should record its firing time.');
    Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c WHERE Source__c = 'SCHEDULED' AND Schedule__c = :scheduleRecord.Id], 'The active schedule must delegate to the shared Batch path.');
    }
  }
}
