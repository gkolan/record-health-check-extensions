@IsTest
private class RHCChangeMonitorDispatcherQueueableTest {
  @TestSetup
  static void assignPermissions() {
    RHCChangeMonitorTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldIgnorePendingClaimWhenPolicyDeactivatedBeforeDispatch() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
      Record_Health_Check_Change_Evaluation__c claim = RHCChangeMonitorTestDataFactory.createPendingClaim(policy, account);
      policy.Active__c = false;
      update policy;

      Test.startTest();
      System.enqueueJob(new RHCChangeMonitorDispatcherQueueable(0));
      Test.stopTest();

      claim = [SELECT Outcome__c, ReasonCode__c, RunId__c FROM Record_Health_Check_Change_Evaluation__c WHERE Id = :claim.Id];
      Assert.areEqual('IGNORED', claim.Outcome__c, 'A deactivated policy must stop pending work.');
      Assert.areEqual('POLICY_INACTIVE', claim.ReasonCode__c, 'Revalidation reason should be explicit.');
      Assert.isNull(claim.RunId__c, 'Core must not be invoked after policy deactivation.');
    }
  }

  @IsTest
  static void shouldCountResultsWhenCoreReturnsMixedStatuses() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      List<Account> accounts = RHCChangeMonitorTestDataFactory.createAccounts(2);
      Record_Health_Check_Change_Evaluation__c first = RHCChangeMonitorTestDataFactory.createPendingClaim(policy, accounts[0]);
      Record_Health_Check_Change_Evaluation__c second = RHCChangeMonitorTestDataFactory.createPendingClaim(policy, accounts[1]);
      RHCChangeMonitorDispatcherQueueable.testRunPermission = true;
      RHCChangeMonitorDispatcherQueueable.testResponse = RHCChangeMonitorTestDataFactory.responseFor(
        new Map<Id, String>{
          accounts[0].Id => RecordHealthCheckStatus.PASS,
          accounts[1].Id => RecordHealthCheckStatus.FAIL
        }
      );

      Test.startTest();
      new RHCChangeMonitorDispatcherQueueable(0).execute((QueueableContext) null);
      Test.stopTest();

      Set<Id> claimIds = new Set<Id>{ first.Id, second.Id };
      Map<Id, Record_Health_Check_Change_Evaluation__c> claims = new Map<Id, Record_Health_Check_Change_Evaluation__c>([
        SELECT Outcome__c, ResultCount__c, ActionableCount__c, RunId__c
        FROM Record_Health_Check_Change_Evaluation__c WHERE Id IN :claimIds
      ]);
      Assert.areEqual('EVALUATED', claims.get(first.Id).Outcome__c, 'A core response should complete the claim.');
      Assert.areEqual(1, claims.get(first.Id).ResultCount__c, 'PASS should count as one result.');
      Assert.areEqual(0, claims.get(first.Id).ActionableCount__c, 'PASS should not be actionable.');
      Assert.areEqual(1, claims.get(second.Id).ActionableCount__c, 'FAIL should be actionable.');
      Assert.isNotNull(claims.get(second.Id).RunId__c, 'Dispatch should retain a safe run correlation.');
    }
  }

  @IsTest
  static void shouldFailClaimWhenRuntimePrincipalLacksRunPermission() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
      Record_Health_Check_Change_Evaluation__c claim = RHCChangeMonitorTestDataFactory.createPendingClaim(policy, account);
      RHCChangeMonitorDispatcherQueueable.testRunPermission = false;

      Test.startTest();
      new RHCChangeMonitorDispatcherQueueable(0).execute((QueueableContext) null);
      Test.stopTest();

      claim = [SELECT Outcome__c, ReasonCode__c, RunId__c FROM Record_Health_Check_Change_Evaluation__c WHERE Id = :claim.Id];
      Assert.areEqual('FAILED', claim.Outcome__c, 'Missing core authorization must be terminal.');
      Assert.areEqual('RUNTIME_PERMISSION_MISSING', claim.ReasonCode__c, 'Authorization failure must be bounded.');
      Assert.isNull(claim.RunId__c, 'Core must not be invoked without its Run permission.');
    }
  }
}
