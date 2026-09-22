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
  public static List<RHCAlertsPolicyAdminService.RecipientOption> listRecipients(
    String recipientType
  ) {
    return RHCAlertsPolicyAdminService.listRecipients(recipientType);
  }

  /**
   * Lists policies visible to the current administrator.
   * @return At most 2,000 policies read in user mode.
   */
  @AuraEnabled
  public static List<Record_Health_Check_Alert_Policy__c> listPolicies() {
    return RHCAlertsPolicyAdminService.listPolicies();
  }

  /**
   * Creates or updates one validated policy in user mode.
   * @param policy Policy values supplied by the administrator interface.
   * @return Id of the inserted or updated policy.
   */
  @AuraEnabled
  public static Id savePolicy(Record_Health_Check_Alert_Policy__c policy) {
    return RHCAlertsPolicyAdminService.savePolicy(policy);
  }

  /**
   * Lists recent bounded delivery evidence without raw event payloads.
   * @return Reviewed history fields for at most 500 recent deliveries.
   */
  @AuraEnabled
  public static List<Record_Health_Check_Alert_Delivery__c> listDeliveries() {
    return RHCAlertsViewerController.listDeliveries();
  }

  /**
   * Returns the package-owned delivery-retention setting without enabling deletion.
   * @return Configured window, or the recommended default when no setting has been saved.
   */
  @AuraEnabled
  public static RHCAlertsRetentionService.Settings getRetentionSettings() {
    return RHCAlertsRetentionService.getSettings();
  }

  /**
   * Saves the singleton retention window used by explicit manual cleanup.
   * @param retentionDays Whole days from 1 through 3,650.
   */
  @AuraEnabled
  public static void saveRetentionSettings(Integer retentionDays) {
    RHCAlertsRetentionService.saveSettings(retentionDays);
  }

  /**
   * Deletes at most 1,000 oldest terminal delivery rows older than the configured window.
   * Pending delivery work is never selected. No cleanup is scheduled by this method.
   * @return Number of delivery rows deleted.
   */
  @AuraEnabled
  public static Integer purgeDeliveries() {
    return RHCAlertsRetentionService.purgeDeliveries();
  }

  /**
   * Sends one synthetic alert for a policy through its configured channel to the current user
   * only. Nothing is written to the delivery ledger and no policy recipient is contacted, so an
   * administrator can verify the channel, notification type, and message shape before activation.
   * @param policyId Policy whose channel is exercised.
   */
  @AuraEnabled
  public static void sendTestAlert(Id policyId) {
    RHCAlertsPolicyAdminService.sendTestAlert(policyId);
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

  private static AuraHandledException handled(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }
}
