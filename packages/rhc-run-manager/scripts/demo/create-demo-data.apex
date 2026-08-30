// RHC Run Manager demo setup. Safe to run repeatedly in a sandbox or scratch org.
// Creates only records whose names begin with "RHC Demo" and does not launch async work.

Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
String rhcPrefix = globalDescribe.containsKey('rhc__Record_Health_Check_Run_Definition__c')
  ? 'rhc__'
  : '';

String checkSetObject = rhcPrefix + 'Record_Health_Check_Set__mdt';
String checkSetObjectField = rhcPrefix + 'ObjectApiName__c';
String checkSetActiveField = rhcPrefix + 'IsActive__c';
String targetObjectName = 'Account';
List<SObject> accountCheckSets = Database.query(
  'SELECT QualifiedApiName, ' + checkSetObjectField +
  ' FROM ' + checkSetObject +
  ' WHERE ' + checkSetObjectField + ' = :targetObjectName' +
  ' AND ' + checkSetActiveField + ' = TRUE' +
  ' ORDER BY QualifiedApiName LIMIT 1'
);
if (accountCheckSets.isEmpty()) {
  throw new IllegalArgumentException(
    'No active Account Check Set exists in Record Health Check core. Create or activate one before loading the demo.'
  );
}
String accountCheckSetQualifiedApiName = (String) accountCheckSets[0].get('QualifiedApiName');

Set<String> accountNames = new Set<String>{
  'RHC Demo - Complete Account',
  'RHC Demo - Sparse Account',
  'RHC Demo - Previous Parent',
  'RHC Demo - Current Parent'
};
Map<String, Account> accountsByName = new Map<String, Account>();
for (Account accountRecord : [
  SELECT Id, Name, Phone, Website, Industry, Type, BillingStreet, BillingCity, BillingState,
    BillingPostalCode, BillingCountry, Description
  FROM Account
  WHERE Name IN :accountNames
]) {
  accountsByName.put(accountRecord.Name, accountRecord);
}
for (String accountName : accountNames) {
  if (!accountsByName.containsKey(accountName)) {
    accountsByName.put(accountName, new Account(Name = accountName));
  }
}

Account completeAccount = accountsByName.get('RHC Demo - Complete Account');
completeAccount.Phone = '312-555-0100';
completeAccount.Website = 'https://example.invalid/rhc-demo';
completeAccount.Industry = 'Technology';
completeAccount.Type = 'Customer - Direct';
completeAccount.BillingStreet = '100 Demo Way';
completeAccount.BillingCity = 'Chicago';
completeAccount.BillingState = 'IL';
completeAccount.BillingPostalCode = '60601';
completeAccount.BillingCountry = 'United States';
completeAccount.Description = 'RHC Demo account populated with common standard fields.';

Account sparseAccount = accountsByName.get('RHC Demo - Sparse Account');
sparseAccount.Phone = null;
sparseAccount.Website = null;
sparseAccount.Industry = null;
sparseAccount.Type = null;
sparseAccount.BillingStreet = null;
sparseAccount.BillingCity = null;
sparseAccount.BillingState = null;
sparseAccount.BillingPostalCode = null;
sparseAccount.BillingCountry = null;
sparseAccount.Description = 'RHC Demo intentionally sparse account.';

for (String parentName : new List<String>{ 'RHC Demo - Previous Parent', 'RHC Demo - Current Parent' }) {
  Account parentAccount = accountsByName.get(parentName);
  parentAccount.Phone = '312-555-0199';
  parentAccount.Website = 'https://example.invalid/rhc-parent';
  parentAccount.Industry = 'Other';
  parentAccount.Type = 'Customer - Direct';
  parentAccount.BillingCity = 'Chicago';
  parentAccount.BillingState = 'IL';
  parentAccount.BillingCountry = 'United States';
  parentAccount.Description = 'RHC Demo relationship-change parent.';
}
upsert accountsByName.values();

Set<String> demoContactLastNames = new Set<String>{
  'RHC Demo Relationship Change',
  'RHC Demo Bulk One',
  'RHC Demo Bulk Two'
};
Map<String, Contact> contactsByLastName = new Map<String, Contact>();
for (Contact contactRecord : [
  SELECT Id, FirstName, LastName, AccountId, Email
  FROM Contact
  WHERE LastName IN :demoContactLastNames
]) {
  contactsByLastName.put(contactRecord.LastName, contactRecord);
}
for (String lastName : demoContactLastNames) {
  Contact contactRecord = contactsByLastName.get(lastName);
  if (contactRecord == null) contactRecord = new Contact(FirstName = 'Demo', LastName = lastName);
  contactRecord.AccountId = accountsByName.get('RHC Demo - Previous Parent').Id;
  contactRecord.Email = lastName.replace(' ', '.').toLowerCase() + '@example.invalid';
  contactsByLastName.put(lastName, contactRecord);
}
upsert contactsByLastName.values();

String definitionObject = rhcPrefix + 'Record_Health_Check_Run_Definition__c';
String displayNameField = rhcPrefix + 'DisplayName__c';
Set<String> definitionNames = new Set<String>{
  'RHC Demo - All Accessible Accounts',
  'RHC Demo - Filtered Accounts',
  'RHC Demo - Accounts from Contact Changes'
};
Map<String, SObject> definitionsByName = new Map<String, SObject>();
for (SObject definitionRecord : Database.query(
  'SELECT Id, ' + displayNameField + ' FROM ' + definitionObject +
  ' WHERE ' + displayNameField + ' IN :definitionNames'
)) {
  definitionsByName.put((String) definitionRecord.get(displayNameField), definitionRecord);
}

List<Map<String, Object>> definitionSpecs = new List<Map<String, Object>>{
  new Map<String, Object>{
    'name' => 'RHC Demo - All Accessible Accounts',
    'population' => 'ALL_ACCESSIBLE',
    'capture' => 'FAIL',
    'filter' => null
  },
  new Map<String, Object>{
    'name' => 'RHC Demo - Filtered Accounts',
    'population' => 'GUIDED_FILTERED',
    'capture' => 'BOTH',
    'filter' => '[{"field":"Name","operator":"STARTS_WITH","value":"RHC Demo -"}]'
  },
  new Map<String, Object>{
    'name' => 'RHC Demo - Accounts from Contact Changes',
    'population' => 'SUPPLIED_IDS',
    'capture' => 'FAIL',
    'filter' => null
  }
};

List<SObject> definitionsToUpsert = new List<SObject>();
for (Map<String, Object> spec : definitionSpecs) {
  String definitionName = (String) spec.get('name');
  SObject definitionRecord = definitionsByName.get(definitionName);
  if (definitionRecord == null) {
    definitionRecord = globalDescribe.get(definitionObject).newSObject();
  }
  definitionRecord.put(displayNameField, definitionName);
  definitionRecord.put(rhcPrefix + 'Active__c', true);
  definitionRecord.put(rhcPrefix + 'SelectionType__c', 'CHECK_SET');
  definitionRecord.put(rhcPrefix + 'QualifiedApiName__c', accountCheckSetQualifiedApiName);
  definitionRecord.put(rhcPrefix + 'TargetObjectApiName__c', 'Account');
  definitionRecord.put(rhcPrefix + 'PopulationMode__c', spec.get('population'));
  definitionRecord.put(rhcPrefix + 'FilterJson__c', spec.get('filter'));
  definitionRecord.put(rhcPrefix + 'BatchSize__c', 2);
  definitionRecord.put(rhcPrefix + 'CaptureMode__c', spec.get('capture'));
  definitionRecord.put(rhcPrefix + 'CoalesceDelayMinutes__c', 1);
  definitionsToUpsert.add(definitionRecord);
}
upsert definitionsToUpsert;

definitionsByName.clear();
for (SObject definitionRecord : Database.query(
  'SELECT Id, ' + displayNameField + ' FROM ' + definitionObject +
  ' WHERE ' + displayNameField + ' IN :definitionNames'
)) {
  definitionsByName.put((String) definitionRecord.get(displayNameField), definitionRecord);
}

String scheduleObject = rhcPrefix + 'Record_Health_Check_Schedule__c';
String scheduleDefinitionField = rhcPrefix + 'RunDefinition__c';
Id filteredDefinitionId = (Id) definitionsByName.get('RHC Demo - Filtered Accounts').get('Id');
List<SObject> existingSchedules = Database.query(
  'SELECT Id FROM ' + scheduleObject +
  ' WHERE ' + scheduleDefinitionField + ' = :filteredDefinitionId LIMIT 1'
);
SObject scheduleRecord = existingSchedules.isEmpty()
  ? globalDescribe.get(scheduleObject).newSObject()
  : existingSchedules[0];
scheduleRecord.put(scheduleDefinitionField, filteredDefinitionId);
scheduleRecord.put(rhcPrefix + 'Active__c', false);
scheduleRecord.put(rhcPrefix + 'Frequency__c', 'WEEKLY');
scheduleRecord.put(rhcPrefix + 'PreferredStartTime__c', '02:00');
scheduleRecord.put(rhcPrefix + 'DayOfWeek__c', 'SUN');
upsert scheduleRecord;

System.debug(LoggingLevel.ERROR, 'RHC DEMO READY');
System.debug(LoggingLevel.ERROR, 'Account Check Set: ' + accountCheckSetQualifiedApiName);
System.debug(LoggingLevel.ERROR, 'Previous Account: ' + accountsByName.get('RHC Demo - Previous Parent').Id);
System.debug(LoggingLevel.ERROR, 'Current Account: ' + accountsByName.get('RHC Demo - Current Parent').Id);
System.debug(LoggingLevel.ERROR, 'Relationship Contact: ' + contactsByLastName.get('RHC Demo Relationship Change').Id);
for (String definitionName : definitionNames) {
  System.debug(LoggingLevel.ERROR, definitionName + ': ' + definitionsByName.get(definitionName).get('Id'));
}
