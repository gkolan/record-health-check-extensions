/** Tests the Builder controller's security, version boundary, and idempotency. */
@IsTest
private class RHCBuilderControllerTest {
  private class MockBuilderContract implements Callable {
    Boolean valid;

    MockBuilderContract(Boolean valid) {
      this.valid = valid;
    }

    /**
     * Returns deterministic contract responses for controller tests.
     * @param action Builder contract action name.
     * @param arguments Builder contract action values.
     * @return Deterministic JSON response, or null for an unsupported action.
     */
    public Object call(String action, Map<String, Object> arguments) {
      if (action == 'describeContract') {
        return '{"contractVersion":"1.0","evaluationTypes":["FORMULA","QUERY","COMPARE_TWO_QUERIES","APEX"]}';
      }
      if (action == 'validateVersion') {
        return valid
          ? RHCBuilderTestDataFactory.validValidationReport()
          : '{"isValid":false,"issues":[{"reasonCode":"INVALID_FORMULA"}]}';
      }
      if (action == 'buildDeploymentPlan') {
        return RHCBuilderTestDataFactory.deploymentPlan();
      }
      return null;
    }
  }

  @IsTest
  static void shouldReturnBuilderContractWhenAuthorHasAccess() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      RHCBuilderContractGateway.testContract = new MockBuilderContract(true);

      Test.startTest();
      Map<String, Object> contract = RHCBuilderController.getAuthoringContract();
      Test.stopTest();

      Assert.areEqual(
        '1.0',
        contract.get('contractVersion'),
        'Builder contract version should be returned.'
      );
    }
  }

  @IsTest
  static void shouldDescribeReadableRelatedRecordsForGuidedQueries() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;

      Test.startTest();
      List<Map<String, String>> relationships = RHCBuilderController.listReadableRelationships(
        'Account'
      );
      Test.stopTest();

      Assert.isFalse(
        relationships.isEmpty(),
        'Account should expose at least one readable child relationship.'
      );
      Assert.isNotNull(
        relationships[0].get('childObjectApiName'),
        'The guided query needs an exact child object API name.'
      );
      Assert.isNotNull(
        relationships[0].get('parentFieldApiName'),
        'The guided query needs an exact parent field API name.'
      );
    }
  }

  @IsTest
  static void shouldReturnHomeVersionAndReadableSchemaState() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      Id versionId = RHCBuilderTestDataFactory.createValidatedVersion();
      Record_Health_Check_Set_Deployment__c operation = new Record_Health_Check_Set_Deployment__c(
        CheckSetVersion__c = versionId,
        OperationToken__c = 'home-operation',
        OperationKind__c = 'SAVE_VERSION',
        Status__c = 'SUCCEEDED',
        RequestedFingerprint__c = 'abc',
        RequestedAt__c = System.now()
      );
      insert operation;

      Test.startTest();
      Map<String, Object> home = RHCBuilderController.getBuilderHome();
      Map<String, Object> version = RHCBuilderController.getCheckSetVersion(versionId);
      Map<String, Object> foundOperation = RHCBuilderController.getSetDeployment('home-operation');
      Map<String, Object> missingOperation = RHCBuilderController.getSetDeployment('missing-operation');
      List<Map<String, String>> objects = RHCBuilderController.listReadableObjects();
      List<Map<String, String>> fields = RHCBuilderController.listReadableFields('Account');
      Test.stopTest();

      Assert.areEqual(1, ((List<Object>) home.get('versions')).size(), 'Home must include the version.');
      Assert.areEqual(1, ((List<Object>) home.get('recentOperations')).size(), 'Home must include the operation.');
      Assert.areEqual(versionId, version.get('versionId'), 'The exact immutable version must be returned.');
      Assert.areEqual('home-operation', foundOperation.get('operationToken'), 'The ledger must be queryable.');
      Assert.isNull(missingOperation, 'An unknown operation token must return null.');
      Assert.isFalse(objects.isEmpty(), 'At least one readable object must be listed.');
      Assert.isFalse(fields.isEmpty(), 'Account must expose readable fields.');
    }
  }

  @IsTest
  static void shouldRejectUnreadableSchemaSelectionsAndMissingPermission() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      for (String endpoint : new List<String>{ 'fields', 'relationships' }) {
        try {
          if (endpoint == 'fields') {
            RHCBuilderController.listReadableFields('Not_An_Object__c');
          } else {
            RHCBuilderController.listReadableRelationships('Not_An_Object__c');
          }
          Assert.fail('An unknown object must be rejected.');
        } catch (AuraHandledException error) {
          Assert.isTrue(error.getMessage().contains('object you can read'));
        }
      }
    }

    System.runAs(unprivilegedUser()) {
      RHCBuilderController.testAuthorAccess = false;
      try {
        RHCBuilderController.getBuilderHome();
        Assert.fail('Builder access must be required.');
      } catch (AuraHandledException error) {
        Assert.isTrue(error.getMessage().contains('authoring access'));
      }
    }
  }

  @IsTest
  static void shouldSaveOneCompleteVersionWhenBuilderValidationPasses() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      RHCBuilderContractGateway.testContract = new MockBuilderContract(true);

      Test.startTest();
      Map<String, Object> first = RHCBuilderController.saveCheckSetVersion(
        RHCBuilderTestDataFactory.validCanonicalVersion(),
        'save-version-1'
      );
      Map<String, Object> retry = RHCBuilderController.saveCheckSetVersion(
        RHCBuilderTestDataFactory.validCanonicalVersion(),
        'save-version-1'
      );
      Test.stopTest();

      Assert.areEqual(
        'SUCCEEDED',
        first.get('status'),
        'Validated save should succeed.'
      );
      Assert.areEqual(
        first.get('checkSetVersionId'),
        retry.get('checkSetVersionId'),
        'An idempotent retry must return the original complete version.'
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Record_Health_Check_Set_Version__c],
        'Retry must not create another version.'
      );
      Record_Health_Check_Draft__c check = [
        SELECT DeveloperName__c, SnapshotJson__c
        FROM Record_Health_Check_Draft__c
        LIMIT 1
      ];
      Assert.areEqual(
        'Billing_Country_Is_Populated',
        check.DeveloperName__c,
        'Qualified API Name must remain exact.'
      );
      Assert.isTrue(
        check.SnapshotJson__c.contains('PassConditionFormula__c'),
        'Child snapshot must store the exact core field map.'
      );
    }
  }

  @IsTest
  static void shouldRejectSaveTokenReusedForDifferentVersion() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      RHCBuilderContractGateway.testContract = new MockBuilderContract(true);
      String token = 'save-version-conflict';
      RHCBuilderController.saveCheckSetVersion(
        RHCBuilderTestDataFactory.validCanonicalVersion(),
        token
      );
      Map<String, Object> changedVersion = (Map<String, Object>) JSON.deserializeUntyped(
        RHCBuilderTestDataFactory.validCanonicalVersion()
      );
      ((Map<String, Object>) changedVersion.get('checkSet')).put(
        'label',
        'Changed request'
      );

      Test.startTest();
      try {
        RHCBuilderController.saveCheckSetVersion(
          JSON.serialize(changedVersion),
          token
        );
        Assert.fail('A token must not authorize a different version payload.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('different Builder request'),
          'The conflict must be explained without returning the prior operation.'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldNotSaveVersionWhenBuilderValidationFails() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      RHCBuilderContractGateway.testContract = new MockBuilderContract(false);

      Test.startTest();
      try {
        RHCBuilderController.saveCheckSetVersion(
          RHCBuilderTestDataFactory.validCanonicalVersion(),
          'invalid-version'
        );
        Assert.fail('Builder validation errors must block persistence.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('validation errors'),
          'User-facing message should explain the validation gate.'
        );
      }
      Test.stopTest();

      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Record_Health_Check_Set_Version__c],
        'Invalid version must not be persisted.'
      );
    }
  }

  @IsTest
  static void shouldPublishExactlyOnceWhenRequestIsRetried() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      RHCBuilderContractGateway.testContract = new MockBuilderContract(true);
      Id versionId = RHCBuilderTestDataFactory.createValidatedVersion();

      Test.startTest();
      Map<String, Object> first = RHCBuilderController.publishCheckSetVersion(
        versionId,
        'publish-version-1'
      );
      Map<String, Object> retry = RHCBuilderController.publishCheckSetVersion(
        versionId,
        'publish-version-1'
      );
      Test.stopTest();

      Assert.areEqual(
        first.get('operationToken'),
        retry.get('operationToken'),
        'Publication retry should return the original ledger entry.'
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Record_Health_Check_Set_Deployment__c],
        'Publication retry must not enqueue a second ledger operation.'
      );
    }
  }

  @IsTest
  static void shouldRejectPublicationTokenReusedForDifferentOperation() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      RHCBuilderContractGateway.testContract = new MockBuilderContract(true);
      Id versionId = RHCBuilderTestDataFactory.createValidatedVersion();
      String token = 'publication-operation-conflict';
      RHCBuilderController.publishCheckSetVersion(versionId, token);

      Test.startTest();
      try {
        RHCBuilderController.activateCheckSetVersion(versionId, token);
        Assert.fail('A token must not be reused for a different publication kind.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('different Builder request'),
          'The conflict must identify changed request intent.'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldRejectPublicationWhenVersionWasNotValidated() {
    System.runAs(currentUser()) {
      RHCBuilderController.testAuthorAccess = true;
      RHCBuilderContractGateway.testContract = new MockBuilderContract(true);
      Id versionId = RHCBuilderTestDataFactory.createValidatedVersion();
      update new Record_Health_Check_Set_Version__c(
        Id = versionId,
        Status__c = 'FAILED'
      );

      Test.startTest();
      try {
        RHCBuilderController.activateCheckSetVersion(
          versionId,
          'activate-invalid'
        );
        Assert.fail('An unvalidated version must not be published.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('previously validated'),
          'Message should identify the complete-version validation requirement.'
        );
      }
      Test.stopTest();
    }
  }

  private static User currentUser() {
    User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    PermissionSet builderAdmin = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'RHC_Builder_Admin'
      LIMIT 1
    ];
    if (
      [
        SELECT COUNT()
        FROM PermissionSetAssignment
        WHERE AssigneeId = :user.Id AND PermissionSetId = :builderAdmin.Id
      ] == 0
    ) {
      insert new PermissionSetAssignment(
        AssigneeId = user.Id,
        PermissionSetId = builderAdmin.Id
      );
    }
    return user;
  }

  private static User unprivilegedUser() {
    User user = new User(
      Alias = 'noauth',
      Email = 'noauth@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'No Builder Access',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Chicago',
      Username = 'noauth+' + String.valueOf(System.now().getTime()) + '@example.com'
    );
    insert user;
    return user;
  }
}
