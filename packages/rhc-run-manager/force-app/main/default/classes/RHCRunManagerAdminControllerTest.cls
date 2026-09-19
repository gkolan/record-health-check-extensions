@IsTest
private class RHCRunManagerAdminControllerTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldSaveAndReadDefinition_WhenInputValid() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Set__mdt checkSet = RHCRunManagerTestDataFactory.accountCheckSet();
    RHCRunManagerAdminController.DefinitionInput input = new RHCRunManagerAdminController.DefinitionInput();
    input.displayName = 'Account health after changes';
    input.active = true;
    input.selectionType = 'CHECK_SET';
    input.qualifiedApiName = checkSet.QualifiedApiName;
    input.populationMode = 'GUIDED_FILTERED';
    input.filterJson = '[{"field":"Name","operator":"STARTS_WITH","value":"Run Manager"}]';
    input.batchSize = 100;
    input.captureMode = 'BOTH';
    input.coalesceDelayMinutes = 2;

    Test.startTest();
    Id definitionId = RHCRunManagerAdminController.saveDefinition(input);
    List<Record_Health_Check_Run_Definition__c> definitions = RHCRunManagerAdminController.getDefinitions();
    RHCRunManagerCoreMetadataGateway.DefinitionInfo info = RHCRunManagerAdminController.resolveSelection('CHECK_SET', checkSet.QualifiedApiName);
    List<RHCRunManagerAdminController.FieldOption> fields = RHCRunManagerAdminController.getTargetFields('CHECK_SET', checkSet.QualifiedApiName);
    Test.stopTest();

    Assert.isNotNull(definitionId, 'A valid definition should be inserted in user mode.');
    Assert.areEqual(1, definitions.size(), 'The saved definition should be visible.');
    Assert.areEqual('Account', info.targetObjectApiName, 'Target object must come from core metadata.');
    Assert.isTrue(!fields.isEmpty(), 'Accessible Account fields should be available to the guided builder.');
    }
  }

  @IsTest
  static void shouldRejectInvalidDefinitionAndResolveErrors() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    RHCRunManagerAdminController.DefinitionInput input = new RHCRunManagerAdminController.DefinitionInput();
    input.selectionType = 'LEGACY';
    input.populationMode = 'ALL_ACCESSIBLE';
    input.captureMode = 'FAIL';
    input.batchSize = 200;
    input.coalesceDelayMinutes = 1;

    Boolean invalidInputRejected = false;
    try {
      RHCRunManagerAdminController.saveDefinition(input);
    } catch (AuraHandledException error) {
      invalidInputRejected = true;
    }
    Assert.isTrue(invalidInputRejected, 'Unsupported Day-1 aliases must be rejected.');

    Boolean missingSelectionRejected = false;
    try {
      RHCRunManagerAdminController.resolveSelection('CHECK_SET', 'Does_Not_Exist');
    } catch (AuraHandledException error) {
      missingSelectionRejected = true;
    }
    Assert.isTrue(missingSelectionRejected, 'Core resolution failures should be translated for the UI.');
    }
  }

  @IsTest
  static void shouldCancelActiveBatchRunAndRejectTerminalOne() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    Record_Health_Check_Batch_Run__c active = RHCRunManagerTestDataFactory.createBatchRun(definition.Id);

    RHCRunManagerAdminController.cancelBatchRun(active.Id);

    Record_Health_Check_Batch_Run__c cancelled = [SELECT Status__c, CompletedAt__c, ErrorSummary__c FROM Record_Health_Check_Batch_Run__c WHERE Id = :active.Id];
    Assert.areEqual('CANCELLED', cancelled.Status__c, 'An active Batch Run becomes CANCELLED.');
    Assert.isNotNull(cancelled.CompletedAt__c, 'Cancellation is a terminal completion.');
    Assert.isTrue(cancelled.ErrorSummary__c.startsWith('Cancelled by '), 'The cancelling user is recorded.');

    Boolean rejected = false;
    try {
      RHCRunManagerAdminController.cancelBatchRun(active.Id);
    } catch (AuraHandledException error) {
      rejected = true;
    }
    Assert.isTrue(rejected, 'A terminal Batch Run cannot be cancelled again.');
    }
  }

  @IsTest
  static void shouldReturnRecentBatchRuns() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    RHCRunManagerTestDataFactory.createBatchRun(definition.Id);

    List<Record_Health_Check_Batch_Run__c> rows = RHCRunManagerAdminController.getBatchRuns();

    Assert.areEqual(1, rows.size(), 'Monitoring should return the owned Batch Run.');
    Assert.areEqual(definition.Id, rows[0].RunDefinition__c, 'Monitoring should retain correlation to its definition.');
    }
  }

  @IsTest
  static void shouldListSelectionsSchedulesAndMonitoringDetails() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    List<RHCRunManagerCoreMetadataGateway.SelectionOption> selections = RHCRunManagerAdminController.getSelections('CHECK_SET');
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    Record_Health_Check_Batch_Run__c batchRun = RHCRunManagerTestDataFactory.createBatchRun(definition.Id);
    Record_Health_Check_Run__c runRecord = new Record_Health_Check_Run__c(
      BatchRun__c = batchRun.Id,
      RunId__c = 'admin-monitoring-test',
      ScopeNumber__c = 1,
      Status__c = 'COMPLETED'
    );
    insert runRecord;

    List<Record_Health_Check_Run__c> runs = RHCRunManagerAdminController.getRuns(batchRun.Id);
    List<Record_Health_Check_Run_Result__c> results = RHCRunManagerAdminController.getResults(runRecord.Id);
    List<Record_Health_Check_Schedule__c> schedules = RHCRunManagerAdminController.getSchedules();

    Assert.isTrue(!selections.isEmpty(), 'The metadata picker should list active Check Sets.');
    Assert.areEqual(1, runs.size(), 'Monitoring should drill into scope Runs.');
    Assert.areEqual(0, results.size(), 'A Run without retained results should return an empty list.');
    Assert.areEqual(0, schedules.size(), 'No schedules should exist before configuration.');
    }
  }

  @IsTest
  static void shouldSaveScheduleThroughController() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    RHCRunManagerAdminController.ScheduleInput input = new RHCRunManagerAdminController.ScheduleInput();
    input.runDefinitionId = definition.Id;
    input.active = false;
    input.frequency = 'WEEKDAYS';
    input.preferredStartTime = '02:00';

    Id scheduleId = RHCRunManagerAdminController.saveSchedule(input);
    Id pausedScheduleId = RHCRunManagerAdminController.pauseSchedule(scheduleId);

    Assert.isNotNull(scheduleId, 'The LWC facade should save human schedule inputs.');
    Assert.areEqual(scheduleId, pausedScheduleId, 'Pausing should retain the managed Schedule record.');
    }
  }
}
