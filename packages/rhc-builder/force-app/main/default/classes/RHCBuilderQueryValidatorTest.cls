/** Tests Builder-owned mirrors of pinned core query validation rules. */
@IsTest
private class RHCBuilderQueryValidatorTest {
  @IsTest
  static void shouldAcceptCompleteSingleQuery() {
    System.runAs(currentUser()) {
      Map<String, Object> values = new Map<String, Object>{
        'SourceQuery__c' => 'SELECT Id FROM Contact WHERE AccountId = {!record.Id}',
        'SourceQueryField__c' => 'Id',
        'ComparisonOperator__c' => 'IS_NOT_BLANK',
        'QueryResultHandling__c' => 'ONE_RESULT'
      };
      Test.startTest();
      List<Object> issues = RHCBuilderQueryValidator.validate(values, 'QUERY');
      Test.stopTest();
      Assert.areEqual(0, issues.size(), 'A complete single Query must pass.');
    }
  }

  @IsTest
  static void shouldRejectMissingSingleQueryChoices() {
    System.runAs(currentUser()) {
      Map<String, Object> values = new Map<String, Object>{
        'SourceQuery__c' => 'SELECT Id FROM Contact',
        'SourceQueryField__c' => 'Id'
      };
      Test.startTest();
      List<Object> issues = RHCBuilderQueryValidator.validate(values, 'QUERY');
      Test.stopTest();
      String serializedIssues = JSON.serialize(issues);
      Assert.isTrue(
        serializedIssues.contains('ComparisonOperator__c'),
        'A Query must select an operator.'
      );
      Assert.isTrue(
        serializedIssues.contains('QueryResultHandling__c'),
        'A Query must select result handling.'
      );
    }
  }

  @IsTest
  static void shouldRejectScalarOperatorForListComparison() {
    System.runAs(currentUser()) {
      Map<String, Object> values = new Map<String, Object>{
        'SourceQuery__c' => 'SELECT Id FROM Contact WHERE AccountId = {!record.Id}',
        'SourceQueryField__c' => 'Id',
        'ComparisonQuery__c' => 'SELECT Id FROM Opportunity WHERE AccountId = {!record.Id}',
        'ComparisonQueryField__c' => 'Id',
        'ComparisonOperator__c' => 'EQUALS',
        'QueryResultHandling__c' => 'COMPARE_AS_LISTS'
      };
      Test.startTest();
      List<Object> issues = RHCBuilderQueryValidator.validate(
        values,
        'COMPARE_TWO_QUERIES'
      );
      Test.stopTest();
      Assert.isTrue(
        JSON.serialize(issues).contains('ComparisonOperator__c'),
        'Compare-as-lists mode must require a list operator.'
      );
    }
  }

  @IsTest
  static void shouldRejectUnsafeBulkShapesAndNonTextContains() {
    System.runAs(currentUser()) {
      Map<String, Object> values = new Map<String, Object>{
        'SourceQuery__c' => 'SELECT NumberOfEmployees FROM Account WHERE Id != {!record.Id}',
        'SourceQueryField__c' => 'NumberOfEmployees',
        'ComparisonOperator__c' => 'CONTAINS',
        'QueryResultHandling__c' => 'ONE_RESULT',
        'ExpectedValueSource__c' => 'FIXED_VALUE',
        'ExpectedFixedValue__c' => '10'
      };
      String issues = JSON.serialize(RHCBuilderQueryValidator.validate(values, 'QUERY'));
      Assert.isTrue(issues.contains('UNSUPPORTED_BULK_QUERY_SHAPE'));
      Assert.isTrue(issues.contains('TEXT_OPERATOR_REQUIRES_TEXT'));
      Assert.isFalse(
        RHCBuilderQueryValidator.isSupportedBulkShape(
          'SELECT Id FROM Account WHERE Id = :recordId'
        ),
        'Raw Apex binds are not supported metadata templates.'
      );
    }
  }

  @IsTest
  static void shouldClassifyApplicabilityCountQueries() {
    System.runAs(currentUser()) {
      Assert.isTrue(
        RHCBuilderQueryValidator.isSingleCountQuery(
          'SELECT COUNT() total FROM Contact WHERE AccountId = {!record.Id}'
        )
      );
      Assert.isFalse(
        RHCBuilderQueryValidator.isSingleCountQuery(
          'SELECT Id FROM Contact WHERE AccountId = {!record.Id}'
        )
      );
    }
  }

  private static User currentUser() {
    return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
  }
}
