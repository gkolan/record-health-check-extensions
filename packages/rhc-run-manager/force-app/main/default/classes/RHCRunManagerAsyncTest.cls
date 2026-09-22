@IsTest
private class RHCRunManagerAsyncTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
    RHCRunManagerTestDataFactory.createPersonaUser('rhcview', 'RHC_Run_Manager_Viewer');
  }

  @IsTest
  static void shouldUseSharedExecutionPathWhenRunNow() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    RHCRunManagerTestDataFactory.createAccounts(2);
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');

    Test.startTest();
    Id batchRunId = RHCRunManagerExecutionService.runNow(definition.Id);
    Test.stopTest();

    Record_Health_Check_Batch_Run__c batchRun = [
      SELECT Status__c, Source__c, AsyncApexJobId__c, SubmittedRecordCount__c, FailedScopeCount__c, ErrorSummary__c
      FROM Record_Health_Check_Batch_Run__c WHERE Id = :batchRunId
    ];
    Assert.areEqual('COMPLETED', batchRun.Status__c, 'The owned Batch should complete. Scope error: ' + batchRun.ErrorSummary__c);
    Assert.areEqual('RUN_NOW', batchRun.Source__c, 'Run Now must use the canonical source.');
    Assert.isNotNull(batchRun.AsyncApexJobId__c, 'Monitoring must retain the exact AsyncApexJob identity.');
    Assert.areEqual(0, batchRun.FailedScopeCount__c, 'Framework execution should not fail a scope.');
    }
  }

  @IsTest
  static void shouldCoalescePendingIdsIntoOneSuppliedIdsBatch() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    List<Account> accounts = RHCRunManagerTestDataFactory.createAccounts(2);
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    insert new List<Record_Health_Check_Run_Request__c>{
      pending(definition.Id, accounts[0].Id),
      pending(definition.Id, accounts[1].Id)
    };

    Test.startTest();
    new RHCRunManagerCoalescerQueueable(definition.Id).execute((QueueableContext) null);
    Test.stopTest();

    Assert.areEqual(2, [SELECT COUNT() FROM Record_Health_Check_Run_Request__c WHERE Status__c = 'SUBMITTED'], 'Every drained request should be marked submitted.');
    Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c WHERE Source__c = 'SUPPLIED_IDS'], 'All committed IDs should share one Batch launch.');
    }
  }

  @IsTest
  static void shouldContinueDrainingWhenPendingRowsExceedSafePage() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    List<Account> accounts = RHCRunManagerTestDataFactory.createAccounts(3);
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    insert new List<Record_Health_Check_Run_Request__c>{
      pending(definition.Id, accounts[0].Id),
      pending(definition.Id, accounts[1].Id),
      pending(definition.Id, accounts[2].Id)
    };
    RHCRunManagerCoalescerQueueable.drainSize = 2;

    Test.startTest();
    new RHCRunManagerCoalescerQueueable(definition.Id).execute((QueueableContext) null);
    Test.stopTest();

    Assert.areEqual(3, [SELECT COUNT() FROM Record_Health_Check_Run_Request__c WHERE Status__c = 'SUBMITTED'], 'A continuation should drain the remaining committed requests.');
    Assert.areEqual(2, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c WHERE Source__c = 'SUPPLIED_IDS'], 'Each governor-safe page should launch one owned Batch.');
    }
  }

  @IsTest
  static void shouldConsumeRequestWithoutBatchWhenRecordIdMalformed() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    Record_Health_Check_Run_Request__c requestValue = new Record_Health_Check_Run_Request__c(
      RunDefinition__c = definition.Id,
      RequestKey__c = definition.Id + '|malformed',
      RecordId__c = 'not-an-id',
      Status__c = 'PENDING',
      RequestedAt__c = System.now()
    );
    insert requestValue;

    Test.startTest();
    new RHCRunManagerCoalescerQueueable(definition.Id).execute((QueueableContext) null);
    Test.stopTest();

    requestValue = [
      SELECT Status__c
      FROM Record_Health_Check_Run_Request__c
      WHERE Id = :requestValue.Id
    ];
    Assert.areEqual('SUBMITTED', requestValue.Status__c, 'A malformed durable ID should not remain pending forever.');
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c], 'Malformed IDs must not launch Batch work.');
    }
  }

  @IsTest
  static void shouldValidateExecutionInputs() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    Boolean customSourceRejected = false;
    try {
      RHCRunManagerExecutionService.start(executionRequest(definition.Id, 'CUSTOM_BATCH', null));
    } catch (RHCRunManagerExecutionService.ExecutionException error) {
      customSourceRejected = true;
    }
    Assert.isTrue(customSourceRejected, 'Customer-owned execution sources are not accepted.');

    Boolean emptyIdsRejected = false;
    try {
      RHCRunManagerExecutionService.start(executionRequest(definition.Id, 'SUPPLIED_IDS', new List<Id>()));
    } catch (RHCRunManagerExecutionService.ExecutionException error) {
      emptyIdsRejected = true;
    }
    Assert.isTrue(emptyIdsRejected, 'Supplied-ID execution requires at least one target.');

    Boolean runNowRejected = false;
    try {
      RHCRunManagerExecutionService.runNow(definition.Id);
    } catch (RHCRunManagerExecutionService.ExecutionException error) {
      runNowRejected = true;
    }
    Assert.isTrue(runNowRejected, 'Supplied-ID definitions must not create empty Run Now jobs.');

    Record_Health_Check_Run_Definition__c allRecordsDefinition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    Boolean wrongDefinitionRejected = false;
    try {
      RHCRunManagerExecutionService.start(executionRequest(allRecordsDefinition.Id, 'SUPPLIED_IDS', new List<Id>{ UserInfo.getUserId() }));
    } catch (RHCRunManagerExecutionService.ExecutionException error) {
      wrongDefinitionRejected = true;
    }
    Assert.isTrue(wrongDefinitionRejected, 'Supplied-ID execution must require a supplied-ID definition.');
    }
  }

  @IsTest
  static void shouldRejectNullExecutionRequest() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Test.startTest();
      try {
        RHCRunManagerExecutionService.start(null);
        Assert.fail('Expected a null execution request to fail.');
      } catch (RHCRunManagerExecutionService.ExecutionException error) {
        Assert.areEqual('Run Definition is required.', error.getMessage(), 'The failure should identify the missing definition.');
      }
      Test.stopTest();
    }
  }

  private static RHCRunManagerExecutionService.Request executionRequest(
    Id definitionId,
    String source,
    List<Id> suppliedIds
  ) {
    RHCRunManagerExecutionService.Request request = new RHCRunManagerExecutionService.Request();
    request.definitionId = definitionId;
    request.source = source;
    request.suppliedIds = suppliedIds;
    return request;
  }

  @IsTest
  static void shouldEnqueueOneDelayedCoalescerWhenDefinitionValid() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');

    Test.startTest();
    Id queueableId = RHCRunManagerCoalescerQueueable.enqueue(definition.Id);
    Test.stopTest();

    Assert.isNotNull(queueableId, 'A valid definition should enqueue an owned delayed coalescer.');
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Batch_Run__c], 'An empty coalescer must not launch Batch work.');
    }
  }

  @IsTest
  static void shouldLetViewerMonitorCrossOwnerRunsWithoutWriteAccess() {
    Record_Health_Check_Batch_Run__c batchRun;
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
      batchRun = RHCRunManagerTestDataFactory.createBatchRun(definition.Id);
    }
    System.runAs(RHCRunManagerTestDataFactory.personaUser('rhcview')) {
      List<Record_Health_Check_Batch_Run__c> visibleRuns = [
        SELECT Id, Status__c
        FROM Record_Health_Check_Batch_Run__c
        WHERE Id = :batchRun.Id
        WITH USER_MODE
      ];
      Assert.areEqual(1, visibleRuns.size(), 'Viewer must monitor an Admin-owned Batch Run.');
      visibleRuns[0].Status__c = 'ERROR';
      Database.SaveResult updateResult = Database.update(visibleRuns[0], false, AccessLevel.USER_MODE);
      Assert.isFalse(updateResult.isSuccess(), 'Cross-owner monitoring must remain read-only.');
    }
  }

  @IsTest
  static void shouldRetryOnlyUnhandledFailuresBeforeAttemptLimit() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Test.startTest();
    Boolean firstFailure = RHCRunManagerCoalescerQueueable.isRetryEligible(ParentJobResult.UNHANDLED_EXCEPTION, 0);
    Boolean secondFailure = RHCRunManagerCoalescerQueueable.isRetryEligible(ParentJobResult.UNHANDLED_EXCEPTION, 1);
    Boolean exhaustedFailure = RHCRunManagerCoalescerQueueable.isRetryEligible(ParentJobResult.UNHANDLED_EXCEPTION, 2);
    Boolean successfulJob = RHCRunManagerCoalescerQueueable.isRetryEligible(ParentJobResult.SUCCESS, 0);
    Test.stopTest();

    Assert.isTrue(
      firstFailure,
      'The first unhandled failure should be retryable.'
    );
    Assert.isTrue(
      secondFailure,
      'The second unhandled failure should be retryable.'
    );
    Assert.isFalse(
      exhaustedFailure,
      'The configured attempt limit must stop recursion.'
    );
    Assert.isFalse(
      successfulJob,
      'Successful jobs must never enqueue a retry.'
    );
    }
  }

  private static Record_Health_Check_Run_Request__c pending(Id definitionId, Id targetId) {
    return new Record_Health_Check_Run_Request__c(
      RunDefinition__c = definitionId,
      RequestKey__c = definitionId + '|' + targetId,
      RecordId__c = String.valueOf(targetId),
      Status__c = 'PENDING',
      RequestedAt__c = System.now()
    );
  }
}
