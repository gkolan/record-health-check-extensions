/** Implements policy, recipient-directory, and test-send behavior for the admin controller. */
public with sharing class RHCAlertsPolicyAdminService {
  private static final List<String> POLICY_EDITOR_FIELDS = new List<String>{
    'DisplayName__c',
    'Active__c',
    'SelectionType__c',
    'QualifiedApiName__c',
    'MatchingStatuses__c',
    'MinimumSeverity__c',
    'RecipientType__c',
    'RecipientId__c',
    'RecipientLabel__c',
    'NotificationChannel__c',
    'CooldownMinutes__c'
  };

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
   * Returns bounded human User or public Group options.
   * @param recipientType USER or PUBLIC_GROUP.
   * @return Recipient options visible to the current administrator.
   */
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
   * Lists at most 2,000 visible policies.
   * @return Policies read in user mode.
   */
  public static List<Record_Health_Check_Alert_Policy__c> listPolicies() {
    assertPolicyReadable();
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
  public static Id savePolicy(Record_Health_Check_Alert_Policy__c policy) {
    if (policy == null) {
      throw handled('Policy is required.');
    }
    String validationError = RHCAlertsPolicyValidator.validationError(policy);
    if (validationError != null) {
      throw handled(validationError);
    }
    assertPolicyWritable(policy.Id == null);
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
   * Sends one synthetic alert through the policy channel to the current user only.
   * @param policyId Policy whose channel is exercised.
   */
  public static void sendTestAlert(Id policyId) {
    if (policyId == null) {
      throw handled('Policy is required.');
    }
    assertPolicyReadable();
    List<Record_Health_Check_Alert_Policy__c> policies = [
      SELECT
        Id,
        DisplayName__c,
        SelectionType__c,
        QualifiedApiName__c,
        NotificationChannel__c
      FROM Record_Health_Check_Alert_Policy__c
      WHERE Id = :policyId
      WITH USER_MODE
      LIMIT 1
    ];
    if (policies.isEmpty()) {
      throw handled('The policy is not visible to you.');
    }
    Record_Health_Check_Alert_Delivery__c sample = new Record_Health_Check_Alert_Delivery__c(
      Policy__r = policies[0],
      CheckSetQualifiedApiName__c = policies[0].SelectionType__c == 'CHECK_SET'
        ? policies[0].QualifiedApiName__c
        : null,
      CheckQualifiedApiName__c = policies[0].SelectionType__c == 'CHECK'
        ? policies[0].QualifiedApiName__c
        : null,
      Status__c = 'TEST',
      Severity__c = 'TEST'
    );
    try {
      RHCAlertsNotificationSender.send(
        sample,
        new Set<Id>{ UserInfo.getUserId() }
      );
    } catch (RHCAlertsNotificationSender.NotificationException error) {
      throw handled('Test alert could not be sent: ' + error.getMessage());
    }
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

  // Object-level read alone is not enough: the policy editor selects every configured field, and a
  // user-mode query for a field the running user cannot read raises an untyped platform error.
  private static void assertPolicyReadable() {
    if (
      !Schema.SObjectType.Record_Health_Check_Alert_Policy__c.isAccessible()
    ) {
      throw handled('You do not have access to RHC Alerts policies.');
    }
    Map<String, Schema.SObjectField> policyFields = Record_Health_Check_Alert_Policy__c.SObjectType.getDescribe(
        SObjectDescribeOptions.DEFERRED
      )
      .fields.getMap();
    for (String fieldName : POLICY_EDITOR_FIELDS) {
      Schema.SObjectField policyField = policyFields.get(fieldName);
      if (policyField == null || !policyField.getDescribe().isAccessible()) {
        throw handled('You do not have access to RHC Alerts policies.');
      }
    }
  }

  private static void assertPolicyWritable(Boolean creating) {
    Schema.DescribeSObjectResult policyDescribe = Schema.SObjectType.Record_Health_Check_Alert_Policy__c;
    Boolean permitted = creating
      ? policyDescribe.isCreateable()
      : policyDescribe.isUpdateable();
    if (!permitted) {
      throw handled(
        'You do not have permission to configure RHC Alerts policies.'
      );
    }
  }
}
