// SANDBOX/DEMO ONLY. Run 01_seed_recipient_groups.apex first.
Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
String namespacePrefix = globalDescribe.containsKey(
    'Record_Health_Check_Alert_Policy__c'
  )
  ? ''
  : 'rhc__';
String policyObjectApiName =
  namespacePrefix + 'Record_Health_Check_Alert_Policy__c';
System.assert(
  globalDescribe.containsKey(policyObjectApiName),
  'RHC Alerts must be deployed or installed.'
);

String checkQualifiedApiName =
  namespacePrefix + 'Example_Opportunity_DR_Next_Step';
String emailCheckQualifiedApiName =
  namespacePrefix + 'Example_Opportunity_DR_Probability';
String checkSetQualifiedApiName =
  namespacePrefix + 'Example_Opportunity_Deal_Readiness';

OpportunityStage demoStage = [
  SELECT MasterLabel
  FROM OpportunityStage
  WHERE IsActive = TRUE
  ORDER BY SortOrder
  LIMIT 1
];

List<Account> accounts = [
  SELECT Id
  FROM Account
  WHERE Name = '[RHC Alerts Demo] Acme'
  ORDER BY CreatedDate
  LIMIT 1
];
Account demoAccount;
if (accounts.isEmpty()) {
  demoAccount = new Account(Name = '[RHC Alerts Demo] Acme');
  insert demoAccount;
} else {
  demoAccount = accounts[0];
}

List<Opportunity> opportunities = [
  SELECT Id, StageName, CloseDate, NextStep, Description
  FROM Opportunity
  WHERE Name = '[RHC Alerts Demo] Renewal'
  ORDER BY CreatedDate
  LIMIT 1
];
Opportunity demoOpportunity;
if (opportunities.isEmpty()) {
  demoOpportunity = new Opportunity(
    Name = '[RHC Alerts Demo] Renewal',
    AccountId = demoAccount.Id,
    StageName = demoStage.MasterLabel,
    CloseDate = Date.today().addDays(30),
    NextStep = null,
    Description = 'Sandbox-only record created by the RHC Alerts demo kit.'
  );
  insert demoOpportunity;
} else {
  demoOpportunity = opportunities[0];
  demoOpportunity.StageName = demoStage.MasterLabel;
  demoOpportunity.CloseDate = Date.today().addDays(30);
  demoOpportunity.NextStep = null;
  demoOpportunity.Description = 'Sandbox-only record created by the RHC Alerts demo kit.';
  update demoOpportunity;
}

Map<String, Group> groupsByDeveloperName = new Map<String, Group>();
for (Group groupValue : [
  SELECT Id, DeveloperName
  FROM Group
  WHERE
    DeveloperName IN (
      'RHC_Alerts_Demo_Recipients',
      'RHC_Alerts_Demo_Empty_Group'
    )
    AND Type = 'Regular'
]) {
  groupsByDeveloperName.put(groupValue.DeveloperName, groupValue);
}
System.assertEquals(
  2,
  groupsByDeveloperName.size(),
  'Run demo script 01 before script 02.'
);

Set<String> policyNames = new Set<String>{
  '[RHC Alerts Demo] Custom Notification Success',
  '[RHC Alerts Demo] Empty Group Failure',
  '[RHC Alerts Demo] Email Opt-In',
  '[RHC Alerts Demo] Set Run Contract Gap'
};
String displayNameField = namespacePrefix + 'DisplayName__c';
Map<String, SObject> existingPolicyByName = new Map<String, SObject>();
for (
  SObject policyValue : Database.query(
    'SELECT Id, ' +
      displayNameField +
      ' FROM ' +
      policyObjectApiName +
      ' WHERE ' +
      displayNameField +
      ' IN :policyNames'
  )
) {
  existingPolicyByName.put(
    (String) policyValue.get(displayNameField),
    policyValue
  );
}

List<Map<String, Object>> definitions = new List<Map<String, Object>>{
  new Map<String, Object>{
    'name' => '[RHC Alerts Demo] Custom Notification Success',
    'active' => true,
    'selectionType' => 'CHECK',
    'qualifiedName' => checkQualifiedApiName,
    'statuses' => 'FAIL;UNABLE_TO_EVALUATE;ERROR',
    'severity' => 'WARNING',
    'recipientType' => 'USER',
    'recipientId' => String.valueOf(UserInfo.getUserId()),
    'recipientLabel' => 'Current demo user',
    'channel' => 'CUSTOM_NOTIFICATION',
    'cooldown' => 1440
  },
  new Map<String, Object>{
    'name' => '[RHC Alerts Demo] Empty Group Failure',
    'active' => true,
    'selectionType' => 'CHECK',
    'qualifiedName' => checkQualifiedApiName,
    'statuses' => 'FAIL;UNABLE_TO_EVALUATE;ERROR',
    'severity' => 'WARNING',
    'recipientType' => 'PUBLIC_GROUP',
    'recipientId' => String.valueOf(
      groupsByDeveloperName.get('RHC_Alerts_Demo_Empty_Group').Id
    ),
    'recipientLabel' => '[RHC Alerts Demo] Empty Group',
    'channel' => 'CUSTOM_NOTIFICATION',
    'cooldown' => 0
  },
  new Map<String, Object>{
    'name' => '[RHC Alerts Demo] Email Opt-In',
    'active' => false,
    'selectionType' => 'CHECK',
    'qualifiedName' => emailCheckQualifiedApiName,
    'statuses' => 'FAIL',
    'severity' => 'INFO',
    'recipientType' => 'USER',
    'recipientId' => String.valueOf(UserInfo.getUserId()),
    'recipientLabel' => 'Current demo user',
    'channel' => 'EMAIL',
    'cooldown' => 0
  },
  new Map<String, Object>{
    'name' => '[RHC Alerts Demo] Set Run Contract Gap',
    'active' => false,
    'selectionType' => 'CHECK_SET',
    'qualifiedName' => checkSetQualifiedApiName,
    'statuses' => 'FAIL;UNABLE_TO_EVALUATE;ERROR',
    'severity' => 'WARNING',
    'recipientType' => 'USER',
    'recipientId' => String.valueOf(UserInfo.getUserId()),
    'recipientLabel' => 'Current demo user',
    'channel' => 'CUSTOM_NOTIFICATION',
    'cooldown' => 0
  }
};

List<SObject> policiesToUpsert = new List<SObject>();
Schema.SObjectType policyType = globalDescribe.get(policyObjectApiName);
for (Map<String, Object> definition : definitions) {
  String policyName = (String) definition.get('name');
  SObject policyValue = existingPolicyByName.containsKey(policyName)
    ? existingPolicyByName.get(policyName)
    : policyType.newSObject();
  policyValue.put(displayNameField, policyName);
  policyValue.put(namespacePrefix + 'Active__c', definition.get('active'));
  policyValue.put(
    namespacePrefix + 'SelectionType__c',
    definition.get('selectionType')
  );
  policyValue.put(
    namespacePrefix + 'QualifiedApiName__c',
    definition.get('qualifiedName')
  );
  policyValue.put(
    namespacePrefix + 'MatchingStatuses__c',
    definition.get('statuses')
  );
  policyValue.put(
    namespacePrefix + 'MinimumSeverity__c',
    definition.get('severity')
  );
  policyValue.put(
    namespacePrefix + 'RecipientType__c',
    definition.get('recipientType')
  );
  policyValue.put(
    namespacePrefix + 'RecipientId__c',
    definition.get('recipientId')
  );
  policyValue.put(
    namespacePrefix + 'RecipientLabel__c',
    definition.get('recipientLabel')
  );
  policyValue.put(
    namespacePrefix + 'NotificationChannel__c',
    definition.get('channel')
  );
  policyValue.put(
    namespacePrefix + 'CooldownMinutes__c',
    definition.get('cooldown')
  );
  policiesToUpsert.add(policyValue);
}
upsert policiesToUpsert;

System.assertEquals(
  4,
  policiesToUpsert.size(),
  'Four deterministic demo policies must be ready.'
);
