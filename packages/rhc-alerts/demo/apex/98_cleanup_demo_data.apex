// SANDBOX/DEMO ONLY. Run before 99_cleanup_recipient_groups.apex.
Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
String namespacePrefix = globalDescribe.containsKey(
    'Record_Health_Check_Alert_Policy__c'
  )
  ? ''
  : 'rhc__';
String policyObjectApiName =
  namespacePrefix + 'Record_Health_Check_Alert_Policy__c';
String deliveryObjectApiName =
  namespacePrefix + 'Record_Health_Check_Alert_Delivery__c';
String displayNameField = namespacePrefix + 'DisplayName__c';
String eventIdField = namespacePrefix + 'EventId__c';

List<SObject> demoDeliveries = Database.query(
  'SELECT Id FROM ' +
    deliveryObjectApiName +
    ' WHERE ' +
    eventIdField +
    ' LIKE \'rhc-alerts-demo-%\''
);
if (!demoDeliveries.isEmpty()) {
  Database.delete(demoDeliveries, false);
}
List<SObject> demoPolicies = Database.query(
  'SELECT Id FROM ' +
    policyObjectApiName +
    ' WHERE ' +
    displayNameField +
    ' LIKE \'[RHC Alerts Demo]%\''
);
if (!demoPolicies.isEmpty()) {
  Database.delete(demoPolicies, false);
}

List<Opportunity> demoOpportunities = [
  SELECT Id
  FROM Opportunity
  WHERE Name = '[RHC Alerts Demo] Renewal'
];
if (!demoOpportunities.isEmpty()) {
  Database.delete(demoOpportunities, false);
}
List<Account> demoAccounts = [
  SELECT Id
  FROM Account
  WHERE Name = '[RHC Alerts Demo] Acme'
];
if (!demoAccounts.isEmpty()) {
  Database.delete(demoAccounts, false);
}
