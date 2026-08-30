/**
 * Creates isolated RHC Actions test records.
 */
@IsTest
public class RHCActionTestDataFactory {
  /** Records Queueable requests without creating asynchronous work. */
  public class AsyncGatewayStub extends RHCActionAsyncGateway {
    public Integer enqueueCount = 0;
    public List<Id> lastPendingIds = new List<Id>();
    public Integer lastDelayMinutes;

    public override Id enqueue(List<Id> pendingIds, Integer delayMinutes) {
      enqueueCount++;
      lastPendingIds = pendingIds == null
        ? new List<Id>()
        : new List<Id>(pendingIds);
      lastDelayMinutes = delayMinutes;
      return null;
    }
  }

  /**
   * @param keyPrefix Three-character Salesforce key prefix
   * @return Stable synthetic 18-character ID for descriptor-only test data
   */
  public static String syntheticId(String keyPrefix) {
    return keyPrefix + '000000' + '000001' + 'AAA';
  }

  /**
   * Assigns the packaged administrator permissions to the test-running user.
   */
  public static void assignAdminPermission() {
    assignPermission('RHC_Actions_Admin');
  }

  /**
   * Assigns the packaged runtime permissions to the test-running user.
   */
  public static void assignRuntimePermission() {
    assignPermission('RHC_Actions_Runtime');
  }

  private static void assignPermission(String permissionSetName) {
    PermissionSet permissionSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :permissionSetName
      LIMIT 1
    ];
    Id assigneeId = UserInfo.getUserId();
    if (
      ![
          SELECT Id
          FROM PermissionSetAssignment
          WHERE AssigneeId = :assigneeId AND PermissionSetId = :permissionSet.Id
          LIMIT 1
        ]
        .isEmpty()
    ) {
      return;
    }
    insert new PermissionSetAssignment(
      AssigneeId = assigneeId,
      PermissionSetId = permissionSet.Id
    );
  }

  /**
   * @return Unsaved valid manual policy
   */
  public static RHC_Action_Policy__c policy() {
    return new RHC_Action_Policy__c(
      Active__c = true,
      Check_Set_Qualified_API_Name__c = 'Account_Health',
      Check_Qualified_API_Name__c = 'Account_Has_Primary_Contact',
      Matching_Statuses__c = 'FAIL;ERROR',
      Matching_Severity__c = 'HIGH',
      Flow_API_Name__c = 'Create_Data_Steward_Task',
      Mode__c = 'MANUAL_APPROVAL',
      Auto_Execution_Enabled__c = false,
      Cooldown_Minutes__c = 60,
      Retry_Limit__c = 1,
      Input_Contract_Version__c = '1.0',
      Map_Record_Id__c = true,
      Map_Check__c = true,
      Map_Status__c = true,
      Map_Severity__c = true,
      Map_Reason_Code__c = true,
      Map_Event_Id__c = true
    );
  }

  /**
   * @param policyId Governing policy
   * @param suffix Unique test suffix
   * @return Inserted queued pending action
   */
  public static RHC_Pending_Action__c pending(Id policyId, String suffix) {
    RHC_Pending_Action__c action = new RHC_Pending_Action__c(
      Policy__c = policyId,
      Idempotency_Key__c = String.valueOf(policyId) + ':event-' + suffix,
      Event_Id__c = 'event-' + suffix,
      Contract_Version__c = '1.0',
      Record_Id__c = syntheticId('001'),
      Run_Id__c = 'run-' + suffix,
      Check_Set_Qualified_API_Name__c = 'Account_Health',
      Check_Qualified_API_Name__c = 'Account_Has_Primary_Contact',
      Status__c = 'FAIL',
      Severity__c = 'HIGH',
      Reason_Code__c = 'NO_PRIMARY_CONTACT',
      Queue_Status__c = 'QUEUED',
      Attempt_Count__c = 0,
      Loop_Guard_Key__c = String.valueOf(policyId) + ':001000000000001AAA'
    );
    insert action;
    return action;
  }

  /**
   * @param eventId Stable event identity
   * @return Finalized core Result event
   */
  public static Record_Health_Check_Result__e eventRecord(String eventId) {
    return new Record_Health_Check_Result__e(
      ContractVersion__c = '1.0',
      FrameworkVersion__c = '2.0.4',
      EventId__c = eventId,
      RunId__c = 'run-' + eventId,
      CheckSetQualifiedApiName__c = 'Account_Health',
      CheckQualifiedApiName__c = 'Account_Has_Primary_Contact',
      Status__c = 'FAIL',
      Severity__c = 'HIGH',
      ReasonCode__c = 'NO_PRIMARY_CONTACT',
      RecordId__c = syntheticId('001'),
      Source__c = 'APEX_API',
      OccurredAt__c = System.now(),
      ContainsRestrictedDetail__c = false
    );
  }
}
