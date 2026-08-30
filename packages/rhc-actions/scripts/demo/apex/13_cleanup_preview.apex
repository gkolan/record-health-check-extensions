// Read-only cleanup preview. The execute script uses these same exact markers.

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
Integer historyCount = actionIds.isEmpty()
  ? 0
  : [
      SELECT COUNT()
      FROM rhc__RHC_Action_History__c
      WHERE rhc__Pending_Action__c IN :actionIds
    ];
Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
Integer taskCount = accountIds.isEmpty()
  ? 0
  : [
      SELECT COUNT()
      FROM Task
      WHERE
        WhatId IN :accountIds
        AND Subject = '[RHC Actions Demo] Review primary contact'
    ];

System.debug(LoggingLevel.INFO, 'DELETE_ACCOUNT_COUNT=' + accounts.size());
System.debug(LoggingLevel.INFO, 'DELETE_POLICY_COUNT=' + policies.size());
System.debug(LoggingLevel.INFO, 'DELETE_PENDING_COUNT=' + actions.size());
System.debug(LoggingLevel.INFO, 'DELETE_HISTORY_COUNT=' + historyCount);
System.debug(LoggingLevel.INFO, 'DELETE_TASK_COUNT=' + taskCount);
