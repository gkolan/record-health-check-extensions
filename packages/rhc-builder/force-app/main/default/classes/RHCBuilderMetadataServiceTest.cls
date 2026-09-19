/** Tests exact deployment-plan handling and version-level publication state. */
@IsTest
private class RHCBuilderMetadataServiceTest {
  @IsTest
  static void shouldBuildContainerWhenBuilderPlanIsComplete() {
    System.runAs(currentUser()) {
      Test.startTest();
      Metadata.DeployContainer container = RHCBuilderMetadataService.buildContainer(
        RHCBuilderTestDataFactory.deploymentPlan()
      );
      Test.stopTest();

      Assert.isNotNull(
        container,
        'A complete core plan should produce a deployment container.'
      );
    }
  }

  @IsTest
  static void shouldRejectPlanWhenNoComponentsExist() {
    System.runAs(currentUser()) {
      Test.startTest();
      try {
        RHCBuilderMetadataService.buildContainer('{"components":[]}');
        Assert.fail('An empty deployment plan must fail closed.');
      } catch (RHCBuilderMetadataService.DeploymentPlanException error) {
        Assert.isTrue(
          error.getMessage().contains('no components'),
          'Failure should identify the empty core plan.'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldRejectMalformedAndIncompletePlans() {
    System.runAs(currentUser()) {
      for (String invalidPlan : new List<String>{
        '{',
        '{"components":["not-an-object"]}',
        '{"components":[{"fullName":"Type.Member","label":"Label"}]}'
      }) {
        try {
          RHCBuilderMetadataService.buildContainer(invalidPlan);
          Assert.fail('Every malformed or incomplete plan must fail closed.');
        } catch (RHCBuilderMetadataService.DeploymentPlanException expected) {
          Assert.isNotNull(expected.getMessage(), 'The failure must be actionable.');
        }
      }
    }
  }

  @IsTest
  static void shouldValidateScheduleInputAndExecuteQueueableInTests() {
    System.runAs(currentUser()) {
      try {
        RHCBuilderMetadataService.schedule(null, null);
        Assert.fail('An incomplete deployment request must be rejected.');
      } catch (IllegalArgumentException expected) {
        Assert.isTrue(expected.getMessage().contains('complete deployment request'));
      }

      Id versionId = RHCBuilderTestDataFactory.createValidatedVersion();
      Record_Health_Check_Set_Deployment__c operation = new Record_Health_Check_Set_Deployment__c(
        CheckSetVersion__c = versionId,
        OperationToken__c = 'queueable-test',
        OperationKind__c = 'PUBLISH_INACTIVE',
        Status__c = 'DEPLOYING',
        RequestedFingerprint__c = 'abc',
        RequestedAt__c = System.now()
      );
      insert operation;
      Test.startTest();
      Id jobId = RHCBuilderMetadataService.schedule(
        operation.Id,
        RHCBuilderTestDataFactory.deploymentPlan()
      );
      Test.stopTest();
      Assert.isNotNull(jobId, 'The queueable job identifier must be returned.');
    }
  }

  @IsTest
  static void shouldRecordMetadataRequestIdInCallbackCompletion() {
    System.runAs(currentUser()) {
      Id versionId = RHCBuilderTestDataFactory.createValidatedVersion();
      Record_Health_Check_Set_Deployment__c operation = operation(
        versionId,
        'request-id-test',
        'PUBLISH_INACTIVE'
      );
      insert operation;
      String requestId = String.valueOf(operation.Id);

      Test.startTest();
      RHCBuilderMetadataService.complete(
        operation.Id,
        false,
        'Rejected.',
        requestId
      );
      Test.stopTest();

      Assert.areEqual(
        requestId,
        [SELECT MetadataRequestId__c FROM Record_Health_Check_Set_Deployment__c WHERE Id = :operation.Id]
          .MetadataRequestId__c,
        'The Metadata API request must remain observable without mixed DML.'
      );
    }
  }

  @IsTest
  static void shouldListBoundedComponentFailuresInFailureSummary() {
    Metadata.DeployResult result = new Metadata.DeployResult();
    result.details = new Metadata.DeployDetails();
    result.details.componentFailures = new List<Metadata.DeployMessage>();
    for (Integer index = 0; index < 12; index++) {
      Metadata.DeployMessage failure = new Metadata.DeployMessage();
      failure.fullName = 'Record_Health_Check.Check_' + index;
      failure.problem = 'Field Bad__c does not exist';
      result.details.componentFailures.add(failure);
    }

    String summary = RHCBuilderMetadataService.failureSummary(result);

    Assert.isTrue(
      summary.contains('Record_Health_Check.Check_0: Field Bad__c does not exist'),
      'The first rejected component and its problem must be listed.'
    );
    Assert.isTrue(summary.contains('Check_9'), 'Ten failures are listed.');
    Assert.isFalse(summary.contains('Check_10'), 'The eleventh failure is omitted.');
    Assert.isTrue(summary.contains('...and 2 more.'), 'Omitted failures are counted.');
    Assert.areEqual(
      'Salesforce rejected the metadata publication. Review Deployment Status before retrying.',
      RHCBuilderMetadataService.failureSummary(null),
      'A result without details keeps the fixed sentence only.'
    );
  }

  @IsTest
  static void shouldActivateSelectedVersionWhenActivationPublicationSucceeds() {
    System.runAs(currentUser()) {
      Id versionId = RHCBuilderTestDataFactory.createValidatedVersion();
      Record_Health_Check_Set_Deployment__c operation = new Record_Health_Check_Set_Deployment__c(
        CheckSetVersion__c = versionId,
        OperationToken__c = 'activate-complete',
        OperationKind__c = 'ACTIVATE_VERSION',
        Status__c = 'DEPLOYING',
        RequestedFingerprint__c = 'abc',
        RequestedAt__c = System.now()
      );
      insert operation;

      Test.startTest();
      RHCBuilderMetadataService.complete(operation.Id, true, 'Published.');
      Test.stopTest();

      Record_Health_Check_Set_Version__c version = [
        SELECT Status__c, IsActive__c, DeployedAt__c
        FROM Record_Health_Check_Set_Version__c
        WHERE Id = :versionId
      ];
      Assert.areEqual(
        'DEPLOYED',
        version.Status__c,
        'Successful publication should mark the version deployed.'
      );
      Assert.areEqual(
        true,
        version.IsActive__c,
        'Activation should apply to the complete selected version.'
      );
      Assert.isNotNull(
        version.DeployedAt__c,
        'Publication completion time should be recorded.'
      );
    }
  }

  @IsTest
  static void shouldPreserveSelectedVersionWhenPublicationFails() {
    System.runAs(currentUser()) {
      Id versionId = RHCBuilderTestDataFactory.createValidatedVersion();
      Datetime originalDeploymentTime = System.now().addDays(-1);
      update new Record_Health_Check_Set_Version__c(
        Id = versionId,
        Status__c = 'DEPLOYED',
        IsActive__c = true,
        DeployedAt__c = originalDeploymentTime
      );
      originalDeploymentTime = [
        SELECT DeployedAt__c
        FROM Record_Health_Check_Set_Version__c
        WHERE Id = :versionId
      ].DeployedAt__c;
      Record_Health_Check_Set_Deployment__c operation = new Record_Health_Check_Set_Deployment__c(
        CheckSetVersion__c = versionId,
        OperationToken__c = 'failed-publication',
        OperationKind__c = 'ACTIVATE_VERSION',
        Status__c = 'DEPLOYING',
        RequestedFingerprint__c = 'abc',
        RequestedAt__c = System.now()
      );
      insert operation;

      Test.startTest();
      RHCBuilderMetadataService.complete(
        operation.Id,
        false,
        'Publication failed.'
      );
      Test.stopTest();

      Record_Health_Check_Set_Version__c version = [
        SELECT Status__c, IsActive__c, DeployedAt__c
        FROM Record_Health_Check_Set_Version__c
        WHERE Id = :versionId
      ];
      Assert.areEqual(
        'DEPLOYED',
        version.Status__c,
        'A failed publication must not rewrite the selected version status.'
      );
      Assert.areEqual(
        true,
        version.IsActive__c,
        'A failed publication must not deactivate the selected version.'
      );
      Assert.areEqual(
        originalDeploymentTime,
        version.DeployedAt__c,
        'A failed publication must not erase the prior deployment timestamp.'
      );
      Record_Health_Check_Set_Deployment__c completedOperation = [
        SELECT Status__c, CompletedAt__c, ResultSummary__c
        FROM Record_Health_Check_Set_Deployment__c
        WHERE Id = :operation.Id
      ];
      Assert.areEqual(
        'FAILED',
        completedOperation.Status__c,
        'The operation ledger should still record the failure.'
      );
      Assert.isNotNull(
        completedOperation.CompletedAt__c,
        'The failed operation should record its completion time.'
      );
    }
  }

  @IsTest
  static void shouldDeployInactiveWithoutSupersedingAndDeactivatePriorOnRollback() {
    System.runAs(currentUser()) {
      Id selectedId = RHCBuilderTestDataFactory.createValidatedVersion();
      Record_Health_Check_Set_Version__c selected = [
        SELECT CheckSetDraft__c FROM Record_Health_Check_Set_Version__c WHERE Id = :selectedId
      ];
      Record_Health_Check_Set_Version__c prior = new Record_Health_Check_Set_Version__c(
        CheckSetDraft__c = selected.CheckSetDraft__c,
        VersionNumber__c = 2,
        Status__c = 'DEPLOYED',
        Label__c = 'Prior active',
        SnapshotJson__c = RHCBuilderTestDataFactory.validCanonicalVersion(),
        Fingerprint__c = 'prior',
        IsActive__c = true
      );
      insert prior;

      Record_Health_Check_Set_Deployment__c inactive = operation(selectedId, 'inactive-complete', 'PUBLISH_INACTIVE');
      insert inactive;
      RHCBuilderMetadataService.complete(inactive.Id, true, 'Published inactive.');
      Assert.areEqual(true, [SELECT IsActive__c FROM Record_Health_Check_Set_Version__c WHERE Id = :prior.Id].IsActive__c);

      Record_Health_Check_Set_Deployment__c rollbackOperation = operation(
        selectedId,
        'rollback-complete',
        'ROLLBACK_VERSION'
      );
      insert rollbackOperation;
      RHCBuilderMetadataService.complete(rollbackOperation.Id, true, 'Rolled back.');
      Map<Id, Record_Health_Check_Set_Version__c> versions = new Map<Id, Record_Health_Check_Set_Version__c>([
        SELECT Id, Status__c, IsActive__c FROM Record_Health_Check_Set_Version__c
        WHERE Id IN :new Set<Id>{ selectedId, prior.Id }
      ]);
      Assert.areEqual(true, versions.get(selectedId).IsActive__c, 'Rollback must activate the selected version.');
      Assert.areEqual(false, versions.get(prior.Id).IsActive__c, 'Rollback must deactivate the prior version.');
      Assert.areEqual('SUPERSEDED', versions.get(prior.Id).Status__c, 'The prior version must be superseded.');
    }
  }

  private static Record_Health_Check_Set_Deployment__c operation(
    Id versionId,
    String token,
    String kind
  ) {
    return new Record_Health_Check_Set_Deployment__c(
      CheckSetVersion__c = versionId,
      OperationToken__c = token,
      OperationKind__c = kind,
      Status__c = 'DEPLOYING',
      RequestedFingerprint__c = 'abc',
      RequestedAt__c = System.now()
    );
  }

  private static User currentUser() {
    return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
  }
}
