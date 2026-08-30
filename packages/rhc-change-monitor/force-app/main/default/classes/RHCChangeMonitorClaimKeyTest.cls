@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCChangeMonitorClaimKeyTest {
  @IsTest
  static void shouldReturnSameDigestWhenDeliveryIsReplayed() {
    Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
    Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
      'UPDATE', new Set<String>{ 'Name' }, new List<String>{ String.valueOf(account.Id) }
    );

    Test.startTest();
    String first = RHCChangeMonitorClaimKey.create(eventEnvelope, policy.Id, String.valueOf(account.Id));
    String replay = RHCChangeMonitorClaimKey.create(eventEnvelope, policy.Id, String.valueOf(account.Id));
    Test.stopTest();

    Assert.areEqual(first, replay, 'Identical redelivery facts must produce the same claim.');
    Assert.areEqual(64, first.length(), 'SHA-256 claim keys must contain 64 hexadecimal characters.');
  }

  @IsTest
  static void shouldReturnDifferentDigestWhenPolicyDiffers() {
    Record_Health_Check_Change_Policy__c firstPolicy = RHCChangeMonitorTestDataFactory.createPolicy();
    Record_Health_Check_Change_Policy__c secondPolicy = RHCChangeMonitorTestDataFactory.createPolicy();
    Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
      'CREATE', new Set<String>(), new List<String>{ String.valueOf(account.Id) }
    );

    Test.startTest();
    String first = RHCChangeMonitorClaimKey.create(eventEnvelope, firstPolicy.Id, String.valueOf(account.Id));
    String second = RHCChangeMonitorClaimKey.create(eventEnvelope, secondPolicy.Id, String.valueOf(account.Id));
    Test.stopTest();

    Assert.areNotEqual(first, second, 'Policy identity must be part of the claim.');
  }

  @IsTest
  static void shouldRejectMissingPolicyWhenClaimCreated() {
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
      'GAP', new Set<String>(), new List<String>()
    );
    Test.startTest();
    try {
      RHCChangeMonitorClaimKey.create(eventEnvelope, null, null);
      Assert.fail('A claim without a policy should fail.');
    } catch (IllegalArgumentException error) {
      Assert.isTrue(error.getMessage().contains('policy'), 'Failure should identify the missing policy.');
    }
    Test.stopTest();
  }
}
