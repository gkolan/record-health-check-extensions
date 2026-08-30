// Optional scale exercise. Creates 251 manual queue candidates; run cleanup afterward.

Account demoAccount = [
  SELECT Id
  FROM Account
  WHERE Name = '[RHC ACTIONS DEMO] Account Missing Primary Contact'
  LIMIT 1
];
List<rhc__Record_Health_Check_Result__e> events = new List<rhc__Record_Health_Check_Result__e>();
for (Integer indexNumber = 1; indexNumber <= 251; indexNumber++) {
  String suffix = String.valueOf(indexNumber).leftPad(3, '0');
  events.add(
    new rhc__Record_Health_Check_Result__e(
      rhc__ContractVersion__c = '1.0',
      rhc__FrameworkVersion__c = '2.0.4',
      rhc__EventId__c = 'RHC-ACT-DEMO-BULK-' + demoAccount.Id + '-' + suffix,
      rhc__RunId__c = 'RHC-ACTIONS-DEMO-RUN-BULK-' + demoAccount.Id + '-' + suffix,
      rhc__CheckSetQualifiedApiName__c = 'RHC_Actions_Demo',
      rhc__CheckQualifiedApiName__c = 'Account_Has_Primary_Contact',
      rhc__Status__c = 'FAIL',
      rhc__Severity__c = 'HIGH',
      rhc__ReasonCode__c = 'BULK_DEMO',
      rhc__RecordId__c = demoAccount.Id,
      rhc__Source__c = 'APEX_API',
      rhc__OccurredAt__c = System.now(),
      rhc__ContainsRestrictedDetail__c = false
    )
  );
}
List<Database.SaveResult> publishResults = EventBus.publish(events);
Integer acceptedCount = 0;
for (Database.SaveResult publishResult : publishResults) {
  if (publishResult.isSuccess()) {
    acceptedCount++;
  }
}
if (acceptedCount != 251) {
  throw new IllegalArgumentException(
    'Expected 251 accepted events but received ' + acceptedCount + '.'
  );
}
System.debug(LoggingLevel.INFO, 'RHC_ACTIONS_DEMO_BULK_ACCEPTED=' + acceptedCount);
