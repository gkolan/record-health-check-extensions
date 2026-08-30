@IsTest
private class RHCRunManagerFilterServiceTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldBuildBoundQuery_WhenGuidedFilterValid() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Test.startTest();
    RHCRunManagerFilterService.QuerySpec result = RHCRunManagerFilterService.build(
      'Account', 'GUIDED_FILTERED',
      '[{"field":"Name","operator":"STARTS_WITH","value":"Acme"}]',
      null
    );
    Test.stopTest();
    Assert.isTrue(result.soql.contains('Name LIKE :value0'), 'Query should contain only validated field/operator syntax.');
    Assert.areEqual('Acme%', result.binds.get('value0'), 'Value should remain a bind variable.');
    }
  }

  @IsTest
  static void shouldRejectUnknownField_WhenFilterAttemptsInjection() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    try {
      RHCRunManagerFilterService.build('Account', 'GUIDED_FILTERED', '[{"field":"Name FROM Account","operator":"EQ","value":"x"}]', null);
      Assert.fail('Expected unknown field to fail.');
    } catch (RHCRunManagerFilterService.FilterException error) {
      Assert.isTrue(error.getMessage().contains('does not exist'), 'Failure should not echo injected syntax.');
    }
    }
  }

  @IsTest
  static void shouldBindDeduplicatedIds_WhenSupplied() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Account account = new Account(Name = 'Bound Account');
    insert account;
    RHCRunManagerFilterService.QuerySpec result = RHCRunManagerFilterService.build('Account', 'SUPPLIED_IDS', null, new List<Id>{ account.Id });
    Assert.isTrue(result.soql.endsWith('WHERE Id IN :targetIds'), 'Supplied population should be ID-bound.');
    }
  }
}
