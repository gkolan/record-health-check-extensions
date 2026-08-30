@IsTest
private class RHCChangeMonitorIntakeTest {
  @TestSetup
  static void assignPermissions() {
    RHCChangeMonitorTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldCreateOneIgnoredClaimWhenDeleteIsRedelivered() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      RHCChangeMonitorTestDataFactory.createPolicy();
      Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
      RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
        'DELETE', new Set<String>(), new List<String>{ String.valueOf(account.Id) }
      );
      Test.startTest();
      RHCChangeMonitorIntake.acceptEnvelopes(new List<RHCChangeMonitorEventEnvelope>{ eventEnvelope });
      RHCChangeMonitorIntake.acceptEnvelopes(new List<RHCChangeMonitorEventEnvelope>{ eventEnvelope });
      Test.stopTest();

      List<Record_Health_Check_Change_Evaluation__c> claims = [
        SELECT Outcome__c, ReasonCode__c FROM Record_Health_Check_Change_Evaluation__c
      ];
      Assert.areEqual(1, claims.size(), 'Duplicate delivery must not create a second durable claim.');
      Assert.areEqual('IGNORED', claims[0].Outcome__c, 'DELETE should be terminally ignored.');
      Assert.areEqual('RECORD_DELETED', claims[0].ReasonCode__c, 'DELETE should retain its bounded reason.');
    }
  }

  @IsTest
  static void shouldCreateBulkClaimsWhenDeleteHeaderContains251Records() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      RHCChangeMonitorTestDataFactory.createPolicy();
      List<Account> accounts = RHCChangeMonitorTestDataFactory.createAccounts(251);
      List<String> recordIds = new List<String>();
      for (Account account : accounts) {
        recordIds.add(String.valueOf(account.Id));
      }
      RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
        'DELETE', new Set<String>(), recordIds
      );

      Test.startTest();
      RHCChangeMonitorIntake.acceptEnvelopes(new List<RHCChangeMonitorEventEnvelope>{ eventEnvelope });
      Test.stopTest();

      Integer claimCount = [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c];
      Assert.areEqual(251, claimCount, 'Every header record ID should receive one policy claim.');
    }
  }
}
