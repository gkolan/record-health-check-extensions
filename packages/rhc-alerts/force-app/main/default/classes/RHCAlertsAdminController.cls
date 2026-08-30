/** Secure administration endpoints for policies, setup coverage, recipients, and delivery history. */
public with sharing class RHCAlertsAdminController {
  /** Administrator-facing platform and package delivery limits. */
  public class LimitInfo {
    @AuraEnabled
    public Integer customNotificationRecipientsPerSend;
    @AuraEnabled
    public Integer emailRecipientsPerAttempt;
    @AuraEnabled
    public Integer maxAttempts;
    @AuraEnabled
    public String note;
  }

  /** Recipient picker row. */
  public class RecipientOption implements Comparable {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
    /**
     * Compares recipient options by their case-insensitive display labels.
     * @param other RecipientOption to compare with this option.
     * @return Negative, zero, or positive according to label sort order.
     */
    public Integer compareTo(Object other) {
      return label.toLowerCase()
        .compareTo(((RecipientOption) other).label.toLowerCase());
    }
  }

  /**
   * Returns exact active core definitions for the policy editor.
   * @param selectionType CHECK_SET or CHECK.
   * @return Active core definitions visible through the public metadata contract.
   */
  @AuraEnabled(cacheable=true)
  public static List<RHCAlertsCoreMetadataGateway.SelectionOption> listSelections(
    String selectionType
  ) {
    try {
      return RHCAlertsCoreMetadataGateway.listSelections(selectionType);
    } catch (Exception error) {
      throw handled('Selections could not be loaded.');
    }
  }

  /**
   * Returns human User or public Group options.
   * @param recipientType USER or PUBLIC_GROUP.
   * @return Bounded recipient options visible to the current administrator.
   */
  @AuraEnabled(cacheable=true)
  public static List<RecipientOption> listRecipients(String recipientType) {
    List<RecipientOption> options = new List<RecipientOption>();
    if ('USER'.equals(recipientType)) {
      for (User userValue : [
        SELECT Id, Name, Email
        FROM User
        WHERE IsActive = TRUE
        WITH USER_MODE
        ORDER BY Name
        LIMIT 2000
      ]) {
        options.add(
          recipient(
            userValue.Name +
            (String.isBlank(userValue.Email) ? '' : ' — ' + userValue.Email),
            userValue.Id
          )
        );
      }
    } else if ('PUBLIC_GROUP'.equals(recipientType)) {
      for (Group groupValue : [
        SELECT Id, Name
        FROM Group
        WHERE Type = 'Regular'
        WITH USER_MODE
        ORDER BY Name
        LIMIT 2000
      ]) {
        options.add(recipient(groupValue.Name, groupValue.Id));
      }
    } else {
      throw handled('Recipient Type must be USER or PUBLIC_GROUP.');
    }
    return options;
  }

  /**
   * Lists policies visible to the current administrator.
   * @return At most 2,000 policies read in user mode.
   */
  @AuraEnabled(cacheable=true)
  public static List<Record_Health_Check_Alert_Policy__c> listPolicies() {
    return [
      SELECT
        Id,
        Name,
        DisplayName__c,
        Active__c,
        SelectionType__c,
        QualifiedApiName__c,
        MatchingStatuses__c,
        MinimumSeverity__c,
        RecipientType__c,
        RecipientId__c,
        RecipientLabel__c,
        NotificationChannel__c,
        CooldownMinutes__c
      FROM Record_Health_Check_Alert_Policy__c
      WITH USER_MODE
      ORDER BY DisplayName__c, Name
      LIMIT 2000
    ];
  }

  /**
   * Creates or updates one validated policy in user mode.
   * @param policy Policy values supplied by the administrator interface.
   * @return Id of the inserted or updated policy.
   */
  @AuraEnabled
  public static Id savePolicy(Record_Health_Check_Alert_Policy__c policy) {
    if (policy == null) {
      throw handled('Policy is required.');
    }
    String validationError = RHCAlertsPolicyValidator.validationError(policy);
    if (validationError != null) {
      throw handled(validationError);
    }
    try {
      if (policy.Id == null) {
        Database.insert(policy, AccessLevel.USER_MODE);
      } else {
        Database.update(policy, AccessLevel.USER_MODE);
      }
      return policy.Id;
    } catch (DmlException error) {
      throw handled(
        'The policy could not be saved. Review field access and values.'
      );
    }
  }

  /**
   * Lists recent bounded delivery evidence without raw event payloads.
   * @return Reviewed history fields for at most 500 recent deliveries.
   */
  @AuraEnabled(cacheable=true)
  public static List<Record_Health_Check_Alert_Delivery__c> listDeliveries() {
    return RHCAlertsViewerController.listDeliveries();
  }

  /**
   * Runs the read-only setup coverage assistant.
   * @return Actionable publication-coverage findings for active policies.
   */
  @AuraEnabled(cacheable=false)
  public static List<RHCAlertsCoreMetadataGateway.CoverageGap> analyzeCoverage() {
    try {
      return RHCAlertsCoreMetadataGateway.analyzeCoverage();
    } catch (Exception error) {
      throw handled('Publication coverage could not be analyzed.');
    }
  }

  /**
   * Returns conservative package caps and directs admins to org allocation pages.
   * @return Package delivery caps and an operational-limit note.
   */
  @AuraEnabled(cacheable=true)
  public static LimitInfo getLimitInfo() {
    LimitInfo info = new LimitInfo();
    info.customNotificationRecipientsPerSend = RHCAlertsRecipientResolver.CUSTOM_NOTIFICATION_RECIPIENT_LIMIT;
    info.emailRecipientsPerAttempt = RHCAlertsRecipientResolver.EMAIL_RECIPIENT_LIMIT;
    info.maxAttempts = 3;
    info.note = 'Review Setup > Company Information for Platform Event allocations and Setup > Deliverability for email. Org, edition, license, and daily messaging limits still apply.';
    return info;
  }

  private static RecipientOption recipient(String label, Id value) {
    RecipientOption option = new RecipientOption();
    option.label = label;
    option.value = String.valueOf(value);
    return option;
  }
  private static AuraHandledException handled(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }
}
