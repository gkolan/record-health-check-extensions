/**
 * Narrow subscriber-adapter boundary for validated Salesforce ChangeEvent records.
 * The handler stores only header identity and routing evidence, never payload values.
 * Global visibility is required so subscriber-owned triggers can cross a package namespace.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class RHCChangeMonitorIntake {
  /** Signals an atomic intake failure without exposing payload or exception detail. */
  global class IntakeException extends Exception {
  }

  private class ClaimContext {
    private Record_Health_Check_Change_Policy__c policy;
    private RHCChangeMonitorEventEnvelope eventEnvelope;
    private String recordId;
    private RHCChangeMonitorRoutingService.Decision decision;
  }

  /**
   * Accepts an object-specific subscriber trigger batch.
   * @param changeEvents Trigger.new from exactly one Salesforce ChangeEvent trigger.
   * @throws IntakeException when the batch cannot be safely claimed.
   */
  global static void accept(List<SObject> changeEvents) {
    if (changeEvents == null || changeEvents.isEmpty()) {
      return;
    }
    List<RHCChangeMonitorEventEnvelope> envelopes = new List<RHCChangeMonitorEventEnvelope>();
    for (SObject changeEvent : changeEvents) {
      envelopes.add(RHCChangeMonitorEventEnvelope.fromChangeEvent(changeEvent));
    }
    acceptEnvelopes(envelopes);
  }

  @TestVisible
  private static void acceptEnvelopes(List<RHCChangeMonitorEventEnvelope> envelopes) {
    if (envelopes == null || envelopes.isEmpty()) {
      return;
    }
    Map<String, List<Record_Health_Check_Change_Policy__c>> policiesBySource = loadPolicies(
      sourceObjects(envelopes)
    );
    List<Record_Health_Check_Change_Evaluation__c> claims = buildClaims(
      envelopes,
      policiesBySource
    );
    if (claims.isEmpty()) {
      return;
    }
    Savepoint dispatchSavepoint = Database.setSavepoint();
    Integer pendingCount = persistClaims(claims);
    try {
      // Publish instead of enqueueing: a Queueable started here would inherit Automated Process.
      RHCChangeMonitorDispatchSupport.publishDispatch(pendingCount);
    } catch (RHCChangeMonitorDispatchSupport.DispatchSignalException error) {
      Database.rollback(dispatchSavepoint);
      throw new IntakeException('CDC claims could not be paired with a dispatch signal.');
    }
  }

  private static Set<String> sourceObjects(List<RHCChangeMonitorEventEnvelope> envelopes) {
    Set<String> sourceObjects = new Set<String>();
    for (RHCChangeMonitorEventEnvelope envelope : envelopes) {
      sourceObjects.add(envelope.sourceObjectApiName);
    }
    return sourceObjects;
  }

  private static Map<String, List<Record_Health_Check_Change_Policy__c>> loadPolicies(
    Set<String> sourceObjects
  ) {
    List<Record_Health_Check_Change_Policy__c> policies = [
      SELECT Id, Active__c, SourceObjectApiName__c, SelectionType__c, QualifiedApiName__c,
        ChangeTypes__c, ChangedFields__c, EventPublication__c, ActiveAfter__c
      FROM Record_Health_Check_Change_Policy__c
      WHERE Active__c = TRUE AND SourceObjectApiName__c IN :sourceObjects
      WITH USER_MODE
      ORDER BY Id
      LIMIT 1000
    ];
    Map<String, List<Record_Health_Check_Change_Policy__c>> policiesBySource =
      new Map<String, List<Record_Health_Check_Change_Policy__c>>();
    for (Record_Health_Check_Change_Policy__c policy : policies) {
      addPolicy(policiesBySource, policy);
    }
    return policiesBySource;
  }

  private static void addPolicy(
    Map<String, List<Record_Health_Check_Change_Policy__c>> policiesBySource,
    Record_Health_Check_Change_Policy__c policy
  ) {
    if (!policiesBySource.containsKey(policy.SourceObjectApiName__c)) {
      policiesBySource.put(
        policy.SourceObjectApiName__c,
        new List<Record_Health_Check_Change_Policy__c>()
      );
    }
    policiesBySource.get(policy.SourceObjectApiName__c).add(policy);
  }

  private static List<Record_Health_Check_Change_Evaluation__c> buildClaims(
    List<RHCChangeMonitorEventEnvelope> envelopes,
    Map<String, List<Record_Health_Check_Change_Policy__c>> policiesBySource
  ) {
    List<Record_Health_Check_Change_Evaluation__c> claims =
      new List<Record_Health_Check_Change_Evaluation__c>();
    for (RHCChangeMonitorEventEnvelope envelope : envelopes) {
      claims.addAll(buildEnvelopeClaims(envelope, policiesBySource));
    }
    return claims;
  }

  private static List<Record_Health_Check_Change_Evaluation__c> buildEnvelopeClaims(
    RHCChangeMonitorEventEnvelope eventEnvelope,
    Map<String, List<Record_Health_Check_Change_Policy__c>> policiesBySource
  ) {
    List<Record_Health_Check_Change_Evaluation__c> claims =
      new List<Record_Health_Check_Change_Evaluation__c>();
    List<Record_Health_Check_Change_Policy__c> policies = policiesBySource.get(
      eventEnvelope.sourceObjectApiName
    );
    if (policies == null) {
      return claims;
    }
    List<String> recordIds = eventEnvelope.recordIds.isEmpty()
      ? new List<String>{ null }
      : eventEnvelope.recordIds;
    for (Record_Health_Check_Change_Policy__c policy : policies) {
      RHCChangeMonitorRoutingService.Decision decision = RHCChangeMonitorRoutingService.route(
        policy,
        eventEnvelope
      );
      for (String recordId : recordIds) {
        ClaimContext context = new ClaimContext();
        context.policy = policy;
        context.eventEnvelope = eventEnvelope;
        context.recordId = recordId;
        context.decision = decision;
        claims.add(createClaim(context));
      }
    }
    return claims;
  }

  private static Integer persistClaims(
    List<Record_Health_Check_Change_Evaluation__c> claims
  ) {
    List<Database.SaveResult> results = Database.insert(claims, false, AccessLevel.USER_MODE);
    Integer pendingCount = 0;
    for (Integer indexValue = 0; indexValue < results.size(); indexValue++) {
      Database.SaveResult result = results[indexValue];
      if (result.isSuccess()) {
        pendingCount += 'PENDING'.equals(claims[indexValue].Outcome__c) ? 1 : 0;
      } else if (!isDuplicateOnly(result.getErrors())) {
        throw new IntakeException('One or more CDC claims could not be persisted.');
      }
    }
    return pendingCount;
  }

  private static Record_Health_Check_Change_Evaluation__c createClaim(ClaimContext context) {
    Boolean terminal = !context.decision.shouldDispatch;
    return new Record_Health_Check_Change_Evaluation__c(
      Policy__c = context.policy.Id,
      ClaimKey__c = RHCChangeMonitorClaimKey.create(
        context.eventEnvelope,
        context.policy.Id,
        context.recordId
      ),
      SourceObjectApiName__c = context.eventEnvelope.sourceObjectApiName,
      RecordId__c = context.recordId,
      ChangeType__c = context.eventEnvelope.changeType,
      TransactionKey__c = context.eventEnvelope.transactionKey,
      SequenceNumber__c = context.eventEnvelope.sequenceNumber,
      ReplayId__c = context.eventEnvelope.replayId,
      OccurredAt__c = context.eventEnvelope.occurredAt,
      AcceptedAt__c = System.now(),
      CompletedAt__c = terminal ? System.now() : null,
      Outcome__c = context.decision.outcome,
      ReasonCode__c = context.decision.reasonCode,
      AttemptCount__c = 0,
      ResultCount__c = 0,
      ActionableCount__c = 0
    );
  }

  private static Boolean isDuplicateOnly(List<Database.Error> errors) {
    if (errors == null || errors.isEmpty()) {
      return false;
    }
    for (Database.Error error : errors) {
      if (error.getStatusCode() != StatusCode.DUPLICATE_VALUE) {
        return false;
      }
    }
    return true;
  }
}
