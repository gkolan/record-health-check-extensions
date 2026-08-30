// Destructive sandbox-only cleanup. Run preview first and use a release/System Administrator.

List<Account> accounts = [
  SELECT Id
  FROM Account
  WHERE Name = '[RHC ACTIONS DEMO] Account Missing Primary Contact'
];
List<rhc__RHC_Action_Policy__c> policies = [
  SELECT Id
  FROM rhc__RHC_Action_Policy__c
  WHERE
    rhc__Check_Set_Qualified_API_Name__c = 'RHC_Actions_Demo'
    AND rhc__Check_Qualified_API_Name__c = 'Account_Has_Primary_Contact'
];
Set<Id> policyIds = new Map<Id, rhc__RHC_Action_Policy__c>(policies).keySet();
List<rhc__RHC_Pending_Action__c> actions = policyIds.isEmpty()
  ? new List<rhc__RHC_Pending_Action__c>()
  : [SELECT Id FROM rhc__RHC_Pending_Action__c WHERE rhc__Policy__c IN :policyIds];
Set<Id> actionIds = new Map<Id, rhc__RHC_Pending_Action__c>(actions).keySet();
List<rhc__RHC_Action_History__c> histories = actionIds.isEmpty()
  ? new List<rhc__RHC_Action_History__c>()
  : [
      SELECT Id
      FROM rhc__RHC_Action_History__c
      WHERE rhc__Pending_Action__c IN :actionIds
    ];
Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
List<Task> tasks = accountIds.isEmpty()
  ? new List<Task>()
  : [
      SELECT Id
      FROM Task
      WHERE
        WhatId IN :accountIds
        AND Subject = '[RHC Actions Demo] Review primary contact'
    ];

if (!histories.isEmpty()) {
  delete histories;
}
if (!actions.isEmpty()) {
  delete actions;
}
if (!policies.isEmpty()) {
  delete policies;
}
if (!tasks.isEmpty()) {
  delete tasks;
}
if (!accounts.isEmpty()) {
  delete accounts;
}
System.debug(LoggingLevel.INFO, 'RHC_ACTIONS_DEMO_CLEANUP_COMPLETE');
