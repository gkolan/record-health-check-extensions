/** Exercises fail-closed Builder validation branches mirrored from the pinned core contract. */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
// These are pure deterministic validator tests: they perform no DML, queries, or user-context
// decisions. Security-context behavior is exercised separately in RHCBuilderControllerTest.
private class RHCBuilderValidationRulesTest {
  @IsTest
  static void shouldRejectInvalidVersionEnvelopeAndIdentityRules() {
    Assert.isTrue(RHCBuilderVersionValidator.validate('{').contains('VERSION_FORMAT_INVALID'));
    Map<String, Object> version = versionMap();
    version.put('schemaVersion', 2);
    version.put('contractVersion', '9.9');
    Map<String, Object> checkSet = (Map<String, Object>) version.get('checkSet');
    checkSet.put('qualifiedApiName', 'package__Owned_Name');
    List<Object> checks = (List<Object>) version.get('checks');
    Map<String, Object> first = (Map<String, Object>) checks[0];
    Map<String, Object> duplicate = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(first));
    ((Map<String, Object>) duplicate.get('values')).put('EvaluationOrder__c', 10);
    checks.add(duplicate);

    String result = RHCBuilderVersionValidator.validate(JSON.serialize(version));
    for (String reason : new List<String>{
      'SCHEMA_VERSION_UNSUPPORTED', 'CONTRACT_VERSION_UNSUPPORTED',
      'NAMESPACED_IDENTITY_NOT_AUTHORABLE', 'DUPLICATE_CHECK_NAME', 'EVALUATION_ORDER_INVALID'
    }) {
      Assert.isTrue(result.contains(reason), 'Expected ' + reason);
    }
  }

  @IsTest
  static void shouldRejectCheckSetAndApplicabilityBranches() {
    Map<String, Object> setValues = new Map<String, Object>{
      'ObjectApiName__c' => 'Not_An_Object__c',
      'CardTitle__c' => '',
      'PassedChecksDisplay__c' => 'BAD',
      'SkippedChecksDisplay__c' => 'BAD',
      'CardRunMode__c' => 'RUN_ON_REQUEST',
      'RunButtonDisplay__c' => 'HIDE',
      'CardRevealMode__c' => 'BAD',
      'SummaryDisplay__c' => 'BAD',
      'FoundExpectedDisplay__c' => 'BAD'
    };
    String setIssues = JSON.serialize(RHCBuilderCoreValidator.validateCheckSet(setValues));
    Assert.isTrue(setIssues.contains('ObjectApiName__c'));
    Assert.isTrue(setIssues.contains('RunButtonDisplay__c'));

    Map<String, Object> checkValues = validCheckValues();
    checkValues.put('ApplicabilityMode__c', 'WHEN_COUNT_QUERY_MATCHES');
    checkValues.put('ApplicabilityCountOperator__c', 'BAD');
    checkValues.put('MaxQueryRows__c', 2001.5);
    checkValues.put('NoRowsResult__c', 'BAD');
    checkValues.put('EmptyValueHandling__c', 'BAD');
    String issues = JSON.serialize(RHCBuilderCoreValidator.validateCheck(checkValues, 'FORMULA', 'checks[0]'));
    Assert.isTrue(issues.contains('ApplicabilityCountQuery__c'));
    Assert.isTrue(issues.contains('ApplicabilityCountThreshold__c'));
    Assert.isTrue(issues.contains('MaxQueryRows__c'));
  }

  @IsTest
  static void shouldRejectApexAndOversizedCheckRules() {
    Map<String, Object> apexValues = validCheckValues();
    apexValues.remove('PassConditionFormula__c');
    apexValues.put('ApexParametersJson__c', '[]');
    String apexIssues = JSON.serialize(RHCBuilderCoreValidator.validateCheck(apexValues, 'APEX', 'checks[0]'));
    Assert.isTrue(apexIssues.contains('ApexClass__c'));
    Assert.isTrue(apexIssues.contains('ApexParametersJson__c'));

    apexValues.put('ApexClass__c', 'String');
    apexValues.put('ApexParametersJson__c', '{}');
    String wrongInterfaceIssues = JSON.serialize(
      RHCBuilderCoreValidator.validateCheck(apexValues, 'APEX', 'checks[0]')
    );
    Assert.isTrue(
      wrongInterfaceIssues.contains('ApexClass__c'),
      'A class that does not implement the core plugin interface must fail.'
    );

    apexValues.put('ApexClass__c', 'AccountHasRecentActivityCheck');
    String validPluginIssues = JSON.serialize(
      RHCBuilderCoreValidator.validateCheck(apexValues, 'APEX', 'checks[0]')
    );
    Assert.isFalse(
      validPluginIssues.contains('ApexClass__c'),
      'A packaged core plugin implementation must pass reflection validation.'
    );

    Map<String, Object> version = versionMap();
    Map<String, Object> check = (Map<String, Object>) ((List<Object>) version.get('checks'))[0];
    Map<String, Object> values = (Map<String, Object>) check.get('values');
    values.put('FailureSeverity__c', 'BAD');
    values.put('EvaluationType__c', 'BAD');
    values.put('FailureMessage__c', ''.leftPad(33000, 'x'));
    String result = RHCBuilderVersionValidator.validate(JSON.serialize(version));
    Assert.isTrue(result.contains('CHECK_VALUES_TOO_LARGE'));
    Assert.isTrue(result.contains('EVALUATION_TYPE_INVALID'));
    Assert.isTrue(result.contains('SEVERITY_INVALID'));
  }

  private static Map<String, Object> versionMap() {
    return (Map<String, Object>) JSON.deserializeUntyped(RHCBuilderTestDataFactory.validCanonicalVersion());
  }

  private static Map<String, Object> validCheckValues() {
    Map<String, Object> version = versionMap();
    return (Map<String, Object>) ((Map<String, Object>) ((List<Object>) version.get('checks'))[0]).get('values');
  }
}
