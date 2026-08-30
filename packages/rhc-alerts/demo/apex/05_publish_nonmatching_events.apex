// SANDBOX/DEMO ONLY. These events must create zero new delivery rows.
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
Schema.SObjectType eventType = globalDescribe.get(eventObjectApiName);
List<Map<String, String>> cases = new List<Map<String, String>>{
  new Map<String, String>{
    'eventId' => 'rhc-alerts-demo-negative-wrong-identity-v1',
    'checkName' => namespacePrefix + 'Different_Namespace_Or_Check',
    'status' => 'FAIL',
    'severity' => 'WARNING'
  },
  new Map<String, String>{
    'eventId' => 'rhc-alerts-demo-negative-status-v1',
    'checkName' => namespacePrefix + 'Example_Opportunity_DR_Next_Step',
    'status' => 'PASS',
    'severity' => ''
  },
  new Map<String, String>{
    'eventId' => 'rhc-alerts-demo-negative-severity-v1',
    'checkName' => namespacePrefix + 'Example_Opportunity_DR_Next_Step',
    'status' => 'FAIL',
    'severity' => 'INFO'
  }
};
List<SObject> events = new List<SObject>();
for (Map<String, String> caseValue : cases) {
  SObject eventValue = eventType.newSObject();
  eventValue.put(namespacePrefix + 'ContractVersion__c', '1.0');
  eventValue.put(namespacePrefix + 'EventId__c', caseValue.get('eventId'));
  eventValue.put(
    namespacePrefix + 'RunId__c',
    'rhc-alerts-demo-run-negative-v1'
  );
  eventValue.put(
    namespacePrefix + 'CheckSetQualifiedApiName__c',
    namespacePrefix + 'Example_Opportunity_Deal_Readiness'
  );
  eventValue.put(
    namespacePrefix + 'CheckQualifiedApiName__c',
    caseValue.get('checkName')
  );
  eventValue.put(namespacePrefix + 'Status__c', caseValue.get('status'));
  if (String.isNotBlank(caseValue.get('severity'))) {
    eventValue.put(namespacePrefix + 'Severity__c', caseValue.get('severity'));
  }
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
    'Every negative-control event must publish successfully.'
  );
}
