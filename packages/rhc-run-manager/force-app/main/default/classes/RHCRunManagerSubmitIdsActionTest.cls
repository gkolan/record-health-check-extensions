@IsTest
private class RHCRunManagerSubmitIdsActionTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
    RHCRunManagerTestDataFactory.createPersonaUser('rhcexec', 'RHC_Run_Manager_Executor');
  }

  @IsTest
  static void shouldRemoveNullsAndDuplicatesWhenCurrentAndPriorParentMatch() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    Account account = new Account(Name = 'Related parent');
    insert account;
    RHCRunManagerSubmitIdsAction.Request requestValue = new RHCRunManagerSubmitIdsAction.Request();
    requestValue.runDefinitionId = definition.Id;
    requestValue.targetRecordId = account.Id;
    requestValue.priorTargetRecordId = account.Id;
    requestValue.targetRecordIds = new List<Id>{ account.Id, null };
    RHCRunManagerSubmitIdsAction.suppressCoalescer = true;

    Test.startTest();
    List<RHCRunManagerSubmitIdsAction.Response> responses = RHCRunManagerSubmitIdsAction.submit(new List<RHCRunManagerSubmitIdsAction.Request>{ requestValue });
    Test.stopTest();

    Assert.isTrue(responses[0].isSuccess, 'Flow action should accept valid related IDs.');
    Assert.areEqual(1, responses[0].acceptedRecordCount, 'Current, prior, and collection duplicates should collapse.');
    Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Run_Request__c WHERE RunDefinition__c = :definition.Id], 'Only one staging row should exist.');
    }
  }

  @IsTest
  static void shouldReturnPerInputErrorWhenDefinitionMissing() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    RHCRunManagerSubmitIdsAction.Request requestValue = new RHCRunManagerSubmitIdsAction.Request();
    List<RHCRunManagerSubmitIdsAction.Response> responses = RHCRunManagerSubmitIdsAction.submit(
      new List<RHCRunManagerSubmitIdsAction.Request>{ requestValue, null }
    );

    Assert.areEqual(2, responses.size(), 'Flow bulk shape should be preserved.');
    Assert.isFalse(responses[0].isSuccess, 'Missing definition should be rejected without failing the transaction.');
    Assert.areEqual('INVALID_INPUT', responses[1].errorType, 'Null input should receive the canonical input error.');
    Assert.areEqual(0, RHCRunManagerSubmitIdsAction.submit(null).size(), 'Null bulk input should be safe.');
    }
  }

  @IsTest
  static void shouldBulkStage251DistinctIdsWhenFlowBulkInput() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    List<Account> accounts = RHCRunManagerTestDataFactory.createAccounts(251);
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    List<RHCRunManagerSubmitIdsAction.Request> requests = new List<RHCRunManagerSubmitIdsAction.Request>();
    for (Account account : accounts) {
      RHCRunManagerSubmitIdsAction.Request requestValue = new RHCRunManagerSubmitIdsAction.Request();
      requestValue.runDefinitionId = definition.Id;
      requestValue.targetRecordId = account.Id;
      requests.add(requestValue);
    }
    RHCRunManagerSubmitIdsAction.suppressCoalescer = true;

    Test.startTest();
    List<RHCRunManagerSubmitIdsAction.Response> responses = RHCRunManagerSubmitIdsAction.submit(requests);
    Test.stopTest();

    Assert.areEqual(251, responses.size(), 'The Flow bulk response shape must be preserved.');
    Assert.areEqual(1, responses[250].acceptedRecordCount, 'Each response should report only its own deduplicated IDs.');
    Assert.areEqual(251, [SELECT COUNT() FROM Record_Health_Check_Run_Request__c WHERE RunDefinition__c = :definition.Id], 'All distinct target IDs should be staged in one DML operation.');
    }
  }

  @IsTest
  static void shouldRejectIdsFromWrongObjectWithoutStagingAnyRows() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    Contact contact = new Contact(LastName = 'Wrong object');
    insert contact;
    RHCRunManagerSubmitIdsAction.Request requestValue = new RHCRunManagerSubmitIdsAction.Request();
    requestValue.runDefinitionId = definition.Id;
    requestValue.targetRecordId = contact.Id;
    RHCRunManagerSubmitIdsAction.suppressCoalescer = true;

    List<RHCRunManagerSubmitIdsAction.Response> responses = RHCRunManagerSubmitIdsAction.submit(
      new List<RHCRunManagerSubmitIdsAction.Request>{ requestValue }
    );

    Assert.isFalse(responses[0].isSuccess, 'An ID for a different sObject must be rejected.');
    Assert.areEqual('INVALID_TARGET_TYPE', responses[0].errorType, 'The rejection should be actionable for Flow fault handling.');
    Assert.areEqual(0, responses[0].acceptedRecordCount, 'Rejected IDs must not be reported as accepted.');
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Run_Request__c], 'Wrong-object IDs must never reach durable staging.');
    }
  }

  @IsTest
  static void shouldRejectEmptyInputAndNonSuppliedDefinition() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c suppliedDefinition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
    Record_Health_Check_Run_Definition__c allAccessibleDefinition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'FAIL');
    Account account = new Account(Name = 'Definition mode validation');
    insert account;
    RHCRunManagerSubmitIdsAction.Request emptyRequest = new RHCRunManagerSubmitIdsAction.Request();
    emptyRequest.runDefinitionId = suppliedDefinition.Id;
    RHCRunManagerSubmitIdsAction.Request wrongModeRequest = new RHCRunManagerSubmitIdsAction.Request();
    wrongModeRequest.runDefinitionId = allAccessibleDefinition.Id;
    wrongModeRequest.targetRecordId = account.Id;
    RHCRunManagerSubmitIdsAction.suppressCoalescer = true;

    List<RHCRunManagerSubmitIdsAction.Response> responses = RHCRunManagerSubmitIdsAction.submit(
      new List<RHCRunManagerSubmitIdsAction.Request>{ emptyRequest, wrongModeRequest }
    );

    Assert.areEqual('INVALID_INPUT', responses[0].errorType, 'At least one supplied ID is required.');
    Assert.areEqual('INVALID_DEFINITION', responses[1].errorType, 'Only supplied-ID definitions may use this action.');
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Run_Request__c], 'Rejected inputs must not create staging rows.');
    }
  }

  @IsTest
  static void shouldUseCrossOwnerDefinitionWithoutGrantingExecutorConfigurationWrite() {
    Record_Health_Check_Run_Definition__c definition;
    Account account;
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      definition = RHCRunManagerTestDataFactory.createDefinition('SUPPLIED_IDS', 'FAIL');
      account = new Account(Name = 'Cross-owner supplied ID');
      insert account;
    }
    System.runAs(RHCRunManagerTestDataFactory.personaUser('rhcexec')) {
      RHCRunManagerSubmitIdsAction.Request requestValue = new RHCRunManagerSubmitIdsAction.Request();
      requestValue.runDefinitionId = definition.Id;
      requestValue.targetRecordId = account.Id;
      RHCRunManagerSubmitIdsAction.suppressCoalescer = true;

      List<RHCRunManagerSubmitIdsAction.Response> responses = RHCRunManagerSubmitIdsAction.submit(
        new List<RHCRunManagerSubmitIdsAction.Request>{ requestValue }
      );
      Assert.isTrue(responses[0].isSuccess, 'Executor must consume an Admin-owned supplied-ID definition.');
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Run_Request__c WITH USER_MODE], 'Executor should create its owned durable request.');

      definition.DisplayName__c = 'Executor must not edit';
      Database.SaveResult updateResult = Database.update(definition, false, AccessLevel.USER_MODE);
      Assert.isFalse(updateResult.isSuccess(), 'Cross-owner read must not grant Executor configuration write.');
    }
  }
}
