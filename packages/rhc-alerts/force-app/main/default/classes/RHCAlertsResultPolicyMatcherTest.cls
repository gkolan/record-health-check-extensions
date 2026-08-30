// Policy matching is a pure contract predicate; subscriber persistence is covered separately.
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsResultPolicyMatcherTest {
  @IsTest
  static void shouldMatchExactIdentityStatusAndMinimumSeverity() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.buildCheckPolicy(
      'pkg__Exact_Check',
      0
    );
    policy.MinimumSeverity__c = 'WARNING';
    Record_Health_Check_Result__e matching = RHCAlertsTestDataFactory.resultEvent(
      'matcher-match',
      'pkg__Exact_Check',
      UserInfo.getUserId()
    );
    Record_Health_Check_Result__e belowThreshold = RHCAlertsTestDataFactory.resultEvent(
      'matcher-low',
      'pkg__Exact_Check',
      UserInfo.getUserId()
    );
    belowThreshold.Severity__c = 'INFO';

    Test.startTest();
    Boolean matches = RHCAlertsResultPolicyMatcher.matches(policy, matching);
    Boolean rejectsLowSeverity = RHCAlertsResultPolicyMatcher.matches(
      policy,
      belowThreshold
    );
    Test.stopTest();

    Assert.isTrue(matches, 'An exact qualifying Result should match.');
    Assert.isFalse(
      rejectsLowSeverity,
      'A Result below the configured minimum severity must not match.'
    );
  }

  @IsTest
  static void shouldRejectWrongNamespaceAndUnselectedStatus() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.buildCheckPolicy(
      'one__Shared_Check',
      0
    );
    Record_Health_Check_Result__e eventValue = RHCAlertsTestDataFactory.resultEvent(
      'matcher-wrong',
      'two__Shared_Check',
      UserInfo.getUserId()
    );
    eventValue.Status__c = 'PASS';

    Assert.isFalse(
      RHCAlertsResultPolicyMatcher.matches(policy, eventValue),
      'Namespace and status matching must both remain exact.'
    );
  }
}
