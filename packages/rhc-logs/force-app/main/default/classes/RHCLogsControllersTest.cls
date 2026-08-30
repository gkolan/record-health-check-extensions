/**
 * Verifies setup findings, bounded configuration, filters, and restricted-field personas.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCLogsControllersTest {
    @IsTest
    static void shouldRejectUsersWithoutPackageObjectAccess() {
        User unprivileged = RHCLogsTestDataFactory.createUser('noaccess');

        System.runAs(unprivileged) {
            Test.startTest();
            try {
                RHCLogsReviewController.search(new RHCLogsReviewController.LogFilter());
                Assert.fail('A user without package access must not review retained Logs');
            } catch (AuraHandledException expected) {
                Assert.isTrue(expected.getMessage().contains('do not have access'), 'Review denial must be sanitized');
            }
            try {
                RHCLogsAdminController.getStatus();
                Assert.fail('A user without package access must not inspect settings');
            } catch (AuraHandledException expected) {
                Assert.isTrue(expected.getMessage().contains('do not have access'), 'Setup denial must be sanitized');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldReportCoreContractAndSourceGapWhenAdminLoadsSetup() {
        User administrator = createAdministrator('statusadmin');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Record_Health_Check_Diagnostic_Log__c unsupported =
                RHCLogsTestDataFactory.createLog('unsupported-contract', System.now());
            unsupported.ContractVersion__c = '2.0';
            update unsupported;
        }

        RHCLogsAdminController.SetupStatus status;
        System.runAs(administrator) {
            Test.startTest();
            status = RHCLogsAdminController.getStatus();
            Test.stopTest();
        }

        Assert.isTrue(status.coreLogEventInstalled, 'The required core dependency should expose the Log event');
        Assert.isTrue(status.coreContractCompatible, 'The promoted canonical fields should be complete');
        Assert.isTrue(status.canInspectCheckSets, 'Admin should be able to inspect core Check Set publication settings');
        Assert.isFalse(status.checkSets.isEmpty(), 'The minimum core package should expose its example Check Sets');
        Assert.areEqual('2.0.4.2', status.minimumCoreVersion, 'Setup should identify the minimum promoted release');
        Assert.isTrue(status.sourceFilterAvailability.contains('Unavailable'), 'Missing source must be explicit');
        Assert.areEqual(1, status.unsupportedContractCount, 'Contract drift should be visible to operators');
    }

    @IsTest
    static void shouldValidateBoundsWhenAdminSavesSettings() {
        User administrator = createAdministrator('boundsadmin');
        RHCLogsAdminController.SettingsInput settingsInput =
            new RHCLogsAdminController.SettingsInput();
        settingsInput.retentionDays = 0;
        settingsInput.cleanupBatchSize = 2000;
        settingsInput.automatedCleanupEnabled = false;
        System.runAs(administrator) {
            Test.startTest();
            try {
                RHCLogsAdminController.saveSettings(settingsInput);
                Assert.fail('Retention below one day should be rejected');
            } catch (AuraHandledException expected) {
                Assert.isTrue(expected.getMessage().contains('Retention Days'), 'Sanitized error should identify retention');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldRejectUnsafeCleanupBatchSizeWhenAdminSavesSettings() {
        User administrator = createAdministrator('sizeadmin');
        RHCLogsAdminController.SettingsInput settingsInput =
            new RHCLogsAdminController.SettingsInput();
        settingsInput.retentionDays = 30;
        settingsInput.cleanupBatchSize = 9999;
        settingsInput.automatedCleanupEnabled = false;
        System.runAs(administrator) {
            Test.startTest();
            try {
                RHCLogsAdminController.saveSettings(settingsInput);
                Assert.fail('A cleanup size that exceeds the DML-row budget should be rejected');
            } catch (AuraHandledException expected) {
                Assert.isTrue(
                    expected.getMessage().contains('9,998'),
                    'Sanitized error should identify the safe maximum'
                );
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldPersistValidSettingsAndSynchronizeSchedule() {
        User administrator = createAdministrator('saveadmin');
        RHCLogsAdminController.SettingsInput settingsInput =
            new RHCLogsAdminController.SettingsInput();
        settingsInput.retentionDays = 45;
        settingsInput.cleanupBatchSize = 500;
        settingsInput.automatedCleanupEnabled = true;

        RHCLogsAdminController.SetupStatus status;
        System.runAs(administrator) {
            Test.startTest();
            status = RHCLogsAdminController.saveSettings(settingsInput);
            Test.stopTest();
        }

        Assert.areEqual(45, status.settings.RetentionDays__c.intValue(), 'Valid retention must persist');
        Assert.areEqual(500, status.settings.CleanupBatchSize__c.intValue(), 'Valid batch size must persist');
        Assert.isTrue(status.settings.AutomatedCleanupEnabled__c, 'Explicit automation enablement must persist');
        Assert.isTrue(status.cleanupScheduled, 'Enabled automation must create the package schedule');
    }

    @IsTest
    static void shouldUpdateExistingSettingsAndDisableSchedule() {
        User administrator = createAdministrator('updateadmin');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            RHCLogsTestDataFactory.createSettings(
                30,
                100,
                RHCLogsTestDataFactory.AutomationState.ENABLED
            );
            RHCLogsCleanupScheduler.scheduleDaily();
        }
        RHCLogsAdminController.SettingsInput settingsInput =
            new RHCLogsAdminController.SettingsInput();
        settingsInput.retentionDays = 60;
        settingsInput.cleanupBatchSize = 250;
        settingsInput.automatedCleanupEnabled = false;

        RHCLogsAdminController.SetupStatus status;
        System.runAs(administrator) {
            Test.startTest();
            status = RHCLogsAdminController.saveSettings(settingsInput);
            Test.stopTest();
        }

        Assert.areEqual(60, status.settings.RetentionDays__c.intValue(), 'Existing retention should update');
        Assert.areEqual(250, status.settings.CleanupBatchSize__c.intValue(), 'Existing batch size should update');
        Assert.isFalse(status.settings.AutomatedCleanupEnabled__c, 'Automation should be explicitly disabled');
        Assert.isFalse(status.cleanupScheduled, 'Disabling automation must remove only the package schedule');
    }

    @IsTest
    static void shouldRunBoundedManualCleanupFromAdminApi() {
        User administrator = createAdministrator('cleanupadmin');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            RHCLogsTestDataFactory.createSettings(
                30,
                10,
                RHCLogsTestDataFactory.AutomationState.DISABLED
            );
            RHCLogsTestDataFactory.createLog('admin-expired', System.now().addDays(-31));
        }

        RHCLogsCleanupService.CleanupResult result;
        System.runAs(administrator) {
            Test.startTest();
            result = RHCLogsAdminController.runCleanup();
            Test.stopTest();
        }

        Assert.areEqual('SUCCESS', result.status, 'Admin API should run configured manual cleanup');
        Assert.areEqual(1, result.deletedCount, 'Admin cleanup should delete only the expired package log');
    }

    @IsTest
    static void shouldFilterByExactIdentityWhenReviewSearchRuns() {
        User administrator = createAdministrator('filteradmin');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            RHCLogsTestDataFactory.createLog('matching', System.now());
            Record_Health_Check_Diagnostic_Log__c matching = [
                SELECT Id, CheckSetDeveloperName__c
                FROM Record_Health_Check_Diagnostic_Log__c
                WHERE EventId__c = 'matching'
            ];
            matching.CheckSetDeveloperName__c = 'vendor__Exact_Set';
            update matching;
            RHCLogsTestDataFactory.createLog('other', System.now());
        }

        RHCLogsReviewController.LogFilter filter = new RHCLogsReviewController.LogFilter();
        filter.checkSetDeveloperName = 'vendor__Exact_Set';
        filter.occurredFrom = System.now().addDays(-1);
        filter.occurredTo = System.now().addDays(1);
        filter.pageSize = 10;

        RHCLogsReviewController.LogPage page;
        System.runAs(administrator) {
            Test.startTest();
            page = RHCLogsReviewController.search(filter);
            Test.stopTest();
        }

        Assert.areEqual(1, page.rows.size(), 'Exact Check Set filter should return one matching Log');
        Assert.areEqual('vendor__Exact_Set', page.rows[0].CheckSetDeveloperName__c, 'Identity must not be normalized');
    }

    @IsTest
    static void shouldHideRestrictedFieldsWhenViewerReviewsLogs() {
        User viewer = RHCLogsTestDataFactory.createUser('viewer');
        RHCLogsTestDataFactory.assignPermissionSet(viewer.Id, 'RHC_Logs_Viewer');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Record_Health_Check_Diagnostic_Log__c logRecord =
                RHCLogsTestDataFactory.createLog('viewer-log', System.now());
            logRecord.Message__c = 'restricted message';
            logRecord.StructuredDetails__c = '{"restricted":true}';
            logRecord.RecordId__c = logRecord.Id;
            logRecord.RunningUserId__c = UserInfo.getUserId();
            update logRecord;
        }

        System.runAs(viewer) {
            Test.startTest();
            RHCLogsReviewController.LogPage page =
                RHCLogsReviewController.search(new RHCLogsReviewController.LogFilter());
            Test.stopTest();

            Assert.areEqual(1, page.rows.size(), 'Viewer should see retained correlation records');
            Assert.isFalse(page.rows[0].getPopulatedFieldsAsMap().containsKey('Message__c'), 'Viewer must not receive Message');
            Assert.isFalse(page.rows[0].getPopulatedFieldsAsMap().containsKey('StructuredDetails__c'), 'Viewer must not receive details');
            Assert.isFalse(page.rows[0].getPopulatedFieldsAsMap().containsKey('RecordId__c'), 'Viewer must not receive Record ID');
            Assert.isFalse(page.rows[0].getPopulatedFieldsAsMap().containsKey('RunningUserId__c'), 'Viewer must not receive Running User ID');
        }
    }

    @IsTest
    static void shouldAllowAdminRestrictedFieldsWhenAdminReviewsLogs() {
        User administrator = RHCLogsTestDataFactory.createUser('logadmin');
        RHCLogsTestDataFactory.assignPermissionSet(administrator.Id, 'RHC_Logs_Admin');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Record_Health_Check_Diagnostic_Log__c logRecord =
                RHCLogsTestDataFactory.createLog('admin-log', System.now());
            logRecord.Message__c = 'restricted message';
            update logRecord;
        }

        System.runAs(administrator) {
            Test.startTest();
            RHCLogsReviewController.LogPage page =
                RHCLogsReviewController.search(new RHCLogsReviewController.LogFilter());
            Test.stopTest();

            Assert.areEqual('restricted message', page.rows[0].Message__c, 'Approved Admin should receive Message');
        }
    }

    @IsTest
    static void shouldRejectRestrictedFilterWhenViewerCannotReadField() {
        User viewer = RHCLogsTestDataFactory.createUser('filterviewer');
        RHCLogsTestDataFactory.assignPermissionSet(viewer.Id, 'RHC_Logs_Viewer');
        RHCLogsReviewController.LogFilter filter = new RHCLogsReviewController.LogFilter();
        filter.recordId = UserInfo.getUserId();

        System.runAs(viewer) {
            Test.startTest();
            try {
                RHCLogsReviewController.search(filter);
                Assert.fail('Viewer must not filter on a restricted field');
            } catch (AuraHandledException expected) {
                Assert.isTrue(
                    expected.getMessage().contains('requested log filters'),
                    'Restricted filter failures must be sanitized'
                );
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldReturnStableKeysetPages() {
        Datetime occurredAt = System.now();
        for (Integer index = 0; index < 3; index++) {
            RHCLogsTestDataFactory.createLog('page-' + index, occurredAt);
        }
        RHCLogsReviewController.LogFilter firstFilter = new RHCLogsReviewController.LogFilter();
        firstFilter.pageSize = 2;

        Test.startTest();
        RHCLogsReviewController.LogPage firstPage = RHCLogsReviewController.search(firstFilter);
        RHCLogsReviewController.LogFilter secondFilter = new RHCLogsReviewController.LogFilter();
        secondFilter.pageSize = 2;
        secondFilter.cursorOccurredAt = firstPage.nextOccurredAt;
        secondFilter.cursorId = firstPage.nextId;
        RHCLogsReviewController.LogPage secondPage = RHCLogsReviewController.search(secondFilter);
        Test.stopTest();

        Assert.areEqual(2, firstPage.rows.size(), 'First page should honor requested size');
        Assert.isTrue(firstPage.hasMore, 'First page should advertise a continuation');
        Assert.areEqual(1, secondPage.rows.size(), 'Second page should return the remaining row');
        Assert.isFalse(secondPage.hasMore, 'Final page should not advertise a continuation');
        Assert.areNotEqual(firstPage.rows[1].Id, secondPage.rows[0].Id, 'Pages must not overlap');
    }

    @IsTest
    static void shouldRejectIncompleteKeysetCursor() {
        RHCLogsReviewController.LogFilter filter = new RHCLogsReviewController.LogFilter();
        filter.cursorOccurredAt = System.now();

        Test.startTest();
        try {
            RHCLogsReviewController.search(filter);
            Assert.fail('A partial cursor must not produce an unstable page');
        } catch (AuraHandledException expected) {
            Assert.isTrue(expected.getMessage().contains('cursor is incomplete'), 'Error should be sanitized and actionable');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldClampReviewPageToTwoHundredRows() {
        List<Record_Health_Check_Diagnostic_Log__c> logs =
            new List<Record_Health_Check_Diagnostic_Log__c>();
        for (Integer index = 0; index < 201; index++) {
            logs.add(RHCLogsTestDataFactory.buildLog('clamp-' + index, System.now()));
        }
        insert logs;
        RHCLogsReviewController.LogFilter filter = new RHCLogsReviewController.LogFilter();
        filter.pageSize = 1000;

        Test.startTest();
        RHCLogsReviewController.LogPage page = RHCLogsReviewController.search(filter);
        Test.stopTest();

        Assert.areEqual(200, page.rows.size(), 'Controller must enforce its absolute page ceiling');
        Assert.isTrue(page.hasMore, 'The look-ahead row should advertise more results');
    }

    private static User createAdministrator(String keyValue) {
        User administrator = RHCLogsTestDataFactory.createUser(keyValue);
        RHCLogsTestDataFactory.assignPermissionSet(administrator.Id, 'RHC_Logs_Admin');
        return administrator;
    }
}
