/**
 * Creates deterministic RHC Logs test data without relying on subscriber org records.
 */
@IsTest
public class RHCLogsTestDataFactory {
    /** Identifies whether a cleanup policy is enabled in test data. */
    public enum AutomationState { ENABLED, DISABLED }

    /**
     * Creates a valid canonical Log event with deterministic values.
     * @param indexValue unique numeric seed
     * @return canonical synthetic Log event
     */
    public static Record_Health_Check_Log__e createEvent(Integer indexValue) {
        return new Record_Health_Check_Log__e(
            EventId__c = 'event-' + indexValue,
            RunId__c = 'run-' + indexValue,
            OccurredAt__c = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0).addMinutes(indexValue),
            ContractVersion__c = '1.0',
            FrameworkVersion__c = '2.0.4',
            Level__c = 'ERROR',
            Code__c = 'TEST_ERROR',
            Message__c = 'Synthetic restricted message ' + indexValue,
            DetailsJson__c = '{"diagnosticId":"synthetic-' + indexValue + '"}',
            ExceptionType__c = 'System.TestException',
            RecordId__c = UserInfo.getUserId(),
            CheckSetDeveloperName__c = 'Managed__Account_Readiness',
            CheckDeveloperName__c = 'Managed__Required_Field',
            UserId__c = UserInfo.getUserId()
        );
    }

    /**
     * Creates deterministic package settings for cleanup tests.
     * @param retentionDays configured retention window
     * @param batchSize configured cleanup batch size
     * @param state enabled or disabled automation state
     * @return inserted settings singleton
     */
    public static Record_Health_Check_Log_Settings__c createSettings(
        Integer retentionDays,
        Integer batchSize,
        AutomationState state
    ) {
        Record_Health_Check_Log_Settings__c settingsRecord = new Record_Health_Check_Log_Settings__c(
            Name = 'Default',
            SettingsKey__c = 'Default',
            RetentionDays__c = retentionDays,
            CleanupBatchSize__c = batchSize,
            AutomatedCleanupEnabled__c = state == AutomationState.ENABLED
        );
        insert settingsRecord;
        return settingsRecord;
    }

    /**
     * Builds one retained Log at the supplied canonical occurrence time.
     * @param eventId canonical event identifier
     * @param occurredAt canonical occurrence time
     * @return unsaved retained Log
     */
    public static Record_Health_Check_Diagnostic_Log__c buildLog(
        String eventId,
        Datetime occurredAt
    ) {
        return new Record_Health_Check_Diagnostic_Log__c(
            EventId__c = eventId,
            RunId__c = 'run-' + eventId,
            OccurredAt__c = occurredAt,
            ContractVersion__c = '1.0',
            Severity__c = 'ERROR',
            Code__c = 'TEST_ERROR',
            IngestedAt__c = occurredAt
        );
    }

    /**
     * Creates one retained Log at the supplied canonical occurrence time.
     * @param eventId canonical event identifier
     * @param occurredAt canonical occurrence time
     * @return inserted retained Log
     */
    public static Record_Health_Check_Diagnostic_Log__c createLog(
        String eventId,
        Datetime occurredAt
    ) {
        Record_Health_Check_Diagnostic_Log__c logRecord = buildLog(eventId, occurredAt);
        insert logRecord;
        return logRecord;
    }

    /**
     * Creates a synthetic active Salesforce user.
     * @param keyValue unique test key
     * @return inserted user
     */
    public static User createUser(String keyValue) {
        Profile standardProfile = [
            SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1
        ];
        String uniqueValue = keyValue + '-' + String.valueOf(Datetime.now().getTime());
        User userRecord = new User(
            Alias = keyValue.left(8),
            Email = uniqueValue + '@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'RHC Logs ' + keyValue,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Chicago',
            Username = uniqueValue + '@example.invalid'
        );
        insert userRecord;
        return userRecord;
    }

    /**
     * Assigns a package Permission Set by developer name.
     * @param userId target user
     * @param permissionSetName permission-set developer name
     */
    public static void assignPermissionSet(Id userId, String permissionSetName) {
        PermissionSet permissionSetRecord = [
            SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = permissionSetRecord.Id
        );
    }

    /**
     * Creates deterministic text of exactly the requested length.
     * @param requestedLength required character count
     * @return deterministic text
     */
    public static String textOfLength(Integer requestedLength) {
        String value = '';
        while (value.length() < requestedLength) {
            value += '0123456789';
        }
        return value.left(requestedLength);
    }
}
