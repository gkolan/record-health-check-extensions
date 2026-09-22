/** Builds deterministic Platform Event and reporting records for package tests. */
@IsTest
public class RHCReportsTestDataFactory {
    /**
     * Creates a least-privilege standard user for explicit-principal service tests.
     * @param stem unique username prefix
     * @return inserted standard user
     */
    public static User createStandardUser(String stem) {
        Profile profile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];
        User userRecord = new User(
            Alias = stem.left(8),
            Email = stem + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Reports Service Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Chicago',
            Username = stem + '.' + System.now().getTime() + '@example.com'
        );
        insert userRecord;
        return userRecord;
    }

    /**
     * Builds a canonical completed Set Run event.
     * @param eventId stable event identity
     * @param occurredAt event timestamp
     * @return populated Set Run event
     */
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
            RecordId__c = fakeId(Opportunity.SObjectType, 1),
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
    /**
     * Builds a canonical Check Result event.
     * @param eventId stable event identity
     * @param status result status
     * @param occurredAt event timestamp
     * @return populated Check Result event
     */
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
            RecordId__c = fakeId(Opportunity.SObjectType, 1),
            Status__c = status,
            Severity__c = 'WARNING',
            ReasonCode__c = status == 'PASS' ? null : 'VALUE_MISSING',
            OccurredAt__c = occurredAt,
            Source__c = 'BATCH',
            ContainsRestrictedDetail__c = false
        );
    }
    /**
     * Builds a stored Result fact.
     * @param request typed Result fact values
     * @return populated Result fact
     */
    public static Record_Health_Check_Report_Result__c resultFact(
        ResultFactRequest request
    ) {
        return new Record_Health_Check_Report_Result__c(
            EventId__c = request.eventId,
            RunId__c = 'run-' + request.eventId,
            CheckSetQualifiedApiName__c = 'Opportunity_Close_Readiness',
            CheckQualifiedApiName__c = 'Close_Date_Complete',
            RecordId__c = request.recordId,
            Status__c = request.status,
            Severity__c = 'WARNING',
            ReasonCode__c = request.status == 'PASS' ? null : 'VALUE_MISSING',
            OccurredAt__c = request.occurredAt,
            Source__c = 'BATCH',
            ContractVersion__c = '1.0',
            FrameworkVersion__c = '2.0.4'
        );
    }
    /**
     * Builds a stored completed Run fact.
     * @param eventId stable event identity
     * @param occurredAt event timestamp
     * @return populated Run fact
     */
    public static Record_Health_Check_Report_Run__c runFact(
        String eventId,
        Datetime occurredAt
    ) {
        return new Record_Health_Check_Report_Run__c(
            EventId__c = eventId,
            RunId__c = 'run-' + eventId,
            CheckSetQualifiedApiName__c = 'Opportunity_Close_Readiness',
            RecordId__c = fakeId(Opportunity.SObjectType, 1),
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

    /**
     * Builds a syntactically valid ID for tests without hardcoding one.
     * @param sobjectType object whose key prefix to use
     * @param sequence positive sequence number
     * @return 18-character ID string
     */
    public static String fakeId(Schema.SObjectType sobjectType, Integer sequence) {
        String suffix = String.valueOf(sequence);
        return sobjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix()
            + '0'.repeat(12 - suffix.length()) + suffix + 'AAA';
    }

    /** Typed values for a stored Result fact. */
    public class ResultFactRequest {
        private String eventId;
        private String status;
        private Datetime occurredAt;
        private String recordId;

        /**
         * Creates Result fact values with a deterministic default record ID.
         * @param eventId stable event identity
         * @param status result status
         * @param occurredAt event timestamp
         */
        public ResultFactRequest(
            String eventId,
            String status,
            Datetime occurredAt
        ) {
            this.eventId = eventId;
            this.status = status;
            this.occurredAt = occurredAt;
            this.recordId = fakeId(Opportunity.SObjectType, 1);
        }

        /**
         * Overrides the evaluated record identity.
         * @param recordId evaluated record identity
         * @return this request
         */
        public ResultFactRequest withRecord(String recordId) {
            this.recordId = recordId;
            return this;
        }
    }
}
