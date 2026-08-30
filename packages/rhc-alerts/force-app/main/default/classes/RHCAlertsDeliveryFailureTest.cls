// Failure classification is a pure bounded-code transformation with no user-data boundary.
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsDeliveryFailureTest {
  @IsTest
  static void shouldClassifyTransientLimitAndPermanentCodes() {
    Test.startTest();
    RHCAlertsDeliveryFailure.Disposition transientValue = RHCAlertsDeliveryFailure.fromCode(
      'TEMPORARY_PLATFORM_FAILURE'
    );
    RHCAlertsDeliveryFailure.Disposition limitValue = RHCAlertsDeliveryFailure.fromCode(
      'EMAIL_RECIPIENT_LIMIT'
    );
    RHCAlertsDeliveryFailure.Disposition permanentValue = RHCAlertsDeliveryFailure.fromCode(
      'EMAIL_PLATFORM_REJECTED'
    );
    Test.stopTest();

    Assert.areEqual(
      'TRANSIENT',
      transientValue.classification,
      'Transient code expected.'
    );
    Assert.isTrue(transientValue.retryable, 'Transient failure should retry.');
    Assert.areEqual(
      'LIMIT',
      limitValue.classification,
      'Limit suffix expected.'
    );
    Assert.isFalse(limitValue.retryable, 'Limit failure should be terminal.');
    Assert.areEqual(
      'PERMANENT',
      permanentValue.classification,
      'Permanent code expected.'
    );
    Assert.isFalse(
      permanentValue.retryable,
      'Permanent failure should not retry.'
    );
  }

  @IsTest
  static void shouldClassifyNonLockingDmlFailureAsPermanent() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Dml_Failure_Check',
      0
    );
    policy.CooldownMinutes__c = -1;

    Test.startTest();
    try {
      update policy;
      Assert.fail('The validation rule should reject a negative cooldown.');
    } catch (DmlException error) {
      RHCAlertsDeliveryFailure.Disposition disposition = RHCAlertsDeliveryFailure.fromDml(
        error
      );
      Assert.areEqual(
        'PERMANENT',
        disposition.classification,
        'A validation failure should be terminal.'
      );
      Assert.areEqual(
        'PLATFORM_DML_FAILURE',
        disposition.code,
        'Non-locking DML errors should use the bounded platform code.'
      );
      Assert.isFalse(
        disposition.retryable,
        'A validation failure should not be retried.'
      );
    }
    Test.stopTest();
  }
}
