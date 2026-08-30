// RHC Actions subscriber-org demo seed. Sandbox only.
// Run after installing core + Actions, assigning permissions, and creating the demo Flow.

String accountName = '[RHC ACTIONS DEMO] Account Missing Primary Contact';
String checkSetName = 'RHC_Actions_Demo';
String checkName = 'Account_Has_Primary_Contact';

List<Account> demoAccounts = [
  SELECT Id, Name
  FROM Account
  WHERE Name = :accountName
  ORDER BY CreatedDate ASC
  LIMIT 2
];
if (demoAccounts.size() > 1) {
  throw new IllegalArgumentException(
    'More than one exact demo Account exists. Run cleanup preview before continuing.'
  );
}

Account demoAccount;
if (demoAccounts.isEmpty()) {
  demoAccount = new Account(Name = accountName);
  insert demoAccount;
} else {
  demoAccount = demoAccounts[0];
}

List<rhc__RHC_Action_Policy__c> demoPolicies = [
  SELECT Id
  FROM rhc__RHC_Action_Policy__c
  WHERE
    rhc__Check_Set_Qualified_API_Name__c = :checkSetName
    AND rhc__Check_Qualified_API_Name__c = :checkName
  ORDER BY CreatedDate ASC
  LIMIT 2
];
if (demoPolicies.size() > 1) {
  throw new IllegalArgumentException(
    'More than one exact demo policy exists. Run cleanup preview before continuing.'
  );
}

rhc__RHC_Action_Policy__c policy = demoPolicies.isEmpty()
  ? new rhc__RHC_Action_Policy__c()
  : demoPolicies[0];
policy.rhc__Active__c = true;
policy.rhc__Check_Set_Qualified_API_Name__c = checkSetName;
policy.rhc__Check_Qualified_API_Name__c = checkName;
policy.rhc__Matching_Statuses__c = 'FAIL';
policy.rhc__Matching_Severity__c = 'HIGH';
policy.rhc__Flow_API_Name__c = 'Create_Data_Steward_Task';
policy.rhc__Mode__c = 'MANUAL_APPROVAL';
policy.rhc__Auto_Execution_Enabled__c = false;
policy.rhc__Cooldown_Minutes__c = 60;
policy.rhc__Retry_Limit__c = 1;
policy.rhc__Input_Contract_Version__c = '1.0';
policy.rhc__Map_Record_Id__c = true;
policy.rhc__Map_Run_Id__c = false;
policy.rhc__Map_Check_Set__c = false;
policy.rhc__Map_Check__c = true;
policy.rhc__Map_Status__c = true;
policy.rhc__Map_Severity__c = true;
policy.rhc__Map_Reason_Code__c = true;
policy.rhc__Map_Event_Id__c = false;
upsert policy;

System.debug(LoggingLevel.INFO, 'RHC_ACTIONS_DEMO_ACCOUNT_ID=' + demoAccount.Id);
System.debug(LoggingLevel.INFO, 'RHC_ACTIONS_DEMO_POLICY_ID=' + policy.Id);
System.debug(LoggingLevel.INFO, 'RHC_ACTIONS_DEMO_SEED_COMPLETE');

