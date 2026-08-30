Opportunity demoOpportunity = [SELECT Id FROM Opportunity WHERE Name = 'RHC Demo - Integration Event Reference' LIMIT 1];
String eventId = 'RHC-DEMO-RESULT-FAIL-' + String.valueOf(Datetime.now().getTime());
rhc__Record_Health_Check_Result__e eventRecord = new rhc__Record_Health_Check_Result__e(
    rhc__EventId__c = eventId, rhc__RunId__c = 'RHC-DEMO-RUN-RESULT-FAIL',
    rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Check_Set',
    rhc__CheckQualifiedApiName__c = 'RHC_Demo_Check', rhc__RecordId__c = demoOpportunity.Id,
    rhc__Status__c = 'FAIL', rhc__Severity__c = 'WARNING',
    rhc__ReasonCode__c = 'DEMO_REQUIREMENT_NOT_MET', rhc__OccurredAt__c = System.now(),
    rhc__Source__c = 'SYSTEM', rhc__ContractVersion__c = '1.0', rhc__FrameworkVersion__c = '2.0.4'
);
Database.SaveResult result = EventBus.publish(eventRecord);
System.assert(result.isSuccess(), 'The demo Result event must publish.');
System.debug(LoggingLevel.INFO, 'RHC_DEMO_EVENT_ID=' + eventId);

