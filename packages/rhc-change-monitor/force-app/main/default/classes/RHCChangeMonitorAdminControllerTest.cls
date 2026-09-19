@IsTest
private class RHCChangeMonitorAdminControllerTest {
  @IsTest
  static void shouldSummarizeRetryAndPurgeBoundedEvidence() {
    Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
    insert new List<Record_Health_Check_Change_Evaluation__c>{
      claim(policy.Id, 'k1', 'FAILED', 'RUNTIME_PERMISSION_MISSING', System.now()),
      claim(policy.Id, 'k2', 'IGNORED', 'RECORD_DELETED', System.now().addDays(-40)),
      claim(policy.Id, 'k3', 'EVALUATED', 'ACCEPTED', System.now().addDays(-40)),
      claim(policy.Id, 'k4', 'PENDING', 'ACCEPTED', System.now().addDays(-40))
    };

    Test.startTest();
    RHCChangeMonitorAdminController.Status before = RHCChangeMonitorAdminController.getStatus();
    Integer retried = RHCChangeMonitorAdminController.retryFailed();
    Integer purged = RHCChangeMonitorAdminController.purgeEvaluations(30);
    Test.stopTest();

    Assert.areEqual(1, before.retryableFailedCount, 'The permission failure is retryable.');
    Assert.areEqual(1, before.pendingCount, 'One claim was pending before retry.');
    Assert.areEqual(1, retried, 'Only the runtime failure is returned to PENDING.');
    Assert.areEqual(2, purged, 'Terminal claims older than 30 days are purged; PENDING is kept.');
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c WHERE Outcome__c = 'PENDING'],
      'The retried claim and the old pending claim remain pending.'
    );
  }

  @IsTest
  static void shouldRejectInvalidRetention() {
    Boolean rejected = false;
    try {
      RHCChangeMonitorAdminController.purgeEvaluations(0);
    } catch (AuraHandledException error) {
      rejected = true;
    }
    Assert.isTrue(rejected, 'Retention below one day is rejected.');
  }

  private static Record_Health_Check_Change_Evaluation__c claim(
    Id policyId, String key, String outcome, String reason, Datetime acceptedAt
  ) {
    return new Record_Health_Check_Change_Evaluation__c(
      Policy__c = policyId, ClaimKey__c = key, SourceObjectApiName__c = 'Account',
      RecordId__c = '001000000000001AAA', ChangeType__c = 'CREATE', Outcome__c = outcome,
      ReasonCode__c = reason, AcceptedAt__c = acceptedAt, AttemptCount__c = 1,
      CompletedAt__c = outcome == 'PENDING' ? null : acceptedAt
    );
  }
}
