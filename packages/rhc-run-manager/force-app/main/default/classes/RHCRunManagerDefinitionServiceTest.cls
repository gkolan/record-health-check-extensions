/** Verifies Run Definition validation, canonicalization, and user-mode persistence. */
@IsTest
private class RHCRunManagerDefinitionServiceTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldInsertCanonicalDefinitionWhenDraftValid() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = validDraft();
      definition.DisplayName__c = '  Account health  ';

      Test.startTest();
      Id definitionId = RHCRunManagerDefinitionService.save(definition);
      Test.stopTest();

      Record_Health_Check_Run_Definition__c saved = [
        SELECT DisplayName__c, QualifiedApiName__c, TargetObjectApiName__c
        FROM Record_Health_Check_Run_Definition__c
        WHERE Id = :definitionId
      ];
      Assert.areEqual('Account health', saved.DisplayName__c, 'Display Name should be trimmed.');
      Assert.areEqual(definition.QualifiedApiName__c, saved.QualifiedApiName__c, 'Core identity should be canonical.');
      Assert.areEqual('Account', saved.TargetObjectApiName__c, 'Target object must come from core metadata.');
    }
  }

  @IsTest
  static void shouldUpdateExistingDefinitionWhenIdPresent() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c existing = RHCRunManagerTestDataFactory.createDefinition(
        'ALL_ACCESSIBLE',
        'FAIL'
      );
      existing.DisplayName__c = 'Updated account health';

      Test.startTest();
      Id definitionId = RHCRunManagerDefinitionService.save(existing);
      Test.stopTest();

      Assert.areEqual(existing.Id, definitionId, 'Update should retain the existing definition ID.');
      Assert.areEqual(
        'Updated account health',
        [SELECT DisplayName__c FROM Record_Health_Check_Run_Definition__c WHERE Id = :definitionId].DisplayName__c,
        'Update should persist changed values.'
      );
    }
  }

  @IsTest
  static void shouldRejectNullDraft() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Assert.isTrue(
        rejectionMessage(null).contains('Run Definition input is required.'),
        'A null draft should be rejected explicitly.'
      );
    }
  }

  @IsTest
  static void shouldRejectBlankDisplayName() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = validDraft();
      definition.DisplayName__c = ' ';
      Assert.isTrue(
        rejectionMessage(definition).contains('Name is required'),
        'A blank Display Name should be rejected explicitly.'
      );
    }
  }

  @IsTest
  static void shouldRejectUnsupportedSelectionType() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = validDraft();
      definition.SelectionType__c = 'LEGACY';
      Assert.isTrue(
        rejectionMessage(definition).contains('Selection Type is invalid.'),
        'An unsupported Selection Type should be rejected explicitly.'
      );
    }
  }

  @IsTest
  static void shouldRejectUnsupportedPopulationMode() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = validDraft();
      definition.PopulationMode__c = 'RAW_SOQL';
      Assert.isTrue(
        rejectionMessage(definition).contains('Population Mode is invalid.'),
        'An unsupported Population Mode should be rejected explicitly.'
      );
    }
  }

  @IsTest
  static void shouldRejectUnsupportedCaptureMode() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = validDraft();
      definition.CaptureMode__c = 'SKIPPED';
      Assert.isTrue(
        rejectionMessage(definition).contains('Capture Mode is invalid.'),
        'An unsupported Capture Mode should be rejected explicitly.'
      );
    }
  }

  @IsTest
  static void shouldRejectFractionalBatchSize() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = validDraft();
      definition.BatchSize__c = 1.5;
      Assert.isTrue(
        rejectionMessage(definition).contains('Batch Size must be a whole number'),
        'A fractional Batch Size should be rejected explicitly.'
      );
    }
  }

  @IsTest
  static void shouldRejectOutOfRangeCoalesceDelay() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = validDraft();
      definition.CoalesceDelayMinutes__c = 11;
      Assert.isTrue(
        rejectionMessage(definition).contains('Coalesce delay must be a whole number'),
        'An out-of-range coalesce delay should be rejected explicitly.'
      );
    }
  }

  private static Record_Health_Check_Run_Definition__c validDraft() {
    Record_Health_Check_Set__mdt checkSet = RHCRunManagerTestDataFactory.accountCheckSet();
    return new Record_Health_Check_Run_Definition__c(
      DisplayName__c = 'Account health',
      Active__c = true,
      SelectionType__c = 'CHECK_SET',
      QualifiedApiName__c = checkSet.QualifiedApiName,
      PopulationMode__c = 'ALL_ACCESSIBLE',
      BatchSize__c = 200,
      CaptureMode__c = 'BOTH',
      CoalesceDelayMinutes__c = 1
    );
  }

  private static String rejectionMessage(Record_Health_Check_Run_Definition__c definition) {
    String errorMessage;
    Test.startTest();
    try {
      RHCRunManagerDefinitionService.save(definition);
      Assert.fail('Expected definition validation to reject the draft.');
    } catch (RHCRunManagerDefinitionService.DefinitionException error) {
      errorMessage = error.getMessage();
    }
    Test.stopTest();
    return errorMessage;
  }
}
