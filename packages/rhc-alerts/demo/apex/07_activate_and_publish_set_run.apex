// SANDBOX/DEMO ONLY. Demonstrates Set Run suppression plus duplicate evidence.
Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
String namespacePrefix = globalDescribe.containsKey(
    'Record_Health_Check_Alert_Policy__c'
  )
  ? ''
  : 'rhc__';
String policyObjectApiName =
  namespacePrefix + 'Record_Health_Check_Alert_Policy__c';
String displayNameField = namespacePrefix + 'DisplayName__c';
List<SObject> setPolicies = Database.query(
  'SELECT Id, ' +
    namespacePrefix +
    'Active__c' +
    ' FROM ' +
    policyObjectApiName +
    ' WHERE ' +
    displayNameField +
    ' = \'[RHC Alerts Demo] Set Run Contract Gap\'' +
    ' LIMIT 1'
);
System.assertEquals(
  1,
  setPolicies.size(),
  'Run demo script 02 before the Set Run script.'
);
SObject setPolicy = setPolicies[0];
setPolicy.put(namespacePrefix + 'Active__c', true);
Database.update(setPolicy);

Opportunity demoOpportunity = [
  SELECT Id
  FROM Opportunity
  WHERE Name = '[RHC Alerts Demo] Renewal'
  ORDER BY CreatedDate
  LIMIT 1
];
String eventObjectApiName = namespacePrefix + 'Record_Health_Check_Set_Run__e';
Schema.SObjectType eventType = globalDescribe.get(eventObjectApiName);
List<SObject> events = new List<SObject>();
for (Integer index = 0; index < 2; index++) {
  SObject eventValue = eventType.newSObject();
  eventValue.put(namespacePrefix + 'ContractVersion__c', '1.0');
  eventValue.put(
    namespacePrefix + 'EventId__c',
    'rhc-alerts-demo-set-run-duplicate-v1'
  );
  eventValue.put(namespacePrefix + 'RunId__c', 'rhc-alerts-demo-set-run-v1');
  eventValue.put(namespacePrefix + 'Phase__c', 'COMPLETED');
  eventValue.put(
    namespacePrefix + 'CheckSetQualifiedApiName__c',
    namespacePrefix + 'Example_Opportunity_Deal_Readiness'
  );
  eventValue.put(namespacePrefix + 'OccurredAt__c', System.now());
  eventValue.put(namespacePrefix + 'Source__c', 'APEX_API');
  eventValue.put(namespacePrefix + 'FrameworkVersion__c', '2.0.4');
  eventValue.put(
    namespacePrefix + 'RecordId__c',
    String.valueOf(demoOpportunity.Id)
  );
  events.add(eventValue);
}
for (Database.SaveResult result : EventBus.publish(events)) {
  System.assert(
    result.isSuccess(),
    'Every demo Set Run event must publish successfully.'
  );
}
