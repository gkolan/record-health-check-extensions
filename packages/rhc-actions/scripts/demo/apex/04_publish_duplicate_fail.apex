// Publishes the same Event ID twice in one call to demonstrate policy/event idempotency.

Account demoAccount = [
  SELECT Id
  FROM Account
  WHERE Name = '[RHC ACTIONS DEMO] Account Missing Primary Contact'
  LIMIT 1
];
String eventId = 'RHC-ACTIONS-DEMO-DUPLICATE-' + demoAccount.Id;
List<rhc__Record_Health_Check_Result__e> events = new List<rhc__Record_Health_Check_Result__e>();
for (Integer index = 0; index < 2; index++) {
  events.add(
    new rhc__Record_Health_Check_Result__e(
      rhc__ContractVersion__c = '1.0',
      rhc__FrameworkVersion__c = '2.0.4',
      rhc__EventId__c = eventId,
      rhc__RunId__c = 'RHC-ACTIONS-DEMO-RUN-DUPLICATE-' + demoAccount.Id,
      rhc__CheckSetQualifiedApiName__c = 'RHC_Actions_Demo',
      rhc__CheckQualifiedApiName__c = 'Account_Has_Primary_Contact',
      rhc__Status__c = 'FAIL',
      rhc__Severity__c = 'HIGH',
      rhc__ReasonCode__c = 'DUPLICATE_DELIVERY_TEST',
      rhc__RecordId__c = demoAccount.Id,
      rhc__Source__c = 'APEX_API',
      rhc__OccurredAt__c = System.now(),
      rhc__ContainsRestrictedDetail__c = false
    )
  );
}
List<Database.SaveResult> publishResults = EventBus.publish(events);
for (Database.SaveResult publishResult : publishResults) {
  if (!publishResult.isSuccess()) {
    throw new IllegalArgumentException(
      'A duplicate demo event was not accepted for publication.'
    );
  }
}
System.debug(LoggingLevel.INFO, 'RHC_ACTIONS_DEMO_EVENT_ID=' + eventId);
System.debug(LoggingLevel.INFO, 'Expected result: one Pending Action, not two.');

