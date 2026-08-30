/**
 * Verifies bulk-safe, idempotent, bounded canonical Log-event ingestion.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCLogsIngestionServiceTest {
    @IsTest
    static void shouldPerformNoWorkWhenDeliveryIsNullOrEmpty() {
        Integer dmlBefore = Limits.getDmlStatements();

        Test.startTest();
        RHCLogsIngestionService.ingest(null);
        RHCLogsIngestionService.ingest(new List<Record_Health_Check_Log__e>());
        Test.stopTest();

        Assert.areEqual(dmlBefore, Limits.getDmlStatements(), 'Empty deliveries must not perform DML');
        Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c], 'No Logs should be retained');
    }

    @IsTest
    static void shouldRetainAllEventsWhenBulkDeliveryCrossesTriggerBoundary() {
        List<Record_Health_Check_Log__e> events = new List<Record_Health_Check_Log__e>();
        for (Integer indexValue = 0; indexValue < 251; indexValue++) {
            events.add(RHCLogsTestDataFactory.createEvent(indexValue));
        }

        Test.startTest();
        List<Database.SaveResult> publishResults = EventBus.publish(events);
        Test.getEventBus().deliver();
        Test.stopTest();

        Assert.areEqual(251, publishResults.size(), 'Every synthetic event should be submitted');
        Assert.areEqual(
            251,
            [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c],
            'All 251 canonical Event IDs should be retained once'
        );
    }

    @IsTest
    static void shouldSuppressDuplicateWhenCanonicalEventIdIsDeliveredTwice() {
        Record_Health_Check_Log__e firstEvent = RHCLogsTestDataFactory.createEvent(1);
        Record_Health_Check_Log__e duplicateEvent = RHCLogsTestDataFactory.createEvent(2);
        duplicateEvent.EventId__c = firstEvent.EventId__c;

        Test.startTest();
        EventBus.publish(new List<Record_Health_Check_Log__e>{ firstEvent, duplicateEvent });
        Test.getEventBus().deliver();
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c],
            'A duplicate canonical Event ID must not create a second retained Log'
        );
        Record_Health_Check_Log_Settings__c settingsRecord = [
            SELECT LastDuplicateCount__c
            FROM Record_Health_Check_Log_Settings__c
            WHERE SettingsKey__c = 'Default'
            LIMIT 1
        ];
        Assert.areEqual(
            1,
            settingsRecord.LastDuplicateCount__c.intValue(),
            'The operational snapshot should expose duplicate suppression'
        );
    }

    @IsTest
    static void shouldBoundRestrictedTextWhenCanonicalFieldsExceedDestinationLimit() {
        Record_Health_Check_Log__e sourceEvent = RHCLogsTestDataFactory.createEvent(3);
        sourceEvent.Message__c = RHCLogsTestDataFactory.textOfLength(9000);
        sourceEvent.DetailsJson__c = RHCLogsTestDataFactory.textOfLength(10000);

        Test.startTest();
        EventBus.publish(sourceEvent);
        Test.getEventBus().deliver();
        Test.stopTest();

        Record_Health_Check_Diagnostic_Log__c retained = [
            SELECT Message__c, StructuredDetails__c
            FROM Record_Health_Check_Diagnostic_Log__c
            WHERE EventId__c = :sourceEvent.EventId__c
        ];
        Assert.areEqual(8000, retained.Message__c.length(), 'Message must be bounded to 8,000 characters');
        Assert.areEqual(8000, retained.StructuredDetails__c.length(), 'Details must be bounded to 8,000 characters');
    }

    @IsTest
    static void shouldPreserveNamespaceBearingIdentityAndNullsWhenOptionalValuesVary() {
        Record_Health_Check_Log__e sourceEvent = RHCLogsTestDataFactory.createEvent(4);
        sourceEvent.CheckSetDeveloperName__c = 'vendor__Exact_Set';
        sourceEvent.CheckDeveloperName__c = 'vendor__Exact_Check';
        sourceEvent.RecordId__c = null;
        sourceEvent.UserId__c = 'not-an-id';
        sourceEvent.ExceptionType__c = null;

        Test.startTest();
        EventBus.publish(sourceEvent);
        Test.getEventBus().deliver();
        Test.stopTest();

        Record_Health_Check_Diagnostic_Log__c retained = [
            SELECT CheckSetDeveloperName__c, CheckDeveloperName__c,
                   RecordId__c, RunningUserId__c, ExceptionType__c
            FROM Record_Health_Check_Diagnostic_Log__c
            WHERE EventId__c = :sourceEvent.EventId__c
        ];
        Assert.areEqual('vendor__Exact_Set', retained.CheckSetDeveloperName__c, 'Check Set identity must remain exact');
        Assert.areEqual('vendor__Exact_Check', retained.CheckDeveloperName__c, 'Check identity must remain exact');
        Assert.isNull(retained.RecordId__c, 'A missing optional Record ID should remain null');
        Assert.areEqual('not-an-id', retained.RunningUserId__c, 'An opaque optional identity should not be inferred');
        Assert.isNull(retained.ExceptionType__c, 'A missing optional exception type should remain null');
    }

    @IsTest
    static void shouldCountMalformedAndContinueWhenRequiredFieldIsMissing() {
        Record_Health_Check_Log__e malformed = RHCLogsTestDataFactory.createEvent(5);
        malformed.EventId__c = null;
        Record_Health_Check_Log__e validEvent = RHCLogsTestDataFactory.createEvent(6);

        Test.startTest();
        RHCLogsIngestionService.ingest(
            new List<Record_Health_Check_Log__e>{ malformed, validEvent }
        );
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c], 'Valid rows should continue after malformed rows');
        Record_Health_Check_Log_Settings__c settingsRecord = [
            SELECT LastIngestionFailureCount__c, LastIngestionStatus__c,
                   LastIngestionErrorCodes__c
            FROM Record_Health_Check_Log_Settings__c
            WHERE SettingsKey__c = 'Default'
        ];
        Assert.areEqual(1, settingsRecord.LastIngestionFailureCount__c.intValue(), 'Malformed row should be counted');
        Assert.areEqual('PARTIAL_FAILURE', settingsRecord.LastIngestionStatus__c, 'Operators need a clear outcome');
        Assert.areEqual('MALFORMED_CONTRACT', settingsRecord.LastIngestionErrorCodes__c, 'Operators need a safe error category');
    }

    @IsTest
    static void shouldRetainUnsupportedContractVersionForOperatorReview() {
        Record_Health_Check_Log__e sourceEvent = RHCLogsTestDataFactory.createEvent(7);
        sourceEvent.ContractVersion__c = '2.0';

        Test.startTest();
        EventBus.publish(sourceEvent);
        Test.getEventBus().deliver();
        Test.stopTest();

        Record_Health_Check_Diagnostic_Log__c retained = [
            SELECT ContractVersion__c
            FROM Record_Health_Check_Diagnostic_Log__c
            WHERE EventId__c = :sourceEvent.EventId__c
        ];
        Assert.areEqual('2.0', retained.ContractVersion__c, 'Contract drift must remain visible');
    }

    @IsTest
    static void shouldClassifyOnlyTransientDatabaseFailuresForRetry() {
        Assert.isTrue(
            RHCLogsIngestionService.isRetryable(StatusCode.UNABLE_TO_LOCK_ROW),
            'Lock contention should retry the complete idempotent delivery'
        );
        Assert.isTrue(
            RHCLogsIngestionService.isRetryable(StatusCode.UNKNOWN_EXCEPTION),
            'Unknown transient platform errors should retry'
        );
        Assert.isFalse(
            RHCLogsIngestionService.isRetryable(StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION),
            'Permanent data failures must not create a retry storm'
        );
    }
}
