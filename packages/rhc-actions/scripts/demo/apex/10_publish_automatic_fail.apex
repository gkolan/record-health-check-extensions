// Use after completing the automatic-execution safety checklist in the demo guide.

Account demoAccount = [
  SELECT Id
  FROM Account
  WHERE Name = '[RHC ACTIONS DEMO] Account Missing Primary Contact'
  LIMIT 1
];
String eventId = 'RHC-ACTIONS-DEMO-AUTO-' + demoAccount.Id;

rhc__Record_Health_Check_Result__e resultEvent = new rhc__Record_Health_Check_Result__e(
  rhc__ContractVersion__c = '1.0',
  rhc__FrameworkVersion__c = '2.0.4',
  rhc__EventId__c = eventId,
  rhc__RunId__c = 'RHC-ACTIONS-DEMO-RUN-AUTO-' + demoAccount.Id,
  rhc__CheckSetQualifiedApiName__c = 'RHC_Actions_Demo',
  rhc__CheckQualifiedApiName__c = 'Account_Has_Primary_Contact',
  rhc__Status__c = 'FAIL',
  rhc__Severity__c = 'HIGH',
  rhc__ReasonCode__c = 'AUTOMATIC_EXECUTION_DEMO',
  rhc__RecordId__c = demoAccount.Id,
  rhc__Source__c = 'APEX_API',
  rhc__OccurredAt__c = System.now(),
  rhc__ContainsRestrictedDetail__c = false
);
Database.SaveResult publishResult = EventBus.publish(resultEvent);
if (!publishResult.isSuccess()) {
  throw new IllegalArgumentException('Automatic demo event was not accepted.');
}
System.debug(LoggingLevel.INFO, 'RHC_ACTIONS_DEMO_EVENT_ID=' + eventId);
