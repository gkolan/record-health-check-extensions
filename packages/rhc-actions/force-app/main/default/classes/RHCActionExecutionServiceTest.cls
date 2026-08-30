/**
 * Verifies single execution, allow-listed inputs, cooldown suppression, and bounded retries.
 */
@IsTest
private class RHCActionExecutionServiceTest {
  private static Integer starts = 0;
  private static Map<String, Object> lastInputs;

  private class TestFlowException extends Exception {
  }

  private class ThrowingAsyncGatewayStub extends RHCActionAsyncGateway {
    public override Id enqueue(List<Id> pendingIds, Integer delayMinutes) {
      throw new TestFlowException('Deliberate enqueue failure');
    }
  }

  private class GatewayStub extends RHCActionFlowGateway {
    private Boolean failStart;

    GatewayStub(Boolean failStart) {
      this.failStart = failStart;
    }

    public override FlowDescriptor describeActive(String flowApiName) {
      FlowDescriptor descriptor = new FlowDescriptor();
      descriptor.apiName = flowApiName;
      descriptor.activeVersionId = RHCActionTestDataFactory.syntheticId('301');
      descriptor.processType = 'AutoLaunchedFlow';
      for (String name : RHCActionConstants.allowedFlowInputs()) {
        VariableDescriptor variable = new VariableDescriptor();
        variable.apiName = name;
        variable.dataType = 'String';
        variable.isInput = true;
        variable.isOutput = false;
        variable.isCollection = false;
        descriptor.variablesByName.put(name, variable);
      }
      VariableDescriptor interview = new VariableDescriptor();
      interview.apiName = 'rhcInterviewGuidV1';
      interview.dataType = 'String';
      interview.isInput = false;
      interview.isOutput = true;
      interview.isCollection = false;
      descriptor.variablesByName.put(interview.apiName, interview);
      return descriptor;
    }

    public override String start(
      String flowApiName,
      Map<String, Object> inputs
    ) {
      RHCActionExecutionServiceTest.starts++;
      RHCActionExecutionServiceTest.lastInputs = inputs;
      if (failStart) {
        throw new TestFlowException('Deliberate test failure');
      }
      return 'interview-' + RHCActionExecutionServiceTest.starts;
    }
  }

  @TestSetup
  static void setupData() {
    RHCActionTestDataFactory.assignAdminPermission();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHC_Action_Policy__c policy = RHCActionTestDataFactory.policy();
      insert policy;
      RHC_Pending_Action__c action = RHCActionTestDataFactory.pending(
        policy.Id,
        'execute'
      );
      action.Approved_By__c = UserInfo.getUserId();
      action.Approved_At__c = System.now();
      update action;
    }
  }

  @IsTest
  static void shouldExecuteOnceAndRecordInterviewAndAllowedInputs() {
    starts = 0;
    GatewayStub gateway = new GatewayStub(false);
    RHCActionPolicyService.gateway = gateway;
    RHCActionExecutionService.gateway = gateway;
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;
    Test.startTest();
    List<Id> retries;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      retries = RHCActionExecutionService.execute(
        new List<Id>{ actionId, actionId }
      );
    }
    Test.stopTest();
    RHC_Pending_Action__c action = [
      SELECT Queue_Status__c, Flow_Interview_Id__c
      FROM RHC_Pending_Action__c
      WHERE Id = :actionId
    ];
    Assert.areEqual(
      'SUCCEEDED',
      action.Queue_Status__c,
      'The Flow should complete once.'
    );
    Assert.areEqual(
      1,
      starts,
      'A duplicate action ID must not start Flow twice.'
    );
    Assert.areEqual(0, retries.size(), 'A success must not retry.');
    Assert.areEqual(
      RHCActionConstants.allowedFlowInputs().size() - 2,
      lastInputs.size(),
      'Only selected allow-listed facts should be passed.'
    );
    Assert.isFalse(
      lastInputs.containsKey('rawPayload'),
      'Raw payloads must never enter Flow.'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM RHC_Action_History__c
        WHERE Outcome__c = 'SUCCEEDED'
      ],
      'The successful interview must be audited.'
    );
  }

  @IsTest
  static void shouldSuppressWhenRecordIsInsideCooldown() {
    RHC_Action_Policy__c policy = [SELECT Id FROM RHC_Action_Policy__c LIMIT 1];
    insert new RHC_Action_History__c(
      Policy__c = policy.Id,
      Execution_Key__c = 'prior-success',
      Record_Id__c = RHCActionTestDataFactory.syntheticId('001'),
      Outcome__c = 'SUCCEEDED',
      Attempt_Number__c = 1,
      Started_At__c = System.now(),
      Completed_At__c = System.now()
    );
    starts = 0;
    GatewayStub gateway = new GatewayStub(false);
    RHCActionPolicyService.gateway = gateway;
    RHCActionExecutionService.gateway = gateway;
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionExecutionService.execute(new List<Id>{ actionId });
    }
    Assert.areEqual(
      0,
      starts,
      'Cooldown must prevent correction-triggered loops.'
    );
    Assert.areEqual(
      'SUPPRESSED',
      [SELECT Queue_Status__c FROM RHC_Pending_Action__c WHERE Id = :actionId]
      .Queue_Status__c,
      'The suppression should be explicit.'
    );
  }

  @IsTest
  static void shouldNotSuppressWhenHistoryIsOutsidePolicyCooldown() {
    RHC_Action_Policy__c shortPolicy = RHCActionTestDataFactory.policy();
    shortPolicy.Cooldown_Minutes__c = 1;
    insert shortPolicy;
    RHC_Pending_Action__c shortAction = RHCActionTestDataFactory.pending(
      shortPolicy.Id,
      'short-cooldown'
    );
    shortAction.Approved_By__c = UserInfo.getUserId();
    shortAction.Approved_At__c = System.now();
    update shortAction;

    RHC_Action_Policy__c longPolicy = RHCActionTestDataFactory.policy();
    longPolicy.Check_Qualified_API_Name__c = 'Account_Long_Cooldown';
    longPolicy.Cooldown_Minutes__c = 60;
    insert longPolicy;
    RHC_Pending_Action__c longAction = RHCActionTestDataFactory.pending(
      longPolicy.Id,
      'long-cooldown'
    );
    longAction.Approved_By__c = UserInfo.getUserId();
    longAction.Approved_At__c = System.now();
    update longAction;

    insert new List<RHC_Action_History__c>{
      new RHC_Action_History__c(
        Policy__c = shortPolicy.Id,
        Execution_Key__c = 'expired-short-success',
        Record_Id__c = shortAction.Record_Id__c,
        Outcome__c = 'SUCCEEDED',
        Attempt_Number__c = 1,
        Started_At__c = System.now().addMinutes(-30),
        Completed_At__c = System.now().addMinutes(-30)
      ),
      new RHC_Action_History__c(
        Policy__c = longPolicy.Id,
        Execution_Key__c = 'active-long-success',
        Record_Id__c = longAction.Record_Id__c,
        Outcome__c = 'SUCCEEDED',
        Attempt_Number__c = 1,
        Started_At__c = System.now().addMinutes(-30),
        Completed_At__c = System.now().addMinutes(-30)
      )
    };
    starts = 0;
    GatewayStub gateway = new GatewayStub(false);
    RHCActionPolicyService.gateway = gateway;
    RHCActionExecutionService.gateway = gateway;

    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionExecutionService.execute(
        new List<Id>{ shortAction.Id, longAction.Id }
      );
    }
    Test.stopTest();

    Set<Id> actionIds = new Set<Id>{ shortAction.Id, longAction.Id };
    Map<Id, RHC_Pending_Action__c> actionsById = new Map<Id, RHC_Pending_Action__c>(
      [
        SELECT Queue_Status__c
        FROM RHC_Pending_Action__c
        WHERE Id IN :actionIds
      ]
    );
    Assert.areEqual(
      'SUCCEEDED',
      actionsById.get(shortAction.Id).Queue_Status__c,
      'History older than the policy-specific cutoff must not suppress execution.'
    );
    Assert.areEqual(
      'SUPPRESSED',
      actionsById.get(longAction.Id).Queue_Status__c,
      'History inside the policy-specific cutoff must suppress execution.'
    );
    Assert.areEqual(1, starts, 'Only the short-cooldown action should execute.');
  }

  @IsTest
  static void shouldFailClosedWhenPolicyIsDeactivatedAfterQueueing() {
    RHC_Action_Policy__c policy = [
      SELECT Id, Active__c
      FROM RHC_Action_Policy__c
      LIMIT 1
    ];
    policy.Active__c = false;
    update policy;
    starts = 0;
    GatewayStub gateway = new GatewayStub(false);
    RHCActionPolicyService.gateway = gateway;
    RHCActionExecutionService.gateway = gateway;
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;

    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionExecutionService.execute(new List<Id>{ actionId });
    }
    Test.stopTest();

    RHC_Pending_Action__c action = [
      SELECT Queue_Status__c, Last_Error_Code__c
      FROM RHC_Pending_Action__c
      WHERE Id = :actionId
    ];
    Assert.areEqual(0, starts, 'A deactivated policy must never start Flow.');
    Assert.areEqual('FAILED', action.Queue_Status__c, 'The action must fail closed.');
    Assert.areEqual(
      'EXECUTION_AUTHORIZATION_REVOKED',
      action.Last_Error_Code__c,
      'The terminal reason must identify authorization revocation.'
    );
  }

  @IsTest
  static void shouldFailClosedWhenAutomaticPermissionIsRevoked() {
    RHC_Action_Policy__c policy = [
      SELECT Id, Mode__c, Auto_Execution_Enabled__c
      FROM RHC_Action_Policy__c
      LIMIT 1
    ];
    policy.Mode__c = 'AUTOMATIC';
    policy.Auto_Execution_Enabled__c = true;
    update policy;
    RHC_Pending_Action__c action = [
      SELECT Id, Approved_By__c, Approved_At__c
      FROM RHC_Pending_Action__c
      LIMIT 1
    ];
    action.Approved_By__c = null;
    action.Approved_At__c = null;
    update action;
    RHCActionExecutionService.automaticPermissionOverride = false;
    starts = 0;
    GatewayStub gateway = new GatewayStub(false);
    RHCActionPolicyService.gateway = gateway;
    RHCActionExecutionService.gateway = gateway;

    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionExecutionService.execute(new List<Id>{ action.Id });
    }
    Test.stopTest();

    action = [
      SELECT Queue_Status__c, Last_Error_Code__c
      FROM RHC_Pending_Action__c
      WHERE Id = :action.Id
    ];
    Assert.areEqual(0, starts, 'Revoked automatic permission must prevent Flow.');
    Assert.areEqual('FAILED', action.Queue_Status__c, 'The action must fail closed.');
    Assert.areEqual(
      'EXECUTION_AUTHORIZATION_REVOKED',
      action.Last_Error_Code__c,
      'The terminal reason must identify authorization revocation.'
    );
  }

  @IsTest
  static void shouldFailClosedWhenApproverPermissionIsRevoked() {
    RHCActionExecutionService.approvalPermissionOverride = false;
    starts = 0;
    GatewayStub gateway = new GatewayStub(false);
    RHCActionPolicyService.gateway = gateway;
    RHCActionExecutionService.gateway = gateway;
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;

    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionExecutionService.execute(new List<Id>{ actionId });
    }
    Test.stopTest();

    RHC_Pending_Action__c action = [
      SELECT Queue_Status__c, Last_Error_Code__c
      FROM RHC_Pending_Action__c
      WHERE Id = :actionId
    ];
    Assert.areEqual(0, starts, 'Revoked approval permission must prevent Flow.');
    Assert.areEqual('FAILED', action.Queue_Status__c, 'The action must fail closed.');
    Assert.areEqual(
      'EXECUTION_AUTHORIZATION_REVOKED',
      action.Last_Error_Code__c,
      'The terminal reason must identify authorization revocation.'
    );
  }

  @IsTest
  static void shouldStopRetryingWhenRetryLimitIsReached() {
    GatewayStub gateway = new GatewayStub(true);
    RHCActionPolicyService.gateway = gateway;
    RHCActionExecutionService.gateway = gateway;
    RHC_Pending_Action__c action = [
      SELECT Id, Attempt_Count__c
      FROM RHC_Pending_Action__c
      LIMIT 1
    ];
    List<Id> firstRetry;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      firstRetry = RHCActionExecutionService.execute(
        new List<Id>{ action.Id }
      );
    }
    Assert.areEqual(
      1,
      firstRetry.size(),
      'The first failed attempt should be retryable.'
    );
    action = [
      SELECT Id, Queue_Status__c, Available_At__c
      FROM RHC_Pending_Action__c
      WHERE Id = :action.Id
    ];
    action.Available_At__c = System.now().addMinutes(-1);
    update action;
    List<Id> secondRetry;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      secondRetry = RHCActionExecutionService.execute(
        new List<Id>{ action.Id }
      );
    }
    Assert.areEqual(
      0,
      secondRetry.size(),
      'The configured retry limit must stop further attempts.'
    );
    Assert.areEqual(
      'FAILED',
      [SELECT Queue_Status__c FROM RHC_Pending_Action__c WHERE Id = :action.Id]
      .Queue_Status__c,
      'The final failure should be terminal.'
    );
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM RHC_Action_History__c],
      'Every attempt should have one history record.'
    );
  }

  @IsTest
  static void shouldScheduleRetryWithTheDocumentedDelay() {
    GatewayStub flowGateway = new GatewayStub(true);
    RHCActionPolicyService.gateway = flowGateway;
    RHCActionExecutionService.gateway = flowGateway;
    RHCActionTestDataFactory.AsyncGatewayStub asyncStub = new RHCActionTestDataFactory.AsyncGatewayStub();
    RHCActionExecutionQueueable.asyncGateway = asyncStub;
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;

    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      new RHCActionExecutionQueueable(new List<Id>{ actionId }).execute(null);
    }
    Test.stopTest();

    Assert.areEqual(1, asyncStub.enqueueCount, 'A retryable failure should enqueue once.');
    Assert.areEqual(1, asyncStub.lastPendingIds.size(), 'The failed action should be retried.');
    Assert.areEqual(1, asyncStub.lastDelayMinutes, 'Retry delay must be one minute.');
  }

  @IsTest
  static void shouldRecoverQueueableInfrastructureFailureWithinRetryLimit() {
    RHCActionTestDataFactory.AsyncGatewayStub asyncStub = new RHCActionTestDataFactory.AsyncGatewayStub();
    RHCActionExecutionFinalizer.asyncGateway = asyncStub;
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;

    Test.startTest();
    new RHCActionExecutionFinalizer(new List<Id>{ actionId }).recoverAfterFailure();
    Test.stopTest();

    RHC_Pending_Action__c action = [
      SELECT Queue_Status__c, Available_At__c, Last_Error_Code__c
      FROM RHC_Pending_Action__c
      WHERE Id = :actionId
    ];
    Assert.areEqual('RETRY_WAIT', action.Queue_Status__c, 'Infrastructure failure should be recoverable.');
    Assert.isNotNull(action.Available_At__c, 'Recovery must be delayed.');
    Assert.areEqual('ASYNC_EXECUTION_RETRYABLE', action.Last_Error_Code__c, 'The failure must be classified.');
    Assert.areEqual(1, asyncStub.enqueueCount, 'Recovery should enqueue exactly once.');
    Assert.areEqual(1, asyncStub.lastDelayMinutes, 'Recovery delay must be one minute.');
  }

  @IsTest
  static void shouldFailQueueableInfrastructureFailureAtRetryLimit() {
    RHC_Pending_Action__c action = [
      SELECT Id, Attempt_Count__c
      FROM RHC_Pending_Action__c
      LIMIT 1
    ];
    action.Attempt_Count__c = 2;
    update action;

    Test.startTest();
    new RHCActionExecutionFinalizer(new List<Id>{ action.Id }).recoverAfterFailure();
    Test.stopTest();

    action = [
      SELECT Queue_Status__c, Available_At__c, Completed_At__c, Last_Error_Code__c
      FROM RHC_Pending_Action__c
      WHERE Id = :action.Id
    ];
    Assert.areEqual('FAILED', action.Queue_Status__c, 'An exhausted recovery must be terminal.');
    Assert.isNull(action.Available_At__c, 'A terminal action must not remain schedulable.');
    Assert.isNotNull(action.Completed_At__c, 'A terminal action must record completion.');
    Assert.areEqual('ASYNC_EXECUTION_FAILED', action.Last_Error_Code__c, 'The terminal reason must be bounded.');
  }

  @IsTest
  static void shouldFailClosedWhenRecoveryCannotBeEnqueued() {
    RHCActionExecutionFinalizer.asyncGateway = new ThrowingAsyncGatewayStub();
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;

    Test.startTest();
    new RHCActionExecutionFinalizer(new List<Id>{ actionId }).recoverAfterFailure();
    Test.stopTest();

    RHC_Pending_Action__c action = [
      SELECT Queue_Status__c, Available_At__c, Completed_At__c, Last_Error_Code__c
      FROM RHC_Pending_Action__c
      WHERE Id = :actionId
    ];
    Assert.areEqual('FAILED', action.Queue_Status__c, 'A failed recovery submission must fail closed.');
    Assert.isNull(action.Available_At__c, 'A failed submission must not remain schedulable.');
    Assert.isNotNull(action.Completed_At__c, 'A failed submission must record completion.');
    Assert.areEqual(
      'ASYNC_RECOVERY_ENQUEUE_FAILED',
      action.Last_Error_Code__c,
      'The enqueue failure must be classified without leaking exception detail.'
    );
  }

  @IsTest
  static void shouldIgnoreEmptyFinalizerRecovery() {
    Test.startTest();
    new RHCActionExecutionFinalizer(null).recoverAfterFailure();
    Test.stopTest();
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM RHC_Pending_Action__c WHERE Queue_Status__c = 'QUEUED'],
      'An empty recovery request must not mutate pending actions.'
    );
  }

  @IsTest
  static void shouldEnqueueImmediateAsyncExecution() {
    Test.startTest();
    Id jobId = new RHCActionAsyncGateway().enqueue(new List<Id>(), 0);
    Test.stopTest();
    Assert.isNotNull(jobId, 'Immediate execution must return its Queueable job ID.');
  }

  @IsTest
  static void shouldEnqueueDelayedAsyncExecution() {
    Test.startTest();
    Id jobId = new RHCActionAsyncGateway().enqueue(new List<Id>(), 1);
    Test.stopTest();
    Assert.isNotNull(jobId, 'Delayed execution must return its Queueable job ID.');
  }
}
