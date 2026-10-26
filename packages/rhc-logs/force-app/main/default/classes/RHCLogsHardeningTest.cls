/**
 * Proves the review query cannot be widened by hostile filter input, that retention deletes
 * exactly the rows its policy names at every boundary, and that retained Logs carry only the
 * allow-listed fields documented in SECURITY.md.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCLogsHardeningTest {
    private static final Datetime ANCHOR = Datetime.newInstanceGmt(2026, 6, 1, 12, 0, 0);
    private static final List<String> HOSTILE_FILTERS = new List<String>{
        'ERROR\' OR Severity__c != null OR \'1\'=\'1',
        '%',
        '_',
        'ERROR%',
        'ERROR\\',
        'ERROR\'; DELETE FROM Record_Health_Check_Diagnostic_Log__c --',
        '\' OR Id != null --',
        'ERROR" OR "1"="1'
    };

    @TestSetup
    static void setup() {
        User adminUser = RHCLogsTestDataFactory.createUser('hardadm');
        RHCLogsTestDataFactory.assignPermissionSet(adminUser.Id, 'RHC_Logs_Admin');
        User viewerUser = RHCLogsTestDataFactory.createUser('hardview');
        RHCLogsTestDataFactory.assignPermissionSet(viewerUser.Id, 'RHC_Logs_Viewer');
        RHCLogsTestDataFactory.createUser('hardnone');
    }

    private static User userByAlias(String aliasValue) {
        return [SELECT Id FROM User WHERE Alias = :aliasValue LIMIT 1];
    }

    @IsTest
    static void shouldNotWidenReviewResultsWhenFilterValueIsHostile() {
        User admin = userByAlias('hardadm');
        System.runAs(admin) {
            insert new List<Record_Health_Check_Diagnostic_Log__c>{
                RHCLogsTestDataFactory.buildLog('hostile-1', ANCHOR),
                RHCLogsTestDataFactory.buildLog('hostile-2', ANCHOR.addMinutes(1)),
                RHCLogsTestDataFactory.buildLog('hostile-3', ANCHOR.addMinutes(2))
            };
        }

        Test.startTest();
        System.runAs(admin) {
            RHCLogsReviewController.LogFilter matching = new RHCLogsReviewController.LogFilter();
            matching.severity = 'ERROR';
            Assert.areEqual(
                3,
                RHCLogsReviewController.search(matching).rows.size(),
                'The exact severity filter must match every seeded Log'
            );

            for (String hostileValue : HOSTILE_FILTERS) {
                RHCLogsReviewController.LogFilter filter = new RHCLogsReviewController.LogFilter();
                filter.severity = hostileValue;
                RHCLogsReviewController.LogPage page = RHCLogsReviewController.search(filter);
                Assert.areEqual(
                    0,
                    page.rows.size(),
                    'A hostile severity value must match nothing and must never widen the result set: ' +
                        hostileValue
                );
                Assert.isFalse(
                    page.hasMore,
                    'A hostile filter must not report further pages: ' + hostileValue
                );
            }
        }
        Test.stopTest();

        Assert.areEqual(
            3,
            [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c],
            'A hostile filter containing DELETE must never remove a retained Log'
        );
    }

    @IsTest
    static void shouldTreatHostileValuesAsLiteralsOnEveryTextFilter() {
        User admin = userByAlias('hardadm');
        System.runAs(admin) {
            insert RHCLogsTestDataFactory.buildLog('literal-1', ANCHOR);
        }

        Test.startTest();
        System.runAs(admin) {
            for (String hostileValue : HOSTILE_FILTERS) {
                RHCLogsReviewController.LogFilter byCode = new RHCLogsReviewController.LogFilter();
                byCode.code = hostileValue;
                Assert.areEqual(
                    0,
                    RHCLogsReviewController.search(byCode).rows.size(),
                    'Hostile Code input must be bound as a literal: ' + hostileValue
                );

                RHCLogsReviewController.LogFilter byRunId = new RHCLogsReviewController.LogFilter();
                byRunId.runId = hostileValue;
                Assert.areEqual(
                    0,
                    RHCLogsReviewController.search(byRunId).rows.size(),
                    'Hostile Run ID input must be bound as a literal: ' + hostileValue
                );

                RHCLogsReviewController.LogFilter byCheckSet = new RHCLogsReviewController.LogFilter();
                byCheckSet.checkSetDeveloperName = hostileValue;
                Assert.areEqual(
                    0,
                    RHCLogsReviewController.search(byCheckSet).rows.size(),
                    'Hostile Check Set input must be bound as a literal: ' + hostileValue
                );

                RHCLogsReviewController.LogFilter byCheck = new RHCLogsReviewController.LogFilter();
                byCheck.checkDeveloperName = hostileValue;
                Assert.areEqual(
                    0,
                    RHCLogsReviewController.search(byCheck).rows.size(),
                    'Hostile Check input must be bound as a literal: ' + hostileValue
                );
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldIgnoreBlankFilterValuesRatherThanMatchingBlankStoredValues() {
        User admin = userByAlias('hardadm');
        System.runAs(admin) {
            insert RHCLogsTestDataFactory.buildLog('blank-1', ANCHOR);
        }

        Test.startTest();
        RHCLogsReviewController.LogPage page;
        System.runAs(admin) {
            RHCLogsReviewController.LogFilter filter = new RHCLogsReviewController.LogFilter();
            filter.severity = '   ';
            filter.code = '';
            filter.runId = null;
            page = RHCLogsReviewController.search(filter);
        }
        Test.stopTest();

        Assert.areEqual(
            1,
            page.rows.size(),
            'A blank filter is an absent filter and must not be applied as an equality condition'
        );
    }

    @IsTest
    static void shouldDenyReviewWhenUserHasNoPackageAccess() {
        User unauthorized = userByAlias('hardnone');

        Test.startTest();
        System.runAs(unauthorized) {
            try {
                RHCLogsReviewController.search(new RHCLogsReviewController.LogFilter());
                Assert.fail('A user without package object access must not read retained Logs');
            } catch (Exception error) {
                Assert.isInstanceOfType(
                    error,
                    AuraHandledException.class,
                    'Denial must be a typed AuraHandledException'
                );
                Assert.areEqual(
                    'You do not have access to RHC Diagnostic Logs.',
                    error.getMessage(),
                    'The denial message must be stable and actionable'
                );
                assertNoSensitiveDetail(error.getMessage());
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldDenyCleanupAndSettingsWhenUserHasNoPackageAccess() {
        User unauthorized = userByAlias('hardnone');

        Test.startTest();
        System.runAs(unauthorized) {
            try {
                RHCLogsAdminController.getStatus();
                Assert.fail('A user without settings access must not load the setup status');
            } catch (Exception error) {
                Assert.isInstanceOfType(
                    error,
                    AuraHandledException.class,
                    'Setup denial must be typed'
                );
                assertNoSensitiveDetail(error.getMessage());
            }
            try {
                RHCLogsAdminController.runCleanup();
                Assert.fail('A user without settings access must not trigger retention cleanup');
            } catch (Exception error) {
                Assert.isInstanceOfType(
                    error,
                    AuraHandledException.class,
                    'Cleanup denial must be typed'
                );
                assertNoSensitiveDetail(error.getMessage());
            }
        }
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Log_Settings__c],
            'A denied call must not create the settings singleton'
        );
    }

    @IsTest
    static void shouldDeleteStrictlyOlderThanCutoffAtEveryBoundary() {
        User admin = userByAlias('hardadm');
        Datetime cutoff = ANCHOR.addDays(-30);

        System.runAs(admin) {
            RHCLogsTestDataFactory.createSettings(
                30,
                100,
                RHCLogsTestDataFactory.AutomationState.ENABLED
            );
            insert new List<Record_Health_Check_Diagnostic_Log__c>{
                RHCLogsTestDataFactory.buildLog('one-second-before', cutoff.addSeconds(-1)),
                RHCLogsTestDataFactory.buildLog('exactly-at-cutoff', cutoff),
                RHCLogsTestDataFactory.buildLog('one-second-after', cutoff.addSeconds(1))
            };
        }

        Test.startTest();
        RHCLogsCleanupService.CleanupResult result;
        System.runAs(admin) {
            RHCLogsCleanupService.nowOverride = ANCHOR;
            result = RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.MANUAL);
        }
        Test.stopTest();

        Set<String> survivors = new Set<String>();
        for (Record_Health_Check_Diagnostic_Log__c row : [
            SELECT EventId__c FROM Record_Health_Check_Diagnostic_Log__c
        ]) {
            survivors.add(row.EventId__c);
        }

        Assert.areEqual('SUCCESS', result.status, 'Configured manual cleanup should succeed');
        Assert.areEqual(cutoff, result.cutoff, 'The reported cutoff must be now minus the retention window');
        Assert.areEqual(1, result.deletedCount, 'Exactly one row lies strictly before the cutoff');
        Assert.areEqual(
            new Set<String>{ 'exactly-at-cutoff', 'one-second-after' },
            survivors,
            'Retention is strictly older-than, so the row exactly at the cutoff must survive'
        );
        Assert.isFalse(
            survivors.contains('one-second-before'),
            'The row one second before the cutoff must be deleted'
        );
    }

    @IsTest
    static void shouldDeleteNothingWhenEveryLogIsInsideTheWindow() {
        User admin = userByAlias('hardadm');

        System.runAs(admin) {
            RHCLogsTestDataFactory.createSettings(
                365,
                100,
                RHCLogsTestDataFactory.AutomationState.ENABLED
            );
            insert new List<Record_Health_Check_Diagnostic_Log__c>{
                RHCLogsTestDataFactory.buildLog('fresh-1', ANCHOR.addDays(-1)),
                RHCLogsTestDataFactory.buildLog('fresh-2', ANCHOR.addDays(-364))
            };
        }

        Test.startTest();
        RHCLogsCleanupService.CleanupResult result;
        System.runAs(admin) {
            RHCLogsCleanupService.nowOverride = ANCHOR;
            result = RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.MANUAL);
        }
        Test.stopTest();

        Assert.areEqual('SUCCESS', result.status, 'A cleanup that matches nothing still succeeds');
        Assert.areEqual(0, result.deletedCount, 'No row outside the window means no deletion');
        Assert.areEqual(
            2,
            [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c],
            'Every in-window audit row must survive, since an off-by-one here destroys customer data'
        );
    }

    @IsTest
    static void shouldFailClosedWhenRetentionPolicyIsOutOfRange() {
        User admin = userByAlias('hardadm');

        Test.startTest();
        System.runAs(admin) {
            Record_Health_Check_Log_Settings__c settingsRecord = RHCLogsTestDataFactory.createSettings(
                30,
                100,
                RHCLogsTestDataFactory.AutomationState.ENABLED
            );
            insert RHCLogsTestDataFactory.buildLog('misconfig-1', ANCHOR.addDays(-400));
            RHCLogsCleanupService.nowOverride = ANCHOR;

            assertRetentionFailsClosed(settingsRecord, null);
            assertRetentionFailsClosed(settingsRecord, 0);
            assertRetentionFailsClosed(settingsRecord, -5);
            assertRetentionFailsClosed(settingsRecord, 366);
        }
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c],
            'A misconfigured policy must never delete an expired row by accident'
        );
    }

    private static void assertRetentionFailsClosed(
        Record_Health_Check_Log_Settings__c settingsRecord,
        Integer invalidWindow
    ) {
        settingsRecord.RetentionDays__c = invalidWindow;
        update settingsRecord;
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(
            RHCLogsCleanupService.CleanupMode.MANUAL
        );
        Assert.areEqual(
            'DISABLED_OR_UNCONFIGURED',
            result.status,
            'An out-of-range retention window must fail closed: ' + invalidWindow
        );
        Assert.areEqual(
            0,
            result.deletedCount,
            'An invalid policy must delete nothing rather than everything: ' + invalidWindow
        );
    }

    @IsTest
    static void shouldFailClosedWhenCleanupBatchSizeIsOutOfRange() {
        User admin = userByAlias('hardadm');

        Test.startTest();
        System.runAs(admin) {
            Record_Health_Check_Log_Settings__c settingsRecord = RHCLogsTestDataFactory.createSettings(
                30,
                100,
                RHCLogsTestDataFactory.AutomationState.ENABLED
            );
            insert RHCLogsTestDataFactory.buildLog('batch-misconfig', ANCHOR.addDays(-400));
            RHCLogsCleanupService.nowOverride = ANCHOR;

            assertBatchSizeFailsClosed(settingsRecord, null);
            assertBatchSizeFailsClosed(settingsRecord, 0);
            assertBatchSizeFailsClosed(settingsRecord, -1);
            assertBatchSizeFailsClosed(settingsRecord, 9999);
        }
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c],
            'The expired row must remain until a safe policy is configured'
        );
    }

    private static void assertBatchSizeFailsClosed(
        Record_Health_Check_Log_Settings__c settingsRecord,
        Integer invalidSize
    ) {
        settingsRecord.CleanupBatchSize__c = invalidSize;
        update settingsRecord;
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(
            RHCLogsCleanupService.CleanupMode.MANUAL
        );
        Assert.areEqual(
            'DISABLED_OR_UNCONFIGURED',
            result.status,
            'An unsafe batch size must fail closed: ' + invalidSize
        );
        Assert.areEqual(
            0,
            result.deletedCount,
            'An unsafe batch size must delete nothing: ' + invalidSize
        );
    }

    @IsTest
    static void shouldRetainOnlyAllowListedFieldsFromACanonicalEvent() {
        Record_Health_Check_Log__e sourceEvent = RHCLogsTestDataFactory.createEvent(1);

        Test.startTest();
        EventBus.publish(sourceEvent);
        Test.getEventBus().deliver();
        Test.stopTest();

        Record_Health_Check_Diagnostic_Log__c retained = [
            SELECT
                EventId__c, RunId__c, OccurredAt__c, ContractVersion__c, FrameworkVersion__c,
                Severity__c, Code__c, Message__c, StructuredDetails__c, ExceptionType__c,
                RecordId__c, CheckSetDeveloperName__c, CheckDeveloperName__c,
                RunningUserId__c, IngestedAt__c
            FROM Record_Health_Check_Diagnostic_Log__c
            LIMIT 1
        ];

        Assert.areEqual('event-1', retained.EventId__c, 'The canonical Event ID is retained verbatim');
        Assert.areEqual('1.0', retained.ContractVersion__c, 'Contract Version keeps drift visible');
        Assert.areEqual(
            sourceEvent.DetailsJson__c,
            retained.StructuredDetails__c,
            'Structured Diagnostic Details is retained verbatim, which is why SECURITY.md restricts it to Admin'
        );
        Assert.isNotNull(retained.IngestedAt__c, 'Ingestion time is stamped by the package, not the event');
        Assert.areEqual(
            UserInfo.getUserId(),
            retained.RunningUserId__c,
            'Running User ID identifies a principal and is Admin-only by documented contract'
        );
        Map<String, Object> populated = retained.getPopulatedFieldsAsMap();
        Assert.isFalse(
            populated.containsKey('Level__c'),
            'The event Level field is mapped to Severity and is not stored under its event name'
        );
        Assert.isFalse(
            populated.containsKey('DetailsJson__c'),
            'The raw event field name must not exist on the retained object'
        );
    }

    @IsTest
    static void shouldBoundEveryCopiedTextFieldAtItsDestinationLength() {
        Record_Health_Check_Log__e oversized = RHCLogsTestDataFactory.createEvent(2);
        oversized.EventId__c = RHCLogsTestDataFactory.textOfLength(200);
        oversized.RunId__c = RHCLogsTestDataFactory.textOfLength(300);
        oversized.Code__c = RHCLogsTestDataFactory.textOfLength(400);
        oversized.ExceptionType__c = RHCLogsTestDataFactory.textOfLength(400);
        oversized.CheckSetDeveloperName__c = RHCLogsTestDataFactory.textOfLength(400);
        oversized.CheckDeveloperName__c = RHCLogsTestDataFactory.textOfLength(400);
        oversized.Message__c = RHCLogsTestDataFactory.textOfLength(9000);
        oversized.DetailsJson__c = RHCLogsTestDataFactory.textOfLength(9000);

        // The canonical event's own short-text fields are capped at the same lengths as the
        // retained object, so an over-length value cannot be published. Ingesting the in-memory
        // event directly proves the package still truncates if a future core contract widens them.
        Test.startTest();
        RHCLogsIngestionService.ingest(new List<Record_Health_Check_Log__e>{ oversized });
        Test.stopTest();

        Record_Health_Check_Diagnostic_Log__c retained = [
            SELECT
                EventId__c, RunId__c, Code__c, ExceptionType__c, Message__c,
                StructuredDetails__c, CheckSetDeveloperName__c, CheckDeveloperName__c
            FROM Record_Health_Check_Diagnostic_Log__c
            LIMIT 1
        ];

        Assert.areEqual(80, retained.EventId__c.length(), 'Event ID is bounded at 80 characters');
        Assert.areEqual(120, retained.RunId__c.length(), 'Run ID is bounded at 120 characters');
        Assert.areEqual(120, retained.Code__c.length(), 'Code is bounded at 120 characters');
        Assert.areEqual(120, retained.ExceptionType__c.length(), 'Exception Type is bounded at 120 characters');
        Assert.areEqual(
            120,
            retained.CheckSetDeveloperName__c.length(),
            'Check Set Developer Name is bounded at 120 characters'
        );
        Assert.areEqual(
            120,
            retained.CheckDeveloperName__c.length(),
            'Check Developer Name is bounded at 120 characters'
        );
        Assert.areEqual(8000, retained.Message__c.length(), 'Message is bounded at 8,000 characters');
        Assert.areEqual(
            8000,
            retained.StructuredDetails__c.length(),
            'Structured Diagnostic Details is bounded at 8,000 characters'
        );
    }

    @IsTest
    static void shouldHideRestrictedPayloadFieldsFromTheViewerPersona() {
        User admin = userByAlias('hardadm');
        User viewer = userByAlias('hardview');
        System.runAs(admin) {
            Record_Health_Check_Diagnostic_Log__c logRecord = RHCLogsTestDataFactory.buildLog(
                'restricted-1',
                ANCHOR
            );
            logRecord.Message__c = 'secret-payload-fragment';
            logRecord.StructuredDetails__c = '{"secret":"payload"}';
            logRecord.RecordId__c = String.valueOf(UserInfo.getUserId());
            logRecord.RunningUserId__c = String.valueOf(UserInfo.getUserId());
            insert logRecord;
        }

        Test.startTest();
        RHCLogsReviewController.LogPage viewerPage;
        System.runAs(viewer) {
            viewerPage = RHCLogsReviewController.search(new RHCLogsReviewController.LogFilter());
        }
        Test.stopTest();

        Assert.areEqual(1, viewerPage.rows.size(), 'The Viewer sees the row through View All Records');
        Map<String, Object> visible = viewerPage.rows[0].getPopulatedFieldsAsMap();
        for (String restrictedField : new List<String>{
            'Message__c', 'StructuredDetails__c', 'RecordId__c', 'RunningUserId__c'
        }) {
            Assert.isFalse(
                hasLocalKey(visible, restrictedField),
                'The Viewer must never receive the restricted field ' + restrictedField
            );
        }
        Assert.isTrue(
            hasLocalKey(visible, 'Code__c'),
            'The Viewer still receives the non-restricted triage fields'
        );
    }

    @IsTest
    static void shouldKeepIngestionQueryCountFlatAcrossTheTriggerBatchBoundary() {
        List<Record_Health_Check_Log__e> smallBatch = new List<Record_Health_Check_Log__e>();
        for (Integer index = 0; index < 1; index++) {
            smallBatch.add(RHCLogsTestDataFactory.createEvent(index));
        }
        List<Record_Health_Check_Log__e> largeBatch = new List<Record_Health_Check_Log__e>();
        for (Integer index = 100; index < 351; index++) {
            largeBatch.add(RHCLogsTestDataFactory.createEvent(index));
        }

        Test.startTest();
        Integer beforeSmall = Limits.getQueries();
        Integer dmlBeforeSmall = Limits.getDmlStatements();
        RHCLogsIngestionService.ingest(smallBatch);
        Integer smallQueries = Limits.getQueries() - beforeSmall;
        Integer smallDml = Limits.getDmlStatements() - dmlBeforeSmall;

        Integer beforeLarge = Limits.getQueries();
        Integer dmlBeforeLarge = Limits.getDmlStatements();
        RHCLogsIngestionService.ingest(largeBatch);
        Integer largeQueries = Limits.getQueries() - beforeLarge;
        Integer largeDml = Limits.getDmlStatements() - dmlBeforeLarge;
        Test.stopTest();

        Assert.areEqual(
            smallQueries,
            largeQueries,
            'Query count must stay flat from 1 to 251 events, proving no SOQL runs per event'
        );
        Assert.areEqual(
            smallDml,
            largeDml,
            'DML count must stay flat from 1 to 251 events, proving no DML runs per event'
        );
        Assert.areEqual(
            252,
            [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c],
            'Every event across both deliveries must be retained exactly once'
        );
    }

    @IsTest
    static void shouldPerformNoWorkWhenEventDeliveryIsEmptyOrNull() {
        Test.startTest();
        RHCLogsIngestionService.ingest(null);
        RHCLogsIngestionService.ingest(new List<Record_Health_Check_Log__e>());
        Integer queriesUsed = Limits.getQueries();
        Integer dmlUsed = Limits.getDmlStatements();
        Test.stopTest();

        Assert.areEqual(0, queriesUsed, 'An absent delivery must return before querying');
        Assert.areEqual(0, dmlUsed, 'An absent delivery must perform no DML');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Log_Settings__c],
            'An absent delivery must not create an operational snapshot'
        );
    }

    @IsTest
    static void shouldRejectEveryMalformedEventWithoutRetainingAnything() {
        Record_Health_Check_Log__e missingEventId = RHCLogsTestDataFactory.createEvent(10);
        missingEventId.EventId__c = null;
        Record_Health_Check_Log__e missingRunId = RHCLogsTestDataFactory.createEvent(11);
        missingRunId.RunId__c = '   ';
        Record_Health_Check_Log__e missingOccurredAt = RHCLogsTestDataFactory.createEvent(12);
        missingOccurredAt.OccurredAt__c = null;
        Record_Health_Check_Log__e missingContract = RHCLogsTestDataFactory.createEvent(13);
        missingContract.ContractVersion__c = null;
        Record_Health_Check_Log__e missingLevel = RHCLogsTestDataFactory.createEvent(14);
        missingLevel.Level__c = null;

        Test.startTest();
        RHCLogsIngestionService.ingest(
            new List<Record_Health_Check_Log__e>{
                missingEventId, missingRunId, missingOccurredAt, missingContract, missingLevel
            }
        );
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c],
            'An event missing a required contract field must never be retained'
        );
        Record_Health_Check_Log_Settings__c snapshot = [
            SELECT LastIngestionStatus__c, LastIngestionFailureCount__c,
                   LastIngestionCount__c, LastIngestionErrorCodes__c
            FROM Record_Health_Check_Log_Settings__c
            LIMIT 1
        ];
        Assert.areEqual(
            'PARTIAL_FAILURE',
            snapshot.LastIngestionStatus__c,
            'Malformed input must be visible to operators rather than silently dropped'
        );
        Assert.areEqual(
            5,
            snapshot.LastIngestionFailureCount__c,
            'Every malformed event must be counted'
        );
        Assert.areEqual(0, snapshot.LastIngestionCount__c, 'Nothing was retained');
        Assert.areEqual(
            'MALFORMED_CONTRACT',
            snapshot.LastIngestionErrorCodes__c,
            'The operator-facing code must be the stable bounded package constant'
        );
    }

    @IsTest
    static void shouldRetainUnparseableDetailsJsonVerbatimWithoutFailing() {
        Record_Health_Check_Log__e brokenJson = RHCLogsTestDataFactory.createEvent(20);
        brokenJson.DetailsJson__c = '{"unterminated": [1,2,{"deep":{"deeper":';

        Test.startTest();
        RHCLogsIngestionService.ingest(new List<Record_Health_Check_Log__e>{ brokenJson });
        Test.stopTest();

        Record_Health_Check_Diagnostic_Log__c retained = [
            SELECT StructuredDetails__c FROM Record_Health_Check_Diagnostic_Log__c LIMIT 1
        ];
        Assert.areEqual(
            brokenJson.DetailsJson__c,
            retained.StructuredDetails__c,
            'The package stores details as opaque text and must never parse or reject it'
        );
    }

    @IsTest
    static void shouldNotLeakPayloadOrPrincipalDetailInOperatorErrorCodes() {
        Record_Health_Check_Log__e malformed = RHCLogsTestDataFactory.createEvent(30);
        malformed.EventId__c = null;
        malformed.Message__c = 'sensitive-payload-fragment';

        Test.startTest();
        RHCLogsIngestionService.ingest(new List<Record_Health_Check_Log__e>{ malformed });
        Test.stopTest();

        Record_Health_Check_Log_Settings__c snapshot = [
            SELECT LastIngestionErrorCodes__c
            FROM Record_Health_Check_Log_Settings__c
            LIMIT 1
        ];
        Assert.isFalse(
            snapshot.LastIngestionErrorCodes__c.contains('sensitive-payload-fragment'),
            'An operator error code must never echo a rejected payload value'
        );
        Assert.isFalse(
            snapshot.LastIngestionErrorCodes__c.contains(UserInfo.getUserName()),
            'An operator error code must never echo a username'
        );
        Assert.isTrue(
            Pattern.matches('[A-Z_,]+', snapshot.LastIngestionErrorCodes__c),
            'Operator error codes are stable uppercase package constants'
        );
    }

    private static Boolean hasLocalKey(Map<String, Object> populated, String localName) {
        String normalized = localName.toLowerCase();
        for (String key : populated.keySet()) {
            String normalizedKey = key.toLowerCase();
            if (normalizedKey == normalized || normalizedKey.endsWith('__' + normalized)) {
                return true;
            }
        }
        return false;
    }

    private static void assertNoSensitiveDetail(String message) {
        Assert.isNotNull(message, 'A sanitized error must still carry a message');
        Assert.isFalse(
            message.contains(UserInfo.getOrganizationId()),
            'A user-facing message must never echo the organization identifier'
        );
        Assert.isFalse(
            message.contains(UserInfo.getUserName()),
            'A user-facing message must never echo a username'
        );
        Assert.isFalse(
            message.containsIgnoreCase('Class.') || message.containsIgnoreCase('SELECT '),
            'A user-facing message must never echo a stack frame or a query'
        );
    }
}
