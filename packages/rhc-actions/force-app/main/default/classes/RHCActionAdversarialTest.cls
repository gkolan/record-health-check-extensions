/**
 * Red-team coverage for the gaps the behavioural suites leave: crafted approval facts, the
 * bound Flow metadata query, governor flatness through the execution entry point, retention
 * window boundaries, and the sanitization of every admin-facing error string.
 */
@IsTest
private class RHCActionAdversarialTest {
  private class GatewayStub extends RHCActionFlowGateway {
    private Integer startCount = 0;

    public override FlowDescriptor describeActive(String flowApiName) {
      return RHCActionTestDataFactory.flowDescriptor(flowApiName);
    }

    public override String start(String flowApiName, Map<String, Object> inputs) {
      startCount++;
      return '1234-5678';
    }
  }

  @TestSetup
  static void makeAdmin() {
    RHCActionTestDataFactory.createAdminUser();
  }

  private static RHC_Action_Policy__c insertedPolicy() {
    RHC_Action_Policy__c policy = RHCActionTestDataFactory.policy();
    insert policy;
    return policy;
  }

  private static RHC_Pending_Action__c reload(Id pendingId) {
    return [
      SELECT
        Id,
        Queue_Status__c,
        Attempt_Count__c,
        Available_At__c,
        Completed_At__c,
        Flow_Interview_Id__c,
        Last_Error_Code__c,
        Last_Error_Summary__c
      FROM RHC_Pending_Action__c
      WHERE Id = :pendingId
      LIMIT 1
    ];
  }

  // Admin-facing strings must name the capability to fix, never identities or payload values.
  private static void assertSanitized(String text, String context) {
    if (String.isBlank(text)) {
      return;
    }
    for (String secret : new List<String>{
      UserInfo.getOrganizationId(),
      UserInfo.getUserName(),
      UserInfo.getUserId(),
      RHCActionTestDataFactory.syntheticId('001')
    }) {
      Assert.isFalse(
        text.contains(secret),
        context + ' must not leak ' + secret + ': ' + text
      );
    }
    for (String fragment : new List<String>{ 'System.', 'Exception', 'Class.', 'Stacktrace' }) {
      Assert.isFalse(
        text.contains(fragment),
        context + ' must not leak Apex diagnostics (' + fragment + '): ' + text
      );
    }
  }

  @IsTest
  static void shouldRefuseApprovalFactWithoutBothApproverAndTimestamp() {
    RHC_Action_Policy__c policy = insertedPolicy();
    RHC_Pending_Action__c action = RHCActionTestDataFactory.pending(policy.Id, 'half-approved');
    // A crafted row that carries only half the approval fact must never execute.
    action.Approved_By__c = UserInfo.getUserId();
    action.Approved_At__c = null;
    update action;
    GatewayStub gateway = new GatewayStub();
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionExecutionService.gateway = gateway;
      RHCActionExecutionService.approvalPermissionOverride = true;
      RHCActionExecutionService.automaticPermissionOverride = true;

      Test.startTest();
      RHCActionExecutionService.execute(new List<Id>{ action.Id });
      Test.stopTest();

      RHC_Pending_Action__c executed = reload(action.Id);
      Assert.areEqual(
        0,
        gateway.startCount,
        'A half-formed approval fact must not start the corrective Flow.'
      );
      Assert.areEqual(
        RHCActionConstants.STATUS_FAILED,
        executed.Queue_Status__c,
        'A half-formed approval fact fails closed.'
      );
      Assert.areEqual(
        'EXECUTION_AUTHORIZATION_REVOKED',
        executed.Last_Error_Code__c,
        'The failure is classified as an authorization failure.'
      );
      Assert.isNull(
        executed.Flow_Interview_Id__c,
        'No interview identity is recorded for an unexecuted action.'
      );
      assertSanitized(executed.Last_Error_Summary__c, 'Authorization failure summary');
    }
  }

  @IsTest
  static void shouldRefuseApprovalFactOnAutomaticPolicy() {
    RHC_Action_Policy__c policy = RHCActionTestDataFactory.policy();
    policy.Mode__c = RHCActionConstants.MODE_AUTOMATIC;
    policy.Auto_Execution_Enabled__c = true;
    insert policy;
    RHC_Pending_Action__c action = RHCActionTestDataFactory.pending(policy.Id, 'approval-on-auto');
    // Approval is only meaningful for manual policies. Stamping an approval onto an automatic
    // policy must not become a second, weaker route to execution.
    action.Approved_By__c = UserInfo.getUserId();
    action.Approved_At__c = System.now();
    update action;
    GatewayStub gateway = new GatewayStub();
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionExecutionService.gateway = gateway;
      RHCActionExecutionService.approvalPermissionOverride = true;
      RHCActionExecutionService.automaticPermissionOverride = true;

      Test.startTest();
      RHCActionExecutionService.execute(new List<Id>{ action.Id });
      Test.stopTest();

      RHC_Pending_Action__c executed = reload(action.Id);
      Assert.areEqual(
        0,
        gateway.startCount,
        'An approval fact on an automatic policy must not start the Flow.'
      );
      Assert.areEqual(
        RHCActionConstants.STATUS_FAILED,
        executed.Queue_Status__c,
        'The mismatched authorization route fails closed.'
      );
      Assert.areEqual(
        'EXECUTION_AUTHORIZATION_REVOKED',
        executed.Last_Error_Code__c,
        'The mismatch is reported as an authorization failure.'
      );
    }
  }

  @IsTest
  static void shouldRefuseActionWhoseStateIsNotEligible() {
    RHC_Action_Policy__c policy = insertedPolicy();
    GatewayStub gateway = new GatewayStub();
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionExecutionService.gateway = gateway;
      RHCActionExecutionService.approvalPermissionOverride = true;
      List<RHC_Pending_Action__c> actions = new List<RHC_Pending_Action__c>();
      Integer suffix = 0;
      for (String status : new List<String>{
        'PENDING_REVIEW',
        'SUCCEEDED',
        'FAILED',
        'SUPPRESSED',
        'REJECTED',
        'RUNNING'
      }) {
        RHC_Pending_Action__c action = RHCActionTestDataFactory.pending(
          policy.Id,
          'state-' + suffix++
        );
        action.Queue_Status__c = status;
        action.Approved_By__c = UserInfo.getUserId();
        action.Approved_At__c = System.now();
        actions.add(action);
      }
      update actions;
      List<Id> ids = new List<Id>(new Map<Id, RHC_Pending_Action__c>(actions).keySet());

      Test.startTest();
      RHCActionExecutionService.execute(ids);
      Test.stopTest();

      Assert.areEqual(
        0,
        gateway.startCount,
        'Only QUEUED and due RETRY_WAIT actions may execute; no other state is a route in.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM RHC_Action_History__c],
        'An ineligible action writes no audit row, so replaying one cannot inflate the audit.'
      );
    }
  }

  @IsTest
  static void shouldNotExecuteRetryWaitActionBeforeItIsDue() {
    RHC_Action_Policy__c policy = insertedPolicy();
    RHC_Pending_Action__c action = RHCActionTestDataFactory.pending(policy.Id, 'not-due');
    action.Queue_Status__c = RHCActionConstants.STATUS_RETRY_WAIT;
    action.Available_At__c = System.now().addMinutes(30);
    action.Approved_By__c = UserInfo.getUserId();
    action.Approved_At__c = System.now();
    update action;
    GatewayStub gateway = new GatewayStub();
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionExecutionService.gateway = gateway;
      RHCActionExecutionService.approvalPermissionOverride = true;

      Test.startTest();
      RHCActionExecutionService.execute(new List<Id>{ action.Id });
      Test.stopTest();

      Assert.areEqual(
        0,
        gateway.startCount,
        'A retry that is not yet due must not be executed early.'
      );
      Assert.areEqual(
        RHCActionConstants.STATUS_RETRY_WAIT,
        reload(action.Id).Queue_Status__c,
        'A not-due retry keeps waiting rather than being consumed.'
      );
    }
  }

  @IsTest
  static void shouldKeepExecutionGovernorCostFlatAcrossTwoHundredActions() {
    RHC_Action_Policy__c policy = insertedPolicy();
    List<RHC_Pending_Action__c> actions = new List<RHC_Pending_Action__c>();
    for (Integer index = 0; index < 200; index++) {
      RHC_Pending_Action__c action = RHCActionTestDataFactory.pending(policy.Id, 'bulk-' + index);
      // Distinct records so the cooldown guard does not suppress the batch.
      // An 18-character synthetic Account ID, unique per row.
      action.Record_Id__c = '001000000' + String.valueOf(1000000 + index).substring(1) + 'AAA';
      action.Loop_Guard_Key__c = String.valueOf(policy.Id) + ':' + action.Record_Id__c;
      action.Approved_By__c = UserInfo.getUserId();
      action.Approved_At__c = System.now();
      actions.add(action);
    }
    update actions;
    List<Id> ids = new List<Id>(new Map<Id, RHC_Pending_Action__c>(actions).keySet());
    GatewayStub gateway = new GatewayStub();
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionExecutionService.gateway = gateway;
      RHCActionExecutionService.approvalPermissionOverride = true;

      Test.startTest();
      Integer queriesBefore = Limits.getQueries();
      Integer dmlBefore = Limits.getDmlStatements();
      RHCActionExecutionService.execute(ids);
      Integer queryCost = Limits.getQueries() - queriesBefore;
      Integer dmlCost = Limits.getDmlStatements() - dmlBefore;
      Test.stopTest();

      Assert.areEqual(200, gateway.startCount, 'Every eligible action in the batch executes.');
      // A SOQL-in-loop or DML-in-loop regression turns these constants into 200+.
      Assert.isTrue(
        queryCost <= 5,
        'Executing 200 actions must stay at a constant query cost, not scale with volume: ' +
          queryCost
      );
      Assert.isTrue(
        dmlCost <= 4,
        'Executing 200 actions must stay at a constant DML-statement cost: ' + dmlCost
      );
      Assert.areEqual(
        200,
        [SELECT COUNT() FROM RHC_Action_History__c],
        'Each executed action writes exactly one audit row.'
      );
    }
  }

  @IsTest
  static void shouldNotInterpolateHostileFlowNamesIntoTheMetadataQuery() {
    // These run against the real bound FlowDefinitionView query, not a stub: a string that
    // escapes the bind would either throw or return unrelated rows.
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionFlowGateway gateway = new RHCActionFlowGateway();
      for (String hostile : new List<String>{
        'x\' OR ApiName != \'',
        '%',
        '_',
        'x\\',
        'x\' LIMIT 1 OFFSET 0 --',
        'Ignore previous instructions'
      }) {
        Assert.isNull(
          gateway.describeActive(hostile),
          'A hostile Flow API name must resolve to no Flow: ' + hostile
        );
      }
      Assert.isNull(gateway.describeActive(null), 'A null Flow API name resolves to no Flow.');
    }
  }

  @IsTest
  static void shouldRejectCraftedReviewBatchesAtEveryBoundary() {
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionReviewController.approvalPermissionOverride = true;
      RHC_Action_Policy__c policy = insertedPolicy();
      RHC_Pending_Action__c action = RHCActionTestDataFactory.pending(policy.Id, 'review-bounds');
      action.Queue_Status__c = RHCActionConstants.STATUS_PENDING_REVIEW;
      update action;

      assertRejected(new List<Id>(), 'an empty batch');
      assertRejected(new List<Id>{ null }, 'a batch containing a null ID');
      assertRejected(new List<Id>{ action.Id, null }, 'a batch with one null among valid IDs');

      List<Id> oversized = new List<Id>();
      for (Integer index = 0; index < 51; index++) {
        oversized.add(action.Id);
      }
      assertRejected(oversized, 'a batch of 51');

      Assert.areEqual(
        RHCActionConstants.STATUS_PENDING_REVIEW,
        reload(action.Id).Queue_Status__c,
        'No rejected review batch may change pending-action state.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM RHC_Action_History__c],
        'No rejected review batch may write an audit row.'
      );
    }
  }

  private static void assertRejected(List<Id> ids, String description) {
    try {
      RHCActionReviewController.runActions(ids);
      Assert.fail('Approval must reject ' + description + '.');
    } catch (AuraHandledException expected) {
      assertSanitized(expected.getMessage(), 'Review rejection for ' + description);
    }
    try {
      RHCActionReviewController.rejectActions(ids);
      Assert.fail('Rejection must also reject ' + description + '.');
    } catch (AuraHandledException expected) {
      assertSanitized(expected.getMessage(), 'Reject rejection for ' + description);
    }
  }

  @IsTest
  static void shouldPurgeOnlyRowsStrictlyOutsideTheRetentionWindow() {
    RHCActionRetentionService.retentionPermissionOverride = true;
    RHC_Action_Policy__c policy = insertedPolicy();
    // The service derives its cutoff from its own clock, so exact-instant equality is not
    // assertable. One minute either side of the boundary is what catches a unit or sign error.
    Datetime base = System.now();
    Datetime justInside = base.addDays(-30).addMinutes(5);
    Datetime justOutside = base.addDays(-30).addMinutes(-5);
    insert new List<RHC_Action_History__c>{
      history(policy.Id, 'inside-window', justInside),
      history(policy.Id, 'outside-window', justOutside),
      history(policy.Id, 'far-outside', base.addDays(-400))
    };
    RHC_Pending_Action__c inside = RHCActionTestDataFactory.pending(policy.Id, 'inside');
    RHC_Pending_Action__c outside = RHCActionTestDataFactory.pending(policy.Id, 'outside');
    inside.Queue_Status__c = 'SUCCEEDED';
    inside.Completed_At__c = justInside;
    outside.Queue_Status__c = 'SUCCEEDED';
    outside.Completed_At__c = justOutside;
    update new List<RHC_Pending_Action__c>{ inside, outside };

    RHCActionRetentionService.PurgeOutcome outcome;
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionRetentionService.saveSettings(30);
      Test.startTest();
      outcome = RHCActionRetentionService.purge();
      Test.stopTest();
    }

    Assert.areEqual(2, outcome.historiesDeleted, 'Both rows past the boundary are removed.');
    Assert.areEqual(1, outcome.pendingActionsDeleted, 'Only the row past the boundary is removed.');
    // Asserting the surviving set as well as the deleted set is what catches an off-by-one
    // that would silently destroy data inside the customer's retention window.
    Set<String> survivingHistories = new Set<String>();
    for (RHC_Action_History__c record : [
      SELECT Execution_Key__c
      FROM RHC_Action_History__c
    ]) {
      survivingHistories.add(record.Execution_Key__c);
    }
    Assert.areEqual(
      new Set<String>{ 'inside-window' },
      survivingHistories,
      'Exactly the in-window history row survives.'
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM RHC_Pending_Action__c WHERE Id = :inside.Id],
      'The in-window pending action survives.'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM RHC_Pending_Action__c WHERE Id = :outside.Id],
      'The out-of-window pending action is gone.'
    );
  }

  @IsTest
  static void shouldRejectEveryInvalidRetentionWindow() {
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionRetentionService.retentionPermissionOverride = true;
      for (Integer invalid : new List<Integer>{ null, 0, -1, -3650, 3651, 2147483647 }) {
        try {
          RHCActionRetentionService.saveSettings(invalid);
          Assert.fail('A retention window of ' + invalid + ' must be rejected.');
        } catch (AuraHandledException expected) {
          Assert.isTrue(
            expected.getMessage().contains('1 through 3650'),
            'The rejection states the supported range: ' + expected.getMessage()
          );
        }
      }
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM RHC_Action_Setting__c],
        'No invalid window is ever persisted.'
      );

      // The documented boundaries themselves must be accepted.
      Assert.areEqual(
        1,
        RHCActionRetentionService.saveSettings(1).retentionDays,
        'One day is the documented minimum.'
      );
      Assert.areEqual(
        3650,
        RHCActionRetentionService.saveSettings(3650).retentionDays,
        'Ten years is the documented maximum.'
      );
    }
  }

  @IsTest
  static void shouldCaptureNothingWhenNoPolicyIsConfigured() {
    // An unconfigured package must be inert: no policy means no pending action, whatever
    // core publishes. This is the fail-closed property an empty policy table must have.
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionCaptureService.automaticPermissionOverride = true;
      RHCActionTestDataFactory.AsyncGatewayStub asyncStub = new RHCActionTestDataFactory.AsyncGatewayStub();
      RHCActionCaptureService.asyncGateway = asyncStub;
      List<Record_Health_Check_Result__e> events = new List<Record_Health_Check_Result__e>();
      for (Integer index = 0; index < 50; index++) {
        events.add(RHCActionTestDataFactory.eventRecord('unconfigured-' + index));
      }

      Test.startTest();
      RHCActionCaptureService.capture(events);
      Test.stopTest();

      Assert.areEqual(
        0,
        [SELECT COUNT() FROM RHC_Pending_Action__c],
        'No policy means no pending action is ever created.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM RHC_Action_History__c],
        'An inert package writes no audit rows.'
      );
      Assert.areEqual(
        0,
        asyncStub.enqueueCount,
        'An inert package submits no asynchronous work.'
      );
    }
  }

  @IsTest
  static void shouldNotCapturePolicyMismatchesOrUnsupportedEvents() {
    RHC_Action_Policy__c policy = insertedPolicy();
    System.runAs(RHCActionTestDataFactory.adminUser()) {
      RHCActionCaptureService.automaticPermissionOverride = false;
      RHCActionTestDataFactory.AsyncGatewayStub asyncStub = new RHCActionTestDataFactory.AsyncGatewayStub();
      RHCActionCaptureService.asyncGateway = asyncStub;

      Record_Health_Check_Result__e wrongCheck = RHCActionTestDataFactory.eventRecord('wrong-check');
      wrongCheck.CheckQualifiedApiName__c = 'Some_Other_Check';
      Record_Health_Check_Result__e wrongStatus = RHCActionTestDataFactory.eventRecord('wrong-status');
      wrongStatus.Status__c = 'PASS';
      Record_Health_Check_Result__e wrongSeverity = RHCActionTestDataFactory.eventRecord('wrong-sev');
      wrongSeverity.Severity__c = 'LOW';
      Record_Health_Check_Result__e wrongCheckSet = RHCActionTestDataFactory.eventRecord('wrong-set');
      wrongCheckSet.CheckSetQualifiedApiName__c = 'Some_Other_Set';
      Record_Health_Check_Result__e blankStatus = RHCActionTestDataFactory.eventRecord('blank-status');
      blankStatus.Status__c = '';
      Record_Health_Check_Result__e blankEvent = RHCActionTestDataFactory.eventRecord('blank-event');
      blankEvent.EventId__c = '';
      Record_Health_Check_Result__e injected = RHCActionTestDataFactory.eventRecord('injected');
      injected.CheckQualifiedApiName__c = policy.Check_Qualified_API_Name__c + '\' OR Name LIKE \'%';

      Test.startTest();
      RHCActionCaptureService.capture(
        new List<Record_Health_Check_Result__e>{
          wrongCheck,
          wrongStatus,
          wrongSeverity,
          wrongCheckSet,
          blankStatus,
          blankEvent,
          injected
        }
      );
      Test.stopTest();

      Assert.areEqual(
        0,
        [SELECT COUNT() FROM RHC_Pending_Action__c],
        'Policy matching is exact: a near-miss or a quoted check name never matches.'
      );
      Assert.areEqual(0, asyncStub.enqueueCount, 'Nothing matched, so nothing is enqueued.');
    }
  }

  private static RHC_Action_History__c history(Id policyId, String key, Datetime completedAt) {
    return new RHC_Action_History__c(
      Policy__c = policyId,
      Execution_Key__c = key,
      Event_Id__c = key,
      Record_Id__c = RHCActionTestDataFactory.syntheticId('001'),
      Run_Id__c = 'run-' + key,
      Outcome__c = 'SUCCEEDED',
      Attempt_Number__c = 1,
      Initiated_By__c = UserInfo.getUserId(),
      Started_At__c = completedAt,
      Completed_At__c = completedAt
    );
  }
}
