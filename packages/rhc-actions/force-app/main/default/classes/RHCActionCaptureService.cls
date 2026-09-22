/**
 * Converts finalized core Result events into idempotent pending actions.
 */
// Individual methods remain below PMD complexity thresholds; the aggregate
// class score reflects the deliberately cohesive capture lifecycle.
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public with sharing class RHCActionCaptureService {
  @TestVisible
  private static Boolean automaticPermissionOverride;
  @TestVisible
  private static Map<String, List<RHC_Action_Policy__c>> policiesByCheck;
  @TestVisible
  private static RHCActionAsyncGateway asyncGateway = new RHCActionAsyncGateway();

  /** Signals a transient subscriber failure that is safe to retry. */
  public class TransientCaptureException extends Exception {
  }

  private class CaptureContext {
    private Map<String, List<RHC_Action_Policy__c>> indexedPolicies;
    private Boolean canRunAutomatically;
    private List<RHC_Pending_Action__c> candidates = new List<RHC_Pending_Action__c>();
    private List<Boolean> automaticByIndex = new List<Boolean>();
  }

  private class SaveClassification {
    private Boolean duplicate = false;
    private Boolean transientFailure = false;
    private Database.Error permanentError;
  }

  /**
   * Maps and inserts one bounded delivery chunk. Duplicate candidate rows are
   * treated as successful idempotent replays.
   *
   * @param events Finalized core result events
   */
  public static void capture(List<Record_Health_Check_Result__e> events) {
    if (events == null || events.isEmpty()) {
      return;
    }
    CaptureContext context = new CaptureContext();
    context.indexedPolicies = getPoliciesByCheck();
    if (context.indexedPolicies.isEmpty()) {
      return;
    }
    context.canRunAutomatically = automaticPermissionOverride == null
      ? FeatureManagement.checkPermission('RHC_Actions_Automatic_Execution')
      : automaticPermissionOverride;
    buildCandidates(events, context);
    if (context.candidates.isEmpty()) {
      return;
    }
    assertDmlCapacity(context.candidates.size());
    assertQueueCapacity(context.automaticByIndex.contains(true));
    Database.SaveResult[] results = Database.insert(
      context.candidates,
      false,
      AccessLevel.USER_MODE
    );
    processSaveResults(context, results);
  }

  private static void buildCandidates(
    List<Record_Health_Check_Result__e> events,
    CaptureContext context
  ) {
    for (Record_Health_Check_Result__e eventRecord : events) {
      if (!isSupported(eventRecord)) {
        continue;
      }
      List<RHC_Action_Policy__c> matchingCheckPolicies = context.indexedPolicies.get(
        eventRecord.CheckQualifiedApiName__c
      );
      if (matchingCheckPolicies == null) {
        continue;
      }
      for (RHC_Action_Policy__c policy : matchingCheckPolicies) {
        if (!matches(policy, eventRecord)) {
          continue;
        }
        Boolean automatic =
          policy.Mode__c == RHCActionConstants.MODE_AUTOMATIC &&
          policy.Auto_Execution_Enabled__c == true &&
          context.canRunAutomatically;
        context.candidates.add(buildPending(policy, eventRecord, automatic));
        context.automaticByIndex.add(automatic);
      }
    }
  }

  private static Map<String, List<RHC_Action_Policy__c>> getPoliciesByCheck() {
    if (policiesByCheck != null) {
      return policiesByCheck;
    }
    policiesByCheck = new Map<String, List<RHC_Action_Policy__c>>();
    for (RHC_Action_Policy__c policy : [
      SELECT
        Id,
        Active__c,
        Check_Set_Qualified_API_Name__c,
        Check_Qualified_API_Name__c,
        Matching_Statuses__c,
        Matching_Severity__c,
        Flow_API_Name__c,
        Mode__c,
        Auto_Execution_Enabled__c,
        Cooldown_Minutes__c,
        Retry_Limit__c,
        Input_Contract_Version__c,
        Map_Record_Id__c,
        Map_Run_Id__c,
        Map_Check_Set__c,
        Map_Check__c,
        Map_Status__c,
        Map_Severity__c,
        Map_Reason_Code__c,
        Map_Event_Id__c
      FROM RHC_Action_Policy__c
      WHERE Active__c = TRUE
      WITH USER_MODE
    ]) {
      String checkName = policy.Check_Qualified_API_Name__c;
      if (!policiesByCheck.containsKey(checkName)) {
        policiesByCheck.put(checkName, new List<RHC_Action_Policy__c>());
      }
      policiesByCheck.get(checkName).add(policy);
    }
    return policiesByCheck;
  }

  @TestVisible
  private static void assertDmlCapacity(Integer candidateCount) {
    Integer remainingRows = Limits.getLimitDmlRows() - Limits.getDmlRows();
    Integer remainingStatements =
      Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    if (candidateCount > remainingRows || remainingStatements < 1) {
      throw new TransientCaptureException(
        'The subscriber reached a safe transaction capacity boundary.'
      );
    }
  }

  private static void assertQueueCapacity(Boolean requiresQueueable) {
    if (
      requiresQueueable &&
      Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()
    ) {
      throw new TransientCaptureException(
        'The subscriber reached a safe asynchronous capacity boundary.'
      );
    }
  }

  private static void processSaveResults(
    CaptureContext context,
    List<Database.SaveResult> results
  ) {
    List<Id> automaticIds = new List<Id>();
    List<RHC_Action_History__c> failureAudits = new List<RHC_Action_History__c>();
    Boolean hasTransientFailure = false;
    for (Integer index = 0; index < results.size(); index++) {
      Database.SaveResult result = results[index];
      if (result.isSuccess()) {
        if (context.automaticByIndex[index]) {
          automaticIds.add(result.getId());
        }
        continue;
      }
      SaveClassification classification = classify(result.getErrors());
      hasTransientFailure =
        hasTransientFailure || classification.transientFailure;
      if (!classification.duplicate && classification.permanentError != null) {
        failureAudits.add(
          captureFailure(
            context.candidates[index],
            classification.permanentError
          )
        );
      }
    }
    if (hasTransientFailure) {
      // Throwing rolls back successful rows in this chunk. Event ID uniqueness
      // makes redelivery safe after subscriber retry or checkpoint resumption.
      throw new TransientCaptureException(
        'A transient RHC Actions capture failure requires redelivery.'
      );
    }
    persistFailureAudits(failureAudits);
    if (!automaticIds.isEmpty()) {
      asyncGateway.enqueue(automaticIds, 0);
    }
  }

  private static SaveClassification classify(List<Database.Error> errors) {
    SaveClassification classification = new SaveClassification();
    for (Database.Error error : errors) {
      StatusCode errorStatus = error.getStatusCode();
      classification.duplicate =
        classification.duplicate || errorStatus == StatusCode.DUPLICATE_VALUE;
      classification.transientFailure =
        classification.transientFailure || isRetryable(errorStatus);
      if (
        errorStatus != StatusCode.DUPLICATE_VALUE &&
        !isRetryable(errorStatus) &&
        classification.permanentError == null
      ) {
        classification.permanentError = error;
      }
    }
    return classification;
  }

  // Audit persistence is deliberately best effort: rolling back successful pending-action
  // capture would make a permanent audit-row defect poison event redelivery. The fixed fallback
  // message contains no record, event, exception, or user-controlled detail.
  @SuppressWarnings('PMD.AvoidDebugStatements')
  private static void persistFailureAudits(
    List<RHC_Action_History__c> failureAudits
  ) {
    if (failureAudits.isEmpty()) {
      return;
    }
    Database.SaveResult[] auditResults = Database.insert(
      failureAudits,
      false,
      AccessLevel.SYSTEM_MODE
    );
    for (Database.SaveResult result : auditResults) {
      if (!result.isSuccess()) {
        System.debug(
          LoggingLevel.ERROR,
          'RHC Actions could not persist a sanitized capture-failure audit.'
        );
      }
    }
  }

  private static RHC_Action_History__c captureFailure(
    RHC_Pending_Action__c candidate,
    Database.Error error
  ) {
    String statusCode = String.valueOf(error.getStatusCode());
    Datetime occurredAt = System.now();
    return new RHC_Action_History__c(
      Policy__c = candidate.Policy__c,
      Execution_Key__c = ('CAPTURE:' + candidate.Idempotency_Key__c).left(255),
      Event_Id__c = candidate.Event_Id__c,
      Record_Id__c = candidate.Record_Id__c,
      Run_Id__c = candidate.Run_Id__c,
      Outcome__c = 'FAILED_FINAL',
      Attempt_Number__c = 0,
      Initiated_By__c = UserInfo.getUserId(),
      Started_At__c = occurredAt,
      Completed_At__c = occurredAt,
      Error_Code__c = ('CAPTURE_' + statusCode).left(80),
      Error_Summary__c = 'A pending action could not be created. Review runtime access and policy field values.'
    );
  }

  @TestVisible
  private static Boolean isRetryable(StatusCode errorStatus) {
    return errorStatus == StatusCode.UNABLE_TO_LOCK_ROW ||
      errorStatus == StatusCode.UNKNOWN_EXCEPTION;
  }

  private static Boolean isSupported(
    Record_Health_Check_Result__e eventRecord
  ) {
    return eventRecord != null &&
      eventRecord.ContractVersion__c ==
      RHCActionConstants.CORE_CONTRACT_VERSION &&
      String.isNotBlank(eventRecord.EventId__c) &&
      String.isNotBlank(eventRecord.CheckQualifiedApiName__c) &&
      String.isNotBlank(eventRecord.Status__c);
  }

  private static Boolean matches(
    RHC_Action_Policy__c policy,
    Record_Health_Check_Result__e eventRecord
  ) {
    if (
      policy.Check_Qualified_API_Name__c != eventRecord.CheckQualifiedApiName__c
    ) {
      return false;
    }
    if (
      String.isNotBlank(policy.Check_Set_Qualified_API_Name__c) &&
      policy.Check_Set_Qualified_API_Name__c !=
      eventRecord.CheckSetQualifiedApiName__c
    ) {
      return false;
    }
    if (
      String.isNotBlank(policy.Matching_Severity__c) &&
      policy.Matching_Severity__c != eventRecord.Severity__c
    ) {
      return false;
    }
    if (String.isBlank(policy.Matching_Statuses__c)) {
      return false;
    }
    Set<String> statuses = new Set<String>();
    for (String status : policy.Matching_Statuses__c.split(';')) {
      if (String.isNotBlank(status)) {
        statuses.add(status.trim());
      }
    }
    return statuses.contains(eventRecord.Status__c);
  }

  private static RHC_Pending_Action__c buildPending(
    RHC_Action_Policy__c policy,
    Record_Health_Check_Result__e eventRecord,
    Boolean automatic
  ) {
    return new RHC_Pending_Action__c(
      Policy__c = policy.Id,
      Idempotency_Key__c = String.valueOf(policy.Id) +
        ':' +
        eventRecord.EventId__c,
      Event_Id__c = eventRecord.EventId__c,
      Contract_Version__c = eventRecord.ContractVersion__c,
      Record_Id__c = eventRecord.RecordId__c,
      Run_Id__c = eventRecord.RunId__c,
      Check_Set_Qualified_API_Name__c = eventRecord.CheckSetQualifiedApiName__c,
      Check_Qualified_API_Name__c = eventRecord.CheckQualifiedApiName__c,
      Status__c = eventRecord.Status__c,
      Severity__c = eventRecord.Severity__c,
      Reason_Code__c = eventRecord.ReasonCode__c,
      Queue_Status__c = automatic
        ? RHCActionConstants.STATUS_QUEUED
        : RHCActionConstants.STATUS_PENDING_REVIEW,
      Attempt_Count__c = 0,
      Loop_Guard_Key__c = String.valueOf(policy.Id) +
        ':' +
        eventRecord.RecordId__c
    );
  }
}
