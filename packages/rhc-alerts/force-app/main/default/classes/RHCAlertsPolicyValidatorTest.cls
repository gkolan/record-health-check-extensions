@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsPolicyValidatorTest {
  @IsTest
  static void shouldAcceptCompleteCanonicalPolicy() {
    Record_Health_Check_Alert_Policy__c policy = validPolicy();

    String errorMessage = validate(policy);

    Assert.isNull(errorMessage, 'A complete canonical policy should be valid.');
  }

  @IsTest
  static void shouldRejectMissingSelection() {
    Record_Health_Check_Alert_Policy__c policy = validPolicy();
    policy.SelectionType__c = null;

    Assert.areEqual(
      'Choose Check Set or Check.',
      validate(policy),
      'A missing selection type should be rejected.'
    );
  }

  @IsTest
  static void shouldRejectUnknownStatus() {
    Record_Health_Check_Alert_Policy__c policy = validPolicy();
    policy.MatchingStatuses__c = 'FAIL;UNKNOWN';

    Assert.areEqual(
      'Choose one or more canonical statuses.',
      validate(policy),
      'An unknown status should be rejected.'
    );
  }

  @IsTest
  static void shouldRejectMissingSeverity() {
    Record_Health_Check_Alert_Policy__c policy = validPolicy();
    policy.MinimumSeverity__c = null;

    Assert.areEqual(
      'Choose a minimum severity.',
      validate(policy),
      'A missing severity should be rejected.'
    );
  }

  @IsTest
  static void shouldRejectMissingRecipient() {
    Record_Health_Check_Alert_Policy__c policy = validPolicy();
    policy.RecipientId__c = null;

    Assert.areEqual(
      'Choose a human recipient.',
      validate(policy),
      'A missing recipient should be rejected.'
    );
  }

  @IsTest
  static void shouldRejectUnsupportedChannel() {
    Record_Health_Check_Alert_Policy__c policy = validPolicy();
    policy.NotificationChannel__c = null;

    Assert.areEqual(
      'Choose Custom Notification or Email.',
      validate(policy),
      'A missing channel should be rejected.'
    );
  }

  @IsTest
  static void shouldRejectNegativeCooldown() {
    Record_Health_Check_Alert_Policy__c policy = validPolicy();
    policy.CooldownMinutes__c = -1;

    Assert.areEqual(
      'Cooldown must be zero or greater.',
      validate(policy),
      'A negative cooldown should be rejected.'
    );
  }

  private static Record_Health_Check_Alert_Policy__c validPolicy() {
    return RHCAlertsTestDataFactory.buildCheckPolicy('pkg__Check', 0);
  }

  private static String validate(Record_Health_Check_Alert_Policy__c policy) {
    Test.startTest();
    String actualMessage = RHCAlertsPolicyValidator.validationError(policy);
    Test.stopTest();
    return actualMessage;
  }
}
