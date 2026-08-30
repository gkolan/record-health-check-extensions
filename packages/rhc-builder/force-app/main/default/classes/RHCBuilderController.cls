/** LWC boundary for complete, immutable Record Health Check Set Versions. */
@SuppressWarnings('PMD.CyclomaticComplexity')
// The aggregate reflects independent Aura endpoints; no individual method exceeds complexity 6.
public with sharing class RHCBuilderController {
  private static final String AUTHOR_PERMISSION = 'RHC_Builder_Author';
  private static final Integer MAX_OPERATION_TOKEN_LENGTH = 80;
  @TestVisible
  private static Boolean testAuthorAccess = false;

  private class OperationExpectation {
    String kind;
    Id versionId;
    String fingerprint;

    OperationExpectation(String kind, Id versionId, String fingerprint) {
      this.kind = kind;
      this.versionId = versionId;
      this.fingerprint = fingerprint;
    }
  }

  /**
   * Returns the choices and limits supported by this Builder version.
   * @return Allowed authoring values and validation limits.
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getAuthoringContract() {
    requireAuthor();
    return parseObject(
      RHCBuilderContractGateway.describeContract(),
      'authoring contract'
    );
  }

  /**
   * Returns the Builder landing-page state.
   * @return Saved complete versions and recent version-level operations.
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getBuilderHome() {
    requireAuthor();
    List<Object> versions = new List<Object>();
    for (Record_Health_Check_Set_Version__c version : [
      SELECT
        Id,
        CheckSetDraft__r.Name,
        CheckSetDraft__r.DeveloperName__c,
        CheckSetDraft__r.ObjectApiName__c,
        VersionNumber__c,
        Status__c,
        Fingerprint__c,
        ValidatedAt__c,
        DeployedAt__c,
        IsActive__c,
        (SELECT Id FROM Checks__r)
      FROM Record_Health_Check_Set_Version__c
      WITH USER_MODE
      ORDER BY LastModifiedDate DESC
      LIMIT 100
    ]) {
      versions.add(
        new Map<String, Object>{
          'versionId' => version.Id,
          'label' => version.CheckSetDraft__r.Name,
          'checkSetQualifiedApiName' => version.CheckSetDraft__r.DeveloperName__c,
          'objectApiName' => version.CheckSetDraft__r.ObjectApiName__c,
          'versionNumber' => version.VersionNumber__c,
          'status' => version.Status__c,
          'fingerprint' => version.Fingerprint__c,
          'validatedAt' => version.ValidatedAt__c,
          'deployedAt' => version.DeployedAt__c,
          'isActive' => version.IsActive__c,
          'checkCount' => version.Checks__r.size()
        }
      );
    }
    List<Object> operations = new List<Object>();
    String recentOperationsQuery =
      deploymentSelectClause() + ' ORDER BY CreatedDate DESC LIMIT 20';
    for (
      Record_Health_Check_Set_Deployment__c operation : Database.query(
        recentOperationsQuery,
        AccessLevel.USER_MODE
      )
    ) {
      operations.add(toOperation(operation));
    }
    return new Map<String, Object>{
      'versions' => versions,
      'recentOperations' => operations
    };
  }

  /**
   * Returns one saved immutable Check Set Version.
   * @param checkSetVersionId Builder version record identifier.
   * @return Exact immutable canonical JSON and version state.
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getCheckSetVersion(Id checkSetVersionId) {
    requireAuthor();
    Record_Health_Check_Set_Version__c version = [
      SELECT
        Id,
        VersionNumber__c,
        Status__c,
        Fingerprint__c,
        SnapshotJson__c,
        ContractVersion__c
      FROM Record_Health_Check_Set_Version__c
      WHERE Id = :checkSetVersionId
      WITH USER_MODE
      LIMIT 1
    ];
    return new Map<String, Object>{
      'versionId' => version.Id,
      'versionNumber' => version.VersionNumber__c,
      'status' => version.Status__c,
      'fingerprint' => version.Fingerprint__c,
      'contractVersion' => version.ContractVersion__c,
      'version' => JSON.deserializeUntyped(version.SnapshotJson__c)
    };
  }

  /**
   * Validates a complete version without changing records.
   * @param canonicalVersionJson Candidate canonical Check Set Version JSON.
   * @return Builder validation result.
   */
  @AuraEnabled
  public static Map<String, Object> validateCheckSetVersion(
    String canonicalVersionJson
  ) {
    requireAuthor();
    String canonical = RHCBuilderFieldMapping.canonicalize(
      canonicalVersionJson
    );
    return parseValidation(
      RHCBuilderContractGateway.validateVersion(canonical)
    );
  }

  /**
   * Saves one validated immutable version and all Check child snapshots exactly once.
   * @param canonicalVersionJson Candidate canonical Check Set Version JSON.
   * @param idempotencyKey Unique retry-safe operation token.
   * @return Terminal idempotent save operation.
   */
  @AuraEnabled
  public static Map<String, Object> saveCheckSetVersion(
    String canonicalVersionJson,
    String idempotencyKey
  ) {
    requireAuthor();
    validateIdempotencyKey(idempotencyKey);
    String canonical = RHCBuilderFieldMapping.canonicalize(
      canonicalVersionJson
    );
    String fingerprint = fingerprint(canonical);
    Record_Health_Check_Set_Deployment__c existing = findOperation(
      idempotencyKey
    );
    if (existing != null) {
      requireMatchingOperation(
        existing,
        new OperationExpectation('SAVE_VERSION', null, fingerprint)
      );
      return toOperation(existing);
    }

    Map<String, Object> validation = parseValidation(
      RHCBuilderContractGateway.validateVersion(canonical)
    );
    if (validation.get('isValid') != true) {
      throw userError(
        'Resolve the Builder validation errors before saving this Check Set Version.'
      );
    }
    Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
      canonical
    );
    Map<String, Object> checkSet = (Map<String, Object>) envelope.get(
      'checkSet'
    );
    Map<String, Object> checkSetValues = (Map<String, Object>) checkSet.get(
      'values'
    );
    Record_Health_Check_Set_Draft__c setDraft = lockOrCreateSetDraft(
      checkSet,
      checkSetValues
    );
    Decimal versionNumber = nextVersionNumber(setDraft.Id);
    Record_Health_Check_Set_Version__c version = new Record_Health_Check_Set_Version__c(
      CheckSetDraft__c = setDraft.Id,
      VersionNumber__c = versionNumber,
      Status__c = 'VALIDATED',
      Label__c = (String) checkSet.get('label'),
      Description__c = (String) checkSetValues.get('CardSubtitle__c'),
      RunMode__c = (String) checkSetValues.get('CardRunMode__c'),
      IsActive__c = false,
      SnapshotJson__c = canonical,
      Fingerprint__c = fingerprint,
      ContractVersion__c = String.valueOf(
        envelope.get('contractVersion')
      ),
      ValidatedAt__c = System.now()
    );
    Database.insert(version, AccessLevel.SYSTEM_MODE);

    List<Record_Health_Check_Draft__c> checksToInsert = new List<Record_Health_Check_Draft__c>();
    for (Object rawCheck : (List<Object>) envelope.get('checks')) {
      Map<String, Object> check = (Map<String, Object>) rawCheck;
      Map<String, Object> values = (Map<String, Object>) check.get('values');
      checksToInsert.add(
        new Record_Health_Check_Draft__c(
          CheckSetVersion__c = version.Id,
          DeveloperName__c = (String) check.get('qualifiedApiName'),
          Label__c = (String) check.get('label'),
          EvaluationOrder__c = decimalValue(values.get('EvaluationOrder__c')),
          EvaluationType__c = (String) values.get('EvaluationType__c'),
          Severity__c = (String) values.get('FailureSeverity__c'),
          SnapshotJson__c = JSON.serialize(values)
        )
      );
    }
    Database.insert(checksToInsert, AccessLevel.SYSTEM_MODE);

    Record_Health_Check_Set_Deployment__c operation = new Record_Health_Check_Set_Deployment__c(
      CheckSetVersion__c = version.Id,
      OperationToken__c = idempotencyKey,
      OperationKind__c = 'SAVE_VERSION',
      Status__c = 'SUCCEEDED',
      RequestedFingerprint__c = fingerprint,
      ValidationReportJson__c = JSON.serialize(validation),
      RequestedAt__c = System.now(),
      CompletedAt__c = System.now(),
      ResultSummary__c = 'Check Set Version ' +
        String.valueOf(versionNumber) +
        ' saved and validated.'
    );
    Database.insert(operation, AccessLevel.SYSTEM_MODE);
    return toOperation(reloadOperation(operation.Id));
  }

  /**
   * Publishes one validated version as inactive core metadata.
   * @param checkSetVersionId Builder version record identifier.
   * @param idempotencyKey Unique retry-safe operation token.
   * @return Version-level publication operation.
   */
  @AuraEnabled
  public static Map<String, Object> publishCheckSetVersion(
    Id checkSetVersionId,
    String idempotencyKey
  ) {
    return beginPublication(
      checkSetVersionId,
      PublicationKind.PUBLISH_INACTIVE,
      idempotencyKey
    );
  }

  /**
   * Publishes and activates one validated complete version.
   * @param checkSetVersionId Builder version record identifier.
   * @param idempotencyKey Unique retry-safe operation token.
   * @return Version-level activation operation.
   */
  @AuraEnabled
  public static Map<String, Object> activateCheckSetVersion(
    Id checkSetVersionId,
    String idempotencyKey
  ) {
    return beginPublication(
      checkSetVersionId,
      PublicationKind.ACTIVATE_VERSION,
      idempotencyKey
    );
  }

  /**
   * Republishes a previously validated complete version as an idempotent rollback.
   * @param checkSetVersionId Builder version record identifier.
   * @param idempotencyKey Unique retry-safe operation token.
   * @return Version-level rollback operation.
   */
  @AuraEnabled
  public static Map<String, Object> rollbackToCheckSetVersion(
    Id checkSetVersionId,
    String idempotencyKey
  ) {
    return beginPublication(
      checkSetVersionId,
      PublicationKind.ROLLBACK_VERSION,
      idempotencyKey
    );
  }

  /**
   * Returns the state of one version-level operation.
   * @param operationToken Idempotent operation token.
   * @return Current operation state, or null when no operation exists.
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getSetDeployment(String operationToken) {
    requireAuthor();
    Record_Health_Check_Set_Deployment__c operation = findOperation(
      operationToken
    );
    return operation == null ? null : toOperation(operation);
  }

  /**
   * Lists accessible and queryable Salesforce objects.
   * @return Object labels and exact API names for the target picker.
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> listReadableObjects() {
    requireAuthor();
    List<Map<String, String>> options = new List<Map<String, String>>();
    for (Schema.SObjectType objectType : Schema.getGlobalDescribe().values()) {
      Schema.DescribeSObjectResult description = objectType.getDescribe();
      if (description.isAccessible() && description.isQueryable()) {
        options.add(
          new Map<String, String>{
            'label' => description.getLabel() +
            ' — ' +
            description.getName(),
            'value' => description.getName()
          }
        );
      }
    }
    return options;
  }

  /**
   * Lists readable fields for a selected target object.
   * @param objectApiName Exact target object API name.
   * @return Field labels, exact API names, and data types.
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> listReadableFields(
    String objectApiName
  ) {
    requireAuthor();
    Schema.SObjectType objectType = Schema.getGlobalDescribe()
      .get(objectApiName);
    if (objectType == null || !objectType.getDescribe().isAccessible()) {
      throw userError('Choose an object you can read.');
    }
    List<Map<String, String>> options = new List<Map<String, String>>();
    for (
      Schema.SObjectField field : objectType.getDescribe()
        .fields.getMap()
        .values()
    ) {
      Schema.DescribeFieldResult description = field.getDescribe();
      if (description.isAccessible()) {
        options.add(
          new Map<String, String>{
            'label' => description.getLabel() +
            ' — ' +
            description.getName(),
            'value' => description.getName(),
            'dataType' => String.valueOf(description.getType())
          }
        );
      }
    }
    return options;
  }

  /**
   * Lists readable child relationships for the guided related-record Query template.
   * @param objectApiName Exact parent object API name.
   * @return Relationship choices with exact child object and parent field API names.
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> listReadableRelationships(
    String objectApiName
  ) {
    requireAuthor();
    Schema.SObjectType objectType = Schema.getGlobalDescribe()
      .get(objectApiName);
    if (objectType == null || !objectType.getDescribe().isAccessible()) {
      throw userError('Choose an object you can read.');
    }
    List<Map<String, String>> options = new List<Map<String, String>>();
    for (
      Schema.ChildRelationship relationship : objectType.getDescribe()
        .getChildRelationships()
    ) {
      if (
        relationship.getRelationshipName() == null ||
        relationship.getField() == null
      ) {
        continue;
      }
      Schema.DescribeSObjectResult childDescription = relationship.getChildSObject()
        .getDescribe();
      Schema.DescribeFieldResult parentField = relationship.getField()
        .getDescribe();
      if (
        !childDescription.isAccessible() ||
        !childDescription.isQueryable() ||
        !parentField.isAccessible()
      ) {
        continue;
      }
      options.add(
        new Map<String, String>{
          'label' => childDescription.getLabelPlural() +
          ' — ' +
          relationship.getRelationshipName(),
          'value' => childDescription.getName() +
          '.' +
          parentField.getName(),
          'childObjectApiName' => childDescription.getName(),
          'parentFieldApiName' => parentField.getName()
        }
      );
    }
    return options;
  }

  private static Map<String, Object> beginPublication(
    Id versionId,
    PublicationKind publicationKind,
    String idempotencyKey
  ) {
    requireAuthor();
    validateIdempotencyKey(idempotencyKey);
    Record_Health_Check_Set_Version__c version = [
      SELECT
        Id,
        CheckSetDraft__c,
        Status__c,
        Fingerprint__c,
        SnapshotJson__c
      FROM Record_Health_Check_Set_Version__c
      WHERE Id = :versionId
      WITH USER_MODE
      LIMIT 1
    ];
    Record_Health_Check_Set_Deployment__c existing = findOperation(
      idempotencyKey
    );
    if (existing != null) {
      requireMatchingOperation(
        existing,
        new OperationExpectation(
          String.valueOf(publicationKind),
          version.Id,
          version.Fingerprint__c
        )
      );
      return toOperation(existing);
    }
    Set<String> publishableStatuses = new Set<String>{
      'VALIDATED',
      'DEPLOYED',
      'SUPERSEDED'
    };
    if (!publishableStatuses.contains(version.Status__c)) {
      throw userError(
        'Only a previously validated complete Check Set Version can be published.'
      );
    }
    Map<String, Object> validation = parseValidation(
      RHCBuilderContractGateway.validateVersion(
        version.SnapshotJson__c
      )
    );
    if (validation.get('isValid') != true) {
      throw userError(
        'Builder validation changed. Resolve the errors before publication.'
      );
    }
    String deploymentPlan = RHCBuilderContractGateway.buildDeploymentPlan(
      version.SnapshotJson__c,
      String.valueOf(publicationKind) == 'PUBLISH_INACTIVE'
        ? RHCBuilderContractGateway.PublicationMode.INACTIVE
        : RHCBuilderContractGateway.PublicationMode.ACTIVATE_NOW,
      priorActiveVersionJson(version)
    );
    Record_Health_Check_Set_Deployment__c operation = new Record_Health_Check_Set_Deployment__c(
      CheckSetVersion__c = version.Id,
      OperationToken__c = idempotencyKey,
      OperationKind__c = String.valueOf(publicationKind),
      Status__c = 'DEPLOYING',
      RequestedFingerprint__c = version.Fingerprint__c,
      ValidationReportJson__c = JSON.serialize(validation),
      RequestedAt__c = System.now(),
      ResultSummary__c = 'Salesforce accepted the complete Check Set Version for publication.'
    );
    Database.insert(operation, AccessLevel.SYSTEM_MODE);
    RHCBuilderMetadataService.schedule(operation.Id, deploymentPlan);
    return toOperation(reloadOperation(operation.Id));
  }

  private static String priorActiveVersionJson(
    Record_Health_Check_Set_Version__c targetVersion
  ) {
    List<Record_Health_Check_Set_Version__c> activeVersions = [
      SELECT SnapshotJson__c
      FROM Record_Health_Check_Set_Version__c
      WHERE
        CheckSetDraft__c = :targetVersion.CheckSetDraft__c
        AND IsActive__c = TRUE
        AND Id != :targetVersion.Id
      WITH USER_MODE
      ORDER BY DeployedAt__c DESC NULLS LAST, LastModifiedDate DESC
      LIMIT 1
    ];
    return activeVersions.isEmpty()
      ? null
      : activeVersions[0].SnapshotJson__c;
  }

  private static Record_Health_Check_Set_Draft__c lockOrCreateSetDraft(
    Map<String, Object> checkSet,
    Map<String, Object> checkSetValues
  ) {
    String qualifiedApiName = (String) checkSet.get('qualifiedApiName');
    List<Record_Health_Check_Set_Draft__c> existing = [
      SELECT Id
      FROM Record_Health_Check_Set_Draft__c
      WHERE DeveloperName__c = :qualifiedApiName
      WITH USER_MODE
      LIMIT 1
      FOR UPDATE
    ];
    if (!existing.isEmpty()) {
      return existing[0];
    }
    Record_Health_Check_Set_Draft__c draft = new Record_Health_Check_Set_Draft__c(
      Name = (String) checkSet.get('label'),
      DeveloperName__c = qualifiedApiName,
      ObjectApiName__c = (String) checkSetValues.get('ObjectApiName__c'),
      Description__c = (String) checkSetValues.get('CardSubtitle__c'),
      Status__c = 'DRAFT'
    );
    Database.insert(draft, AccessLevel.SYSTEM_MODE);
    return draft;
  }

  private static Decimal nextVersionNumber(Id setDraftId) {
    List<Record_Health_Check_Set_Version__c> versions = [
      SELECT VersionNumber__c
      FROM Record_Health_Check_Set_Version__c
      WHERE CheckSetDraft__c = :setDraftId
      WITH USER_MODE
      ORDER BY VersionNumber__c DESC
      LIMIT 1
    ];
    return versions.isEmpty() ? 1 : versions[0].VersionNumber__c + 1;
  }

  private static Decimal decimalValue(Object value) {
    return value == null ? null : Decimal.valueOf(String.valueOf(value));
  }

  private static String fingerprint(String canonicalVersionJson) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalVersionJson))
    );
  }

  private static void requireMatchingOperation(
    Record_Health_Check_Set_Deployment__c existing,
    OperationExpectation expected
  ) {
    if (
      existing.OperationKind__c != expected.kind ||
      (expected.versionId != null &&
      existing.CheckSetVersion__c != expected.versionId) ||
      existing.RequestedFingerprint__c != expected.fingerprint
    ) {
      throw userError(
        'This idempotency key is already associated with a different Builder request.'
      );
    }
  }

  private static Map<String, Object> parseValidation(String jsonValue) {
    Map<String, Object> validation = parseObject(
      jsonValue,
      'validation response'
    );
    if (
      !(validation.get('isValid') instanceof Boolean) ||
      !(validation.get('issues') instanceof List<Object>)
    ) {
      throw userError(
        'The installed Record Health Check package returned an invalid validation response.'
      );
    }
    return validation;
  }

  private static Map<String, Object> parseObject(String value, String label) {
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(value);
    } catch (Exception error) {
      throw userError('Salesforce could not read the Builder ' + label + '.');
    }
  }

  private static Record_Health_Check_Set_Deployment__c findOperation(
    String token
  ) {
    if (String.isBlank(token)) {
      return null;
    }
    String queryText =
      deploymentSelectClause() +
      ' WHERE ' +
      qualifiedField(Record_Health_Check_Set_Deployment__c.OperationToken__c) +
      ' = :token LIMIT 1';
    List<Record_Health_Check_Set_Deployment__c> operations = Database.queryWithBinds(
      queryText,
      new Map<String, Object>{ 'token' => token },
      AccessLevel.USER_MODE
    );
    return operations.isEmpty() ? null : operations[0];
  }

  private static Record_Health_Check_Set_Deployment__c reloadOperation(
    Id operationId
  ) {
    String queryText = deploymentSelectClause() + ' WHERE Id = :operationId';
    List<Record_Health_Check_Set_Deployment__c> operations = Database.queryWithBinds(
      queryText,
      new Map<String, Object>{ 'operationId' => operationId },
      AccessLevel.USER_MODE
    );
    return operations[0];
  }

  /**
   * Uses the names Salesforce assigned in this org. This matters when the core
   * and Builder packages share a namespace but own different fields.
   * @return A package-safe SELECT clause for deployment records.
   */
  private static String deploymentSelectClause() {
    String versionRelationship = Record_Health_Check_Set_Deployment__c.CheckSetVersion__c.getDescribe()
      .getRelationshipName();
    String draftRelationship = Record_Health_Check_Set_Version__c.CheckSetDraft__c.getDescribe()
      .getRelationshipName();
    String qualifiedName = qualifiedField(
      Record_Health_Check_Set_Draft__c.DeveloperName__c
    );
    return 'SELECT Id, ' +
      qualifiedField(Record_Health_Check_Set_Deployment__c.OperationToken__c) +
      ', ' +
      qualifiedField(Record_Health_Check_Set_Deployment__c.OperationKind__c) +
      ', ' +
      qualifiedField(Record_Health_Check_Set_Deployment__c.Status__c) +
      ', ' +
      qualifiedField(
        Record_Health_Check_Set_Deployment__c.RequestedFingerprint__c
      ) +
      ', ' +
      qualifiedField(
        Record_Health_Check_Set_Deployment__c.MetadataRequestId__c
      ) +
      ', ' +
      qualifiedField(
        Record_Health_Check_Set_Deployment__c.CheckSetVersion__c
      ) +
      ', ' +
      versionRelationship +
      '.' +
      draftRelationship +
      '.' +
      qualifiedName +
      ', ' +
      qualifiedField(Record_Health_Check_Set_Deployment__c.ResultSummary__c) +
      ', ' +
      qualifiedField(Record_Health_Check_Set_Deployment__c.RequestedAt__c) +
      ', ' +
      qualifiedField(Record_Health_Check_Set_Deployment__c.CompletedAt__c) +
      ' FROM ' +
      Record_Health_Check_Set_Deployment__c.SObjectType.getDescribe(
          SObjectDescribeOptions.DEFERRED
        )
        .getName();
  }

  private static String qualifiedField(Schema.SObjectField field) {
    return field.getDescribe().getName();
  }

  private static Map<String, Object> toOperation(
    Record_Health_Check_Set_Deployment__c operation
  ) {
    return new Map<String, Object>{
      'operationToken' => operation.OperationToken__c,
      'operationKind' => operation.OperationKind__c,
      'status' => operation.Status__c,
      'requestedFingerprint' => operation.RequestedFingerprint__c,
      'metadataRequestId' => operation.MetadataRequestId__c,
      'checkSetVersionId' => operation.CheckSetVersion__c,
      'checkSetQualifiedApiName' => operation.CheckSetVersion__r
        ?.CheckSetDraft__r
        ?.DeveloperName__c,
      'resultSummary' => operation.ResultSummary__c,
      'requestedAt' => operation.RequestedAt__c,
      'completedAt' => operation.CompletedAt__c
    };
  }

  private static void validateIdempotencyKey(String key) {
    if (String.isBlank(key) || key.length() > MAX_OPERATION_TOKEN_LENGTH) {
      throw userError(
        'Provide a fresh idempotency key of 80 characters or fewer.'
      );
    }
  }

  private static void requireAuthor() {
    if (Test.isRunningTest() && testAuthorAccess) {
      return;
    }
    if (!FeatureManagement.checkPermission(AUTHOR_PERMISSION)) {
      throw userError(
        'Record Health Check Builder authoring access is required.'
      );
    }
  }

  private static AuraHandledException userError(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }

  private enum PublicationKind {
    PUBLISH_INACTIVE,
    ACTIVATE_VERSION,
    ROLLBACK_VERSION
  }
}
