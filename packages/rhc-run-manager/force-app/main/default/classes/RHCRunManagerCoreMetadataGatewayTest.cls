@IsTest
private class RHCRunManagerCoreMetadataGatewayTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldResolveCheckSet_WhenQualifiedIdentityExists() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Set__mdt fixture = RHCRunManagerTestDataFactory.accountCheckSet();
    Test.startTest();
    RHCRunManagerCoreMetadataGateway.DefinitionInfo result = RHCRunManagerCoreMetadataGateway.resolve('CHECK_SET', fixture.QualifiedApiName);
    Test.stopTest();
    Assert.areEqual('Account', result.targetObjectApiName, 'Target object should come from core metadata.');
    Assert.areEqual(fixture.QualifiedApiName, result.checkSetQualifiedApiName, 'Check Set identity should remain exact.');
    }
  }

  @IsTest
  static void shouldResolveOwningSet_WhenCheckSelected() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check__mdt fixture = RHCRunManagerTestDataFactory.accountCheck();
    RHCRunManagerCoreMetadataGateway.DefinitionInfo result = RHCRunManagerCoreMetadataGateway.resolve('CHECK', fixture.QualifiedApiName);
    Assert.areEqual('CHECK', result.selectionType, 'Selection type should remain explicit.');
    Assert.areEqual(fixture.Record_Health_Check_Set__r.QualifiedApiName, result.checkSetQualifiedApiName, 'Check should resolve its owning Check Set.');
    }
  }

  @IsTest
  static void shouldRejectInvalidSelectionType_WhenUnknown() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Test.startTest();
    try {
      RHCRunManagerCoreMetadataGateway.resolve('UNKNOWN', 'Anything');
      Assert.fail('Expected invalid Selection Type to fail.');
    } catch (RHCRunManagerCoreMetadataGateway.ResolutionException error) {
      Assert.isTrue(error.getMessage().contains('Selection Type'), 'Failure should identify Selection Type.');
    }
    Test.stopTest();
    }
  }
}
