/** Bulk-safe subscriber orchestration for canonical core Result and Set Run events. */
// Platform Event subscribers must durably claim package-owned ledger rows even though Automated
// Process cannot receive a permission set. No checked business record is queried or updated.
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class RHCAlertsEventService {
  @TestVisible
  private static final Integer MAX_CLAIMS_PER_BATCH = 2000;

  /**
   * Claims matching Result events and enqueues one bulk delivery job.
   * @param events Canonical core Result contract events from one trigger batch.
   */
  public static void processResults(
    List<Record_Health_Check_Result__e> events
  ) {
    if (events == null || events.isEmpty()) {
      return;
    }
    Map<String, List<Record_Health_Check_Alert_Policy__c>> policies = policiesByIdentity(
      RHCAlertsEventCandidateBuilder.resultIdentities(events)
    );
    claim(
      RHCAlertsEventCandidateBuilder.resultCandidates(
        events,
        policies,
        MAX_CLAIMS_PER_BATCH
      ),
      true
    );
  }

  /**
   * Subscribes to Set Run 1.0 without inventing missing canonical severity.
   * @param events Canonical core Set Run contract events from one trigger batch.
   */
  public static void processSetRuns(
    List<Record_Health_Check_Set_Run__e> events
  ) {
    if (events == null || events.isEmpty()) {
      return;
    }
    Map<String, List<Record_Health_Check_Alert_Policy__c>> policies = policiesByIdentity(
      RHCAlertsEventCandidateBuilder.setRunIdentities(events)
    );
    claim(
      RHCAlertsEventCandidateBuilder.setRunCandidates(
        events,
        policies,
        MAX_CLAIMS_PER_BATCH
      ),
      false
    );
  }

  private static Map<String, List<Record_Health_Check_Alert_Policy__c>> policiesByIdentity(
    Set<String> identities
  ) {
    identities.remove(null);
    identities.remove('');
    Map<String, List<Record_Health_Check_Alert_Policy__c>> result = new Map<String, List<Record_Health_Check_Alert_Policy__c>>();
    if (identities.isEmpty()) {
      return result;
    }
    for (Record_Health_Check_Alert_Policy__c policy : [
      SELECT
        Id,
        Active__c,
        SelectionType__c,
        QualifiedApiName__c,
        MatchingStatuses__c,
        MinimumSeverity__c,
        RecipientType__c,
        RecipientId__c,
        NotificationChannel__c,
        CooldownMinutes__c
      FROM Record_Health_Check_Alert_Policy__c
      WHERE Active__c = TRUE AND QualifiedApiName__c IN :identities
      ORDER BY Id
      LIMIT 5000
    ]) {
      String key = policy.SelectionType__c + '|' + policy.QualifiedApiName__c;
      if (!result.containsKey(key)) {
        result.put(key, new List<Record_Health_Check_Alert_Policy__c>());
      }
      result.get(key).add(policy);
    }
    return result;
  }

  @TestVisible
  private static void claim(
    List<Record_Health_Check_Alert_Delivery__c> candidates,
    Boolean enqueue
  ) {
    if (candidates.isEmpty()) {
      return;
    }
    List<Database.SaveResult> results = Database.insert(candidates, false);
    List<Id> claimedIds = new List<Id>();
    List<Record_Health_Check_Alert_Delivery__c> evidenceRows = new List<Record_Health_Check_Alert_Delivery__c>();
    for (Integer index = 0; index < results.size(); index++) {
      if (results[index].isSuccess()) {
        if (enqueue && candidates[index].Outcome__c == 'PENDING') {
          claimedIds.add(results[index].getId());
        }
        continue;
      }
      if (isDuplicate(results[index].getErrors())) {
        evidenceRows.add(duplicateEvidence(candidates[index]));
      } else {
        evidenceRows.add(claimFailure(candidates[index]));
      }
    }
    if (!evidenceRows.isEmpty()) {
      assertAllSucceeded(
        Database.insert(evidenceRows, false),
        'CLAIM_EVIDENCE_INSERT_FAILED'
      );
    }
    if (!claimedIds.isEmpty()) {
      enqueueClaims(claimedIds);
    }
  }

  private static Boolean isDuplicate(List<Database.Error> errors) {
    for (Database.Error error : errors) {
      if (error.getStatusCode() == StatusCode.DUPLICATE_VALUE) {
        return true;
      }
    }
    return false;
  }

  private static Record_Health_Check_Alert_Delivery__c duplicateEvidence(
    Record_Health_Check_Alert_Delivery__c source
  ) {
    source.Id = null;
    source.DeliveryKey__c = null;
    source.Outcome__c = 'DUPLICATE';
    source.SuppressionReason__c = null;
    source.FailureClass__c = null;
    source.ErrorCode__c = null;
    source.AttemptedAt__c = System.now();
    return source;
  }

  private static Record_Health_Check_Alert_Delivery__c claimFailure(
    Record_Health_Check_Alert_Delivery__c source
  ) {
    return new Record_Health_Check_Alert_Delivery__c(
      EventId__c = source.EventId__c,
      EventType__c = source.EventType__c,
      RunId__c = source.RunId__c,
      CheckSetQualifiedApiName__c = source.CheckSetQualifiedApiName__c,
      CheckQualifiedApiName__c = source.CheckQualifiedApiName__c,
      RecordId__c = source.RecordId__c,
      Status__c = source.Status__c,
      Severity__c = source.Severity__c,
      Outcome__c = 'FAILED',
      FailureClass__c = 'PERMANENT',
      ErrorCode__c = 'CLAIM_INSERT_FAILED',
      OccurredAt__c = source.OccurredAt__c,
      AttemptedAt__c = System.now(),
      AttemptCount__c = 0,
      RecipientCount__c = 0
    );
  }

  private static void enqueueClaims(List<Id> claimedIds) {
    if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
      markDispatchFailure(claimedIds);
      return;
    }
    try {
      System.enqueueJob(new RHCAlertsDeliveryQueueable(claimedIds));
    } catch (AsyncException error) {
      markDispatchFailure(claimedIds);
    }
  }

  private static void markDispatchFailure(List<Id> claimedIds) {
    List<Record_Health_Check_Alert_Delivery__c> failedRows = new List<Record_Health_Check_Alert_Delivery__c>();
    Datetime attemptedAt = System.now();
    for (Id claimedId : claimedIds) {
      failedRows.add(
        new Record_Health_Check_Alert_Delivery__c(
          Id = claimedId,
          Outcome__c = 'FAILED',
          FailureClass__c = 'LIMIT',
          ErrorCode__c = 'QUEUE_ENQUEUE_FAILED',
          AttemptedAt__c = attemptedAt,
          AttemptCount__c = 0,
          RecipientCount__c = 0
        )
      );
    }
    assertAllSucceeded(
      Database.update(failedRows, false),
      'QUEUE_FAILURE_UPDATE_FAILED'
    );
  }

  private static void assertAllSucceeded(
    List<Database.SaveResult> results,
    String errorCode
  ) {
    for (Database.SaveResult result : results) {
      if (!result.isSuccess()) {
        throw new ClaimException(errorCode);
      }
    }
  }

  /** Bounded internal signal used when claim evidence cannot be persisted. */
  private class ClaimException extends Exception {
  }
}
