/**
 * Verifies bulk capture, direct event subscription, and Event ID idempotency.
 */
@IsTest
private class RHCActionCaptureServiceTest {
  @TestSetup
  static void setupData() {
    RHCActionTestDataFactory.assignRuntimePermission();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert RHCActionTestDataFactory.policy();
    }
  }

  @IsTest
  static void shouldCreateOnePendingActionWhenDuplicateEventIsDelivered() {
    RHCActionCaptureService.automaticPermissionOverride = false;
    Record_Health_Check_Result__e eventRecord = RHCActionTestDataFactory.eventRecord(
      'duplicate-event'
    );
    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionCaptureService.capture(
        new List<Record_Health_Check_Result__e>{ eventRecord, eventRecord }
      );
    }
    Test.stopTest();
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM RHC_Pending_Action__c],
      'A policy and Event ID may create only one pending action.'
    );
  }

  @IsTest
  static void shouldCapture251EventsInBulk() {
    RHCActionCaptureService.automaticPermissionOverride = false;
    List<Record_Health_Check_Result__e> events = new List<Record_Health_Check_Result__e>();
    for (Integer index = 0; index < 251; index++) {
      events.add(RHCActionTestDataFactory.eventRecord('bulk-' + index));
    }
    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionCaptureService.capture(events);
    }
    Test.stopTest();
    Assert.areEqual(
      251,
      [SELECT COUNT() FROM RHC_Pending_Action__c],
      'All unique events should be captured in one bulk call.'
    );
  }

  @IsTest
  static void shouldIgnoreWhenContractVersionIsUnsupported() {
    Record_Health_Check_Result__e eventRecord = RHCActionTestDataFactory.eventRecord(
      'future-contract'
    );
    eventRecord.ContractVersion__c = '2.0';
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionCaptureService.capture(
        new List<Record_Health_Check_Result__e>{ eventRecord }
      );
    }
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM RHC_Pending_Action__c],
      'Unknown event contracts must fail closed.'
    );
  }

  @IsTest
  static void shouldQueueAutomaticMatchesThroughTheAsyncBoundary() {
    RHC_Action_Policy__c policy = [
      SELECT Id, Mode__c, Auto_Execution_Enabled__c
      FROM RHC_Action_Policy__c
      LIMIT 1
    ];
    policy.Mode__c = RHCActionConstants.MODE_AUTOMATIC;
    policy.Auto_Execution_Enabled__c = true;
    update policy;
    RHCActionCaptureService.automaticPermissionOverride = true;
    RHCActionTestDataFactory.AsyncGatewayStub asyncStub = new RHCActionTestDataFactory.AsyncGatewayStub();
    RHCActionCaptureService.asyncGateway = asyncStub;

    Test.startTest();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionCaptureService.capture(
        new List<Record_Health_Check_Result__e>{
          RHCActionTestDataFactory.eventRecord('automatic-event')
        }
      );
    }
    Test.stopTest();

    RHC_Pending_Action__c action = [
      SELECT Queue_Status__c
      FROM RHC_Pending_Action__c
      LIMIT 1
    ];
    Assert.areEqual('QUEUED', action.Queue_Status__c, 'Automatic capture should queue execution.');
    Assert.areEqual(1, asyncStub.enqueueCount, 'The chunk should create one Queueable request.');
    Assert.areEqual(1, asyncStub.lastPendingIds.size(), 'The request should contain the captured action.');
    Assert.areEqual(0, asyncStub.lastDelayMinutes, 'Initial execution must not be delayed.');
  }

  @IsTest
  static void shouldSubscribeDirectlyWhenPlatformEventIsDelivered() {
    RHCActionCaptureService.automaticPermissionOverride = false;
    Test.startTest();
    EventBus.publish(RHCActionTestDataFactory.eventRecord('bus-event'));
    Test.getEventBus().deliver();
    Test.stopTest();
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM RHC_Pending_Action__c],
      'The packaged trigger should subscribe directly to the core event.'
    );
  }

  @IsTest
  static void shouldClassifyOnlyTransientDatabaseFailuresAsRetryable() {
    Assert.isTrue(
      RHCActionCaptureService.isRetryable(StatusCode.UNABLE_TO_LOCK_ROW),
      'Record locking can succeed on a later delivery.'
    );
    Assert.isTrue(
      RHCActionCaptureService.isRetryable(StatusCode.UNKNOWN_EXCEPTION),
      'Unknown platform failures are treated as transient.'
    );
    Assert.isFalse(
      RHCActionCaptureService.isRetryable(StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION),
      'Permanent data validation failures must not loop through retries.'
    );
  }

  @IsTest
  static void shouldStopBeforeCrossingTheDmlRowLimit() {
    try {
      RHCActionCaptureService.assertDmlCapacity(
        Limits.getLimitDmlRows() + 1
      );
      Assert.fail('The service must stop at a safe capacity boundary.');
    } catch (RHCActionCaptureService.TransientCaptureException expected) {
      Assert.isTrue(
        expected.getMessage().contains('capacity boundary'),
        'The retry reason should be sanitized and operationally useful.'
      );
    }
  }

  @IsTest
  static void shouldIgnoreNullSubscriberInput() {
    Test.startTest();
    RHCActionResultSubscriberHandler.process(null);
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM RHC_Pending_Action__c],
      'Null subscriber input must be a no-op.'
    );
  }

  @IsTest
  static void shouldIgnoreEmptySubscriberInput() {
    Test.startTest();
    RHCActionResultSubscriberHandler.process(
      new List<Record_Health_Check_Result__e>()
    );
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM RHC_Pending_Action__c],
      'Empty subscriber input must be a no-op.'
    );
  }

  @IsTest
  static void shouldRethrowTransientFailureAfterACompletedChunk() {
    RHCActionCaptureService.TransientCaptureException expected = new RHCActionCaptureService.TransientCaptureException(
      'Deliberate transient failure'
    );
    Test.startTest();
    try {
      RHCActionResultSubscriberHandler.retryOrResume(expected, 1);
      Assert.fail('A failure after a checkpoint must resume from that checkpoint.');
    } catch (RHCActionCaptureService.TransientCaptureException actual) {
      Assert.areEqual(
        expected.getMessage(),
        actual.getMessage(),
        'The original transient classification must be preserved.'
      );
    }
    Test.stopTest();
  }
}
