/**
 * Executes a Builder-approved Metadata API plan and updates the Builder publication history.
 * Elevated access is isolated here; callers must pass the with-sharing controller permission check.
 */
public without sharing class RHCBuilderMetadataService {
  private static final Integer MAX_REPORTED_FAILURES = 10;
  private static final Integer MAX_FAILURE_LENGTH = 255;

  /**
   * Schedules one complete Check Set Version publication.
   * @param deploymentId Package-owned deployment ledger identifier.
   * @param deploymentPlanJson Exact publication plan approved by Builder.
   * @return Queueable job identifier.
   */
  public static Id schedule(Id deploymentId, String deploymentPlanJson) {
    if (deploymentId == null || String.isBlank(deploymentPlanJson)) {
      throw new IllegalArgumentException(
        'A complete deployment request is required.'
      );
    }
    return System.enqueueJob(
      new DeploymentJob(deploymentId, deploymentPlanJson)
    );
  }

  private class DeploymentJob implements Queueable, Finalizer {
    private Id deploymentId;
    private String deploymentPlanJson;

    DeploymentJob(Id deploymentId, String deploymentPlanJson) {
      this.deploymentId = deploymentId;
      this.deploymentPlanJson = deploymentPlanJson;
    }

    /**
     * Enqueues the trusted Metadata API plan.
     * @param context Queueable execution context.
     */
    public void execute(QueueableContext context) {
      System.attachFinalizer(this);
      Metadata.DeployContainer container = buildContainer(deploymentPlanJson);
      if (Test.isRunningTest()) {
        return;
      }
      Metadata.Operations.enqueueDeployment(
        container,
        new DeploymentCallback(deploymentId)
      );
    }

    /**
     * Records an enqueue failure that bypassed the metadata callback.
     * @param context Queueable finalizer context.
     */
    public void execute(FinalizerContext context) {
      if (context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
        complete(
          deploymentId,
          false,
          'Salesforce could not enqueue the metadata publication. Review Apex Jobs before retrying.'
        );
      }
    }
  }

  private class DeploymentCallback implements Metadata.DeployCallback {
    private Id deploymentId;

    DeploymentCallback(Id deploymentId) {
      this.deploymentId = deploymentId;
    }

    /**
     * Finalizes Builder state after Salesforce completes metadata deployment.
     * @param result Metadata deployment result.
     * @param context Metadata deployment callback context.
     */
    public void handleResult(
      Metadata.DeployResult result,
      Metadata.DeployCallbackContext context
    ) {
      Boolean succeeded =
        result != null &&
        result.status == Metadata.DeployStatus.Succeeded;
      complete(
        deploymentId,
        succeeded,
        succeeded
          ? 'The complete Check Set Version was published successfully.'
          : failureSummary(result),
        result == null ? null : String.valueOf(result.id)
      );
    }
  }

  /**
   * Builds the administrator-facing failure text: a fixed sentence plus a bounded list of the
   * rejected components so the cause is visible without opening Setup > Deployment Status.
   * @param result Metadata deployment result, possibly null or without details.
   * @return Sanitized summary containing component names and Salesforce problem text only.
   */
  @TestVisible
  private static String failureSummary(Metadata.DeployResult result) {
    String summary = 'Salesforce rejected the metadata publication. Review Deployment Status before retrying.';
    List<Metadata.DeployMessage> failures = result == null || result.details == null
      ? null
      : result.details.componentFailures;
    if (failures == null || failures.isEmpty()) {
      return summary;
    }
    List<String> lines = new List<String>();
    for (Metadata.DeployMessage failure : failures) {
      if (lines.size() == MAX_REPORTED_FAILURES) {
        break;
      }
      lines.add(
        (String.isBlank(failure.fullName) ? '(component)' : failure.fullName) +
        ': ' +
        String.valueOf(failure.problem).abbreviate(MAX_FAILURE_LENGTH)
      );
    }
    if (failures.size() > MAX_REPORTED_FAILURES) {
      lines.add('...and ' + (failures.size() - MAX_REPORTED_FAILURES) + ' more.');
    }
    return summary + '\n' + String.join(lines, '\n');
  }

  @TestVisible
  @SuppressWarnings('PMD.ApexCRUDViolation')
  // Salesforce invokes this package-owned callback asynchronously; it must finalize only
  // the addressed deployment ledger and version even if the initiating user's access changes.
  private static void complete(
    Id deploymentId,
    Boolean succeeded,
    String summary
  ) {
    complete(deploymentId, succeeded, summary, null);
  }

  @TestVisible
  @SuppressWarnings('PMD.ApexCRUDViolation,PMD.ExcessiveParameterList')
  // Callback completion is an atomic four-value boundary: ledger, outcome, user-safe summary,
  // and the Salesforce deployment identifier. A wrapper would only hide those required values.
  private static void complete(
    Id deploymentId,
    Boolean succeeded,
    String summary,
    String metadataRequestId
  ) {
    Record_Health_Check_Set_Deployment__c ledger = [
      SELECT
        Id,
        CheckSetVersion__c,
        OperationKind__c,
        CheckSetVersion__r.CheckSetDraft__c
      FROM Record_Health_Check_Set_Deployment__c
      WHERE Id = :deploymentId
      LIMIT 1
    ];
    ledger.Status__c = succeeded ? 'SUCCEEDED' : 'FAILED';
    ledger.CompletedAt__c = System.now();
    ledger.ResultSummary__c = summary;
    if (String.isNotBlank(metadataRequestId)) {
      ledger.MetadataRequestId__c = metadataRequestId;
    }
    Database.update(ledger, AccessLevel.SYSTEM_MODE);

    if (!succeeded) {
      return;
    }

    Boolean activates =
      ledger.OperationKind__c == 'ACTIVATE_VERSION' ||
      ledger.OperationKind__c == 'ROLLBACK_VERSION';
    Record_Health_Check_Set_Version__c selected = new Record_Health_Check_Set_Version__c(
      Id = ledger.CheckSetVersion__c,
      Status__c = 'DEPLOYED',
      IsActive__c = activates,
      DeployedAt__c = System.now()
    );
    Database.update(selected, AccessLevel.SYSTEM_MODE);

    if (activates) {
      List<Record_Health_Check_Set_Version__c> priorActiveVersions = [
        SELECT Id
        FROM Record_Health_Check_Set_Version__c
        WHERE
          CheckSetDraft__c = :ledger.CheckSetVersion__r.CheckSetDraft__c
          AND IsActive__c = TRUE
          AND Id != :ledger.CheckSetVersion__c
      ];
      for (Record_Health_Check_Set_Version__c prior : priorActiveVersions) {
        prior.IsActive__c = false;
        prior.Status__c = 'SUPERSEDED';
      }
      Database.update(priorActiveVersions, AccessLevel.SYSTEM_MODE);
    }
  }

  /**
   * Builds only the exact components and values approved by the Builder contract.
   * @param deploymentPlanJson Builder-owned publication-plan JSON.
   * @return Native Metadata API container.
   */
  @TestVisible
  private static Metadata.DeployContainer buildContainer(
    String deploymentPlanJson
  ) {
    List<Object> components = parseComponents(deploymentPlanJson);
    Metadata.DeployContainer container = new Metadata.DeployContainer();
    for (Object rawComponent : components) {
      container.addMetadata(buildComponent(rawComponent));
    }
    return container;
  }

  private static List<Object> parseComponents(String deploymentPlanJson) {
    Map<String, Object> plan;
    try {
      plan = (Map<String, Object>) JSON.deserializeUntyped(deploymentPlanJson);
    } catch (Exception error) {
      throw new DeploymentPlanException(
        'The Builder publication plan is malformed.',
        error
      );
    }
    List<Object> components = plan.get('components') instanceof List<Object>
      ? (List<Object>) plan.get('components')
      : null;
    if (components == null || components.isEmpty()) {
      throw new DeploymentPlanException(
        'The Builder publication plan has no components.'
      );
    }
    return components;
  }

  private static Metadata.CustomMetadata buildComponent(Object rawComponent) {
    if (!(rawComponent instanceof Map<String, Object>)) {
      throw new DeploymentPlanException(
        'The Builder publication plan contains an invalid component.'
      );
    }
    Map<String, Object> componentPlan = (Map<String, Object>) rawComponent;
    String fullName = (String) componentPlan.get('fullName');
    String label = (String) componentPlan.get('label');
    Map<String, Object> values = componentPlan.get(
        'values'
      ) instanceof Map<String, Object>
      ? (Map<String, Object>) componentPlan.get('values')
      : null;
    if (String.isBlank(fullName) || String.isBlank(label) || values == null) {
      throw new DeploymentPlanException(
        'The Builder publication plan contains an incomplete component.'
      );
    }
    Metadata.CustomMetadata metadataComponent = new Metadata.CustomMetadata();
    metadataComponent.fullName = fullName;
    metadataComponent.label = label;
    appendValues(metadataComponent, values);
    return metadataComponent;
  }

  private static void appendValues(
    Metadata.CustomMetadata metadataComponent,
    Map<String, Object> values
  ) {
    for (String fieldName : values.keySet()) {
      Metadata.CustomMetadataValue metadataValue = new Metadata.CustomMetadataValue();
      metadataValue.field = fieldName;
      metadataValue.value = values.get(fieldName);
      metadataComponent.values.add(metadataValue);
    }
  }

  /** Invalid Builder publication-plan failure. */
  public class DeploymentPlanException extends Exception {
  }
}
