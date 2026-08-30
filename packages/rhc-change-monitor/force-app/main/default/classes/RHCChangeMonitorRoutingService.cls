/** Applies the closed Change Monitor change-type and changed-field routing contract. */
public with sharing class RHCChangeMonitorRoutingService {
  /** One bounded routing decision with no payload values. */
  public class Decision {
    public Boolean shouldDispatch;
    public String outcome;
    public String reasonCode;
  }

  @SuppressWarnings('PMD.EmptyStatementBlock')
  private RHCChangeMonitorRoutingService() {
  }

  /**
   * Routes a validated event against one policy without querying or performing DML.
   * @param policy Active or recently deactivated policy snapshot.
   * @param eventEnvelope Validated CDC facts.
   * @return Bounded dispatch or terminal-ignore decision.
   */
  public static Decision route(
    Record_Health_Check_Change_Policy__c policy,
    RHCChangeMonitorEventEnvelope eventEnvelope
  ) {
    requireInputs(policy, eventEnvelope);
    String reasonCode = terminalReason(policy, eventEnvelope);
    return reasonCode == null ? accepted() : ignored(reasonCode);
  }

  private static void requireInputs(
    Record_Health_Check_Change_Policy__c policy,
    RHCChangeMonitorEventEnvelope eventEnvelope
  ) {
    if (policy == null || eventEnvelope == null) {
      throw new IllegalArgumentException('Policy and event envelope are required.');
    }
  }

  private static String terminalReason(
    Record_Health_Check_Change_Policy__c policy,
    RHCChangeMonitorEventEnvelope eventEnvelope
  ) {
    if (policy.Active__c != true) {
      return 'POLICY_INACTIVE';
    }
    if (!eventEnvelope.sourceObjectApiName.equals(policy.SourceObjectApiName__c)) {
      return 'CORE_CONFIGURATION_INVALID';
    }
    if (isBeforeActivation(policy, eventEnvelope)) {
      return 'EVENT_BEFORE_ACTIVATION';
    }
    String changeTypeReason = changeTypeReason(policy, eventEnvelope);
    if (changeTypeReason != null) {
      return changeTypeReason;
    }
    return updateFieldReason(policy, eventEnvelope);
  }

  private static Boolean isBeforeActivation(
    Record_Health_Check_Change_Policy__c policy,
    RHCChangeMonitorEventEnvelope eventEnvelope
  ) {
    return policy.ActiveAfter__c != null && eventEnvelope.occurredAt < policy.ActiveAfter__c;
  }

  private static String changeTypeReason(
    Record_Health_Check_Change_Policy__c policy,
    RHCChangeMonitorEventEnvelope eventEnvelope
  ) {
    Map<String, String> terminalReasons = new Map<String, String>{
      'GAP' => 'GAP_DETECTED',
      'DELETE' => 'RECORD_DELETED',
      'UNKNOWN' => 'UNSUPPORTED_CHANGE_TYPE'
    };
    if (terminalReasons.containsKey(eventEnvelope.changeType)) {
      return terminalReasons.get(eventEnvelope.changeType);
    }
    if (!selectedChangeTypes(policy.ChangeTypes__c).contains(eventEnvelope.changeType)) {
      return 'CHANGE_TYPE_NOT_SELECTED';
    }
    return null;
  }

  private static String updateFieldReason(
    Record_Health_Check_Change_Policy__c policy,
    RHCChangeMonitorEventEnvelope eventEnvelope
  ) {
    if (!'UPDATE'.equals(eventEnvelope.changeType)) {
      return null;
    }
    Set<String> requiredFields = configuredFields(policy.ChangedFields__c);
    if (requiredFields.isEmpty()) {
      return null;
    }
    requiredFields.retainAll(eventEnvelope.changedFields);
    return requiredFields.isEmpty() ? 'CHANGED_FIELDS_NOT_MATCHED' : null;
  }

  private static Decision accepted() {
    Decision decision = new Decision();
    decision.shouldDispatch = true;
    decision.outcome = 'PENDING';
    decision.reasonCode = 'ACCEPTED';
    return decision;
  }

  private static Decision ignored(String reasonCode) {
    Decision decision = new Decision();
    decision.shouldDispatch = false;
    decision.outcome = 'IGNORED';
    decision.reasonCode = reasonCode;
    return decision;
  }

  private static Set<String> selectedChangeTypes(String value) {
    Set<String> values = new Set<String>();
    if (String.isBlank(value)) {
      return values;
    }
    for (String token : value.toUpperCase().split('[,;\\s]+')) {
      if (!String.isBlank(token)) {
        values.add(token);
      }
    }
    return values;
  }

  private static Set<String> configuredFields(String value) {
    Set<String> values = new Set<String>();
    if (String.isBlank(value)) {
      return values;
    }
    for (String line : value.split('[\\r\\n]+')) {
      if (!String.isBlank(line)) {
        values.add(line.trim());
      }
    }
    return values;
  }
}
