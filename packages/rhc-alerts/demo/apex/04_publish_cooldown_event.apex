// SANDBOX/DEMO ONLY. Run only after the success row from script 03 is DELIVERED.
Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
String namespacePrefix = globalDescribe.containsKey(
    'Record_Health_Check_Result__e'
  )
  ? ''
  : 'rhc__';
String eventObjectApiName = namespacePrefix + 'Record_Health_Check_Result__e';
Opportunity demoOpportunity = [
  SELECT Id
  FROM Opportunity
  WHERE Name = '[RHC Alerts Demo] Renewal'
  ORDER BY CreatedDate
  LIMIT 1
];
SObject eventValue = globalDescribe.get(eventObjectApiName).newSObject();
eventValue.put(namespacePrefix + 'ContractVersion__c', '1.0');
eventValue.put(
  namespacePrefix + 'EventId__c',
  'rhc-alerts-demo-result-cooldown-v1'
);
eventValue.put(namespacePrefix + 'RunId__c', 'rhc-alerts-demo-run-cooldown-v1');
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
Database.SaveResult result = EventBus.publish(eventValue);
System.assert(
  result.isSuccess(),
  'The cooldown demo event must publish successfully.'
);
