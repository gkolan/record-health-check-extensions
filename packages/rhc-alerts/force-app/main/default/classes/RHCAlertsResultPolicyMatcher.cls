/** Evaluates one Result event against one exact alert policy without performing data access. */
public inherited sharing class RHCAlertsResultPolicyMatcher {
  /**
   * Evaluates exact identity, selected status, and minimum severity.
   * @param policy Active package policy candidate.
   * @param eventValue Canonical Result contract event.
   * @return True only when every configured criterion matches.
   */
  public static Boolean matches(
    Record_Health_Check_Alert_Policy__c policy,
    Record_Health_Check_Result__e eventValue
  ) {
    Boolean identityMatches = 'CHECK'.equals(policy.SelectionType__c)
      ? policy.QualifiedApiName__c == eventValue.CheckQualifiedApiName__c
      : policy.QualifiedApiName__c == eventValue.CheckSetQualifiedApiName__c;
    if (
      !identityMatches ||
      !statusValues(policy.MatchingStatuses__c).contains(eventValue.Status__c)
    ) {
      return false;
    }
    return String.isBlank(eventValue.Severity__c) ||
      severityRank(eventValue.Severity__c) >=
      severityRank(policy.MinimumSeverity__c);
  }

  private static Set<String> statusValues(String value) {
    return String.isBlank(value)
      ? new Set<String>()
      : new Set<String>(value.split(';'));
  }

  private static Integer severityRank(String value) {
    if ('CRITICAL'.equals(value)) {
      return 3;
    }
    if ('WARNING'.equals(value)) {
      return 2;
    }
    if ('INFO'.equals(value)) {
      return 1;
    }
    return 0;
  }
}
