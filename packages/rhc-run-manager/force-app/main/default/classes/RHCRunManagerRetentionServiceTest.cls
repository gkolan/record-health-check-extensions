/** Verifies explicit settings and bounded, child-first terminal-record cleanup. */
@IsTest
private class RHCRunManagerRetentionServiceTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldRecommendSaveAndUpdateTheSingleton() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerRetentionService.retentionPermissionOverride = true;
      RHCRunManagerRetentionService.Settings recommendation = RHCRunManagerRetentionService.getSettings();
      Assert.areEqual(365, recommendation.retentionDays, 'The unsaved recommendation should be conservative.');
      Assert.isFalse(recommendation.configured, 'A recommendation must not authorize cleanup.');

      RHCRunManagerRetentionService.Settings saved = RHCRunManagerRetentionService.saveSettings(30);
      Assert.areEqual(30, saved.retentionDays, 'The selected window should be returned.');
      Assert.isTrue(saved.configured, 'The singleton should now be explicit.');
      RHCRunManagerRetentionService.saveSettings(60);
    }
    Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Run_Setting__c], 'Settings must remain a singleton.');
  }

  @IsTest
  static void shouldRejectUnauthorizedInvalidAndUnsavedCleanup() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerRetentionService.retentionPermissionOverride = false;
      Assert.isFalse(RHCRunManagerRetentionService.getSettings().canManage, 'Unauthorized users must not see controls.');
      assertHandled('permission', new Invocation('save', 30));
      assertHandled('permission', new Invocation('purge', null));

      RHCRunManagerRetentionService.retentionPermissionOverride = true;
      assertHandled('Save Run Manager retention settings', new Invocation('purge', null));
      assertHandled('1 through 3650', new Invocation('save', 0));
      assertHandled('1 through 3650', new Invocation('save', 3651));
    }
  }

  @IsTest
  static void shouldDeleteOnlyOldTerminalRecordsInDependencyOrder() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerRetentionService.retentionPermissionOverride = true;
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
      Id targetId = RHCRunManagerTestDataFactory.createAccounts(1)[0].Id;
      Record_Health_Check_Batch_Run__c oldTerminal = batch(definition.Id, 'COMPLETED', System.now().addDays(-61));
      Record_Health_Check_Run__c oldRun = run(oldTerminal.Id, 'COMPLETED', 'old-terminal');
      insert result(oldRun.Id, targetId, 'old-terminal');
      Record_Health_Check_Batch_Run__c active = batch(definition.Id, 'PROCESSING', null);
      Record_Health_Check_Run__c activeRun = run(active.Id, 'IN_PROGRESS', 'active');
      insert result(activeRun.Id, targetId, 'active');
      Record_Health_Check_Run_Request__c recentRequest = request(
        definition.Id,
        targetId,
        'recent-submitted'
      );
      recentRequest.RequestedAt__c = System.now().addDays(-2);
      Record_Health_Check_Run_Request__c pendingRequest = request(
        definition.Id,
        targetId,
        'old-pending'
      );
      pendingRequest.Status__c = 'PENDING';
      insert new List<Record_Health_Check_Run_Request__c>{
        request(definition.Id, targetId, 'old-submitted'),
        pendingRequest,
        recentRequest
      };
      RHCRunManagerRetentionService.saveSettings(30);

      RHCRunManagerRetentionService.PurgeOutcome outcome = RHCRunManagerRetentionService.purge();

      Assert.areEqual(1, outcome.resultsDeleted, 'The old terminal Result should be deleted first.');
      Assert.areEqual(1, outcome.runsDeleted, 'The emptied terminal scope Run should then be deleted.');
      Assert.areEqual(1, outcome.batchRunsDeleted, 'The emptied terminal Batch Run should then be deleted.');
      Assert.areEqual(1, outcome.requestsDeleted, 'Only the old submitted Request should be deleted.');
      Assert.areEqual(4, outcome.totalDeleted, 'Every explicitly deleted row should be counted.');
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c], 'The active Batch Run must remain.');
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Run_Request__c WHERE Status__c = 'PENDING'], 'Pending Requests must remain.');
    }
  }

  @IsTest
  static void shouldCapEachRequestAtOneThousandRows() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerRetentionService.retentionPermissionOverride = true;
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'BOTH');
      Id targetId = RHCRunManagerTestDataFactory.createAccounts(1)[0].Id;
      Record_Health_Check_Batch_Run__c batchRun = batch(definition.Id, 'COMPLETED', System.now().addDays(-61));
      Record_Health_Check_Run__c runRecord = run(batchRun.Id, 'COMPLETED', 'bounded');
      List<Record_Health_Check_Run_Result__c> results = new List<Record_Health_Check_Run_Result__c>();
      for (Integer index = 0; index < 1001; index++) {
        results.add(result(runRecord.Id, targetId, 'bounded-' + index));
      }
      insert results;
      RHCRunManagerRetentionService.saveSettings(30);

      Test.startTest();
      RHCRunManagerRetentionService.PurgeOutcome outcome = RHCRunManagerRetentionService.purge();
      Test.stopTest();

      Assert.areEqual(1000, outcome.totalDeleted, 'One request must never delete more than the hard cap.');
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Run_Result__c], 'Additional evidence waits for another request.');
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Run__c], 'A Run with remaining Results cannot be deleted.');
    }
  }

  private static Record_Health_Check_Batch_Run__c batch(Id definitionId, String status, Datetime completedAt) {
    Record_Health_Check_Batch_Run__c row = new Record_Health_Check_Batch_Run__c(
      RunDefinition__c = definitionId,
      Source__c = 'RUN_NOW',
      Status__c = status,
      StartedAt__c = System.now().addDays(-62),
      CompletedAt__c = completedAt
    );
    insert row;
    return row;
  }

  private static Record_Health_Check_Run__c run(Id batchRunId, String status, String key) {
    Record_Health_Check_Run__c row = new Record_Health_Check_Run__c(
      BatchRun__c = batchRunId,
      RunId__c = key,
      ScopeNumber__c = 1,
      Status__c = status,
      CompletedAt__c = status == 'IN_PROGRESS' ? null : System.now().addDays(-61)
    );
    insert row;
    return row;
  }

  private static Record_Health_Check_Run_Result__c result(Id runId, Id targetId, String key) {
    return new Record_Health_Check_Run_Result__c(
      Run__c = runId,
      ResultKey__c = key,
      RecordId__c = String.valueOf(targetId),
      CheckQualifiedApiName__c = 'Account_Health',
      Status__c = 'FAIL',
      OccurredAt__c = System.now().addDays(-61)
    );
  }

  private static Record_Health_Check_Run_Request__c request(
    Id definitionId,
    Id targetId,
    String key
  ) {
    return new Record_Health_Check_Run_Request__c(
      RunDefinition__c = definitionId,
      RequestKey__c = key,
      RecordId__c = String.valueOf(targetId),
      Status__c = 'SUBMITTED',
      RequestedAt__c = System.now().addDays(-61)
    );
  }

  private class Invocation {
    private String operation;
    private Integer days;
    Invocation(String operation, Integer days) { this.operation = operation; this.days = days; }
    void run() {
      if (operation == 'save') {
        RHCRunManagerRetentionService.saveSettings(days);
      } else {
        RHCRunManagerRetentionService.purge();
      }
    }
  }

  private static void assertHandled(String expected, Invocation invocation) {
    try {
      invocation.run();
      Assert.fail('Expected a handled exception containing ' + expected);
    } catch (AuraHandledException error) {
      Assert.isTrue(error.getMessage().contains(expected), 'The error should explain the rejected request.');
    }
  }
}
