/**
 * Provides the least-privilege manual review and policy-validation UI contract.
 */
public with sharing class RHCActionReviewController {
  @TestVisible
  private static Boolean approvalPermissionOverride;
  @TestVisible
  private static RHCActionAsyncGateway asyncGateway = new RHCActionAsyncGateway();

  /**
   * @return Pending actions visible to the current user
   */
  @AuraEnabled(cacheable=true)
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

  /**
   * @param pendingActionId Pending action approved for execution
   */
  @AuraEnabled
  public static void runAction(Id pendingActionId) {
    requireApprovalPermission();
    if (pendingActionId == null) {
      throw new AuraHandledException('Pending Action ID is required.');
    }
    RHC_Pending_Action__c action = [
      SELECT Id, Queue_Status__c
      FROM RHC_Pending_Action__c
      WHERE Id = :pendingActionId
      WITH USER_MODE
      FOR UPDATE
    ];
    if (action.Queue_Status__c != RHCActionConstants.STATUS_PENDING_REVIEW) {
      throw new AuraHandledException('Only pending-review actions can be run.');
    }
    action.Queue_Status__c = RHCActionConstants.STATUS_QUEUED;
    action.Approved_By__c = UserInfo.getUserId();
    action.Approved_At__c = System.now();
    // Permission and user-mode visibility checks guard this package-owned
    // lifecycle transition; approvers do not need direct field edit access.
    Database.update(action, AccessLevel.SYSTEM_MODE);
    asyncGateway.enqueue(new List<Id>{ action.Id }, 0);
  }

  /**
   * @param pendingActionId Pending action to reject
   */
  @AuraEnabled
  public static void rejectAction(Id pendingActionId) {
    requireApprovalPermission();
    if (pendingActionId == null) {
      throw new AuraHandledException('Pending Action ID is required.');
    }
    RHC_Pending_Action__c action = [
      SELECT Id, Queue_Status__c
      FROM RHC_Pending_Action__c
      WHERE Id = :pendingActionId
      WITH USER_MODE
      FOR UPDATE
    ];
    if (action.Queue_Status__c != RHCActionConstants.STATUS_PENDING_REVIEW) {
      throw new AuraHandledException(
        'Only pending-review actions can be rejected.'
      );
    }
    action.Queue_Status__c = 'REJECTED';
    action.Approved_By__c = UserInfo.getUserId();
    action.Approved_At__c = System.now();
    action.Completed_At__c = System.now();
    // Permission and user-mode visibility checks guard this package-owned
    // lifecycle transition; approvers do not need direct field edit access.
    Database.update(action, AccessLevel.SYSTEM_MODE);
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
