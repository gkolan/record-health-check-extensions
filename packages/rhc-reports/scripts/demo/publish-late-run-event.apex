// Complete the late-arrival scenario only after its Result Fact has been observed.
Datetime occurredAt = Datetime.now();
rhc__Record_Health_Check_Set_Run__e eventRecord =
    new rhc__Record_Health_Check_Set_Run__e(
        rhc__EventId__c = 'RHC-DEMO-LATE-RUN-EVENT',
        rhc__RunId__c = 'RHC-DEMO-LATE-RUN',
        rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Late_Arrival',
        rhc__RecordId__c = '006000000000001AAA',
        rhc__OccurredAt__c = occurredAt,
        rhc__Source__c = 'QUEUEABLE',
        rhc__ContractVersion__c = '1.0',
        rhc__FrameworkVersion__c = '2.0.4',
        rhc__Phase__c = 'COMPLETED',
        rhc__SubmittedRecordCount__c = 1,
        rhc__ProcessedRecordCount__c = 1,
        rhc__EligibleCheckCount__c = 1,
        rhc__EvaluatedCheckCount__c = 1,
        rhc__PassedCount__c = 0,
        rhc__FailedCount__c = 1,
        rhc__SkippedCount__c = 0,
        rhc__UnableCount__c = 0,
        rhc__SystemErrorCount__c = 0
    );
EventBus.publish(eventRecord);
System.debug(LoggingLevel.INFO, 'Published the delayed Run summary.');
