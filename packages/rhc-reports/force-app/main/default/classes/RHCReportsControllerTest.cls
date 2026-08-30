@isTest
private class RHCReportsControllerTest {
    @isTest
    static void shouldSaveNinetyDayDefaults_WhenAdminHasPermission() {
        User administrator = createUser('reports.admin');
        assignPermissionSet(administrator.Id, 'RHC_Reports_Admin');

        System.runAs(administrator) {
            Test.startTest();
            RHCReportsSetupController.SettingDTO saved =
                RHCReportsSetupController.saveSettings(
                    90,
                    730,
                    true,
                    true,
                    'America/Chicago',
                    false
                );
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

    @isTest
    static void shouldRejectInvalidRetention_WhenAdminSaves() {
        User administrator = createUser('reports.invalid');
        assignPermissionSet(administrator.Id, 'RHC_Reports_Admin');

        System.runAs(administrator) {
            Test.startTest();
            try {
                RHCReportsSetupController.saveSettings(
                    0,
                    730,
                    true,
                    true,
                    'GMT',
                    false
                );
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

    @isTest
    static void shouldDefaultRetentionCleanupOff_WhenOrgSettingIsAbsent() {
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

    @isTest
    static void shouldShowActionableCoverage_WhenOnlyActionableDetailArrives() {
        User viewer = createUser('reports.viewer');
        assignPermissionSet(viewer.Id, 'RHC_Reports_Viewer');

        System.runAs(viewer) {
            insert RHCReportsTestDataFactory.runFact(
                'coverage-run',
                Datetime.now()
            );
            insert RHCReportsTestDataFactory.resultFact(
                'coverage-result',
                'FAIL',
                Datetime.now(),
                '006000000000001AAA',
                'Close_Date_Complete'
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
