/** Verifies least-privilege settings and bounded terminal-record cleanup. */
@IsTest
private class RHCActionRetentionServiceTest {
  @TestSetup
  static void assignPermissions() {
    RHCActionTestDataFactory.assignAdminPermission();
  }

  @IsTest
  static void shouldRecommendSaveAndUpdateTheSingleton() {
    RHCActionRetentionService.retentionPermissionOverride = true;
    RHCActionRetentionService.Settings recommendation = RHCActionRetentionService.getSettings();
    Assert.areEqual(365, recommendation.retentionDays, 'The unsaved recommendation should be conservative.');
    Assert.isFalse(recommendation.configured, 'A recommendation must not authorize deletion.');

    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionRetentionService.Settings saved = RHCActionRetentionService.saveSettings(30);
      Assert.areEqual(30, saved.retentionDays, 'The selected window should be returned.');
      Assert.isTrue(saved.configured, 'The singleton should now be explicit.');
      RHCActionRetentionService.saveSettings(60);
    }

    Assert.areEqual(1, [SELECT COUNT() FROM RHC_Action_Setting__c], 'Settings must remain a singleton.');
    Assert.areEqual(
      60,
      [SELECT Retention_Days__c FROM RHC_Action_Setting__c LIMIT 1].Retention_Days__c,
      'Saving again should update the singleton.'
    );
  }

  @IsTest
  static void shouldRejectUnauthorizedInvalidAndUnsavedCleanup() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionRetentionService.retentionPermissionOverride = false;
      Assert.isFalse(RHCActionRetentionService.getSettings().canManage, 'Unauthorized users must not see controls.');
      assertHandled('permission', new Invocation('save', 30));
      assertHandled('permission', new Invocation('purge', null));

      RHCActionRetentionService.retentionPermissionOverride = true;
      assertHandled('Save action retention settings', new Invocation('purge', null));
      assertHandled('1 through 3650', new Invocation('save', 0));
      assertHandled('1 through 3650', new Invocation('save', 3651));
    }
  }

  @IsTest
  static void shouldDeleteOnlyOldCompletedEvidence() {
    RHCActionRetentionService.retentionPermissionOverride = true;
    RHC_Action_Policy__c policy = RHCActionTestDataFactory.policy();
    insert policy;
    List<RHC_Pending_Action__c> actions = new List<RHC_Pending_Action__c>{
      RHCActionTestDataFactory.pending(policy.Id, 'old-terminal'),
      RHCActionTestDataFactory.pending(policy.Id, 'old-review'),
      RHCActionTestDataFactory.pending(policy.Id, 'recent-terminal'),
      RHCActionTestDataFactory.pending(policy.Id, 'old-retry')
    };
    actions[0].Queue_Status__c = 'SUCCEEDED';
    actions[0].Completed_At__c = System.now().addDays(-61);
    actions[1].Queue_Status__c = 'PENDING_REVIEW';
    actions[1].Completed_At__c = System.now().addDays(-61);
    actions[2].Queue_Status__c = 'FAILED';
    actions[2].Completed_At__c = System.now().addDays(-2);
    actions[3].Queue_Status__c = 'RETRY_WAIT';
    actions[3].Completed_At__c = System.now().addDays(-61);
    update actions;
    insert new List<RHC_Action_History__c>{
      history(policy.Id, 'old-history', System.now().addDays(-61)),
      history(policy.Id, 'recent-history', System.now().addDays(-2))
    };

    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionRetentionService.saveSettings(30);
    }
    RHCActionRetentionService.PurgeOutcome outcome = RHCActionRetentionService.purge();

    Assert.areEqual(1, outcome.historiesDeleted, 'Only old completed history should be removed.');
    Assert.areEqual(1, outcome.pendingActionsDeleted, 'Only an old terminal action should be removed.');
    Assert.areEqual(2, outcome.totalDeleted, 'The combined count should be explicit.');
    Assert.areEqual(1, [SELECT COUNT() FROM RHC_Action_History__c], 'Recent history should remain.');
    Assert.areEqual(3, [SELECT COUNT() FROM RHC_Pending_Action__c], 'Active, retrying, and recent actions should remain.');
  }

  @IsTest
  static void shouldCapEachRequestAtOneThousandRows() {
    RHCActionRetentionService.retentionPermissionOverride = true;
    RHC_Action_Policy__c policy = RHCActionTestDataFactory.policy();
    insert policy;
    List<RHC_Action_History__c> histories = new List<RHC_Action_History__c>();
    for (Integer index = 0; index < 1001; index++) {
      histories.add(history(policy.Id, 'bounded-' + index, System.now().addDays(-61)));
    }
    insert histories;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionRetentionService.saveSettings(30);
    }

    Test.startTest();
    RHCActionRetentionService.PurgeOutcome outcome = RHCActionRetentionService.purge();
    Test.stopTest();

    Assert.areEqual(1000, outcome.totalDeleted, 'One request must never delete more than the hard cap.');
    Assert.areEqual(1, [SELECT COUNT() FROM RHC_Action_History__c], 'Additional eligible evidence waits for another request.');
  }

  private static RHC_Action_History__c history(
    Id policyId,
    String key,
    Datetime completedAt
  ) {
    return new RHC_Action_History__c(
      Policy__c = policyId,
      Execution_Key__c = key,
      Record_Id__c = RHCActionTestDataFactory.syntheticId('001'),
      Outcome__c = 'SUCCEEDED',
      Attempt_Number__c = 1,
      Started_At__c = completedAt.addMinutes(-1),
      Completed_At__c = completedAt
    );
  }

  private class Invocation {
    private String operation;
    private Integer days;

    Invocation(String operation, Integer days) {
      this.operation = operation;
      this.days = days;
    }

    void run() {
      if (operation == 'save') {
        RHCActionRetentionService.saveSettings(days);
      } else {
        RHCActionRetentionService.purge();
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
