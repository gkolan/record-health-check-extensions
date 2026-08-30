/** Converts supported canonical core events and matching policies into bounded ledger candidates. */
public inherited sharing class RHCAlertsEventCandidateBuilder {
  private static final String CONTRACT_VERSION = '1.0';

  /**
   * Returns exact Check Set and Check identities from supported Result events.
   * @param events Canonical Result events from one subscriber batch.
   * @return Exact identities eligible for a bounded policy query.
   */
  public static Set<String> resultIdentities(
    List<Record_Health_Check_Result__e> events
  ) {
    Set<String> identities = new Set<String>();
    for (Record_Health_Check_Result__e eventValue : events) {
      if (!isSupported(eventValue.ContractVersion__c, eventValue.EventId__c)) {
        continue;
      }
      identities.add(eventValue.CheckSetQualifiedApiName__c);
      identities.add(eventValue.CheckQualifiedApiName__c);
    }
    return identities;
  }

  /**
   * Builds matching Result delivery candidates up to the supplied transaction bound.
   * @param events Canonical Result events from one subscriber batch.
   * @param policiesByIdentity Active policies grouped by exact type and identity.
   * @param maximumClaims Maximum processing claims allowed in this transaction.
   * @return Pending delivery candidates plus at most one overflow evidence row.
   */
  public static List<Record_Health_Check_Alert_Delivery__c> resultCandidates(
    List<Record_Health_Check_Result__e> events,
    Map<String, List<Record_Health_Check_Alert_Policy__c>> policiesByIdentity,
    Integer maximumClaims
  ) {
    CandidateBuffer buffer = new CandidateBuffer(maximumClaims);
    for (Record_Health_Check_Result__e eventValue : events) {
      if (!isSupported(eventValue.ContractVersion__c, eventValue.EventId__c)) {
        continue;
      }
      if (addResultCandidates(eventValue, policiesByIdentity, buffer)) {
        break;
      }
    }
    return buffer.rows;
  }

  private static Boolean addResultCandidates(
    Record_Health_Check_Result__e eventValue,
    Map<String, List<Record_Health_Check_Alert_Policy__c>> policiesByIdentity,
    CandidateBuffer buffer
  ) {
    List<Record_Health_Check_Alert_Policy__c> matchingPolicies = new List<Record_Health_Check_Alert_Policy__c>();
    addPolicies(
      matchingPolicies,
      policiesByIdentity.get(
        'CHECK_SET|' + eventValue.CheckSetQualifiedApiName__c
      )
    );
    addPolicies(
      matchingPolicies,
      policiesByIdentity.get('CHECK|' + eventValue.CheckQualifiedApiName__c)
    );
    for (Record_Health_Check_Alert_Policy__c policy : matchingPolicies) {
      if (!RHCAlertsResultPolicyMatcher.matches(policy, eventValue)) {
        continue;
      }
      if (buffer.isFull()) {
        buffer.rows.add(overflow(eventValue));
        return true;
      }
      buffer.rows.add(delivery(policy, eventValue));
    }
    return false;
  }

  /**
   * Returns exact Check Set identities from supported Set Run events.
   * @param events Canonical Set Run events from one subscriber batch.
   * @return Exact identities eligible for a bounded policy query.
   */
  public static Set<String> setRunIdentities(
    List<Record_Health_Check_Set_Run__e> events
  ) {
    Set<String> identities = new Set<String>();
    for (Record_Health_Check_Set_Run__e eventValue : events) {
      if (isSupported(eventValue.ContractVersion__c, eventValue.EventId__c)) {
        identities.add(eventValue.CheckSetQualifiedApiName__c);
      }
    }
    return identities;
  }

  /**
   * Builds Set Run evidence candidates up to the supplied transaction bound.
   * @param events Canonical Set Run events from one subscriber batch.
   * @param policiesByIdentity Active policies grouped by exact type and identity.
   * @param maximumClaims Maximum evidence claims allowed in this transaction.
   * @return Suppressed evidence candidates plus at most one overflow evidence row.
   */
  public static List<Record_Health_Check_Alert_Delivery__c> setRunCandidates(
    List<Record_Health_Check_Set_Run__e> events,
    Map<String, List<Record_Health_Check_Alert_Policy__c>> policiesByIdentity,
    Integer maximumClaims
  ) {
    CandidateBuffer buffer = new CandidateBuffer(maximumClaims);
    for (Record_Health_Check_Set_Run__e eventValue : events) {
      if (!isSupported(eventValue.ContractVersion__c, eventValue.EventId__c)) {
        continue;
      }
      List<Record_Health_Check_Alert_Policy__c> matchingPolicies = policiesByIdentity.get(
        'CHECK_SET|' + eventValue.CheckSetQualifiedApiName__c
      );
      if (matchingPolicies == null) {
        continue;
      }
      if (addSetRunCandidates(eventValue, matchingPolicies, buffer)) {
        break;
      }
    }
    return buffer.rows;
  }

  private static Boolean addSetRunCandidates(
    Record_Health_Check_Set_Run__e eventValue,
    List<Record_Health_Check_Alert_Policy__c> matchingPolicies,
    CandidateBuffer buffer
  ) {
    for (Record_Health_Check_Alert_Policy__c policy : matchingPolicies) {
      if (buffer.isFull()) {
        buffer.rows.add(overflow(eventValue));
        return true;
      }
      buffer.rows.add(delivery(policy, eventValue));
    }
    return false;
  }

  private static Boolean isSupported(String contractVersion, String eventId) {
    return contractVersion == CONTRACT_VERSION && String.isNotBlank(eventId);
  }

  private static void addPolicies(
    List<Record_Health_Check_Alert_Policy__c> target,
    List<Record_Health_Check_Alert_Policy__c> source
  ) {
    if (source != null) {
      target.addAll(source);
    }
  }

  private static Record_Health_Check_Alert_Delivery__c delivery(
    Record_Health_Check_Alert_Policy__c policy,
    Record_Health_Check_Result__e eventValue
  ) {
    return new Record_Health_Check_Alert_Delivery__c(
      Policy__c = policy.Id,
      DeliveryKey__c = digest(eventValue.EventId__c + '|' + policy.Id),
      EventId__c = eventValue.EventId__c,
      EventType__c = 'RESULT',
      RunId__c = eventValue.RunId__c,
      CheckSetQualifiedApiName__c = eventValue.CheckSetQualifiedApiName__c,
      CheckQualifiedApiName__c = eventValue.CheckQualifiedApiName__c,
      RecordId__c = eventValue.RecordId__c,
      Status__c = eventValue.Status__c,
      Severity__c = eventValue.Severity__c,
      Outcome__c = 'PENDING',
      SuppressionReason__c = null,
      FailureClass__c = null,
      OccurredAt__c = eventValue.OccurredAt__c,
      AttemptCount__c = 0,
      RecipientCount__c = 0,
      CooldownKey__c = cooldownKey(policy.Id, eventValue.RecordId__c)
    );
  }

  private static Record_Health_Check_Alert_Delivery__c delivery(
    Record_Health_Check_Alert_Policy__c policy,
    Record_Health_Check_Set_Run__e eventValue
  ) {
    return new Record_Health_Check_Alert_Delivery__c(
      Policy__c = policy.Id,
      DeliveryKey__c = digest(eventValue.EventId__c + '|' + policy.Id),
      EventId__c = eventValue.EventId__c,
      EventType__c = 'SET_RUN',
      RunId__c = eventValue.RunId__c,
      CheckSetQualifiedApiName__c = eventValue.CheckSetQualifiedApiName__c,
      RecordId__c = eventValue.RecordId__c,
      Status__c = eventValue.Phase__c,
      Outcome__c = 'SUPPRESSED',
      SuppressionReason__c = 'RUN_CONTRACT_INSUFFICIENT',
      FailureClass__c = null,
      OccurredAt__c = eventValue.OccurredAt__c,
      AttemptCount__c = 0,
      RecipientCount__c = 0,
      CooldownKey__c = cooldownKey(policy.Id, eventValue.RecordId__c)
    );
  }

  private static Record_Health_Check_Alert_Delivery__c overflow(
    Record_Health_Check_Result__e eventValue
  ) {
    return new Record_Health_Check_Alert_Delivery__c(
      DeliveryKey__c = digest(eventValue.EventId__c + '|BATCH_OVERFLOW|RESULT'),
      EventId__c = eventValue.EventId__c,
      EventType__c = 'RESULT',
      RunId__c = eventValue.RunId__c,
      CheckSetQualifiedApiName__c = eventValue.CheckSetQualifiedApiName__c,
      CheckQualifiedApiName__c = eventValue.CheckQualifiedApiName__c,
      RecordId__c = eventValue.RecordId__c,
      Status__c = eventValue.Status__c,
      Severity__c = eventValue.Severity__c,
      Outcome__c = 'FAILED',
      FailureClass__c = 'LIMIT',
      ErrorCode__c = 'EVENT_POLICY_FANOUT_LIMIT',
      OccurredAt__c = eventValue.OccurredAt__c,
      AttemptCount__c = 0,
      RecipientCount__c = 0
    );
  }

  private static Record_Health_Check_Alert_Delivery__c overflow(
    Record_Health_Check_Set_Run__e eventValue
  ) {
    return new Record_Health_Check_Alert_Delivery__c(
      DeliveryKey__c = digest(
        eventValue.EventId__c + '|BATCH_OVERFLOW|SET_RUN'
      ),
      EventId__c = eventValue.EventId__c,
      EventType__c = 'SET_RUN',
      RunId__c = eventValue.RunId__c,
      CheckSetQualifiedApiName__c = eventValue.CheckSetQualifiedApiName__c,
      RecordId__c = eventValue.RecordId__c,
      Status__c = eventValue.Phase__c,
      Outcome__c = 'FAILED',
      FailureClass__c = 'LIMIT',
      ErrorCode__c = 'EVENT_POLICY_FANOUT_LIMIT',
      OccurredAt__c = eventValue.OccurredAt__c,
      AttemptCount__c = 0,
      RecipientCount__c = 0
    );
  }

  private static String cooldownKey(Id policyId, String recordId) {
    return digest(
      String.valueOf(policyId) +
        '|' +
        (String.isBlank(recordId) ? 'NO_RECORD' : recordId)
    );
  }

  private static String digest(String value) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(value))
    );
  }

  private class CandidateBuffer {
    private Integer maximumClaims;
    private List<Record_Health_Check_Alert_Delivery__c> rows = new List<Record_Health_Check_Alert_Delivery__c>();

    private CandidateBuffer(Integer maximumClaims) {
      this.maximumClaims = maximumClaims;
    }

    private Boolean isFull() {
      return rows.size() >= maximumClaims;
    }
  }
}
