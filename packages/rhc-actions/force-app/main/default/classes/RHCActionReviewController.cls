/**
 * Provides the least-privilege manual review and policy-validation UI contract.
 */
public with sharing class RHCActionReviewController {
  private static final Integer MAX_BULK = 50;

  @TestVisible
  private static Boolean approvalPermissionOverride;
  @TestVisible
  private static RHCActionAsyncGateway asyncGateway = new RHCActionAsyncGateway();

  /**
   * Lists pending-review actions visible to the current user.
   * @return Pending actions visible to the current user
   */
  @AuraEnabled
  public static List<RHC_Pending_Action__c> getPendingActions() {
    return [
      SELECT
        Id,
        Name,
        Policy__c,
        Event_Id__c,
        Record_Id__c,
        Run_Id__c,
        Check_Set_Qualified_API_Name__c,
        Check_Qualified_API_Name__c,
        Status__c,
        Severity__c,
        Reason_Code__c,
        Queue_Status__c,
        Policy__r.Name,
        Policy__r.Flow_API_Name__c,
        CreatedDate
      FROM RHC_Pending_Action__c
      WHERE Queue_Status__c = 'PENDING_REVIEW'
      WITH USER_MODE
      ORDER BY CreatedDate ASC
      LIMIT 200
    ];
  }

  /**
   * Validates one policy for an authorized reviewer.
   * @param policyId Policy to validate
   * @return Validation result
   */
  @AuraEnabled
  public static RHCActionPolicyService.ValidationResult validatePolicy(
    Id policyId
  ) {
    requireApprovalPermission();
    if (policyId == null) {
      throw new AuraHandledException('Policy ID is required.');
    }
    RHC_Action_Policy__c policy = [
      SELECT
        Id,
        Active__c,
        Check_Qualified_API_Name__c,
        Matching_Statuses__c,
        Flow_API_Name__c,
        Mode__c,
        Auto_Execution_Enabled__c,
        Cooldown_Minutes__c,
        Retry_Limit__c,
        Input_Contract_Version__c,
        Map_Record_Id__c,
        Map_Run_Id__c,
        Map_Check_Set__c,
        Map_Check__c,
        Map_Status__c,
        Map_Severity__c,
        Map_Reason_Code__c,
        Map_Event_Id__c
      FROM RHC_Action_Policy__c
      WHERE Id = :policyId
      WITH USER_MODE
      LIMIT 1
    ];
    return RHCActionPolicyService.validate(policy);
  }

  /** Outcome of a bulk review decision. */
  public class ReviewOutcome {
    @AuraEnabled
    public Integer processed = 0;
    @AuraEnabled
    public Integer skipped = 0;
  }

  /**
   * Approves one pending action and submits it for execution.
   * @param pendingActionId Pending action approved for execution
   */
  @AuraEnabled
  public static void runAction(Id pendingActionId) {
    requireIds(new List<Id>{ pendingActionId });
    runActions(new List<Id>{ pendingActionId });
  }

  /**
   * Rejects one pending action.
   * @param pendingActionId Pending action to reject
   */
  @AuraEnabled
  public static void rejectAction(Id pendingActionId) {
    requireIds(new List<Id>{ pendingActionId });
    rejectActions(new List<Id>{ pendingActionId });
  }

  /**
   * Approves up to {@link #MAX_BULK} pending-review actions in one decision. Rows that are no
   * longer pending review are skipped, not failed. The execution service re-validates each
   * policy's Flow contract at run time, so an invalid policy fails closed there.
   * @param pendingActionIds Pending actions approved for execution
   * @return processed and skipped counts
   */
  @AuraEnabled
  public static ReviewOutcome runActions(List<Id> pendingActionIds) {
    requireApprovalPermission();
    requireIds(pendingActionIds);
    List<RHC_Pending_Action__c> actions = lockPendingReview(pendingActionIds);
    ReviewOutcome outcome = new ReviewOutcome();
    outcome.skipped = pendingActionIds.size() - actions.size();
    List<Id> queuedIds = new List<Id>();
    for (RHC_Pending_Action__c action : actions) {
      action.Queue_Status__c = RHCActionConstants.STATUS_QUEUED;
      action.Approved_By__c = UserInfo.getUserId();
      action.Approved_At__c = System.now();
      queuedIds.add(action.Id);
    }
    // Permission and user-mode visibility checks guard this package-owned
    // lifecycle transition; approvers do not need direct field edit access.
    Database.update(actions, AccessLevel.SYSTEM_MODE);
    if (!queuedIds.isEmpty()) {
      asyncGateway.enqueue(queuedIds, 0);
    }
    outcome.processed = queuedIds.size();
    return outcome;
  }

  /**
   * Rejects up to {@link #MAX_BULK} pending-review actions in one decision.
   * @param pendingActionIds Pending actions to reject
   * @return processed and skipped counts
   */
  @AuraEnabled
  public static ReviewOutcome rejectActions(List<Id> pendingActionIds) {
    requireApprovalPermission();
    requireIds(pendingActionIds);
    List<RHC_Pending_Action__c> actions = lockPendingReview(pendingActionIds);
    for (RHC_Pending_Action__c action : actions) {
      action.Queue_Status__c = 'REJECTED';
      action.Approved_By__c = UserInfo.getUserId();
      action.Approved_At__c = System.now();
      action.Completed_At__c = System.now();
    }
    Database.update(actions, AccessLevel.SYSTEM_MODE);
    ReviewOutcome outcome = new ReviewOutcome();
    outcome.processed = actions.size();
    outcome.skipped = pendingActionIds.size() - actions.size();
    return outcome;
  }

  /**
   * Returns retention settings visible to the current user.
   * @return Retention settings visible to the current user.
   */
  @AuraEnabled(cacheable=true)
  public static RHCActionRetentionService.Settings getRetentionSettings() {
    return RHCActionRetentionService.getSettings();
  }

  /**
   * Saves the audit-retention window.
   * @param retentionDays Number of days to retain completed audit records
   * @return Saved retention settings
   */
  @AuraEnabled
  public static RHCActionRetentionService.Settings saveRetentionSettings(
    Integer retentionDays
  ) {
    return RHCActionRetentionService.saveSettings(retentionDays);
  }

  /**
   * Permanently purges one bounded set of eligible audit records.
   * @return Counts for the bounded retention purge.
   */
  @AuraEnabled
  public static RHCActionRetentionService.PurgeOutcome purgeAuditRecords() {
    return RHCActionRetentionService.purge();
  }

  private static void requireIds(List<Id> pendingActionIds) {
    if (
      pendingActionIds == null ||
      pendingActionIds.isEmpty() ||
      pendingActionIds.contains(null)
    ) {
      throw new AuraHandledException('Pending Action ID is required.');
    }
    if (pendingActionIds.size() > MAX_BULK) {
      throw new AuraHandledException(
        'Review at most ' + MAX_BULK + ' actions in one decision.'
      );
    }
  }

  private static List<RHC_Pending_Action__c> lockPendingReview(
    List<Id> pendingActionIds
  ) {
    List<RHC_Pending_Action__c> actions = [
      SELECT Id, Queue_Status__c
      FROM RHC_Pending_Action__c
      WHERE
        Id IN :pendingActionIds
        AND Queue_Status__c = :RHCActionConstants.STATUS_PENDING_REVIEW
      WITH USER_MODE
      FOR UPDATE
    ];
    if (actions.isEmpty()) {
      throw new AuraHandledException(
        'Only pending-review actions can be reviewed.'
      );
    }
    return actions;
  }

  private static void requireApprovalPermission() {
    Boolean allowed = approvalPermissionOverride == null
      ? FeatureManagement.checkPermission('RHC_Actions_Approve')
      : approvalPermissionOverride;
    if (!allowed) {
      throw new AuraHandledException(
        'RHC Actions approval permission is required.'
      );
    }
  }
}
