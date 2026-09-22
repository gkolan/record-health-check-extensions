@IsTest
private class RHCReportsControllerTest {
    @IsTest
    static void shouldSaveNinetyDayDefaultsWhenAdminHasPermission() {
        User administrator = createUser('reports.admin');
        assignPermissionSet(administrator.Id, 'RHC_Reports_Admin');

        System.runAs(administrator) {
            Test.startTest();
            RHCReportsSetupController.SettingDTO saved =
                RHCReportsSetupController.saveSettings(defaultSettingsInput());
            Test.stopTest();

            Assert.areEqual(
                90,
                saved.detailedRetentionDays,
                'The setup assistant must save 90-day detailed retention.'
            );
            Assert.areEqual(
                'America/Chicago',
                saved.aggregationTimeZone,
                'The explicit reporting time zone must round-trip.'
            );
            Assert.isFalse(saved.scheduled, 'The test did not request a schedule.');
        }
    }

    @IsTest
    static void shouldRejectInvalidRetentionWhenAdminSaves() {
        User administrator = createUser('reports.invalid');
        assignPermissionSet(administrator.Id, 'RHC_Reports_Admin');

        System.runAs(administrator) {
            Test.startTest();
            try {
                RHCReportsSetupController.SaveSettingsInput input = defaultSettingsInput();
                input.detailedRetentionDays = 0;
                input.aggregationTimeZone = 'GMT';
                RHCReportsSetupController.saveSettings(input);
                Assert.fail('Zero-day detailed retention should be rejected.');
            } catch (AuraHandledException error) {
                Assert.areNotEqual(
                    null,
                    error,
                    'The invalid retention request must throw an AuraHandledException.'
                );
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldRejectMissingSettingsWhenAdminSaves() {
        User administrator = createUser('reports.missing');
        assignPermissionSet(administrator.Id, 'RHC_Reports_Admin');

        System.runAs(administrator) {
            Test.startTest();
            try {
                RHCReportsSetupController.saveSettings(null);
                Assert.fail('A missing settings request should be rejected.');
            } catch (AuraHandledException error) {
                Assert.areNotEqual(
                    null,
                    error,
                    'The missing settings request must throw an AuraHandledException.'
                );
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldQueueLatestCompletedDayWhenAdminRunsAggregationNow() {
        User administrator = createUser('reports.runnow');
        assignPermissionSet(administrator.Id, 'RHC_Reports_Admin');

        System.runAs(administrator) {
            Test.startTest();
            Date queued = RHCReportsSetupController.runAggregationNow();
            Integer jobs = Limits.getQueueableJobs();
            Test.stopTest();

            Assert.areEqual(1, jobs, 'One aggregation job is queued on demand.');
            Assert.isTrue(queued < Date.today().addDays(1), 'Only a completed local day is aggregated.');
            Assert.isNotNull(
                Record_Health_Check_Report_Setting__c.getOrgDefaults().LastAggregationAttemptAt__c,
                'The on-demand run records its outcome like the scheduled one.'
            );
        }
    }

    @IsTest
    static void shouldDefaultRetentionCleanupOffWhenOrgSettingIsAbsent() {
        User administrator = createUser('reports.defaults');
        assignPermissionSet(administrator.Id, 'RHC_Reports_Admin');

        System.runAs(administrator) {
            Test.startTest();
            RHCReportsSetupController.SettingDTO settings =
                RHCReportsSetupController.getSettings();
            Test.stopTest();

            Assert.isFalse(
                settings.retentionCleanupEnabled,
                'Irreversible retention cleanup must require deliberate opt-in.'
            );
        }
    }

    @IsTest
    static void shouldShowActionableCoverageWhenOnlyActionableDetailArrives() {
        User viewer = createUser('reports.viewer');
        assignPermissionSet(viewer.Id, 'RHC_Reports_Viewer');

        System.runAs(viewer) {
            insert RHCReportsTestDataFactory.runFact(
                'coverage-run',
                Datetime.now()
            );
            insert RHCReportsTestDataFactory.resultFact(
                new RHCReportsTestDataFactory.ResultFactRequest(
                    'coverage-result',
                    'FAIL',
                    Datetime.now()
                )
            );
            Test.startTest();
            List<RHCReportsCoverageController.CoverageRow> rows =
                RHCReportsCoverageController.getCoverage();
            Test.stopTest();

            RHCReportsCoverageController.CoverageRow observed;
            for (RHCReportsCoverageController.CoverageRow row : rows) {
                if (
                    row.checkSetQualifiedApiName ==
                    'Opportunity_Close_Readiness'
                ) {
                    observed = row;
                }
            }
            Assert.areNotEqual(
                null,
                observed,
                'Observed events must appear even when matching core configuration is absent.'
            );
            Assert.areEqual(
                'PARTIAL_ACTIONABLE_COVERAGE',
                observed.state,
                'Actionable-only detail must not be mislabeled as full ALL coverage.'
            );
        }
    }

    private static User createUser(String stem) {
        return insertUser(
            new User(
                Alias = stem.left(8),
                Email = stem + '@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Reports Test',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = UserInfo.getProfileId(),
                TimeZoneSidKey = 'America/Chicago',
                Username = stem + '.' + System.now().getTime() + '@example.com'
            )
        );
    }

    private static RHCReportsSetupController.SaveSettingsInput defaultSettingsInput() {
        RHCReportsSetupController.SaveSettingsInput input =
            new RHCReportsSetupController.SaveSettingsInput();
        input.detailedRetentionDays = 90;
        input.snapshotRetentionDays = 730;
        input.dailyAggregationEnabled = true;
        input.retentionCleanupEnabled = true;
        input.aggregationTimeZone = 'America/Chicago';
        input.scheduled = false;
        return input;
    }

    private static User insertUser(User userRecord) {
        insert userRecord;
        return userRecord;
    }

    private static void assignPermissionSet(Id userId, String permissionSetName) {
        PermissionSet permissionSet = [
            SELECT Id FROM PermissionSet
            WHERE Name = :permissionSetName
            LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = permissionSet.Id
        );
    }
}
