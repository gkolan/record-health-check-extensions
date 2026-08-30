// Subscribers run in the Platform Event context; System.runAs would not model Automated Process.
// User-mode Admin and Viewer surfaces are verified in their controller test classes.
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsEventServiceTest {
  @TestSetup
  static void setup() {
    RHCAlertsTestDataFactory.assignAdminPermissions();
  }

  @IsTest
  static void shouldCreateOneSuccessAndDuplicateWhenEventIdRepeats() {
    Account account = new Account(Name = 'Idempotency');
    insert account;
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Exact_Check',
      0
    );
    Record_Health_Check_Result__e eventValue = RHCAlertsTestDataFactory.resultEvent(
      'event-duplicate',
      'pkg__Exact_Check',
      account.Id
    );

    Test.startTest();
    RHCAlertsEventService.processResults(
      new List<Record_Health_Check_Result__e>{ eventValue, eventValue }
    );
    List<Record_Health_Check_Alert_Delivery__c> pending = [
      SELECT Id
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Policy__c = :policy.Id AND Outcome__c = 'PENDING'
    ];
    RHCAlertsDeliveryService.deliver(new List<Id>{ pending[0].Id });
    Test.stopTest();

    List<Record_Health_Check_Alert_Delivery__c> rows = [
      SELECT Outcome__c, DeliveryKey__c, SuppressionReason__c, FailureClass__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Policy__c = :policy.Id
      ORDER BY CreatedDate
    ];
    Assert.areEqual(
      2,
      rows.size(),
      'Both the claim and duplicate evidence should exist.'
    );
    Assert.areEqual(
      'DELIVERED',
      rows[0].Outcome__c,
      'The unique claim should deliver once.'
    );
    Assert.areEqual(
      'DUPLICATE',
      rows[1].Outcome__c,
      'The repeated Event ID should be explicitly duplicate.'
    );
    Assert.isNotNull(
      rows[0].DeliveryKey__c,
      'Only the processing claim carries the unique key.'
    );
    Assert.isNull(
      rows[1].DeliveryKey__c,
      'Duplicate evidence must not compete for the unique key.'
    );
    Assert.isNull(
      rows[0].SuppressionReason__c,
      'Delivered rows must not display a suppression reason.'
    );
    Assert.isNull(
      rows[1].FailureClass__c,
      'Duplicate evidence must not display a failure class.'
    );
  }

  @IsTest
  static void shouldPreserveNamespaceWhenMatchingExactIdentity() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'one__Shared_Name',
      0
    );
    Record_Health_Check_Result__e wrongNamespace = RHCAlertsTestDataFactory.resultEvent(
      'event-wrong',
      'two__Shared_Name',
      UserInfo.getUserId()
    );
    Record_Health_Check_Result__e exactNamespace = RHCAlertsTestDataFactory.resultEvent(
      'event-exact',
      'one__Shared_Name',
      UserInfo.getUserId()
    );

    Test.startTest();
    RHCAlertsEventService.processResults(
      new List<Record_Health_Check_Result__e>{ wrongNamespace, exactNamespace }
    );
    Test.stopTest();

    List<Record_Health_Check_Alert_Delivery__c> rows = [
      SELECT EventId__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Policy__c = :policy.Id
    ];
    Assert.areEqual(
      1,
      rows.size(),
      'Namespace prefixes must not be stripped or aliased.'
    );
    Assert.areEqual(
      'event-exact',
      rows[0].EventId__c,
      'Only the exact Qualified API Name should match.'
    );
  }

  @IsTest
  static void shouldRecordRunContractGapWithoutSending() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'unused',
      0
    );
    policy.SelectionType__c = 'CHECK_SET';
    policy.QualifiedApiName__c = 'pkg__Test_Set';
    update policy;
    Record_Health_Check_Set_Run__e eventValue = new Record_Health_Check_Set_Run__e(
      ContractVersion__c = '1.0',
      EventId__c = 'set-event',
      RunId__c = 'set-run',
      Phase__c = 'COMPLETED',
      CheckSetQualifiedApiName__c = 'pkg__Test_Set',
      OccurredAt__c = System.now(),
      Source__c = 'FLOW',
      FrameworkVersion__c = '2.0.4'
    );
    Record_Health_Check_Set_Run__e duplicateEvent = new Record_Health_Check_Set_Run__e(
      ContractVersion__c = '1.0',
      EventId__c = 'set-event',
      RunId__c = 'set-run',
      Phase__c = 'COMPLETED',
      CheckSetQualifiedApiName__c = 'pkg__Test_Set',
      OccurredAt__c = eventValue.OccurredAt__c,
      Source__c = 'FLOW',
      FrameworkVersion__c = '2.0.4'
    );

    Test.startTest();
    EventBus.publish(
      new List<Record_Health_Check_Set_Run__e>{ eventValue, duplicateEvent }
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    List<Record_Health_Check_Alert_Delivery__c> rows = [
      SELECT Outcome__c, SuppressionReason__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Policy__c = :policy.Id
      ORDER BY CreatedDate
    ];
    Assert.areEqual(
      'SUPPRESSED',
      rows[0].Outcome__c,
      'Run contract 1.0 must not invent severity.'
    );
    Assert.areEqual(
      'RUN_CONTRACT_INSUFFICIENT',
      rows[0].SuppressionReason__c,
      'The contract limitation should be visible.'
    );
    Assert.areEqual(
      'DUPLICATE',
      rows[1].Outcome__c,
      'At-least-once run delivery should remain idempotent.'
    );
  }

  @IsTest
  static void shouldInvokeResultSubscriberForCanonicalEvent() {
    Record_Health_Check_Result__e eventValue = RHCAlertsTestDataFactory.resultEvent(
      'trigger-result',
      'pkg__No_Policy',
      UserInfo.getUserId()
    );
    Test.startTest();
    EventBus.publish(eventValue);
    Test.getEventBus().deliver();
    Test.stopTest();
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Record_Health_Check_Alert_Delivery__c
        WHERE EventId__c = 'trigger-result'
      ],
      'An event without a matching policy should not retain result history.'
    );
  }

  @IsTest
  static void shouldIgnoreUnsupportedContractWithoutAffectingValidEvent() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Supported_Check',
      0
    );
    Record_Health_Check_Result__e unsupported = RHCAlertsTestDataFactory.resultEvent(
      'unsupported-event',
      'pkg__Unsupported_Check',
      UserInfo.getUserId()
    );
    unsupported.ContractVersion__c = '2.0';
    Record_Health_Check_Result__e supported = RHCAlertsTestDataFactory.resultEvent(
      'supported-event',
      'pkg__Supported_Check',
      UserInfo.getUserId()
    );

    Test.startTest();
    RHCAlertsEventService.processResults(
      new List<Record_Health_Check_Result__e>{ unsupported, supported }
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Record_Health_Check_Alert_Delivery__c
        WHERE EventId__c = 'unsupported-event'
      ],
      'Unsupported contracts must not query or claim policy work.'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Record_Health_Check_Alert_Delivery__c
        WHERE EventId__c = 'supported-event' AND Policy__c = :policy.Id
      ],
      'A valid event in the same batch must still be claimed.'
    );
  }

  @IsTest
  static void shouldBoundClaimsAndRecordFailureWhenPolicyFanoutExceedsLimit() {
    String checkSetName = 'pkg__Fanout_Set';
    Integer policyCount = RHCAlertsEventService.MAX_CLAIMS_PER_BATCH + 1;
    insert RHCAlertsTestDataFactory.buildCheckSetPolicies(
      checkSetName,
      policyCount
    );
    Record_Health_Check_Set_Run__e eventValue = new Record_Health_Check_Set_Run__e(
      ContractVersion__c = '1.0',
      EventId__c = 'fanout-event',
      RunId__c = 'fanout-run',
      Phase__c = 'COMPLETED',
      CheckSetQualifiedApiName__c = checkSetName,
      OccurredAt__c = System.now(),
      Source__c = 'APEX_API',
      FrameworkVersion__c = '2.0.4'
    );

    Test.startTest();
    RHCAlertsEventService.processSetRuns(
      new List<Record_Health_Check_Set_Run__e>{ eventValue }
    );
    Test.stopTest();

    List<AggregateResult> outcomes = [
      SELECT Outcome__c outcome, ErrorCode__c errorCode, COUNT(Id) rowCount
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE EventId__c = 'fanout-event'
      GROUP BY Outcome__c, ErrorCode__c
    ];
    Integer suppressedCount = 0;
    Integer overflowCount = 0;
    for (AggregateResult outcome : outcomes) {
      Integer rowCount = Integer.valueOf(
        String.valueOf(outcome.get('rowCount'))
      );
      if (
        'SUPPRESSED'.equals(outcome.get('outcome')) &&
        outcome.get('errorCode') == null
      ) {
        suppressedCount += rowCount;
      }
      if (
        'FAILED'.equals(outcome.get('outcome')) &&
        'EVENT_POLICY_FANOUT_LIMIT'.equals(outcome.get('errorCode'))
      ) {
        overflowCount += rowCount;
      }
    }
    Assert.areEqual(
      RHCAlertsEventService.MAX_CLAIMS_PER_BATCH,
      suppressedCount,
      'Only the documented maximum policy claims may be inserted.'
    );
    Assert.areEqual(
      1,
      overflowCount,
      'Overflow must create one visible bounded failure row.'
    );
  }

  @IsTest
  static void shouldPersistBoundedEvidenceWhenClaimInsertFails() {
    Record_Health_Check_Alert_Delivery__c invalidCandidate = new Record_Health_Check_Alert_Delivery__c(
      EventId__c = 'invalid-claim',
      EventType__c = 'RESULT',
      Outcome__c = 'NOT_A_CANONICAL_OUTCOME',
      OccurredAt__c = System.now(),
      AttemptCount__c = 0,
      RecipientCount__c = 0
    );

    Test.startTest();
    RHCAlertsEventService.claim(
      new List<Record_Health_Check_Alert_Delivery__c>{ invalidCandidate },
      false
    );
    Test.stopTest();

    Record_Health_Check_Alert_Delivery__c evidence = [
      SELECT Outcome__c, FailureClass__c, ErrorCode__c, DeliveryKey__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE EventId__c = 'invalid-claim'
      LIMIT 1
    ];
    Assert.areEqual(
      'FAILED',
      evidence.Outcome__c,
      'A rejected claim must not disappear silently.'
    );
    Assert.areEqual(
      'PERMANENT',
      evidence.FailureClass__c,
      'Non-duplicate claim rejection must be terminal.'
    );
    Assert.areEqual(
      'CLAIM_INSERT_FAILED',
      evidence.ErrorCode__c,
      'Evidence must retain only a bounded package code.'
    );
    Assert.isNull(
      evidence.DeliveryKey__c,
      'Fallback evidence must not compete for the idempotency key.'
    );
  }

  @IsTest
  @SuppressWarnings('PMD.OperationWithLimitsInLoop')
  static void shouldFailClaimsWhenQueueableCapacityIsExhausted() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Queue_Limit_Check',
      0
    );
    Record_Health_Check_Result__e eventValue = RHCAlertsTestDataFactory.resultEvent(
      'queue-limit-event',
      'pkg__Queue_Limit_Check',
      UserInfo.getUserId()
    );

    Test.startTest();
    // Intentionally consume the transaction's Queueable allocation to verify the preflight guard.
    for (Integer index = 0; index < Limits.getLimitQueueableJobs(); index++) {
      System.enqueueJob(new RHCAlertsDeliveryQueueable(null));
    }
    RHCAlertsEventService.processResults(
      new List<Record_Health_Check_Result__e>{ eventValue }
    );
    Test.stopTest();

    Record_Health_Check_Alert_Delivery__c row = [
      SELECT Outcome__c, FailureClass__c, ErrorCode__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE EventId__c = 'queue-limit-event' AND Policy__c = :policy.Id
      LIMIT 1
    ];
    Assert.areEqual(
      'FAILED',
      row.Outcome__c,
      'A claim without Queueable capacity must be terminally dispositioned.'
    );
    Assert.areEqual(
      'LIMIT',
      row.FailureClass__c,
      'Queue capacity is a limit failure.'
    );
    Assert.areEqual(
      'QUEUE_ENQUEUE_FAILED',
      row.ErrorCode__c,
      'Dispatch failure must use the bounded package code.'
    );
  }
}
