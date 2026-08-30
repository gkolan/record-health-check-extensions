// Delivery runs as the Platform Event/Queueable platform context; user impersonation would test a
// different security boundary. Admin and Viewer entry points have dedicated System.runAs tests.
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsDeliveryServiceTest {
  @TestSetup
  static void setup() {
    RHCAlertsTestDataFactory.assignAdminPermissions();
    User inactiveUser = new User(
      Alias = 'rhcoff',
      Email = 'rhc-alerts-inactive@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Alerts Inactive',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Chicago',
      Username = 'rhc-alerts-inactive-' +
        UserInfo.getOrganizationId() +
        '@example.invalid'
    );
    insert inactiveUser;
    inactiveUser.IsActive = false;
    update inactiveUser;
  }

  @IsTest
  static void shouldSuppressSecondRecordPolicyDeliveryDuringCooldown() {
    Account account = new Account(Name = 'Cooldown');
    insert account;
    RHCAlertsTestDataFactory.createCheckPolicy('pkg__Cooldown_Check', 60);
    Record_Health_Check_Result__e first = RHCAlertsTestDataFactory.resultEvent(
      'cooldown-1',
      'pkg__Cooldown_Check',
      account.Id
    );
    Record_Health_Check_Result__e second = RHCAlertsTestDataFactory.resultEvent(
      'cooldown-2',
      'pkg__Cooldown_Check',
      account.Id
    );

    Test.startTest();
    RHCAlertsEventService.processResults(
      new List<Record_Health_Check_Result__e>{ first }
    );
    Id firstId = [
      SELECT Id
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE EventId__c = 'cooldown-1'
      LIMIT 1
    ]
    .Id;
    RHCAlertsDeliveryService.deliver(new List<Id>{ firstId });
    RHCAlertsEventService.processResults(
      new List<Record_Health_Check_Result__e>{ second }
    );
    Id secondId = [
      SELECT Id
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE EventId__c = 'cooldown-2'
      LIMIT 1
    ]
    .Id;
    RHCAlertsDeliveryService.deliver(new List<Id>{ secondId });
    Test.stopTest();

    Record_Health_Check_Alert_Delivery__c row = [
      SELECT Outcome__c, SuppressionReason__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id = :secondId
    ];
    Assert.areEqual(
      'SUPPRESSED',
      row.Outcome__c,
      'The policy-record pair should cool down independently.'
    );
    Assert.areEqual(
      'COOLDOWN',
      row.SuppressionReason__c,
      'Cooldown suppression should be explicit.'
    );
  }

  @IsTest
  static void shouldRejectInvalidRecipientWithoutQueryingBusinessRecords() {
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'USER',
      'not-an-id'
    );
    Assert.areEqual(
      'INVALID_RECIPIENT_ID',
      result.errorCode,
      'Invalid recipient configuration should have a bounded code.'
    );
    Assert.areEqual(
      0,
      result.userIds.size(),
      'No recipient should be returned.'
    );
  }

  @IsTest
  static void shouldResolveCurrentHumanUser() {
    Test.startTest();
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'USER',
      UserInfo.getUserId()
    );
    Test.stopTest();
    Assert.isNull(result.errorCode, 'The current active User should resolve.');
    Assert.isTrue(
      result.userIds.contains(UserInfo.getUserId()),
      'The configured human User should be returned exactly.'
    );
  }

  @IsTest
  static void shouldResolveDirectPublicGroupUsers() {
    Group recipientGroup = new Group(
      Name = 'RHC Alerts Test Group',
      Type = 'Regular'
    );
    insert recipientGroup;
    insert new GroupMember(
      GroupId = recipientGroup.Id,
      UserOrGroupId = UserInfo.getUserId()
    );
    Test.startTest();
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'PUBLIC_GROUP',
      recipientGroup.Id
    );
    Test.stopTest();
    Assert.isNull(
      result.errorCode,
      'A public group with a direct active User should resolve.'
    );
    Assert.isTrue(
      result.userIds.contains(UserInfo.getUserId()),
      'Direct active User membership should be preserved.'
    );
  }

  @IsTest
  static void shouldClassifyUnavailableConfiguredUserAsConfigurationFailure() {
    User inactiveUser = [SELECT Id FROM User WHERE Alias = 'rhcoff' LIMIT 1];
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Recipient_Check',
      0
    );
    policy.RecipientId__c = inactiveUser.Id;
    update policy;
    Record_Health_Check_Result__e eventValue = RHCAlertsTestDataFactory.resultEvent(
      'recipient-failure',
      'pkg__Recipient_Check',
      UserInfo.getUserId()
    );

    Test.startTest();
    RHCAlertsEventService.processResults(
      new List<Record_Health_Check_Result__e>{ eventValue }
    );
    Id deliveryId = [
      SELECT Id
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE EventId__c = 'recipient-failure'
      LIMIT 1
    ]
    .Id;
    RHCAlertsDeliveryService.deliver(new List<Id>{ deliveryId });
    Test.stopTest();

    Record_Health_Check_Alert_Delivery__c row = [
      SELECT Outcome__c, FailureClass__c, ErrorCode__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id = :deliveryId
    ];
    Assert.areEqual(
      'FAILED',
      row.Outcome__c,
      'Unavailable human recipient should fail permanently.'
    );
    Assert.areEqual(
      'CONFIGURATION',
      row.FailureClass__c,
      'Recipient setup errors should be classified for administrators.'
    );
    Assert.areEqual(
      'RECIPIENT_USER_UNAVAILABLE',
      row.ErrorCode__c,
      'Only a bounded code should be retained.'
    );
  }

  @IsTest
  static void shouldSuppressClaimWhenPolicyDeactivatedBeforeDelivery() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Inactive_Check',
      0
    );
    Record_Health_Check_Result__e eventValue = RHCAlertsTestDataFactory.resultEvent(
      'inactive-policy',
      'pkg__Inactive_Check',
      UserInfo.getUserId()
    );
    RHCAlertsEventService.processResults(
      new List<Record_Health_Check_Result__e>{ eventValue }
    );
    Id deliveryId = [
      SELECT Id
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE EventId__c = 'inactive-policy'
      LIMIT 1
    ]
    .Id;
    policy.Active__c = false;
    update policy;

    Test.startTest();
    RHCAlertsDeliveryService.deliver(new List<Id>{ deliveryId });
    Test.stopTest();

    Record_Health_Check_Alert_Delivery__c row = [
      SELECT Outcome__c, SuppressionReason__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id = :deliveryId
    ];
    Assert.areEqual(
      'SUPPRESSED',
      row.Outcome__c,
      'A deactivated policy must not send.'
    );
    Assert.areEqual(
      'POLICY_INACTIVE',
      row.SuppressionReason__c,
      'Deactivation suppression should be explicit.'
    );
  }

  @IsTest
  static void shouldFailClaimWhenPolicyDeletedBeforeDelivery() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Deleted_Check',
      0
    );
    Record_Health_Check_Alert_Delivery__c delivery = RHCAlertsTestDataFactory.createPendingDelivery(
      policy,
      'deleted-policy'
    );
    delete policy;

    Test.startTest();
    RHCAlertsDeliveryService.deliver(new List<Id>{ delivery.Id });
    Test.stopTest();

    Record_Health_Check_Alert_Delivery__c row = [
      SELECT Outcome__c, FailureClass__c, ErrorCode__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id = :delivery.Id
    ];
    Assert.areEqual(
      'FAILED',
      row.Outcome__c,
      'A missing policy must not strand its claim in PENDING.'
    );
    Assert.areEqual(
      'CONFIGURATION',
      row.FailureClass__c,
      'A deleted policy is an administrator configuration failure.'
    );
    Assert.areEqual(
      'POLICY_UNAVAILABLE',
      row.ErrorCode__c,
      'The missing-policy state must use a bounded code.'
    );
  }

  @IsTest
  static void shouldHandleEmptyQueueableInput() {
    Test.startTest();
    new RHCAlertsDeliveryQueueable(null).execute((QueueableContext) null);
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Record_Health_Check_Alert_Delivery__c],
      'Empty queue work should be a no-op.'
    );
  }

  @IsTest
  static void shouldMarkPendingRowsFailedWhenFinalizerRecoversUnhandledFailure() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Recovery_Check',
      0
    );
    Record_Health_Check_Alert_Delivery__c delivery = RHCAlertsTestDataFactory.createPendingDelivery(
      policy,
      'recovery-event'
    );

    Test.startTest();
    RHCAlertsDeliveryQueueable.recoverUnhandledFailure(
      new List<Id>{ delivery.Id }
    );
    Test.stopTest();

    Record_Health_Check_Alert_Delivery__c recovered = [
      SELECT
        Outcome__c,
        FailureClass__c,
        ErrorCode__c,
        AttemptCount__c,
        AttemptedAt__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id = :delivery.Id
    ];
    Assert.areEqual(
      'FAILED',
      recovered.Outcome__c,
      'Unhandled Queueable work must not remain pending.'
    );
    Assert.areEqual(
      'PERMANENT',
      recovered.FailureClass__c,
      'Unhandled execution must use a bounded terminal class.'
    );
    Assert.areEqual(
      'QUEUEABLE_UNHANDLED_FAILURE',
      recovered.ErrorCode__c,
      'Recovery must retain only the package error code.'
    );
    Assert.areEqual(
      1,
      recovered.AttemptCount__c,
      'Recovery must account for the failed attempt.'
    );
    Assert.isNotNull(
      recovered.AttemptedAt__c,
      'Recovery must timestamp the failed attempt.'
    );
  }

  @IsTest
  static void shouldRetryOnlyTransientFailuresUpToThreeAttempts() {
    Record_Health_Check_Alert_Delivery__c retryable = new Record_Health_Check_Alert_Delivery__c(
      AttemptCount__c = 1,
      SuppressionReason__c = 'COOLDOWN'
    );
    List<Id> retryIds = new List<Id>();

    RHCAlertsDeliveryService.failTransient(
      retryable,
      'TEMPORARY_PLATFORM_FAILURE',
      retryIds
    );

    Assert.areEqual(
      'PENDING',
      retryable.Outcome__c,
      'A transient failure below the cap should remain pending.'
    );
    Assert.areEqual(
      'TRANSIENT',
      retryable.FailureClass__c,
      'Retry classification should remain bounded.'
    );
    Assert.areEqual(
      'TEMPORARY_PLATFORM_FAILURE',
      retryable.ErrorCode__c,
      'Only the bounded error code should be retained.'
    );
    Assert.isNull(
      retryable.SuppressionReason__c,
      'A retryable failure must not display a suppression reason.'
    );
    Assert.isNotNull(
      retryable.NextRetryAt__c,
      'The next retry time should be explicit.'
    );
    Assert.areEqual(
      1,
      retryIds.size(),
      'The delivery should be returned to the Queueable retry chain.'
    );

    Record_Health_Check_Alert_Delivery__c exhausted = new Record_Health_Check_Alert_Delivery__c(
      AttemptCount__c = 3
    );
    retryIds.clear();
    RHCAlertsDeliveryService.failTransient(
      exhausted,
      'UNABLE_TO_LOCK_ROW',
      retryIds
    );

    Assert.areEqual(
      'FAILED',
      exhausted.Outcome__c,
      'The third failed attempt must be terminal.'
    );
    Assert.isNull(
      exhausted.NextRetryAt__c,
      'A terminal failure must not claim another retry time.'
    );
    Assert.areEqual(
      0,
      retryIds.size(),
      'An exhausted failure must not re-enter the retry chain.'
    );
  }
}
