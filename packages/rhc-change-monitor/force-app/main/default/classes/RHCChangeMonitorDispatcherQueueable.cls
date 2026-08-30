/** Dispatches durable claims to core in policy-homogeneous slices of at most 200 record IDs. */
public with sharing class RHCChangeMonitorDispatcherQueueable implements Queueable, Finalizer {
  private static final Integer CLAIM_SCOPE = 200;
  private static final Integer MAX_ATTEMPTS = 3;
  private static final Integer MAX_CHAIN_DEPTH = 10;
  private Integer chainDepth;
  @TestVisible private static Boolean testRunPermission;
  @TestVisible private static RecordHealthCheckResponse testResponse;

  private class DispatchPlan {
    private Map<Id, List<Record_Health_Check_Change_Evaluation__c>> claimsByPolicy =
      new Map<Id, List<Record_Health_Check_Change_Evaluation__c>>();
    private List<Record_Health_Check_Change_Evaluation__c> updates =
      new List<Record_Health_Check_Change_Evaluation__c>();
  }

  /**
   * Creates one bounded dispatcher hop.
   * @param chainDepth Zero-based bounded queue chain depth.
   */
  public RHCChangeMonitorDispatcherQueueable(Integer chainDepth) {
    this.chainDepth = chainDepth == null ? 0 : chainDepth;
  }

  /**
   * Processes one bounded claim scope and chains only while durable pending work remains.
   * @param context Salesforce Queueable execution context.
   */
  public void execute(QueueableContext context) {
    if (context != null) {
      System.attachFinalizer(this);
    }
    List<Record_Health_Check_Change_Evaluation__c> claims = loadPendingClaims();
    if (claims.isEmpty()) {
      return;
    }
    DispatchPlan plan = createDispatchPlan(claims);
    persistUpdates(plan.updates);
    persistUpdates(evaluatePolicies(plan.claimsByPolicy));
    continueOrExhaust();
  }

  /**
   * Restarts a rolled-back dispatcher hop after an otherwise unhandled asynchronous failure.
   * @param context Salesforce Finalizer execution context.
   */
  public void execute(FinalizerContext context) {
    Boolean failed = context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION;
    if (failed && chainDepth + 1 < MAX_CHAIN_DEPTH) {
      System.enqueueJob(new RHCChangeMonitorDispatcherQueueable(chainDepth + 1));
    }
  }

  private static List<Record_Health_Check_Change_Evaluation__c> loadPendingClaims() {
    return [
      SELECT Id, Policy__c, ClaimKey__c, SourceObjectApiName__c, RecordId__c, OccurredAt__c,
        AttemptCount__c, Outcome__c, Policy__r.Active__c, Policy__r.SourceObjectApiName__c,
        Policy__r.SelectionType__c, Policy__r.QualifiedApiName__c,
        Policy__r.EventPublication__c, Policy__r.ActiveAfter__c
      FROM Record_Health_Check_Change_Evaluation__c
      WHERE Outcome__c = 'PENDING'
      ORDER BY AcceptedAt__c, Id
      LIMIT :CLAIM_SCOPE
    ];
  }

  private static DispatchPlan createDispatchPlan(
    List<Record_Health_Check_Change_Evaluation__c> claims
  ) {
    DispatchPlan plan = new DispatchPlan();
    for (Record_Health_Check_Change_Evaluation__c claim : claims) {
      addClaimToPlan(plan, claim);
    }
    return plan;
  }

  private static void addClaimToPlan(
    DispatchPlan plan,
    Record_Health_Check_Change_Evaluation__c claim
  ) {
    String reasonCode = RHCChangeMonitorDispatchSupport.revalidationReason(claim);
    if (reasonCode != null) {
      plan.updates.add(terminalUpdate(claim.Id, 'IGNORED', reasonCode));
      return;
    }
    if (!plan.claimsByPolicy.containsKey(claim.Policy__c)) {
      plan.claimsByPolicy.put(
        claim.Policy__c,
        new List<Record_Health_Check_Change_Evaluation__c>()
      );
    }
    plan.claimsByPolicy.get(claim.Policy__c).add(claim);
    claim.AttemptCount__c = safeAttemptCount(claim.AttemptCount__c) + 1;
    plan.updates.add(new Record_Health_Check_Change_Evaluation__c(
      Id = claim.Id,
      AttemptCount__c = claim.AttemptCount__c
    ));
  }

  private static List<Record_Health_Check_Change_Evaluation__c> evaluatePolicies(
    Map<Id, List<Record_Health_Check_Change_Evaluation__c>> claimsByPolicy
  ) {
    List<Record_Health_Check_Change_Evaluation__c> outcomes =
      new List<Record_Health_Check_Change_Evaluation__c>();
    for (List<Record_Health_Check_Change_Evaluation__c> policyClaims : claimsByPolicy.values()) {
      try {
        outcomes.addAll(evaluatePolicyScope(policyClaims));
      } catch (Exception error) {
        outcomes.addAll(RHCChangeMonitorDispatchSupport.failureUpdates(
          policyClaims,
          RHCChangeMonitorDispatchSupport.failureKind(error),
          MAX_ATTEMPTS
        ));
      }
    }
    return outcomes;
  }

  private static List<Record_Health_Check_Change_Evaluation__c> evaluatePolicyScope(
    List<Record_Health_Check_Change_Evaluation__c> claims
  ) {
    if (!hasRunPermission()) {
      return terminalUpdates(claims, 'FAILED', 'RUNTIME_PERMISSION_MISSING');
    }
    String runId = 'cm-v1-' + claims[0].ClaimKey__c.substring(0, 48);
    RecordHealthCheckResponse response = evaluate(
      RHCChangeMonitorDispatchSupport.buildRequest(claims, runId)
    );
    if (response == null || response.results == null) {
      return terminalUpdates(claims, 'FAILED', 'CORE_CONFIGURATION_INVALID');
    }
    return evaluatedUpdates(
      claims,
      runId,
      RHCChangeMonitorDispatchSupport.summarize(response.results)
    );
  }

  private static RecordHealthCheckResponse evaluate(RecordHealthCheckRequest request) {
    return Test.isRunningTest() && testResponse != null
      ? testResponse
      : RecordHealthCheck.evaluate(request);
  }

  private static List<Record_Health_Check_Change_Evaluation__c> evaluatedUpdates(
    List<Record_Health_Check_Change_Evaluation__c> claims,
    String runId,
    RHCChangeMonitorDispatchSupport.ResultCounts counts
  ) {
    List<Record_Health_Check_Change_Evaluation__c> updates =
      new List<Record_Health_Check_Change_Evaluation__c>();
    for (Record_Health_Check_Change_Evaluation__c claim : claims) {
      updates.add(new Record_Health_Check_Change_Evaluation__c(
        Id = claim.Id,
        RunId__c = runId,
        Outcome__c = 'EVALUATED',
        ReasonCode__c = 'ACCEPTED',
        ResultCount__c = counts.totalByRecord.get(claim.RecordId__c) ?? 0,
        ActionableCount__c = counts.actionableByRecord.get(claim.RecordId__c) ?? 0,
        CompletedAt__c = System.now()
      ));
    }
    return updates;
  }

  private static List<Record_Health_Check_Change_Evaluation__c> terminalUpdates(
    List<Record_Health_Check_Change_Evaluation__c> claims,
    String outcome,
    String reasonCode
  ) {
    List<Record_Health_Check_Change_Evaluation__c> updates =
      new List<Record_Health_Check_Change_Evaluation__c>();
    for (Record_Health_Check_Change_Evaluation__c claim : claims) {
      updates.add(terminalUpdate(claim.Id, outcome, reasonCode));
    }
    return updates;
  }

  private static Record_Health_Check_Change_Evaluation__c terminalUpdate(
    Id claimId,
    String outcome,
    String reasonCode
  ) {
    return new Record_Health_Check_Change_Evaluation__c(
      Id = claimId,
      Outcome__c = outcome,
      ReasonCode__c = reasonCode,
      CompletedAt__c = System.now()
    );
  }

  private void continueOrExhaust() {
    List<Record_Health_Check_Change_Evaluation__c> pending = [
      SELECT Id
      FROM Record_Health_Check_Change_Evaluation__c
      WHERE Outcome__c = 'PENDING'
      ORDER BY AcceptedAt__c, Id
      LIMIT 2000
    ];
    if (pending.isEmpty()) {
      return;
    }
    if (chainDepth + 1 < MAX_CHAIN_DEPTH) {
      System.enqueueJob(new RHCChangeMonitorDispatcherQueueable(chainDepth + 1));
      return;
    }
    List<Record_Health_Check_Change_Evaluation__c> exhausted =
      terminalUpdates(pending, 'FAILED', 'DISPATCH_CHAIN_EXHAUSTED');
    update exhausted;
  }

  private static void persistUpdates(
    List<Record_Health_Check_Change_Evaluation__c> updates
  ) {
    if (!updates.isEmpty()) {
      update updates;
    }
  }

  private static Integer safeAttemptCount(Decimal value) {
    return value == null ? 0 : value.intValue();
  }

  private static Boolean hasRunPermission() {
    if (Test.isRunningTest() && testRunPermission != null) {
      return testRunPermission;
    }
    return FeatureManagement.checkPermission('Record_Health_Check_Run');
  }
}
