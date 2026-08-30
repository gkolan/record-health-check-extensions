@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCChangeMonitorRoutingServiceTest {
  @IsTest
  static void shouldDispatchUpdateWhenConfiguredFieldChanged() {
    Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
    Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
      'UPDATE', new Set<String>{ 'Industry' }, new List<String>{ String.valueOf(account.Id) }
    );
    Test.startTest();
    RHCChangeMonitorRoutingService.Decision decision = RHCChangeMonitorRoutingService.route(policy, eventEnvelope);
    Test.stopTest();
    Assert.isTrue(decision.shouldDispatch, 'A matching changed field should dispatch.');
    Assert.areEqual('ACCEPTED', decision.reasonCode, 'Accepted work should use the bounded reason code.');
  }

  @IsTest
  static void shouldIgnoreUpdateWhenConfiguredFieldDidNotChange() {
    Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
    Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
      'UPDATE', new Set<String>{ 'Phone' }, new List<String>{ String.valueOf(account.Id) }
    );
    Test.startTest();
    RHCChangeMonitorRoutingService.Decision decision = RHCChangeMonitorRoutingService.route(policy, eventEnvelope);
    Test.stopTest();
    Assert.isFalse(decision.shouldDispatch, 'A nonmatching UPDATE should not dispatch.');
    Assert.areEqual('CHANGED_FIELDS_NOT_MATCHED', decision.reasonCode, 'Field mismatch must be explicit.');
  }

  @IsTest
  static void shouldIgnoreDeleteWhenRecordIsNotDurable() {
    Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
    Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
      'DELETE', new Set<String>(), new List<String>{ String.valueOf(account.Id) }
    );
    Test.startTest();
    RHCChangeMonitorRoutingService.Decision decision = RHCChangeMonitorRoutingService.route(policy, eventEnvelope);
    Test.stopTest();
    Assert.isFalse(decision.shouldDispatch, 'DELETE must never invoke core.');
    Assert.areEqual('RECORD_DELETED', decision.reasonCode, 'DELETE must remain an orchestration outcome.');
  }

  @IsTest
  static void shouldIgnoreGapWhenDeliveryIsIncomplete() {
    Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
      'GAP_UPDATE', new Set<String>(), new List<String>()
    );
    Test.startTest();
    RHCChangeMonitorRoutingService.Decision decision = RHCChangeMonitorRoutingService.route(policy, eventEnvelope);
    Test.stopTest();
    Assert.isFalse(decision.shouldDispatch, 'Gap signals must stop automatic evaluation.');
    Assert.areEqual('GAP_DETECTED', decision.reasonCode, 'Gap evidence must be high-signal and bounded.');
  }

  @IsTest
  static void shouldIgnoreUnknownWhenSalesforceAddsChangeType() {
    Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
    Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorTestDataFactory.accountEvent(
      'FUTURE_VALUE', new Set<String>(), new List<String>{ String.valueOf(account.Id) }
    );
    Test.startTest();
    RHCChangeMonitorRoutingService.Decision decision = RHCChangeMonitorRoutingService.route(policy, eventEnvelope);
    Test.stopTest();
    Assert.isFalse(decision.shouldDispatch, 'Unknown additive values must fail closed.');
    Assert.areEqual('UNSUPPORTED_CHANGE_TYPE', decision.reasonCode, 'Unknown values need a bounded reason.');
  }
}
