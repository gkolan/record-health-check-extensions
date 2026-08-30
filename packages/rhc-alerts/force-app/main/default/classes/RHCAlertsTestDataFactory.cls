@IsTest
public class RHCAlertsTestDataFactory {
  /** Assigns the packaged administrator permission set to the current test user. */
  public static void assignAdminPermissions() {
    PermissionSet permissionValue = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'RHC_Alerts_Admin'
      LIMIT 1
    ];
    List<PermissionSetAssignment> existingAssignments = [
      SELECT Id
      FROM PermissionSetAssignment
      WHERE
        AssigneeId = :UserInfo.getUserId()
        AND PermissionSetId = :permissionValue.Id
      LIMIT 1
    ];
    if (existingAssignments.isEmpty()) {
      insert new PermissionSetAssignment(
        AssigneeId = UserInfo.getUserId(),
        PermissionSetId = permissionValue.Id
      );
    }
  }

  /**
   * Creates one active Check policy targeting the current human user.
   * @param qualifiedApiName Exact core Check identity.
   * @param cooldownMinutes Nonnegative cooldown duration.
   * @return Inserted package policy.
   */
  public static Record_Health_Check_Alert_Policy__c createCheckPolicy(
    String qualifiedApiName,
    Integer cooldownMinutes
  ) {
    Record_Health_Check_Alert_Policy__c policy = buildCheckPolicy(
      qualifiedApiName,
      cooldownMinutes
    );
    insert policy;
    return policy;
  }

  /**
   * Builds one valid unsaved Check policy targeting the current human user.
   * @param qualifiedApiName Exact core Check identity.
   * @param cooldownMinutes Nonnegative cooldown duration.
   * @return Unsaved valid package policy.
   */
  public static Record_Health_Check_Alert_Policy__c buildCheckPolicy(
    String qualifiedApiName,
    Integer cooldownMinutes
  ) {
    return new Record_Health_Check_Alert_Policy__c(
      DisplayName__c = 'Test policy ' + qualifiedApiName,
      Active__c = true,
      SelectionType__c = 'CHECK',
      QualifiedApiName__c = qualifiedApiName,
      MatchingStatuses__c = 'FAIL;UNABLE_TO_EVALUATE;ERROR',
      MinimumSeverity__c = 'INFO',
      RecipientType__c = 'USER',
      RecipientId__c = UserInfo.getUserId(),
      RecipientLabel__c = 'Current user',
      NotificationChannel__c = 'CUSTOM_NOTIFICATION',
      CooldownMinutes__c = cooldownMinutes
    );
  }

  /**
   * Builds active Check Set policies for bulk and fan-out boundary tests.
   * @param qualifiedApiName Exact core Check Set identity.
   * @param count Number of transient policies to build.
   * @return Unsaved package policies for bulk insertion.
   */
  public static List<Record_Health_Check_Alert_Policy__c> buildCheckSetPolicies(
    String qualifiedApiName,
    Integer count
  ) {
    List<Record_Health_Check_Alert_Policy__c> policies = new List<Record_Health_Check_Alert_Policy__c>();
    for (Integer index = 0; index < count; index++) {
      policies.add(
        new Record_Health_Check_Alert_Policy__c(
          DisplayName__c = 'Bulk policy ' + index,
          Active__c = true,
          SelectionType__c = 'CHECK_SET',
          QualifiedApiName__c = qualifiedApiName,
          MatchingStatuses__c = 'FAIL;UNABLE_TO_EVALUATE;ERROR',
          MinimumSeverity__c = 'INFO',
          RecipientType__c = 'USER',
          RecipientId__c = UserInfo.getUserId(),
          RecipientLabel__c = 'Current user',
          NotificationChannel__c = 'CUSTOM_NOTIFICATION',
          CooldownMinutes__c = 0
        )
      );
    }
    return policies;
  }

  /**
   * Creates one pending ledger row for Queueable recovery tests.
   * @param policy Parent alert policy.
   * @param eventId Stable canonical event identifier.
   * @return Inserted pending delivery ledger row.
   */
  public static Record_Health_Check_Alert_Delivery__c createPendingDelivery(
    Record_Health_Check_Alert_Policy__c policy,
    String eventId
  ) {
    Record_Health_Check_Alert_Delivery__c delivery = new Record_Health_Check_Alert_Delivery__c(
      Policy__c = policy.Id,
      EventId__c = eventId,
      EventType__c = 'RESULT',
      Outcome__c = 'PENDING',
      AttemptCount__c = 0,
      RecipientCount__c = 0,
      OccurredAt__c = System.now()
    );
    insert delivery;
    return delivery;
  }

  /**
   * Creates a canonical contract 1.0 Result event without restricted details.
   * @param eventId Stable canonical event identifier.
   * @param checkName Exact core Check identity.
   * @param recordId Checked record identifier represented as an event string.
   * @return Unsaved Platform Event test payload.
   */
  public static Record_Health_Check_Result__e resultEvent(
    String eventId,
    String checkName,
    Id recordId
  ) {
    return new Record_Health_Check_Result__e(
      ContractVersion__c = '1.0',
      EventId__c = eventId,
      RunId__c = 'run-' + eventId,
      CheckSetQualifiedApiName__c = 'pkg__Test_Set',
      CheckQualifiedApiName__c = checkName,
      Status__c = 'FAIL',
      Severity__c = 'CRITICAL',
      OccurredAt__c = System.now(),
      Source__c = 'APEX_API',
      FrameworkVersion__c = '2.0.4',
      ContainsRestrictedDetail__c = false,
      RecordId__c = String.valueOf(recordId)
    );
  }
}
