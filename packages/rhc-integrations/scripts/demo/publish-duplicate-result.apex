Opportunity demoOpportunity = [SELECT Id FROM Opportunity WHERE Name = 'RHC Demo - Integration Event Reference' LIMIT 1];
String eventId = 'RHC-DEMO-DUPLICATE-' + String.valueOf(Datetime.now().getTime());
List<rhc__Record_Health_Check_Result__e> events = new List<rhc__Record_Health_Check_Result__e>();
for (Integer index = 0; index < 2; index++) {
    events.add(new rhc__Record_Health_Check_Result__e(
        rhc__EventId__c = eventId, rhc__RunId__c = 'RHC-DEMO-RUN-DUPLICATE',
        rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Check_Set',
        rhc__CheckQualifiedApiName__c = 'RHC_Demo_Check', rhc__RecordId__c = demoOpportunity.Id,
        rhc__Status__c = 'ERROR', rhc__Severity__c = 'CRITICAL',
        rhc__ReasonCode__c = 'DEMO_DUPLICATE', rhc__OccurredAt__c = System.now(),
        rhc__Source__c = 'SYSTEM', rhc__ContractVersion__c = '1.0', rhc__FrameworkVersion__c = '2.0.4'
    ));
}
List<Database.SaveResult> results = EventBus.publish(events);
System.assertEquals(2, results.size(), 'Both duplicate source events must publish for the subscriber test.');
System.assert(results[0].isSuccess() && results[1].isSuccess(), 'Both source events must reach the event bus.');
System.debug(LoggingLevel.INFO, 'RHC_DEMO_DUPLICATE_EVENT_ID=' + eventId);

