// Read-only summary of records owned by the exact demo policy and Account.

List<Account> accounts = [
  SELECT Id, Name
  FROM Account
  WHERE Name = '[RHC ACTIONS DEMO] Account Missing Primary Contact'
];
List<rhc__RHC_Action_Policy__c> policies = [
  SELECT
    Id,
    rhc__Active__c,
    rhc__Mode__c,
    rhc__Flow_API_Name__c,
    rhc__Cooldown_Minutes__c,
    rhc__Retry_Limit__c
  FROM rhc__RHC_Action_Policy__c
  WHERE
    rhc__Check_Set_Qualified_API_Name__c = 'RHC_Actions_Demo'
    AND rhc__Check_Qualified_API_Name__c = 'Account_Has_Primary_Contact'
];
Set<Id> policyIds = new Map<Id, rhc__RHC_Action_Policy__c>(policies).keySet();
List<rhc__RHC_Pending_Action__c> actions = policyIds.isEmpty()
  ? new List<rhc__RHC_Pending_Action__c>()
  : [
      SELECT
        Id,
        rhc__Event_Id__c,
        rhc__Queue_Status__c,
        rhc__Attempt_Count__c,
        rhc__Last_Error_Code__c,
        rhc__Flow_Interview_Id__c
      FROM rhc__RHC_Pending_Action__c
      WHERE rhc__Policy__c IN :policyIds
      ORDER BY CreatedDate ASC
    ];
Set<Id> actionIds = new Map<Id, rhc__RHC_Pending_Action__c>(actions).keySet();
List<rhc__RHC_Action_History__c> histories = actionIds.isEmpty()
  ? new List<rhc__RHC_Action_History__c>()
  : [
      SELECT
        Id,
        rhc__Pending_Action__c,
        rhc__Attempt_Number__c,
        rhc__Outcome__c,
        rhc__Error_Code__c,
        rhc__Flow_Interview_Id__c
      FROM rhc__RHC_Action_History__c
      WHERE rhc__Pending_Action__c IN :actionIds
      ORDER BY CreatedDate ASC
    ];
Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
List<Task> tasks = accountIds.isEmpty()
  ? new List<Task>()
  : [
      SELECT Id, Subject, Status, WhatId
      FROM Task
      WHERE
        WhatId IN :accountIds
        AND Subject = '[RHC Actions Demo] Review primary contact'
      ORDER BY CreatedDate ASC
    ];

System.debug(LoggingLevel.INFO, 'DEMO_ACCOUNTS=' + accounts);
System.debug(LoggingLevel.INFO, 'DEMO_POLICIES=' + policies);
System.debug(LoggingLevel.INFO, 'DEMO_PENDING_ACTIONS=' + actions);
System.debug(LoggingLevel.INFO, 'DEMO_ACTION_HISTORY=' + histories);
System.debug(LoggingLevel.INFO, 'DEMO_TASKS=' + tasks);
