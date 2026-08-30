Opportunity demoOpportunity = [SELECT Id FROM Opportunity WHERE Name = 'RHC Demo - Integration Event Reference' LIMIT 1];
String eventId = 'RHC-DEMO-LOG-ERROR-' + String.valueOf(Datetime.now().getTime());
rhc__Record_Health_Check_Log__e eventRecord = new rhc__Record_Health_Check_Log__e(
    rhc__EventId__c = eventId, rhc__RunId__c = 'RHC-DEMO-RUN-LOG',
    rhc__CheckSetDeveloperName__c = 'RHC_Demo_Check_Set', rhc__CheckDeveloperName__c = 'RHC_Demo_Check',
    rhc__Level__c = 'ERROR', rhc__Code__c = 'RHC_DEMO_ERROR',
    rhc__Message__c = 'DEMO_RESTRICTED_MESSAGE_MUST_NOT_LEAVE_SALESFORCE',
    rhc__ExceptionType__c = 'DemoRestrictedException',
    rhc__StackTrace__c = 'DEMO_RESTRICTED_STACK_MUST_NOT_LEAVE_SALESFORCE',
    rhc__DetailsJson__c = '{"demoRestricted":true}', rhc__UserId__c = UserInfo.getUserId(),
    rhc__RecordId__c = demoOpportunity.Id, rhc__OccurredAt__c = System.now(),
    rhc__ContractVersion__c = '1.0', rhc__FrameworkVersion__c = '2.0.4'
);
Database.SaveResult result = EventBus.publish(eventRecord);
System.assert(result.isSuccess(), 'The demo Log event must publish.');
System.debug(LoggingLevel.INFO, 'RHC_DEMO_EVENT_ID=' + eventId);

