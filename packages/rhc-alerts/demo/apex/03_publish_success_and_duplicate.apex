// SANDBOX/DEMO ONLY. Creates one claim and one duplicate per matching active policy.
Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
String namespacePrefix = globalDescribe.containsKey(
    'Record_Health_Check_Result__e'
  )
  ? ''
  : 'rhc__';
String eventObjectApiName = namespacePrefix + 'Record_Health_Check_Result__e';
System.assert(
  globalDescribe.containsKey(eventObjectApiName),
  'Record Health Check core must be present.'
);

Opportunity demoOpportunity = [
  SELECT Id
  FROM Opportunity
  WHERE Name = '[RHC Alerts Demo] Renewal'
  ORDER BY CreatedDate
  LIMIT 1
];
Schema.SObjectType eventType = globalDescribe.get(eventObjectApiName);
List<SObject> events = new List<SObject>();
for (Integer index = 0; index < 2; index++) {
  SObject eventValue = eventType.newSObject();
  eventValue.put(namespacePrefix + 'ContractVersion__c', '1.0');
  eventValue.put(
    namespacePrefix + 'EventId__c',
    'rhc-alerts-demo-result-duplicate-v1'
  );
  eventValue.put(
    namespacePrefix + 'RunId__c',
    'rhc-alerts-demo-run-duplicate-v1'
  );
  eventValue.put(
    namespacePrefix + 'CheckSetQualifiedApiName__c',
    namespacePrefix + 'Example_Opportunity_Deal_Readiness'
  );
  eventValue.put(
    namespacePrefix + 'CheckQualifiedApiName__c',
    namespacePrefix + 'Example_Opportunity_DR_Next_Step'
  );
  eventValue.put(namespacePrefix + 'Status__c', 'FAIL');
  eventValue.put(namespacePrefix + 'Severity__c', 'WARNING');
  eventValue.put(namespacePrefix + 'OccurredAt__c', System.now());
  eventValue.put(namespacePrefix + 'Source__c', 'APEX_API');
  eventValue.put(namespacePrefix + 'FrameworkVersion__c', '2.0.4');
  eventValue.put(namespacePrefix + 'ContainsRestrictedDetail__c', false);
  eventValue.put(
    namespacePrefix + 'RecordId__c',
    String.valueOf(demoOpportunity.Id)
  );
  events.add(eventValue);
}
for (Database.SaveResult result : EventBus.publish(events)) {
  System.assert(
    result.isSuccess(),
    'Every demo Result event must publish successfully.'
  );
}
