@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsCoverageAnalyzerTest {
  @IsTest
  static void shouldReportMissingExactCheckAndCallerGuidance() {
    List<Record_Health_Check_Alert_Policy__c> policies = new List<Record_Health_Check_Alert_Policy__c>{
      RHCAlertsTestDataFactory.buildCheckPolicy('missing__Check', 0)
    };

    Test.startTest();
    List<RHCAlertsCoreMetadataGateway.CoverageGap> gaps = RHCAlertsCoverageAnalyzer.analyzePolicies(
      policies,
      new Map<String, Record_Health_Check__mdt>()
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      gaps.size(),
      'Missing Check plus caller guidance expected.'
    );
    Assert.areEqual(
      'DEFINITION_NOT_FOUND',
      gaps[0].code,
      'Exact missing Check should be actionable.'
    );
    Assert.areEqual(
      'PROGRAMMATIC_CALLER_CHOICE',
      gaps[1].code,
      'Programmatic publication guidance should always accompany active policies.'
    );
  }

  @IsTest
  static void shouldReportMissingCheckSetAndContractGap() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.buildCheckPolicy(
      'missing__Set',
      0
    );
    policy.SelectionType__c = 'CHECK_SET';

    Test.startTest();
    List<RHCAlertsCoreMetadataGateway.CoverageGap> gaps = RHCAlertsCoverageAnalyzer.analyzePolicies(
      new List<Record_Health_Check_Alert_Policy__c>{ policy },
      new Map<String, Record_Health_Check__mdt>()
    );
    Test.stopTest();

    Assert.areEqual(
      3,
      gaps.size(),
      'Missing Set plus two contract notes expected.'
    );
    Assert.areEqual(
      'CHECK_SET_NOT_FOUND',
      gaps[0].code,
      'Missing Check Set should be actionable.'
    );
    Assert.areEqual(
      'SET_RUN_CONTRACT_1_0',
      gaps[2].code,
      'Set Run contract limitation should remain explicit.'
    );
  }
}
