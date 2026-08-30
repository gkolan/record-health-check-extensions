// Publishes a Result before its Run plus two events that RHC Reports must reject.
Datetime occurredAt = Datetime.now();
String recordId = '006000000000001AAA';

List<rhc__Record_Health_Check_Result__e> results =
    new List<rhc__Record_Health_Check_Result__e>{
        new rhc__Record_Health_Check_Result__e(
            rhc__EventId__c = 'RHC-DEMO-LATE-RESULT',
            rhc__RunId__c = 'RHC-DEMO-LATE-RUN',
            rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Late_Arrival',
            rhc__CheckQualifiedApiName__c = 'Opportunity_Close_Date_Current',
            rhc__RecordId__c = recordId,
            rhc__Status__c = 'FAIL',
            rhc__Severity__c = 'WARNING',
            rhc__OccurredAt__c = occurredAt,
            rhc__Source__c = 'QUEUEABLE',
            rhc__ContractVersion__c = '1.0',
            rhc__FrameworkVersion__c = '2.0.4',
            rhc__ContainsRestrictedDetail__c = false
        ),
        new rhc__Record_Health_Check_Result__e(
            rhc__EventId__c = 'RHC-DEMO-RESTRICTED',
            rhc__RunId__c = 'RHC-DEMO-RESTRICTED-RUN',
            rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Rejected',
            rhc__CheckQualifiedApiName__c = 'Restricted_Detail_Check',
            rhc__RecordId__c = recordId,
            rhc__Status__c = 'ERROR',
            rhc__OccurredAt__c = occurredAt,
            rhc__Source__c = 'APEX_API',
            rhc__ContractVersion__c = '1.0',
            rhc__FrameworkVersion__c = '2.0.4',
            rhc__ContainsRestrictedDetail__c = true
        )
    };
List<rhc__Record_Health_Check_Set_Run__e> runs =
    new List<rhc__Record_Health_Check_Set_Run__e>{
        new rhc__Record_Health_Check_Set_Run__e(
            rhc__EventId__c = 'RHC-DEMO-UNSUPPORTED-CONTRACT',
            rhc__RunId__c = 'RHC-DEMO-UNSUPPORTED-CONTRACT',
            rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Rejected',
            rhc__RecordId__c = recordId,
            rhc__OccurredAt__c = occurredAt,
            rhc__Source__c = 'APEX_API',
            rhc__ContractVersion__c = '9.9',
            rhc__FrameworkVersion__c = '9.9.9',
            rhc__Phase__c = 'COMPLETED',
            rhc__SubmittedRecordCount__c = 1,
            rhc__ProcessedRecordCount__c = 1,
            rhc__EligibleCheckCount__c = 1,
            rhc__EvaluatedCheckCount__c = 1,
            rhc__PassedCount__c = 0,
            rhc__FailedCount__c = 0,
            rhc__SkippedCount__c = 0,
            rhc__UnableCount__c = 0,
            rhc__SystemErrorCount__c = 1
        )
    };
EventBus.publish(results);
EventBus.publish(runs);
System.debug(LoggingLevel.INFO, 'Published late-result and rejection test events.');
