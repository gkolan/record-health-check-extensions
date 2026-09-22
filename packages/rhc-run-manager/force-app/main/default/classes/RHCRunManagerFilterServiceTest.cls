@IsTest
private class RHCRunManagerFilterServiceTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldBuildBoundQueryWhenGuidedFilterValid() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Test.startTest();
    RHCRunManagerFilterService.QuerySpec result = RHCRunManagerFilterService.build(queryRequest(
      'Account', 'GUIDED_FILTERED',
      '[{"field":"Name","operator":"STARTS_WITH","value":"Acme"}]'
    ));
    Test.stopTest();
    Assert.isTrue(result.soql.contains('Name LIKE :value0'), 'Query should contain only validated field/operator syntax.');
    Assert.areEqual('Acme%', result.binds.get('value0'), 'Value should remain a bind variable.');
    }
  }

  @IsTest
  static void shouldRejectUnknownFieldWhenFilterAttemptsInjection() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Test.startTest();
    try {
      RHCRunManagerFilterService.build(queryRequest('Account', 'GUIDED_FILTERED', '[{"field":"Name FROM Account","operator":"EQ","value":"x"}]'));
      Assert.fail('Expected unknown field to fail.');
    } catch (RHCRunManagerFilterService.FilterException error) {
      Assert.isTrue(error.getMessage().contains('does not exist'), 'Failure should not echo injected syntax.');
    }
    Test.stopTest();
    }
  }

  @IsTest
  static void shouldRejectNullQueryRequest() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Test.startTest();
      try {
        RHCRunManagerFilterService.build(null);
        Assert.fail('Expected a null query request to fail.');
      } catch (RHCRunManagerFilterService.FilterException error) {
        Assert.areEqual('Query request is required.', error.getMessage(), 'The failure should identify the missing request.');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldBindSuppliedIds() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Account account = new Account(Name = 'Bound Account');
    insert account;
    Test.startTest();
    RHCRunManagerFilterService.QueryRequest request = queryRequest('Account', 'SUPPLIED_IDS', null);
    request.suppliedIds = new List<Id>{ account.Id };
    RHCRunManagerFilterService.QuerySpec result = RHCRunManagerFilterService.build(request);
    Test.stopTest();
    Assert.isTrue(result.soql.endsWith('WHERE Id IN :targetIds'), 'Supplied population should be ID-bound.');
    }
  }

  @IsTest
  static void shouldRejectUnsupportedOperator() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    String errorMessage = filterRejectionMessage(
      '[{"field":"Name","operator":"EQ OR Name !=","value":"x"}]'
    );
    Assert.isTrue(errorMessage?.contains('operator is not supported'), 'Unsupported operator syntax must be rejected.');
    }
  }

  @IsTest
  static void shouldRejectTextOperatorForNumericField() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    String errorMessage = filterRejectionMessage(
      '[{"field":"AnnualRevenue","operator":"CONTAINS","value":"10"}]'
    );
    Assert.isTrue(errorMessage?.contains('requires a text field'), 'Text operators must be limited to text fields.');
    }
  }

  @IsTest
  static void shouldRejectMalformedTypedValue() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    String errorMessage = filterRejectionMessage(
      '[{"field":"AnnualRevenue","operator":"EQ","value":"not-a-number"}]'
    );
    Assert.isTrue(errorMessage?.contains('does not match its field type'), 'Malformed typed values must be rejected.');
    }
  }

  @IsTest
  static void shouldBuildNullClauseWithoutBind() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Test.startTest();
    RHCRunManagerFilterService.QuerySpec result = RHCRunManagerFilterService.build(queryRequest(
      'Account',
      'GUIDED_FILTERED',
      '[{"field":"Name","operator":"IS_NULL","value":null}]'
    ));
    Test.stopTest();

    Assert.isTrue(result.soql.endsWith('WHERE Name = NULL'), 'IS_NULL should use packaged syntax without a value.');
    Assert.areEqual(0, result.binds.size(), 'IS_NULL should not create an unused bind value.');
    }
  }

  @IsTest
  static void shouldRejectMoreThanTenFilters() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    List<Object> filters = new List<Object>();
    for (Integer filterIndex = 0; filterIndex < 11; filterIndex++) {
      filters.add(new Map<String, Object>{ 'field' => 'Name', 'operator' => 'EQ', 'value' => 'Account' });
    }

    String errorMessage = filterRejectionMessage(JSON.serialize(filters));
    Assert.isTrue(errorMessage?.contains('require 1-10 conditions'), 'Guided filters must enforce the ten-condition cap.');
    }
  }

  private static String filterRejectionMessage(String filterJson) {
    String errorMessage;
    Test.startTest();
    try {
      RHCRunManagerFilterService.build(queryRequest('Account', 'GUIDED_FILTERED', filterJson));
    } catch (RHCRunManagerFilterService.FilterException error) {
      errorMessage = error.getMessage();
    }
    Test.stopTest();
    return errorMessage;
  }

  private static RHCRunManagerFilterService.QueryRequest queryRequest(
    String objectApiName,
    String populationMode,
    String filterJson
  ) {
    RHCRunManagerFilterService.QueryRequest request = new RHCRunManagerFilterService.QueryRequest();
    request.objectApiName = objectApiName;
    request.populationMode = populationMode;
    request.filterJson = filterJson;
    return request;
  }
}
