/**
 * Proves the bounded delivery worker slices and chains correctly, never double-sends a row that
 * already reached a terminal outcome, and converts an unhandled async failure into evidence.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsDeliveryQueueableTest {
  @TestSetup
  static void setup() {
    RHCAlertsTestDataFactory.assignAdminPermissions();
  }

  private static Record_Health_Check_Alert_Policy__c policy() {
    return RHCAlertsTestDataFactory.createCheckPolicy('pkg__Queue_Check', 0);
  }

  private static List<Id> pendingIds(
    Record_Health_Check_Alert_Policy__c parentPolicy,
    Integer count
  ) {
    List<Record_Health_Check_Alert_Delivery__c> rows = new List<Record_Health_Check_Alert_Delivery__c>();
    for (Integer index = 0; index < count; index++) {
      rows.add(
        new Record_Health_Check_Alert_Delivery__c(
          Policy__c = parentPolicy.Id,
          EventId__c = 'q-evt-' + index,
          EventType__c = 'RESULT',
          Outcome__c = 'PENDING',
          AttemptCount__c = 0,
          RecipientCount__c = 0,
          CooldownKey__c = 'cooldown-' + index,
          OccurredAt__c = System.now()
        )
      );
    }
    insert rows;
    List<Id> ids = new List<Id>();
    for (Record_Health_Check_Alert_Delivery__c row : rows) {
      ids.add(row.Id);
    }
    return ids;
  }

  @IsTest
  static void shouldDoNothingWhenConstructedWithNullOrEmptyClaims() {
    Test.startTest();
    new RHCAlertsDeliveryQueueable(null).execute((QueueableContext) null);
    new RHCAlertsDeliveryQueueable(new List<Id>())
      .execute((QueueableContext) null);
    Integer queriesUsed = Limits.getQueries();
    Integer dmlUsed = Limits.getDmlStatements();
    Integer chainedJobs = Limits.getQueueableJobs();
    Test.stopTest();

    Assert.areEqual(
      0,
      queriesUsed,
      'An empty claim list must return before querying the ledger'
    );
    Assert.areEqual(0, dmlUsed, 'An empty claim list must perform no DML');
    Assert.areEqual(
      0,
      chainedJobs,
      'An empty claim list must not chain another worker'
    );
  }

  @IsTest
  static void shouldDeliverOnlyTheFirstSliceAndChainTheRemainder() {
    Record_Health_Check_Alert_Policy__c parentPolicy = policy();
    List<Id> claims = pendingIds(parentPolicy, 14);

    Test.startTest();
    new RHCAlertsDeliveryQueueable(claims).execute((QueueableContext) null);
    Integer chained = Limits.getQueueableJobs();
    Integer deliveredInSlice = [
      SELECT COUNT()
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Outcome__c = 'DELIVERED'
    ];
    Integer pendingAfterSlice = [
      SELECT COUNT()
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Outcome__c = 'PENDING'
    ];
    // Test.stopTest() runs the one chained continuation, which drains the remaining claims.
    Test.stopTest();

    Assert.areEqual(
      1,
      chained,
      'A claim list larger than the slice must chain exactly one continuation'
    );
    Assert.areEqual(
      10,
      deliveredInSlice,
      'Exactly one bounded slice of ten rows is delivered in this transaction'
    );
    Assert.areEqual(
      4,
      pendingAfterSlice,
      'The remaining four claims must still be pending for the chained worker'
    );
    Assert.areEqual(
      14,
      [
        SELECT COUNT()
        FROM Record_Health_Check_Alert_Delivery__c
        WHERE Outcome__c = 'DELIVERED'
      ],
      'The chained continuation must deliver the remainder exactly once'
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Record_Health_Check_Alert_Delivery__c
        WHERE Outcome__c = 'PENDING'
      ],
      'No claim may be left pending once the chain has drained'
    );
  }

  @IsTest
  static void shouldNotDoubleSendWhenTheSameClaimsAreReplayed() {
    Record_Health_Check_Alert_Policy__c parentPolicy = policy();
    List<Id> claims = pendingIds(parentPolicy, 3);

    Test.startTest();
    List<Id> firstRetry = RHCAlertsDeliveryService.deliver(claims);
    Integer deliveredAfterFirst = [
      SELECT COUNT()
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Outcome__c = 'DELIVERED'
    ];
    List<Record_Health_Check_Alert_Delivery__c> afterFirst = [
      SELECT Id, AttemptCount__c, DeliveredAt__c
      FROM Record_Health_Check_Alert_Delivery__c
      ORDER BY EventId__c
    ];
    List<Id> secondRetry = RHCAlertsDeliveryService.deliver(claims);
    Test.stopTest();

    List<Record_Health_Check_Alert_Delivery__c> afterSecond = [
      SELECT Id, AttemptCount__c, DeliveredAt__c, Outcome__c
      FROM Record_Health_Check_Alert_Delivery__c
      ORDER BY EventId__c
    ];

    Assert.areEqual(
      3,
      deliveredAfterFirst,
      'The first pass delivers every claimed row'
    );
    Assert.isTrue(
      firstRetry.isEmpty(),
      'A successful delivery schedules no retry'
    );
    Assert.isTrue(
      secondRetry.isEmpty(),
      'Replaying delivered claims must schedule no retry'
    );
    for (Integer index = 0; index < afterSecond.size(); index++) {
      Assert.areEqual(
        'DELIVERED',
        afterSecond[index].Outcome__c,
        'Replay must leave the terminal outcome unchanged'
      );
      Assert.areEqual(
        afterFirst[index].AttemptCount__c,
        afterSecond[index].AttemptCount__c,
        'Replaying a delivered claim must not increment the attempt count'
      );
      Assert.areEqual(
        afterFirst[index].DeliveredAt__c,
        afterSecond[index].DeliveredAt__c,
        'Replaying a delivered claim must not restamp the delivery time, proving no second send'
      );
    }
  }

  @IsTest
  static void shouldKeepLedgerQueryCountFlatAcrossSliceSizes() {
    Record_Health_Check_Alert_Policy__c parentPolicy = policy();
    List<Id> single = pendingIds(parentPolicy, 1);

    Test.startTest();
    Integer beforeSingle = Limits.getQueries();
    RHCAlertsDeliveryService.deliver(single);
    Integer singleQueries = Limits.getQueries() - beforeSingle;

    Record_Health_Check_Alert_Policy__c secondPolicy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Queue_Check_Bulk',
      0
    );
    List<Record_Health_Check_Alert_Delivery__c> rows = new List<Record_Health_Check_Alert_Delivery__c>();
    for (Integer index = 0; index < 10; index++) {
      rows.add(
        new Record_Health_Check_Alert_Delivery__c(
          Policy__c = secondPolicy.Id,
          EventId__c = 'bulk-evt-' + index,
          EventType__c = 'RESULT',
          Outcome__c = 'PENDING',
          AttemptCount__c = 0,
          RecipientCount__c = 0,
          CooldownKey__c = 'bulk-cooldown-' + index,
          OccurredAt__c = System.now()
        )
      );
    }
    insert rows;
    List<Id> fullSlice = new List<Id>();
    for (Record_Health_Check_Alert_Delivery__c row : rows) {
      fullSlice.add(row.Id);
    }
    Integer beforeFull = Limits.getQueries();
    RHCAlertsDeliveryService.deliver(fullSlice);
    Integer fullQueries = Limits.getQueries() - beforeFull;
    Test.stopTest();

    Assert.areEqual(
      4,
      singleQueries,
      'One claim costs three fixed context queries plus one recipient-directory query'
    );
    Assert.areEqual(
      13,
      fullQueries,
      'A full slice of ten adds only one directory query per row: the packaged ' +
      'notification-type lookup is resolved once, not per row'
    );
    Assert.areEqual(
      singleQueries - 1,
      fullQueries - 10,
      'The fixed per-transaction overhead must not grow with the number of claims'
    );
    Assert.areEqual(
      11,
      [
        SELECT COUNT()
        FROM Record_Health_Check_Alert_Delivery__c
        WHERE Outcome__c = 'DELIVERED'
      ],
      'Every claimed row across both passes must be delivered exactly once'
    );
  }

  @IsTest
  static void shouldRecordTerminalEvidenceWhenFinalizerReportsUnhandledFailure() {
    Record_Health_Check_Alert_Policy__c parentPolicy = policy();
    List<Id> claims = pendingIds(parentPolicy, 2);

    Test.startTest();
    RHCAlertsDeliveryQueueable.recoverUnhandledFailure(claims);
    Test.stopTest();

    List<Record_Health_Check_Alert_Delivery__c> recovered = [
      SELECT
        Id,
        Outcome__c,
        FailureClass__c,
        ErrorCode__c,
        AttemptCount__c,
        NextRetryAt__c,
        SuppressionReason__c
      FROM Record_Health_Check_Alert_Delivery__c
    ];
    Assert.areEqual(2, recovered.size(), 'Both claims must be accounted for');
    for (Record_Health_Check_Alert_Delivery__c row : recovered) {
      Assert.areEqual(
        'FAILED',
        row.Outcome__c,
        'An unhandled async failure must never leave a claim silently pending'
      );
      Assert.areEqual(
        'PERMANENT',
        row.FailureClass__c,
        'Unhandled async failure is terminal, not retryable'
      );
      Assert.areEqual(
        'QUEUEABLE_UNHANDLED_FAILURE',
        row.ErrorCode__c,
        'The recovery code must be the stable bounded package constant'
      );
      Assert.areEqual(
        1,
        row.AttemptCount__c,
        'Recovery must record the consumed attempt'
      );
      Assert.isNull(
        row.NextRetryAt__c,
        'A terminal failure must not schedule another attempt'
      );
      Assert.isNull(
        row.SuppressionReason__c,
        'A failure is not a suppression and must not carry a suppression reason'
      );
    }
  }

  @IsTest
  static void shouldLeaveTerminalRowsUntouchedWhenRecoveringUnhandledFailure() {
    Record_Health_Check_Alert_Policy__c parentPolicy = policy();
    List<Id> claims = pendingIds(parentPolicy, 2);
    RHCAlertsDeliveryService.deliver(new List<Id>{ claims[0] });

    Test.startTest();
    RHCAlertsDeliveryQueueable.recoverUnhandledFailure(claims);
    Test.stopTest();

    Record_Health_Check_Alert_Delivery__c alreadyDelivered = [
      SELECT Outcome__c, ErrorCode__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id = :claims[0]
    ];
    Record_Health_Check_Alert_Delivery__c stillPending = [
      SELECT Outcome__c, ErrorCode__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id = :claims[1]
    ];

    Assert.areEqual(
      'DELIVERED',
      alreadyDelivered.Outcome__c,
      'Recovery must only claim rows still pending, never rewrite a delivered row'
    );
    Assert.isNull(
      alreadyDelivered.ErrorCode__c,
      'A delivered row must not acquire a failure code from a sibling failure'
    );
    Assert.areEqual(
      'FAILED',
      stillPending.Outcome__c,
      'The still-pending row must become terminal evidence'
    );
  }

  @IsTest
  static void shouldIgnoreRecoveryWhenNoClaimsAreSupplied() {
    Test.startTest();
    RHCAlertsDeliveryQueueable.recoverUnhandledFailure(null);
    RHCAlertsDeliveryQueueable.recoverUnhandledFailure(new List<Id>());
    Integer queriesUsed = Limits.getQueries();
    Integer dmlUsed = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(
      0,
      queriesUsed,
      'Recovery with no claims must return before querying'
    );
    Assert.areEqual(0, dmlUsed, 'Recovery with no claims must perform no DML');
  }

  @IsTest
  static void shouldReturnNoRetryWhenClaimListIsNullOrEmpty() {
    Test.startTest();
    List<Id> nullResult = RHCAlertsDeliveryService.deliver(null);
    List<Id> emptyResult = RHCAlertsDeliveryService.deliver(new List<Id>());
    Integer queriesUsed = Limits.getQueries();
    Test.stopTest();

    Assert.isTrue(
      nullResult.isEmpty(),
      'A null claim list must yield no retry work'
    );
    Assert.isTrue(
      emptyResult.isEmpty(),
      'An empty claim list must yield no retry work'
    );
    Assert.areEqual(
      0,
      queriesUsed,
      'An absent claim list must be rejected before querying'
    );
  }
}
