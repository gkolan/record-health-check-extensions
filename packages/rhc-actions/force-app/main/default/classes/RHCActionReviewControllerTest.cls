/**
 * Verifies manual authorization and locked state transitions.
 */
@IsTest
private class RHCActionReviewControllerTest {
  private class ReviewGatewayStub extends RHCActionFlowGateway {
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
  }

  @TestSetup
  static void setupData() {
    RHCActionTestDataFactory.assignAdminPermission();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHC_Action_Policy__c policy = RHCActionTestDataFactory.policy();
      insert policy;
      RHC_Pending_Action__c action = RHCActionTestDataFactory.pending(
        policy.Id,
        'manual'
      );
      action.Queue_Status__c = 'PENDING_REVIEW';
      update action;
    }
  }

  @IsTest
  static void shouldRejectRequestWhenApprovalPermissionIsMissing() {
    RHCActionReviewController.approvalPermissionOverride = false;
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;
    Test.startTest();
    try {
      RHCActionReviewController.runAction(actionId);
      Assert.fail('Missing approval permission should reject execution.');
    } catch (AuraHandledException expected) {
      Assert.isNotNull(
        expected,
        'The server must enforce the approval permission.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRecordMayaAsApproverWhenManualActionIsRun() {
    RHCActionReviewController.approvalPermissionOverride = true;
    RHCActionTestDataFactory.AsyncGatewayStub asyncStub = new RHCActionTestDataFactory.AsyncGatewayStub();
    RHCActionReviewController.asyncGateway = asyncStub;
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;
    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionReviewController.runAction(actionId);
    }
    Test.stopTest();
    RHC_Pending_Action__c action = [
      SELECT Queue_Status__c, Approved_By__c, Approved_At__c
      FROM RHC_Pending_Action__c
      WHERE Id = :actionId
    ];
    Assert.areEqual(
      'QUEUED',
      action.Queue_Status__c,
      'Manual approval should queue asynchronous execution.'
    );
    Assert.areEqual(
      UserInfo.getUserId(),
      action.Approved_By__c,
      'The approving identity must be audited.'
    );
    Assert.isNotNull(action.Approved_At__c, 'Approval time must be audited.');
    Assert.areEqual(1, asyncStub.enqueueCount, 'Approval should enqueue exactly once.');
  }

  @IsTest
  static void shouldRejectSecondApprovalWhenActionIsAlreadyQueued() {
    RHCActionReviewController.approvalPermissionOverride = true;
    RHCActionReviewController.asyncGateway = new RHCActionTestDataFactory.AsyncGatewayStub();
    Id actionId = [SELECT Id FROM RHC_Pending_Action__c LIMIT 1].Id;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionReviewController.runAction(actionId);
      try {
        RHCActionReviewController.runAction(actionId);
        Assert.fail('The same pending action cannot be approved twice.');
      } catch (AuraHandledException expected) {
        Assert.isNotNull(
          expected,
          'The locked state transition should reject duplicates.'
        );
      }
    }
  }

  @IsTest
  static void shouldApproveSelectionInOneDecisionAndSkipNonPending() {
    RHCActionReviewController.approvalPermissionOverride = true;
    RHCActionReviewController.asyncGateway = new RHCActionTestDataFactory.AsyncGatewayStub();
    RHCActionReviewController.ReviewOutcome outcome;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHC_Pending_Action__c pending = [SELECT Id, Policy__c FROM RHC_Pending_Action__c LIMIT 1];
      RHC_Pending_Action__c second = RHCActionTestDataFactory.pending(pending.Policy__c, 'manual-2');
      second.Queue_Status__c = 'PENDING_REVIEW';
      update second;
      RHC_Pending_Action__c alreadyQueued = RHCActionTestDataFactory.pending(pending.Policy__c, 'queued');
      alreadyQueued.Queue_Status__c = 'QUEUED';
      update alreadyQueued;

      Test.startTest();
      outcome = RHCActionReviewController.runActions(
        new List<Id>{ pending.Id, second.Id, alreadyQueued.Id }
      );
      Test.stopTest();
    }
    Assert.areEqual(2, outcome.processed, 'Both pending-review rows are approved.');
    Assert.areEqual(1, outcome.skipped, 'The already queued row is skipped, not failed.');
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM RHC_Pending_Action__c WHERE Queue_Status__c = 'QUEUED' AND Approved_By__c = :UserInfo.getUserId()],
      'Approved rows record the approver.'
    );
  }

  @IsTest
  static void shouldListAndRejectWhenApproverReviewsQueue() {
    RHCActionReviewController.approvalPermissionOverride = true;
    Test.startTest();
    List<RHC_Pending_Action__c> actions;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      actions = RHCActionReviewController.getPendingActions();
      RHCActionReviewController.rejectAction(actions[0].Id);
    }
    Test.stopTest();
    RHC_Pending_Action__c rejected = [
      SELECT Queue_Status__c, Approved_By__c, Completed_At__c
      FROM RHC_Pending_Action__c
      WHERE Id = :actions[0].Id
    ];
    Assert.areEqual(
      'REJECTED',
      rejected.Queue_Status__c,
      'The reviewer should be able to reject safely.'
    );
    Assert.areEqual(
      UserInfo.getUserId(),
      rejected.Approved_By__c,
      'The rejecting identity should be recorded.'
    );
    Assert.isNotNull(rejected.Completed_At__c, 'Rejection should be terminal.');
  }

  @IsTest
  static void shouldValidatePolicyWhenApproverRequestsReview() {
    RHCActionReviewController.approvalPermissionOverride = true;
    RHCActionPolicyService.gateway = new ReviewGatewayStub();
    Id policyId = [SELECT Id FROM RHC_Action_Policy__c LIMIT 1].Id;
    Test.startTest();
    RHCActionPolicyService.ValidationResult result;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      result = RHCActionReviewController.validatePolicy(policyId);
    }
    Test.stopTest();
    Assert.isTrue(
      result.valid,
      'The controller should return Flow contract validation.'
    );
  }

  @IsTest
  static void shouldRejectNullIdsWhenApproverInvokesMutation() {
    RHCActionReviewController.approvalPermissionOverride = true;
    try {
      RHCActionReviewController.runAction(null);
      Assert.fail('A null pending action ID must be rejected.');
    } catch (AuraHandledException expected) {
      Assert.isNotNull(
        expected,
        'The controller should throw a handled error.'
      );
    }
  }

  @IsTest
  static void shouldExecuteQueueableWithEmptyInput() {
    Integer beforeCount = [SELECT COUNT() FROM RHC_Action_History__c];
    Test.startTest();
    System.enqueueJob(new RHCActionExecutionQueueable(null));
    Test.stopTest();
    Assert.areEqual(
      beforeCount,
      [SELECT COUNT() FROM RHC_Action_History__c],
      'An empty Queueable must not create audit attempts.'
    );
  }
}
