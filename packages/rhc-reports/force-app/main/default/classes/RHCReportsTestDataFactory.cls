@isTest
public class RHCReportsTestDataFactory {
    public static Record_Health_Check_Set_Run__e runEvent(
        String eventId,
        Datetime occurredAt
    ) {
        return new Record_Health_Check_Set_Run__e(
            ContractVersion__c = '1.0',
            FrameworkVersion__c = '2.0.4',
            EventId__c = eventId,
            RunId__c = 'run-' + eventId,
            Phase__c = 'COMPLETED',
            CheckSetQualifiedApiName__c = 'Opportunity_Close_Readiness',
            RecordId__c = '006000000000001AAA',
            OccurredAt__c = occurredAt,
            Source__c = 'BATCH',
            EligibleCheckCount__c = 5,
            EvaluatedCheckCount__c = 5,
            PassedCount__c = 3,
            FailedCount__c = 1,
            SkippedCount__c = 0,
            UnableCount__c = 1,
            SystemErrorCount__c = 0
        );
    }
    public static Record_Health_Check_Result__e resultEvent(
        String eventId,
        String status,
        Datetime occurredAt
    ) {
        return new Record_Health_Check_Result__e(
            ContractVersion__c = '1.0',
            FrameworkVersion__c = '2.0.4',
            EventId__c = eventId,
            RunId__c = 'run-' + eventId,
            CheckSetQualifiedApiName__c = 'Opportunity_Close_Readiness',
            CheckQualifiedApiName__c = 'Close_Date_Complete',
            RecordId__c = '006000000000001AAA',
            Status__c = status,
            Severity__c = 'WARNING',
            ReasonCode__c = status == 'PASS' ? null : 'VALUE_MISSING',
            OccurredAt__c = occurredAt,
            Source__c = 'BATCH',
            ContainsRestrictedDetail__c = false
        );
    }
    public static Record_Health_Check_Report_Result__c resultFact(
        String eventId,
        String status,
        Datetime occurredAt,
        String recordId,
        String checkName
    ) {
        return new Record_Health_Check_Report_Result__c(
            EventId__c = eventId,
            RunId__c = 'run-' + eventId,
            CheckSetQualifiedApiName__c = 'Opportunity_Close_Readiness',
            CheckQualifiedApiName__c = checkName,
            RecordId__c = recordId,
            Status__c = status,
            Severity__c = 'WARNING',
            ReasonCode__c = status == 'PASS' ? null : 'VALUE_MISSING',
            OccurredAt__c = occurredAt,
            Source__c = 'BATCH',
            ContractVersion__c = '1.0',
            FrameworkVersion__c = '2.0.4'
        );
    }
    public static Record_Health_Check_Report_Run__c runFact(
        String eventId,
        Datetime occurredAt
    ) {
        return new Record_Health_Check_Report_Run__c(
            EventId__c = eventId,
            RunId__c = 'run-' + eventId,
            CheckSetQualifiedApiName__c = 'Opportunity_Close_Readiness',
            RecordId__c = '006000000000001AAA',
            OccurredAt__c = occurredAt,
            Source__c = 'BATCH',
            ContractVersion__c = '1.0',
            FrameworkVersion__c = '2.0.4',
            Phase__c = 'COMPLETED',
            EligibleCheckCount__c = 5,
            EvaluatedCheckCount__c = 5,
            PassedCount__c = 3,
            FailedCount__c = 1,
            SkippedCount__c = 0,
            UnableCount__c = 1,
            SystemErrorCount__c = 0
        );
    }
}
