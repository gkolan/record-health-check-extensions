/** Builds core requests and summarizes bounded core responses for Change Monitor dispatch. */
public class RHCChangeMonitorDispatchSupport {
  /** Per-record total and actionable result counts. */
  public class ResultCounts {
    public Map<String, Integer> totalByRecord = new Map<String, Integer>();
    public Map<String, Integer> actionableByRecord = new Map<String, Integer>();
  }

  @SuppressWarnings('PMD.EmptyStatementBlock')
  private RHCChangeMonitorDispatchSupport() {
  }

  /**
   * Starts one dispatcher chain unless one is already queued, so a burst of dispatch events
   * does not fan out into parallel workers competing for the same pending claims.
   */
  public static void enqueueDispatcher() {
    if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
      return;
    }
    List<AsyncApexJob> queued = [
      SELECT Id FROM AsyncApexJob
      WHERE ApexClass.Name = 'RHCChangeMonitorDispatcherQueueable'
        AND JobType = 'Queueable' AND Status IN ('Queued', 'Holding', 'Preparing')
      WITH USER_MODE
      LIMIT 1
    ];
    if (queued.isEmpty()) {
      System.enqueueJob(new RHCChangeMonitorDispatcherQueueable(0));
    }
  }

  /**
   * Builds one policy-homogeneous core request.
   * @param claims Validated pending claims for one policy.
   * @param runId Safe caller correlation.
   * @return Configured core request.
   */
  public static RecordHealthCheckRequest buildRequest(
    List<Record_Health_Check_Change_Evaluation__c> claims,
    String runId
  ) {
    Record_Health_Check_Change_Policy__c policy = claims[0].Policy__r;
    List<Id> recordIds = new List<Id>();
    for (Record_Health_Check_Change_Evaluation__c claim : claims) {
      recordIds.add((Id) claim.RecordId__c);
    }
    RecordHealthCheckRequest request = 'CHECK_SET'.equals(policy.SelectionType__c)
      ? RecordHealthCheckRequest.forCheckSet(policy.QualifiedApiName__c, recordIds)
      : RecordHealthCheckRequest.forCheck(policy.QualifiedApiName__c, recordIds);
    return request
      .withResultMode(RecordHealthCheckResultMode.EVALUATION)
      .withRunId(runId)
      .withEventPublication(publication(policy.EventPublication__c));
  }

  /**
   * Summarizes result and actionable counts without retaining diagnostic payloads.
   * @param results Core result items.
   * @return Per-record bounded counts.
   */
  public static ResultCounts summarize(List<RecordHealthCheckResultItem> results) {
    ResultCounts counts = new ResultCounts();
    for (RecordHealthCheckResultItem item : results) {
      addResult(counts, item?.evaluation);
    }
    return counts;
  }

  /**
   * Revalidates mutable policy facts immediately before dispatch.
   * @param claim Pending claim with its current policy relationship.
   * @return Bounded terminal reason, or null when dispatch remains valid.
   */
  public static String revalidationReason(
    Record_Health_Check_Change_Evaluation__c claim
  ) {
    if (claim.Policy__c == null || claim.Policy__r?.Active__c != true) {
      return 'POLICY_INACTIVE';
    }
    if (!claim.SourceObjectApiName__c.equals(claim.Policy__r.SourceObjectApiName__c)) {
      return 'CORE_CONFIGURATION_INVALID';
    }
    if (
      claim.Policy__r.ActiveAfter__c != null &&
      claim.OccurredAt__c < claim.Policy__r.ActiveAfter__c
    ) {
      return 'EVENT_BEFORE_ACTIVATION';
    }
    return null;
  }

  /**
   * Builds retry or terminal failure updates after a bounded dispatch exception.
   * @param claims Claims in the failed policy scope.
   * @param failureKind TRANSIENT when the exception is explicitly retryable.
   * @param maximumAttempts Maximum permitted dispatch attempts.
   * @return Bounded claim updates.
   */
  public static List<Record_Health_Check_Change_Evaluation__c> failureUpdates(
    List<Record_Health_Check_Change_Evaluation__c> claims,
    String failureKind,
    Integer maximumAttempts
  ) {
    List<Record_Health_Check_Change_Evaluation__c> updates =
      new List<Record_Health_Check_Change_Evaluation__c>();
    for (Record_Health_Check_Change_Evaluation__c claim : claims) {
      Integer attempts = claim.AttemptCount__c == null ? 0 : claim.AttemptCount__c.intValue();
      Boolean retry = 'TRANSIENT'.equals(failureKind) && attempts < maximumAttempts;
      updates.add(new Record_Health_Check_Change_Evaluation__c(
        Id = claim.Id,
        Outcome__c = retry ? 'PENDING' : 'FAILED',
        ReasonCode__c = retry ? 'TRANSIENT_RETRY' : 'RETRY_EXHAUSTED',
        CompletedAt__c = retry ? null : System.now()
      ));
    }
    return updates;
  }

  /**
   * Classifies the deliberately narrow transient exception contract.
   * @param error Dispatch exception.
   * @return TRANSIENT only for row-lock contention; TERMINAL otherwise.
   */
  public static String failureKind(Exception error) {
    String message = error == null ? null : error.getMessage();
    return message != null && message.contains('UNABLE_TO_LOCK_ROW')
      ? 'TRANSIENT'
      : 'TERMINAL';
  }

  private static void addResult(
    ResultCounts counts,
    RecordHealthCheckEvaluationResult evaluation
  ) {
    if (evaluation?.recordId == null) {
      return;
    }
    String recordId = String.valueOf(evaluation.recordId);
    counts.totalByRecord.put(recordId, (counts.totalByRecord.get(recordId) ?? 0) + 1);
    if (RecordHealthCheckStatus.isActionable(evaluation.status)) {
      counts.actionableByRecord.put(
        recordId,
        (counts.actionableByRecord.get(recordId) ?? 0) + 1
      );
    }
  }

  private static RecordHealthCheckEventPublication publication(String value) {
    Map<String, RecordHealthCheckEventPublication> values =
      new Map<String, RecordHealthCheckEventPublication>{
        'NONE' => RecordHealthCheckEventPublication.NONE,
        'ALL' => RecordHealthCheckEventPublication.ALL,
        'ACTIONABLE' => RecordHealthCheckEventPublication.ACTIONABLE
      };
    return values.containsKey(value)
      ? values.get(value)
      : RecordHealthCheckEventPublication.ACTIONABLE;
  }
}
