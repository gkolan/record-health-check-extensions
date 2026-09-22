/**
 * Executes corrective Flows with locks, idempotency, cooldown, retry, and audit controls.
 */
// Individual methods remain below PMD complexity thresholds; the aggregate
// class score reflects the complete guarded attempt lifecycle.
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public with sharing class RHCActionExecutionService {
  @TestVisible
  private static RHCActionFlowGateway gateway = new RHCActionFlowGateway();
  @TestVisible
  private static Boolean automaticPermissionOverride;
  @TestVisible
  private static Boolean approvalPermissionOverride;

  private class MissingInterviewIdentityException extends Exception {
  }

  private class ExecutionWork {
    private List<RHC_Action_History__c> histories = new List<RHC_Action_History__c>();
    private List<RHC_Pending_Action__c> updates = new List<RHC_Pending_Action__c>();
    private List<Id> retryIds = new List<Id>();
    private Set<String> succeededKeys = new Set<String>();
  }

  /**
   * Executes eligible pending actions and returns work that needs a delayed retry.
   * @param pendingIds Pending actions to execute
   * @return IDs eligible for a delayed retry
   */
  public static List<Id> execute(List<Id> pendingIds) {
    if (pendingIds == null || pendingIds.isEmpty()) {
      return new List<Id>();
    }
    List<RHC_Pending_Action__c> actions = queryActions(pendingIds);
    ExecutionWork work = new ExecutionWork();
    work.succeededKeys = findSucceededCooldownKeys(actions);
    for (RHC_Pending_Action__c action : actions) {
      processAction(action, work);
    }
    persist(work);
    return work.retryIds;
  }

  private static List<RHC_Pending_Action__c> queryActions(List<Id> pendingIds) {
    return [
      SELECT
        Id,
        Policy__c,
        Event_Id__c,
        Record_Id__c,
        Run_Id__c,
        Check_Set_Qualified_API_Name__c,
        Check_Qualified_API_Name__c,
        Status__c,
        Severity__c,
        Reason_Code__c,
        Queue_Status__c,
        Attempt_Count__c,
        Available_At__c,
        Approved_By__c,
        Approved_At__c,
        Policy__r.Active__c,
        Policy__r.Flow_API_Name__c,
        Policy__r.Cooldown_Minutes__c,
        Policy__r.Retry_Limit__c,
        Policy__r.Input_Contract_Version__c,
        Policy__r.Mode__c,
        Policy__r.Auto_Execution_Enabled__c,
        Policy__r.Check_Qualified_API_Name__c,
        Policy__r.Matching_Statuses__c,
        Policy__r.Map_Record_Id__c,
        Policy__r.Map_Run_Id__c,
        Policy__r.Map_Check_Set__c,
        Policy__r.Map_Check__c,
        Policy__r.Map_Status__c,
        Policy__r.Map_Severity__c,
        Policy__r.Map_Reason_Code__c,
        Policy__r.Map_Event_Id__c
      FROM RHC_Pending_Action__c
      WHERE Id IN :pendingIds
      WITH USER_MODE
      FOR UPDATE
    ];
  }

  private static Set<String> findSucceededCooldownKeys(
    List<RHC_Pending_Action__c> actions
  ) {
    Map<String, Datetime> cutoffByKey = cooldownCutoffs(actions);
    Set<String> succeededKeys = new Set<String>();
    if (cutoffByKey.isEmpty()) {
      return succeededKeys;
    }
    Set<Id> policyIds = new Set<Id>();
    Set<String> recordIds = new Set<String>();
    for (RHC_Pending_Action__c action : actions) {
      policyIds.add(action.Policy__c);
      recordIds.add(action.Record_Id__c);
    }
    Datetime earliest = earliestCutoff(cutoffByKey.values());
    for (RHC_Action_History__c history : [
      SELECT Policy__c, Record_Id__c, Completed_At__c
      FROM RHC_Action_History__c
      WHERE
        Policy__c IN :policyIds
        AND Record_Id__c IN :recordIds
        AND Outcome__c = 'SUCCEEDED'
        AND Completed_At__c >= :earliest
      WITH USER_MODE
    ]) {
      String key = cooldownKey(history.Policy__c, history.Record_Id__c);
      Datetime cutoff = cutoffByKey.get(key);
      if (cutoff != null && history.Completed_At__c >= cutoff) {
        succeededKeys.add(key);
      }
    }
    return succeededKeys;
  }

  private static Map<String, Datetime> cooldownCutoffs(
    List<RHC_Pending_Action__c> actions
  ) {
    Map<String, Datetime> cutoffByKey = new Map<String, Datetime>();
    Datetime nowValue = System.now();
    for (RHC_Pending_Action__c action : actions) {
      if (action.Policy__r == null) {
        continue;
      }
      Integer minutes = action.Policy__r.Cooldown_Minutes__c == null
        ? 1
        : Integer.valueOf(action.Policy__r.Cooldown_Minutes__c);
      cutoffByKey.put(
        cooldownKey(action.Policy__c, action.Record_Id__c),
        nowValue.addMinutes(-minutes)
      );
    }
    return cutoffByKey;
  }

  private static Datetime earliestCutoff(List<Datetime> cutoffs) {
    Datetime earliest = System.now();
    for (Datetime cutoff : cutoffs) {
      if (cutoff < earliest) {
        earliest = cutoff;
      }
    }
    return earliest;
  }

  private static void processAction(
    RHC_Pending_Action__c action,
    ExecutionWork work
  ) {
    if (!isEligibleState(action)) {
      return;
    }
    Integer attempt = nextAttempt(action);
    action.Attempt_Count__c = attempt;
    if (!isExecutionAuthorized(action)) {
      failAuthorization(action, attempt, work);
      return;
    }
    String loopKey = cooldownKey(action.Policy__c, action.Record_Id__c);
    if (work.succeededKeys.contains(loopKey)) {
      suppressForCooldown(action, attempt, work);
      return;
    }
    RHCActionPolicyService.ValidationResult validation = RHCActionPolicyService.validate(
      action.Policy__r
    );
    if (!validation.valid) {
      action.Last_Error_Summary__c = bounded(
        String.join(validation.errors, ' ')
      );
      failContract(action, attempt, work);
      return;
    }
    executeFlow(action, attempt, work);
  }

  private static Integer nextAttempt(RHC_Pending_Action__c action) {
    return action.Attempt_Count__c == null
      ? 1
      : action.Attempt_Count__c.intValue() + 1;
  }

  private static void failAuthorization(
    RHC_Pending_Action__c action,
    Integer attempt,
    ExecutionWork work
  ) {
    action.Queue_Status__c = RHCActionConstants.STATUS_FAILED;
    action.Completed_At__c = System.now();
    action.Available_At__c = null;
    action.Last_Error_Code__c = 'EXECUTION_AUTHORIZATION_REVOKED';
    action.Last_Error_Summary__c = 'The action was not executed because its policy or execution authorization changed.';
    addFailureHistory(action, attempt, work);
  }

  private static void suppressForCooldown(
    RHC_Pending_Action__c action,
    Integer attempt,
    ExecutionWork work
  ) {
    action.Queue_Status__c = RHCActionConstants.STATUS_SUPPRESSED;
    action.Completed_At__c = System.now();
    action.Available_At__c = null;
    action.Last_Error_Code__c = null;
    action.Last_Error_Summary__c = null;
    RHC_Action_History__c history = historyFor(action, attempt, 'SUPPRESSED');
    history.Error_Code__c = 'COOLDOWN_ACTIVE';
    history.Error_Summary__c = 'A recent successful correction is still inside the policy cooldown.';
    work.histories.add(history);
    work.updates.add(action);
  }

  private static void failContract(
    RHC_Pending_Action__c action,
    Integer attempt,
    ExecutionWork work
  ) {
    action.Queue_Status__c = RHCActionConstants.STATUS_FAILED;
    action.Completed_At__c = System.now();
    action.Available_At__c = null;
    action.Last_Error_Code__c = 'FLOW_CONTRACT_INVALID';
    addFailureHistory(action, attempt, work);
  }

  private static void addFailureHistory(
    RHC_Pending_Action__c action,
    Integer attempt,
    ExecutionWork work
  ) {
    RHC_Action_History__c history = historyFor(action, attempt, 'FAILED_FINAL');
    history.Error_Code__c = action.Last_Error_Code__c;
    history.Error_Summary__c = action.Last_Error_Summary__c;
    work.histories.add(history);
    work.updates.add(action);
  }

  private static void executeFlow(
    RHC_Pending_Action__c action,
    Integer attempt,
    ExecutionWork work
  ) {
    action.Queue_Status__c = RHCActionConstants.STATUS_RUNNING;
    RHC_Action_History__c history = historyFor(action, attempt, 'SUCCEEDED');
    try {
      String interviewId = gateway.start(
        action.Policy__r.Flow_API_Name__c,
        buildInputs(action)
      );
      if (String.isBlank(interviewId)) {
        throw new MissingInterviewIdentityException(
          'The Flow did not return its interview identity.'
        );
      }
      recordSuccess(action, history, interviewId);
      work.succeededKeys.add(
        cooldownKey(action.Policy__c, action.Record_Id__c)
      );
    } catch (Exception ex) {
      recordFlowFailure(action, history, work);
    }
    work.histories.add(history);
    work.updates.add(action);
  }

  private static void recordSuccess(
    RHC_Pending_Action__c action,
    RHC_Action_History__c history,
    String interviewId
  ) {
    Datetime completedAt = System.now();
    action.Flow_Interview_Id__c = interviewId;
    action.Queue_Status__c = RHCActionConstants.STATUS_SUCCEEDED;
    action.Completed_At__c = completedAt;
    action.Available_At__c = null;
    action.Last_Error_Code__c = null;
    action.Last_Error_Summary__c = null;
    history.Flow_Interview_Id__c = interviewId;
    history.Completed_At__c = completedAt;
  }

  private static void recordFlowFailure(
    RHC_Pending_Action__c action,
    RHC_Action_History__c history,
    ExecutionWork work
  ) {
    Integer retryLimit = Integer.valueOf(
      action.Policy__r.Retry_Limit__c == null
        ? 0
        : action.Policy__r.Retry_Limit__c
    );
    Boolean retryable = action.Attempt_Count__c <= retryLimit;
    action.Queue_Status__c = retryable
      ? RHCActionConstants.STATUS_RETRY_WAIT
      : RHCActionConstants.STATUS_FAILED;
    action.Available_At__c = retryable ? System.now().addMinutes(1) : null;
    action.Completed_At__c = retryable ? null : System.now();
    action.Last_Error_Code__c = retryable
      ? 'FLOW_START_RETRYABLE'
      : 'FLOW_START_FAILED';
    action.Last_Error_Summary__c = 'The approved Flow did not complete. Review Flow access and fault handling.';
    history.Outcome__c = retryable ? 'FAILED_RETRYABLE' : 'FAILED_FINAL';
    history.Error_Code__c = action.Last_Error_Code__c;
    history.Error_Summary__c = action.Last_Error_Summary__c;
    history.Completed_At__c = System.now();
    if (retryable) {
      work.retryIds.add(action.Id);
    }
  }

  private static void persist(ExecutionWork work) {
    if (!work.histories.isEmpty()) {
      // Audit values are derived exclusively from locked package state.
      Database.insert(work.histories, AccessLevel.SYSTEM_MODE);
    }
    if (!work.updates.isEmpty()) {
      // Lifecycle values are derived exclusively by this service.
      Database.update(work.updates, AccessLevel.SYSTEM_MODE);
    }
  }

  private static Boolean isExecutionAuthorized(RHC_Pending_Action__c action) {
    RHC_Action_Policy__c policy = action.Policy__r;
    if (policy == null || policy.Active__c != true) {
      return false;
    }
    Boolean hasApprovalFact =
      action.Approved_By__c != null ||
      action.Approved_At__c != null;
    if (hasApprovalFact) {
      Boolean canApprove = approvalPermissionOverride == null
        ? FeatureManagement.checkPermission('RHC_Actions_Approve')
        : approvalPermissionOverride;
      return action.Approved_By__c != null &&
        action.Approved_At__c != null &&
        policy.Mode__c == RHCActionConstants.MODE_MANUAL &&
        canApprove;
    }
    Boolean canRunAutomatically = automaticPermissionOverride == null
      ? FeatureManagement.checkPermission('RHC_Actions_Automatic_Execution')
      : automaticPermissionOverride;
    return policy.Mode__c == RHCActionConstants.MODE_AUTOMATIC &&
      policy.Auto_Execution_Enabled__c == true &&
      canRunAutomatically;
  }

  private static Boolean isEligibleState(RHC_Pending_Action__c action) {
    if (action.Queue_Status__c == RHCActionConstants.STATUS_QUEUED) {
      return true;
    }
    return action.Queue_Status__c == RHCActionConstants.STATUS_RETRY_WAIT &&
      (action.Available_At__c == null ||
      action.Available_At__c <= System.now());
  }

  private static String cooldownKey(Id policyId, String recordId) {
    return String.valueOf(policyId) + ':' + recordId;
  }

  private static Map<String, Object> buildInputs(RHC_Pending_Action__c action) {
    Map<String, Object> inputs = new Map<String, Object>();
    RHC_Action_Policy__c policy = action.Policy__r;
    if (policy.Map_Record_Id__c == true) {
      inputs.put('rhcRecordIdV1', action.Record_Id__c);
    }
    if (policy.Map_Run_Id__c == true) {
      inputs.put('rhcRunIdV1', action.Run_Id__c);
    }
    if (policy.Map_Check_Set__c == true) {
      inputs.put(
        'rhcCheckSetQualifiedApiNameV1',
        action.Check_Set_Qualified_API_Name__c
      );
    }
    if (policy.Map_Check__c == true) {
      inputs.put(
        'rhcCheckQualifiedApiNameV1',
        action.Check_Qualified_API_Name__c
      );
    }
    if (policy.Map_Status__c == true) {
      inputs.put('rhcStatusV1', action.Status__c);
    }
    if (policy.Map_Severity__c == true) {
      inputs.put('rhcSeverityV1', action.Severity__c);
    }
    if (policy.Map_Reason_Code__c == true) {
      inputs.put('rhcReasonCodeV1', action.Reason_Code__c);
    }
    if (policy.Map_Event_Id__c == true) {
      inputs.put('rhcEventIdV1', action.Event_Id__c);
    }
    return inputs;
  }

  private static RHC_Action_History__c historyFor(
    RHC_Pending_Action__c action,
    Integer attempt,
    String outcome
  ) {
    return new RHC_Action_History__c(
      Pending_Action__c = action.Id,
      Policy__c = action.Policy__c,
      Execution_Key__c = String.valueOf(action.Id) + ':' + attempt,
      Event_Id__c = action.Event_Id__c,
      Record_Id__c = action.Record_Id__c,
      Run_Id__c = action.Run_Id__c,
      Initiated_By__c = UserInfo.getUserId(),
      Approved_By__c = action.Approved_By__c,
      Started_At__c = System.now(),
      Completed_At__c = System.now(),
      Outcome__c = outcome,
      Attempt_Number__c = attempt
    );
  }

  private static String bounded(String value) {
    if (
      String.isBlank(value) ||
      value.length() <= RHCActionConstants.MAX_ERROR_LENGTH
    ) {
      return value;
    }
    return value.substring(0, RHCActionConstants.MAX_ERROR_LENGTH);
  }
}
