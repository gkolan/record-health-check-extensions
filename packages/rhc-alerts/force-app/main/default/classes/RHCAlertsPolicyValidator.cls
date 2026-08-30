/** Validates package alert-policy values without performing queries or DML. */
public inherited sharing class RHCAlertsPolicyValidator {
  private static final Set<String> SELECTION_TYPES = new Set<String>{
    'CHECK_SET',
    'CHECK'
  };
  private static final Set<String> CANONICAL_STATUSES = new Set<String>{
    'PASS',
    'FAIL',
    'SKIPPED',
    'UNABLE_TO_EVALUATE',
    'ERROR'
  };
  private static final Set<String> SEVERITIES = new Set<String>{
    'INFO',
    'WARNING',
    'CRITICAL'
  };
  private static final Set<String> RECIPIENT_TYPES = new Set<String>{
    'USER',
    'PUBLIC_GROUP'
  };
  private static final Set<String> NOTIFICATION_CHANNELS = new Set<String>{
    'CUSTOM_NOTIFICATION',
    'EMAIL'
  };

  /**
   * Returns the first bounded validation error for a policy.
   * @param policy Policy values supplied through an administrator or generic edit surface.
   * @return User-safe validation message, or null when all package invariants hold.
   */
  public static String validationError(
    Record_Health_Check_Alert_Policy__c policy
  ) {
    if (policy == null) {
      return 'Policy is required.';
    }
    String errorMessage = selectionError(policy);
    if (errorMessage == null) {
      errorMessage = statusError(policy.MatchingStatuses__c);
    }
    if (errorMessage == null) {
      errorMessage = severityError(policy.MinimumSeverity__c);
    }
    if (errorMessage == null) {
      errorMessage = recipientError(policy);
    }
    return errorMessage == null ? deliveryError(policy) : errorMessage;
  }

  private static String selectionError(
    Record_Health_Check_Alert_Policy__c policy
  ) {
    if (!SELECTION_TYPES.contains(policy.SelectionType__c)) {
      return 'Choose Check Set or Check.';
    }
    return String.isBlank(policy.QualifiedApiName__c) ||
      policy.QualifiedApiName__c.length() > 120
      ? 'Choose an exact Qualified API Name.'
      : null;
  }

  private static String statusError(String matchingStatuses) {
    Set<String> statuses = String.isBlank(matchingStatuses)
      ? new Set<String>()
      : new Set<String>(matchingStatuses.split(';'));
    return statuses.isEmpty() || !CANONICAL_STATUSES.containsAll(statuses)
      ? 'Choose one or more canonical statuses.'
      : null;
  }

  private static String severityError(String minimumSeverity) {
    return SEVERITIES.contains(minimumSeverity)
      ? null
      : 'Choose a minimum severity.';
  }

  private static String recipientError(
    Record_Health_Check_Alert_Policy__c policy
  ) {
    return RECIPIENT_TYPES.contains(policy.RecipientType__c) &&
      String.isNotBlank(policy.RecipientId__c)
      ? null
      : 'Choose a human recipient.';
  }

  private static String deliveryError(
    Record_Health_Check_Alert_Policy__c policy
  ) {
    if (!NOTIFICATION_CHANNELS.contains(policy.NotificationChannel__c)) {
      return 'Choose Custom Notification or Email.';
    }
    return policy.CooldownMinutes__c == null ||
      policy.CooldownMinutes__c < 0
      ? 'Cooldown must be zero or greater.'
      : null;
  }
}
