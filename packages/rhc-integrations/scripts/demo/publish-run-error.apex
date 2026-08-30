Opportunity demoOpportunity = [SELECT Id FROM Opportunity WHERE Name = 'RHC Demo - Integration Event Reference' LIMIT 1];
String eventId = 'RHC-DEMO-RUN-ERROR-' + String.valueOf(Datetime.now().getTime());
rhc__Record_Health_Check_Set_Run__e eventRecord = new rhc__Record_Health_Check_Set_Run__e(
    rhc__EventId__c = eventId, rhc__RunId__c = 'RHC-DEMO-RUN-SUMMARY',
    rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Check_Set', rhc__RecordId__c = demoOpportunity.Id,
    rhc__EligibleCheckCount__c = 4, rhc__EvaluatedCheckCount__c = 4,
    rhc__PassedCount__c = 2, rhc__FailedCount__c = 1, rhc__SkippedCount__c = 0,
    rhc__UnableCount__c = 0, rhc__SystemErrorCount__c = 1,
    rhc__ProcessedRecordCount__c = 1, rhc__SubmittedRecordCount__c = 1,
    rhc__Phase__c = 'COMPLETED', rhc__OccurredAt__c = System.now(), rhc__Source__c = 'SYSTEM',
    rhc__ContractVersion__c = '1.0', rhc__FrameworkVersion__c = '2.0.4'
);
Database.SaveResult result = EventBus.publish(eventRecord);
System.assert(result.isSuccess(), 'The demo Run event must publish.');
System.debug(LoggingLevel.INFO, 'RHC_DEMO_EVENT_ID=' + eventId);

