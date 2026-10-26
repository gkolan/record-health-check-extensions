/** Red-scenario tests: permission denial, retention misconfiguration, bounded purge, and dispatcher failure paths. */
@IsTest
private class RHCChangeMonitorAccessTest {
  private static Integer sequence = 0;

  @TestSetup
  static void createUsers() {
    RHCChangeMonitorTestDataFactory.createAdminUser();
    Profile minimal = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
    List<User> users = new List<User>();
    for (String alias : new List<String>{ 'rhcnone', 'rhcview' }) {
      users.add(new User(
        Alias = alias, Email = alias + '@example.invalid', EmailEncodingKey = 'UTF-8', LastName = alias,
        LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = minimal.Id,
        TimeZoneSidKey = 'America/Chicago',
        Username = alias + '-' + UserInfo.getOrganizationId() + '@example.invalid'
      ));
    }
    insert users;
    insert new PermissionSetAssignment(
      AssigneeId = users[1].Id,
      PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'RHC_Change_Monitor_Viewer' LIMIT 1].Id
    );
  }

  private static User named(String alias) {
    return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1];
  }

  @SuppressWarnings('PMD.ExcessiveParameterList')
  private static Record_Health_Check_Change_Evaluation__c claim(Id policyId, String outcome, String reason, Datetime accepted) {
    Integer index = ++sequence;
    return new Record_Health_Check_Change_Evaluation__c(
      Policy__c = policyId, ClaimKey__c = 'key-' + index + '-' + outcome, SourceObjectApiName__c = 'Account',
      RecordId__c = String.valueOf(UserInfo.getUserId()), ChangeType__c = 'UPDATE', TransactionKey__c = 'tx', SequenceNumber__c = index,
      OccurredAt__c = accepted, AcceptedAt__c = accepted, Outcome__c = outcome, ReasonCode__c = reason,
      AttemptCount__c = 0, ResultCount__c = 0, ActionableCount__c = 0
    );
  }

  private static void assertDenied(String expected, System.Callable action) {
    try {
      action.call('run', null);
      Assert.fail('Access must be denied.');
    } catch (AuraHandledException error) {
      Assert.areEqual(expected, error.getMessage(), 'The denial message is stable.');
      Assert.isFalse(error.getMessage().contains('001'), 'No record identifier is disclosed.');
    }
  }

  private class Action implements System.Callable {
    private String name;
    Action(String name) {
      this.name = name;
    }
    /**
     * Invokes the named controller entry point.
     * @param method Unused callable method name.
     * @param args Unused callable arguments.
     * @return The controller entry point's result.
     */
    public Object call(String method, Map<String, Object> args) {
      if (name == 'status') {
        return RHCChangeMonitorAdminController.getStatus();
      } else if (name == 'retry') {
        return RHCChangeMonitorAdminController.retryFailed();
      } else if (name == 'dispatch') {
        return RHCChangeMonitorAdminController.dispatchPending();
      }
      return null;
    }
  }

  @IsTest
  static void shouldDenyUserWithoutAnyPermissionSet() {
    Record_Health_Check_Change_Evaluation__c failed;
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      failed = claim(RHCChangeMonitorTestDataFactory.createPolicy().Id, 'FAILED', 'RETRY_EXHAUSTED', System.now());
      insert failed;
    }
    System.runAs(named('rhcnone')) {
      assertDenied('You do not have access to Change Monitor evidence.', new Action('status'));
      assertDenied('You do not have access to Change Monitor evidence.', new Action('retry'));
      assertDenied('You do not have access to Change Monitor evidence.', new Action('dispatch'));
    }
    Assert.areEqual('FAILED', [SELECT Outcome__c FROM Record_Health_Check_Change_Evaluation__c WHERE Id = :failed.Id].Outcome__c, 'A denied retry changes nothing.');
  }

  @IsTest
  static void shouldLetViewerReadButNeverOperate() {
    Id claimId;
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Evaluation__c failed = claim(RHCChangeMonitorTestDataFactory.createPolicy().Id, 'FAILED', 'RETRY_EXHAUSTED', System.now());
      insert failed;
      claimId = failed.Id;
    }
    System.runAs(named('rhcview')) {
      Assert.areEqual(1, RHCChangeMonitorAdminController.getStatus().retryableFailedCount, 'Viewer reads evidence.');
      assertDenied('You do not have permission to operate Change Monitor.', new Action('retry'));
      assertDenied('You do not have permission to operate Change Monitor.', new Action('dispatch'));
    }
    Assert.areEqual('FAILED', [SELECT Outcome__c FROM Record_Health_Check_Change_Evaluation__c WHERE Id = :claimId].Outcome__c, 'A denied retry changes nothing.');
  }

  @IsTest
  @SuppressWarnings('PMD.OperationWithLimitsInLoop')
  static void shouldDenyRetentionEndpointsWithoutSettingAccess() {
    for (String alias : new List<String>{ 'rhcnone', 'rhcview' }) {
      System.runAs(named(alias)) {
        try {
          RHCChangeMonitorAdminController.saveRetentionSettings(30);
          Assert.fail('Saving must be denied for ' + alias);
        } catch (AuraHandledException error) {
          Assert.isFalse(error.getMessage().contains('rhc__'), 'No schema detail leaks.');
        }
        try {
          RHCChangeMonitorAdminController.purgeEvaluations();
          Assert.fail('Purging must be denied for ' + alias);
        } catch (AuraHandledException error) {
          Assert.isFalse(error.getMessage().contains('rhc__'), 'No schema detail leaks.');
        }
      }
    }
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Change_Setting__c], 'No setting was written.');
  }

  @IsTest
  @SuppressWarnings('PMD.OperationWithLimitsInLoop')
  static void shouldFailClosedOnInvalidStoredRetention() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      insert claim(policy.Id, 'EVALUATED', 'ACCEPTED', System.now().addDays(-4000));
      Record_Health_Check_Change_Setting__c setting = new Record_Health_Check_Change_Setting__c(Name = 'Default', SettingKey__c = 'Default');
      insert setting;
      for (Decimal stored : new List<Decimal>{ null, 0, -5, 5000 }) {
        setting.RetentionDays__c = stored;
        try {
          update setting;
        } catch (DmlException blocked) {
          continue;
        }
        try {
          RHCChangeMonitorAdminController.purgeEvaluations();
          Assert.fail('Purge must be rejected for stored value ' + stored);
        } catch (AuraHandledException error) {
          Assert.isTrue(error.getMessage().length() > 0, 'An admin-facing message is returned.');
        }
      }
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c], 'Nothing was purged under invalid configuration.');
    }
  }

  @IsTest
  static void shouldReportDefaultsWhenSettingValueIsMissing() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      insert new Record_Health_Check_Change_Setting__c(Name = 'Default', SettingKey__c = 'Default');
      RHCChangeMonitorRetentionService.Settings settings = RHCChangeMonitorAdminController.getRetentionSettings();
      Assert.areEqual(90, settings.retentionDays, 'A blank stored value falls back to the recommendation.');
    }
  }

  @IsTest
  static void shouldBoundPurgeAndKeepPendingAndRecentClaims() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      List<Record_Health_Check_Change_Evaluation__c> rows = new List<Record_Health_Check_Change_Evaluation__c>();
      for (Integer i = 0; i < 1005; i++) {
        rows.add(claim(policy.Id, 'IGNORED', 'RECORD_DELETED', System.now().addDays(-100)));
      }
      rows.add(claim(policy.Id, 'PENDING', 'ACCEPTED', System.now().addDays(-100)));
      rows.add(claim(policy.Id, 'IGNORED', 'RECORD_DELETED', System.now()));
      insert rows;
      RHCChangeMonitorAdminController.saveRetentionSettings(30);
      Assert.areEqual(1000, RHCChangeMonitorAdminController.purgeEvaluations(), 'A purge is bounded to 1000 rows.');
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c WHERE Outcome__c = 'PENDING'], 'Pending is never purged.');
      Assert.areEqual(7, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c], 'Five old, one pending, one recent remain.');
    }
  }

  @IsTest
  static void shouldKeepRetryQueriesFlatAt251Claims() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Id policyId = RHCChangeMonitorTestDataFactory.createPolicy().Id;
      insert claim(policyId, 'FAILED', 'RETRY_EXHAUSTED', System.now());
      Integer queries = Limits.getQueries();
      Integer dml = Limits.getDmlStatements();
      Assert.areEqual(1, RHCChangeMonitorAdminController.retryFailed(), 'One claim retried.');
      Integer oneQueries = Limits.getQueries() - queries;
      Integer oneDml = Limits.getDmlStatements() - dml;
      List<Record_Health_Check_Change_Evaluation__c> rows = new List<Record_Health_Check_Change_Evaluation__c>();
      for (Integer i = 1; i <= 251; i++) {
        rows.add(claim(policyId, 'FAILED', i31(i), System.now()));
      }
      insert rows;
      queries = Limits.getQueries();
      dml = Limits.getDmlStatements();
      Assert.areEqual(251, RHCChangeMonitorAdminController.retryFailed(), 'Every failed claim is retried.');
      Assert.areEqual(oneQueries, Limits.getQueries() - queries, 'SOQL count is volume-independent.');
      Assert.areEqual(oneDml, Limits.getDmlStatements() - dml, 'DML count is volume-independent.');
    }
  }

  private static String i31(Integer i) {
    return new List<String>{ 'RUNTIME_PERMISSION_MISSING', 'TRANSIENT_RETRY', 'DISPATCH_CHAIN_EXHAUSTED' }[Math.mod(i, 3)];
  }

  @IsTest
  static void shouldNotRetryRoutingOrConfigurationVerdicts() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Id policyId = RHCChangeMonitorTestDataFactory.createPolicy().Id;
      insert claim(policyId, 'FAILED', 'CORE_CONFIGURATION_INVALID', System.now());
      Assert.areEqual(0, RHCChangeMonitorAdminController.retryFailed(), 'A configuration verdict is not retryable.');
      Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c WHERE Outcome__c = 'PENDING'], 'Nothing was re-queued.');
    }
  }

  @IsTest
  static void shouldRollbackRetryWhenDispatchSignalFails() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Id policyId = RHCChangeMonitorTestDataFactory.createPolicy().Id;
      insert claim(policyId, 'FAILED', 'RETRY_EXHAUSTED', System.now());
      RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = false;
      try {
        RHCChangeMonitorAdminController.retryFailed();
        Assert.fail('A rejected signal must fail the retry.');
      } catch (AuraHandledException error) {
        Assert.areEqual('Failed claims could not be re-queued. Try again.', error.getMessage(), 'Stable message.');
      }
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c WHERE Outcome__c = 'FAILED'], 'The retry was rolled back.');
      insert claim(policyId, 'PENDING', 'ACCEPTED', System.now());
      try {
        RHCChangeMonitorAdminController.dispatchPending();
        Assert.fail('A rejected signal must fail dispatch.');
      } catch (AuraHandledException error) {
        Assert.areEqual('Pending claims could not be dispatched. Try again.', error.getMessage(), 'Stable message.');
      }
    }
  }

  @IsTest
  static void shouldFailClaimsWhenCoreResponseIsEmpty() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      Record_Health_Check_Change_Evaluation__c pending = RHCChangeMonitorTestDataFactory.createPendingClaim(policy, RHCChangeMonitorTestDataFactory.createAccounts(1)[0]);
      RHCChangeMonitorDispatcherQueueable.testRunPermission = true;
      RHCChangeMonitorDispatcherQueueable.testResponse = new RecordHealthCheckResponse();
      RHCChangeMonitorDispatcherQueueable.testResponse.results = null;
      Test.startTest();
      new RHCChangeMonitorDispatcherQueueable(0).execute((QueueableContext) null);
      Test.stopTest();
      Record_Health_Check_Change_Evaluation__c after = [SELECT Outcome__c, ReasonCode__c, AttemptCount__c FROM Record_Health_Check_Change_Evaluation__c WHERE Id = :pending.Id];
      Assert.areEqual('FAILED', after.Outcome__c, 'A null core result fails closed.');
      Assert.areEqual('CORE_CONFIGURATION_INVALID', after.ReasonCode__c, 'Bounded reason code.');
      Assert.areEqual(1, after.AttemptCount__c, 'The attempt was counted.');
    }
  }

  @IsTest
  static void shouldFailTerminallyWhenCoreRejectsTheRequest() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      Record_Health_Check_Change_Evaluation__c pending = RHCChangeMonitorTestDataFactory.createPendingClaim(policy, RHCChangeMonitorTestDataFactory.createAccounts(1)[0]);
      RHCChangeMonitorDispatcherQueueable.testRunPermission = true;
      new RHCChangeMonitorDispatcherQueueable(0).execute((QueueableContext) null);
      Record_Health_Check_Change_Evaluation__c after = [SELECT Outcome__c, ReasonCode__c, CompletedAt__c FROM Record_Health_Check_Change_Evaluation__c WHERE Id = :pending.Id];
      Assert.areNotEqual('PENDING', after.Outcome__c, 'A real core call with an unknown check set must not leave the claim pending forever.');
      Assert.isNotNull(after.CompletedAt__c, 'The terminal outcome is completed.');
    }
  }

  @IsTest
  static void shouldExhaustChainAndKeepDispatcherQueriesFlat() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
      RHCChangeMonitorTestDataFactory.createPendingClaim(policy, account);
      RHCChangeMonitorDispatcherQueueable.testRunPermission = false;
      Integer queries = Limits.getQueries();
      new RHCChangeMonitorDispatcherQueueable(0).execute((QueueableContext) null);
      Integer oneQueries = Limits.getQueries() - queries;
      List<Record_Health_Check_Change_Evaluation__c> rows = new List<Record_Health_Check_Change_Evaluation__c>();
      for (Integer i = 1; i <= 200; i++) {
        rows.add(claim(policy.Id, 'PENDING', 'ACCEPTED', System.now()));
      }
      insert rows;
      queries = Limits.getQueries();
      new RHCChangeMonitorDispatcherQueueable(0).execute((QueueableContext) null);
      Assert.areEqual(oneQueries, Limits.getQueries() - queries, 'Dispatcher SOQL is volume-independent.');
      Assert.areEqual(201, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c WHERE ReasonCode__c = 'RUNTIME_PERMISSION_MISSING'], 'Every claim in scope failed closed.');

      List<Record_Health_Check_Change_Evaluation__c> more = new List<Record_Health_Check_Change_Evaluation__c>();
      for (Integer i = 3000; i < 3201; i++) {
        more.add(claim(policy.Id, 'PENDING', 'ACCEPTED', System.now()));
      }
      insert more;
      new RHCChangeMonitorDispatcherQueueable(9).execute((QueueableContext) null);
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c WHERE ReasonCode__c = 'DISPATCH_CHAIN_EXHAUSTED'],
        'The last hop marks remaining claims exhausted instead of looping.'
      );
      new RHCChangeMonitorDispatcherQueueable(null).execute((QueueableContext) null);
    }
  }
}
