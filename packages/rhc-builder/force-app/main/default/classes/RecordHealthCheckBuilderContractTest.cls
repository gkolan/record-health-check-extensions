/** Tests the contract that is owned and used by RHC Builder. */
@IsTest
private inherited sharing class RecordHealthCheckBuilderContractTest {
  @IsTest
  static void shouldDescribeSupportedBuilderChoices() {
    System.runAs(currentUser()) {
      RecordHealthCheckBuilderContract contract = new RecordHealthCheckBuilderContract();

      Test.startTest();
      Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
        (String) contract.call('describeContract', new Map<String, Object>())
      );
      Test.stopTest();

      Assert.areEqual(
        '1.0',
        result.get('contractVersion'),
        'Builder must publish its contract version.'
      );
      Assert.areEqual(
        4,
        ((List<Object>) result.get('evaluationTypes')).size(),
        'Builder must offer all four supported evaluation types.'
      );
      Map<String, Object> allowedValues = (Map<String, Object>) result.get(
        'allowedValues'
      );
      List<Object> emptyValueHandling = (List<Object>) allowedValues.get(
        'EmptyValueHandling__c'
      );
      Assert.isTrue(
        emptyValueHandling.contains('SKIP_RECORD'),
        'Builder choices must include the core empty-value default.'
      );
      Assert.isFalse(
        emptyValueHandling.contains('FAIL'),
        'No-row behavior values must not leak into core empty-value choices.'
      );
      Assert.areEqual(
        new List<Object>{
          'LABEL_AND_ICON',
          'LABEL_ONLY',
          'ICON_ONLY',
          'HIDE'
        },
        (List<Object>) allowedValues.get('RunButtonDisplay__c'),
        'Builder must describe every supported Run button presentation.'
      );
      Assert.areEqual(
        new List<Object>{ 'ON_DEMAND', 'FAILURES_ONLY', 'ALL_ROWS' },
        (List<Object>) allowedValues.get('FoundExpectedDisplay__c'),
        'Builder must describe every supported Found/Expected presentation.'
      );
      Assert.areEqual(
        new List<Object>{ 'TOP', 'BOTTOM' },
        (List<Object>) allowedValues.get('SummaryDisplay__c'),
        'Builder must describe both supported summary positions.'
      );
    }
  }

  @IsTest
  static void shouldAcceptACompleteValidVersion() {
    System.runAs(currentUser()) {
      RecordHealthCheckBuilderContract contract = new RecordHealthCheckBuilderContract();

      Test.startTest();
      Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
        (String) contract.call(
          'validateVersion',
          new Map<String, Object>{
            'canonicalVersionJson' => RHCBuilderTestDataFactory.validCanonicalVersion()
          }
        )
      );
      Test.stopTest();

      Assert.areEqual(
        true,
        result.get('isValid'),
        'A complete supported version must pass validation.'
      );
      Assert.areEqual(
        0,
        ((List<Object>) result.get('issues')).size(),
        'A valid version must have no issues.'
      );
    }
  }

  @IsTest
  static void shouldRejectAnUnsupportedEvaluationType() {
    System.runAs(currentUser()) {
      Map<String, Object> version = (Map<String, Object>) JSON.deserializeUntyped(
        RHCBuilderTestDataFactory.validCanonicalVersion()
      );
      Map<String, Object> check = (Map<String, Object>) ((List<Object>) version.get(
        'checks'
      ))[0];
      ((Map<String, Object>) check.get('values'))
        .put('EvaluationType__c', 'UNKNOWN');
      RecordHealthCheckBuilderContract contract = new RecordHealthCheckBuilderContract();

      Test.startTest();
      Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
        (String) contract.call(
          'validateVersion',
          new Map<String, Object>{
            'canonicalVersionJson' => JSON.serialize(version)
          }
        )
      );
      Test.stopTest();

      Assert.areEqual(
        false,
        result.get('isValid'),
        'An unsupported evaluation type must fail validation.'
      );
      Assert.isTrue(
        JSON.serialize(result.get('issues'))
          .contains('EVALUATION_TYPE_INVALID'),
        'The result must identify the unsupported evaluation type.'
      );
    }
  }

  @IsTest
  static void shouldRejectAQueryThatFailsCoreValidation() {
    System.runAs(currentUser()) {
      Map<String, Object> version = (Map<String, Object>) JSON.deserializeUntyped(
        RHCBuilderTestDataFactory.validCanonicalVersion()
      );
      Map<String, Object> check = (Map<String, Object>) ((List<Object>) version.get(
        'checks'
      ))[0];
      Map<String, Object> values = (Map<String, Object>) check.get('values');
      values.put('EvaluationType__c', 'QUERY');
      values.remove('PassConditionFormula__c');
      values.put('SourceQuery__c', 'SELECT Id FROM Contact');
      values.put('SourceQueryField__c', 'Id');
      values.put('EmptyValueHandling__c', 'FAIL');
      RecordHealthCheckBuilderContract contract = new RecordHealthCheckBuilderContract();

      Test.startTest();
      Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
        (String) contract.call(
          'validateVersion',
          new Map<String, Object>{
            'canonicalVersionJson' => JSON.serialize(version)
          }
        )
      );
      Test.stopTest();

      Assert.areEqual(
        false,
        result.get('isValid'),
        'A Query that core rejects must not be saveable by Builder.'
      );
      String serializedIssues = JSON.serialize(result.get('issues'));
      Assert.isTrue(
        serializedIssues.contains('checks[0].values.ComparisonOperator__c'),
        'Builder should preserve the core validator field path.'
      );
      Assert.isTrue(
        serializedIssues.contains('checks[0].values.EmptyValueHandling__c'),
        'Builder should reject a no-row behavior used as empty-value handling.'
      );
    }
  }

  @IsTest
  static void shouldRejectAnInvalidQualifiedApiNameWithoutRewritingIt() {
    System.runAs(currentUser()) {
      Map<String, Object> version = (Map<String, Object>) JSON.deserializeUntyped(
        RHCBuilderTestDataFactory.validCanonicalVersion()
      );
      Map<String, Object> checkSet = (Map<String, Object>) version.get(
        'checkSet'
      );
      checkSet.put('qualifiedApiName', 'Invalid name!');
      RecordHealthCheckBuilderContract contract = new RecordHealthCheckBuilderContract();

      Test.startTest();
      Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
        (String) contract.call(
          'validateVersion',
          new Map<String, Object>{
            'canonicalVersionJson' => JSON.serialize(version)
          }
        )
      );
      Test.stopTest();

      Assert.areEqual(
        false,
        result.get('isValid'),
        'An invalid exact identity must fail rather than being rewritten.'
      );
      Assert.isTrue(
        JSON.serialize(result.get('issues'))
          .contains('QUALIFIED_API_NAME_INVALID'),
        'The issue must point to the Qualified API Name.'
      );
    }
  }

  @IsTest
  static void shouldBuildAnInactivePublicationPlan() {
    System.runAs(currentUser()) {
      RecordHealthCheckBuilderContract contract = new RecordHealthCheckBuilderContract();

      Test.startTest();
      Map<String, Object> plan = (Map<String, Object>) JSON.deserializeUntyped(
        (String) contract.call(
          'buildDeploymentPlan',
          new Map<String, Object>{
            'canonicalVersionJson' => RHCBuilderTestDataFactory.validCanonicalVersion(),
            'activate' => false
          }
        )
      );
      Test.stopTest();

      List<Object> components = (List<Object>) plan.get('components');
      Assert.areEqual(
        2,
        components.size(),
        'The plan must include the Check Set and its Check.'
      );
      Map<String, Object> checkSet = (Map<String, Object>) components[0];
      Assert.isTrue(
        ((String) checkSet.get('fullName'))
          .contains('Account_Handoff_Review'),
        'The exact Qualified API Name must be preserved.'
      );
      Assert.isTrue(
        JSON.serialize(checkSet.get('values')).contains('IsActive__c'),
        'The plan must explicitly keep inactive publication inactive.'
      );
    }
  }

  @IsTest
  static void shouldDeactivateCheckOmittedFromPriorActiveVersion() {
    System.runAs(currentUser()) {
      Map<String, Object> priorVersion = (Map<String, Object>) JSON.deserializeUntyped(
        RHCBuilderTestDataFactory.validCanonicalVersion()
      );
      List<Object> priorChecks = (List<Object>) priorVersion.get('checks');
      Map<String, Object> omittedCheck = (Map<String, Object>) JSON.deserializeUntyped(
        JSON.serialize(priorChecks[0])
      );
      omittedCheck.put('qualifiedApiName', 'Previously_Active_Check');
      omittedCheck.put('label', 'Previously active Check');
      priorChecks.add(omittedCheck);
      RecordHealthCheckBuilderContract contract = new RecordHealthCheckBuilderContract();

      Test.startTest();
      Map<String, Object> plan = (Map<String, Object>) JSON.deserializeUntyped(
        (String) contract.call(
          'buildDeploymentPlan',
          new Map<String, Object>{
            'canonicalVersionJson' => RHCBuilderTestDataFactory.validCanonicalVersion(),
            'activate' => true,
            'priorActiveVersionJson' => JSON.serialize(priorVersion)
          }
        )
      );
      Test.stopTest();

      List<Object> components = (List<Object>) plan.get('components');
      Assert.areEqual(
        3,
        components.size(),
        'The plan must include one deactivation for the omitted prior Check.'
      );
      Map<String, Object> deactivation = (Map<String, Object>) components[2];
      Assert.isTrue(
        ((String) deactivation.get('fullName')).endsWith(
          'Previously_Active_Check'
        ),
        'The deactivation must preserve the omitted Check identity.'
      );
      Assert.areEqual(
        false,
        activationValue((Map<String, Object>) deactivation.get('values')),
        'The omitted Check must be explicitly inactive.'
      );
    }
  }

  @IsTest
  static void shouldRejectAnUnsupportedAction() {
    System.runAs(currentUser()) {
      RecordHealthCheckBuilderContract contract = new RecordHealthCheckBuilderContract();

      Test.startTest();
      try {
        contract.call('unknownAction', new Map<String, Object>());
        Assert.fail('An unsupported action must be rejected.');
      } catch (RecordHealthCheckBuilderContract.BuilderContractException error) {
        Assert.isTrue(
          error.getMessage().contains('does not support'),
          'The message must explain that the action is unsupported.'
        );
      }
      Test.stopTest();
    }
  }

  private static User currentUser() {
    return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
  }

  private static Object activationValue(Map<String, Object> values) {
    for (String fieldName : values.keySet()) {
      if (
        fieldName == 'IsActive__c' ||
        fieldName.endsWith('__IsActive__c')
      ) {
        return values.get(fieldName);
      }
    }
    return null;
  }
}
