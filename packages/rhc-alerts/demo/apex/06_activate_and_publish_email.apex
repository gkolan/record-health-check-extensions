// SANDBOX/DEMO ONLY. This script explicitly opts in to one real email attempt.
Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
String namespacePrefix = globalDescribe.containsKey(
    'Record_Health_Check_Alert_Policy__c'
  )
  ? ''
  : 'rhc__';
String policyObjectApiName =
  namespacePrefix + 'Record_Health_Check_Alert_Policy__c';
String displayNameField = namespacePrefix + 'DisplayName__c';
List<SObject> emailPolicies = Database.query(
  'SELECT Id, ' +
    namespacePrefix +
    'Active__c' +
    ' FROM ' +
    policyObjectApiName +
    ' WHERE ' +
    displayNameField +
    ' = \'[RHC Alerts Demo] Email Opt-In\'' +
    ' LIMIT 1'
);
System.assertEquals(
  1,
  emailPolicies.size(),
  'Run demo script 02 before the email script.'
);
SObject emailPolicy = emailPolicies[0];
emailPolicy.put(namespacePrefix + 'Active__c', true);
Database.update(emailPolicy);

Opportunity demoOpportunity = [
  SELECT Id
  FROM Opportunity
  WHERE Name = '[RHC Alerts Demo] Renewal'
  ORDER BY CreatedDate
  LIMIT 1
];
String eventObjectApiName = namespacePrefix + 'Record_Health_Check_Result__e';
SObject eventValue = globalDescribe.get(eventObjectApiName).newSObject();
eventValue.put(namespacePrefix + 'ContractVersion__c', '1.0');
eventValue.put(namespacePrefix + 'EventId__c', 'rhc-alerts-demo-email-v1');
eventValue.put(namespacePrefix + 'RunId__c', 'rhc-alerts-demo-run-email-v1');
eventValue.put(
  namespacePrefix + 'CheckSetQualifiedApiName__c',
  namespacePrefix + 'Example_Opportunity_Deal_Readiness'
);
eventValue.put(
  namespacePrefix + 'CheckQualifiedApiName__c',
  namespacePrefix + 'Example_Opportunity_DR_Probability'
);
eventValue.put(namespacePrefix + 'Status__c', 'FAIL');
eventValue.put(namespacePrefix + 'Severity__c', 'INFO');
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
  'The email demo event must publish successfully.'
);
