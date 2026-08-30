// Candidate construction is a pure contract transformation; platform-context persistence and
// dispatch are covered by RHCAlertsEventServiceTest.
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsEventCandidateBuilderTest {
  @IsTest
  static void shouldIgnoreUnsupportedContractsWhenCollectingIdentities() {
    Record_Health_Check_Result__e supported = RHCAlertsTestDataFactory.resultEvent(
      'candidate-supported',
      'pkg__Supported_Check',
      UserInfo.getUserId()
    );
    Record_Health_Check_Result__e unsupported = RHCAlertsTestDataFactory.resultEvent(
      'candidate-unsupported',
      'pkg__Unsupported_Check',
      UserInfo.getUserId()
    );
    unsupported.ContractVersion__c = '2.0';

    Test.startTest();
    Set<String> identities = RHCAlertsEventCandidateBuilder.resultIdentities(
      new List<Record_Health_Check_Result__e>{ supported, unsupported }
    );
    Test.stopTest();

    Assert.isTrue(
      identities.contains('pkg__Supported_Check'),
      'Supported exact identities should be queried.'
    );
    Assert.isFalse(
      identities.contains('pkg__Unsupported_Check'),
      'Unsupported contract identities must not expand the policy query.'
    );
  }

  @IsTest
  static void shouldCreateOneBoundedOverflowCandidate() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.buildCheckPolicy(
      'pkg__Overflow_Check',
      0
    );
    Record_Health_Check_Result__e eventValue = RHCAlertsTestDataFactory.resultEvent(
      'candidate-overflow',
      'pkg__Overflow_Check',
      UserInfo.getUserId()
    );
    Map<String, List<Record_Health_Check_Alert_Policy__c>> policies = new Map<String, List<Record_Health_Check_Alert_Policy__c>>{
      'CHECK|pkg__Overflow_Check' => new List<Record_Health_Check_Alert_Policy__c>{
        policy
      }
    };

    Test.startTest();
    List<Record_Health_Check_Alert_Delivery__c> candidates = RHCAlertsEventCandidateBuilder.resultCandidates(
      new List<Record_Health_Check_Result__e>{ eventValue },
      policies,
      0
    );
    Test.stopTest();

    Assert.areEqual(1, candidates.size(), 'Only one overflow row is required.');
    Assert.areEqual(
      'EVENT_POLICY_FANOUT_LIMIT',
      candidates[0].ErrorCode__c,
      'Overflow evidence must use the bounded package code.'
    );
    Assert.areEqual(
      'FAILED',
      candidates[0].Outcome__c,
      'Overflow evidence must be terminal.'
    );
  }
}
