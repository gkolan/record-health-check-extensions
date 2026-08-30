Opportunity demoOpportunity = [SELECT Id FROM Opportunity WHERE Name = 'RHC Demo - Integration Event Reference' LIMIT 1];
String eventId = 'RHC-DEMO-UNSUPPORTED-' + String.valueOf(Datetime.now().getTime());
rhc__Record_Health_Check_Result__e eventRecord = new rhc__Record_Health_Check_Result__e(
    rhc__EventId__c = eventId, rhc__RunId__c = 'RHC-DEMO-RUN-UNSUPPORTED',
    rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Check_Set',
    rhc__CheckQualifiedApiName__c = 'RHC_Demo_Check', rhc__RecordId__c = demoOpportunity.Id,
    rhc__Status__c = 'ERROR', rhc__Severity__c = 'CRITICAL',
    rhc__ReasonCode__c = 'DEMO_UNSUPPORTED_CONTRACT', rhc__OccurredAt__c = System.now(),
    rhc__Source__c = 'SYSTEM', rhc__ContractVersion__c = '2.0', rhc__FrameworkVersion__c = '2.0.4'
);
Database.SaveResult result = EventBus.publish(eventRecord);
System.assert(result.isSuccess(), 'The unsupported-contract event must publish and fail closed in Integrations.');
System.debug(LoggingLevel.INFO, 'RHC_DEMO_UNSUPPORTED_EVENT_ID=' + eventId);

