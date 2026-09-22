@IsTest
private class RHCIntegrationDeadLetterControllerTest {
    @IsTest
    static void shouldListAndReplayWhenAdministratorHasCustomPermission() {
        User administrator = createAuthorizedAdministrator('rhcadmin');
        Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(200, '{}'));

        System.runAs(administrator) {
            Record_Health_Check_Integration_Route__c route = RHCIntegrationTestDataFactory.createExampleRoute();
            Record_Health_Check_Integration_Delivery__c delivery = RHCIntegrationTestDataFactory.createDelivery(route.Id, 'DEAD_LETTER');
            List<RHCIntegrationDeadLetterController.DeadLetterRow> rows =
                RHCIntegrationDeadLetterController.getDeadLetters();
            Assert.areEqual(1, rows.size(), 'The administrator should see the dead letter');
            Assert.areEqual(delivery.EventId__c, rows[0].eventId, 'The sanitized projection should include Event ID');

            Test.startTest();
            RHCIntegrationDeadLetterController.replay(delivery.Id);
            Test.stopTest();

            Record_Health_Check_Integration_Delivery__c replayed = [
                SELECT Status__c, ReplayCount__c, EventId__c
                FROM Record_Health_Check_Integration_Delivery__c WHERE Id = :delivery.Id
            ];
            Assert.areEqual('SUCCEEDED', replayed.Status__c, 'An authorized replay should enqueue delivery');
            Assert.areEqual(1, replayed.ReplayCount__c, 'Replay count should be incremented');
            Assert.areEqual(replayed.EventId__c, RHCIntegrationHttpMock.capturedRequest.getHeader('Idempotency-Key'),
                'Replay must retain the original external idempotency key');
        }
    }

    @IsTest
    static void shouldReplaySelectionInOneChainAndSkipNonDeadLetters() {
        User administrator = createAuthorizedAdministrator('rhcbulk');
        Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(200, '{}'));
        System.runAs(administrator) {
            Record_Health_Check_Integration_Route__c route = RHCIntegrationTestDataFactory.createExampleRoute();
            Record_Health_Check_Integration_Delivery__c first = RHCIntegrationTestDataFactory.createDelivery(route.Id, 'DEAD_LETTER');
            Record_Health_Check_Integration_Delivery__c second = RHCIntegrationTestDataFactory.createDelivery(route.Id, 'DEAD_LETTER');
            Record_Health_Check_Integration_Delivery__c done = RHCIntegrationTestDataFactory.createDelivery(route.Id, 'SUCCEEDED');

            Test.startTest();
            Integer replayed = RHCIntegrationDeadLetterController.replayAll(new List<Id>{ first.Id, second.Id, done.Id });
            Test.stopTest();

            Assert.areEqual(2, replayed, 'Only dead letters are replayed; the succeeded row is skipped.');
            Assert.areEqual(
                2,
                [SELECT COUNT() FROM Record_Health_Check_Integration_Delivery__c WHERE Id IN (:first.Id, :second.Id) AND Status__c = 'SUCCEEDED' AND ReplayCount__c = 1],
                'Both replayed rows are delivered by the single chain.'
            );
        }
    }

    @IsTest
    static void shouldRejectReplayWhenDeliveryIsNoLongerDeadLettered() {
        User administrator = createAuthorizedAdministrator('rhcstate');
        System.runAs(administrator) {
            Record_Health_Check_Integration_Route__c route = RHCIntegrationTestDataFactory.createExampleRoute();
            Record_Health_Check_Integration_Delivery__c delivery =
                RHCIntegrationTestDataFactory.createDelivery(route.Id, 'PENDING');

            Test.startTest();
            try {
                RHCIntegrationDeadLetterController.replay(delivery.Id);
                Assert.fail('A stale replay request must not claim a non-dead-letter delivery');
            } catch (AuraHandledException expected) {
                Assert.isNotNull(expected, 'The stale replay request should fail safely');
            }
            Test.stopTest();

            Record_Health_Check_Integration_Delivery__c unchanged = [
                SELECT Status__c, ReplayCount__c
                FROM Record_Health_Check_Integration_Delivery__c
                WHERE Id = :delivery.Id
            ];
            Assert.areEqual('PENDING', unchanged.Status__c, 'Replay must not alter a newer delivery state');
            Assert.areEqual(0, unchanged.ReplayCount__c, 'Rejected replay must not increment replay count');
        }
    }

    @IsTest
    static void shouldRejectReplayWhenRouteIsInactive() {
        User administrator = createAuthorizedAdministrator('rhcroute');
        System.runAs(administrator) {
            Record_Health_Check_Integration_Route__c route = RHCIntegrationTestDataFactory.createExampleRoute();
            route.Active__c = false;
            update route;
            Record_Health_Check_Integration_Delivery__c delivery =
                RHCIntegrationTestDataFactory.createDelivery(route.Id, 'DEAD_LETTER');

            Test.startTest();
            try {
                RHCIntegrationDeadLetterController.replay(delivery.Id);
                Assert.fail('Replay must fail closed while its route is inactive');
            } catch (AuraHandledException expected) {
                Assert.isNotNull(expected, 'Inactive-route replay should return an Aura-safe error');
            }
            Test.stopTest();

            Record_Health_Check_Integration_Delivery__c unchanged = [
                SELECT Status__c, ReplayCount__c
                FROM Record_Health_Check_Integration_Delivery__c
                WHERE Id = :delivery.Id
            ];
            Assert.areEqual('DEAD_LETTER', unchanged.Status__c, 'Rejected replay must remain dead-lettered');
            Assert.areEqual(0, unchanged.ReplayCount__c, 'Rejected replay must not increment replay count');
        }
    }

    @IsTest
    static void shouldRejectReplayWhenUserLacksCustomPermission() {
        User viewer = createUser('rhcviewer');
        System.runAs(viewer) {
            Test.startTest();
            try {
                RHCIntegrationDeadLetterController.replay(null);
                Assert.fail('Replay should require the packaged Custom Permission');
            } catch (AuraHandledException expected) {
                Assert.isNotNull(expected, 'An Aura-safe exception should reject unauthorized replay');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldSaveValidateAndRequireRetentionSettings() {
        User administrator = createAuthorizedAdministrator('rhcret');
        System.runAs(administrator) {
            RHCIntegrationRetentionService.Settings recommended =
                RHCIntegrationDeadLetterController.getRetentionSettings();
            Assert.isTrue(recommended.canManage, 'The administrator can manage retention.');
            Assert.areEqual(false, recommended.configured, 'The default is not purge authorization.');
            Assert.areEqual(90, recommended.retentionDays, 'The recommended window is 90 days.');
            Assert.areEqual(1000, recommended.maxDeleteRows, 'A purge transaction is bounded.');

            Boolean unsavedRejected = false;
            try {
                RHCIntegrationDeadLetterController.purgeDeliveries();
            } catch (AuraHandledException expected) {
                unsavedRejected = true;
            }
            Assert.isTrue(unsavedRejected, 'A recommendation alone never authorizes deletion.');

            RHCIntegrationDeadLetterController.saveRetentionSettings(45);
            Assert.areEqual(
                45,
                RHCIntegrationDeadLetterController.getRetentionSettings().retentionDays,
                'The saved retention window is returned.'
            );
            RHCIntegrationDeadLetterController.saveRetentionSettings(60);
            Assert.areEqual(
                1,
                [SELECT COUNT() FROM Record_Health_Check_Integration_Setting__c],
                'Saving again updates rather than duplicates the singleton.'
            );

            assertRetentionRejected(null);
            assertRetentionRejected(0);
            assertRetentionRejected(3651);
        }
    }

    @IsTest
    static void shouldPurgeOnlyOldCompletedTerminalDeliveries() {
        User administrator = createAuthorizedAdministrator('rhcpurge');
        System.runAs(administrator) {
            Record_Health_Check_Integration_Route__c route =
                RHCIntegrationTestDataFactory.createExampleRoute();
            Datetime oldCompletion = System.now().addDays(-40);
            Datetime recentCompletion = System.now().addDays(-5);
            List<Record_Health_Check_Integration_Delivery__c> deliveries = new List<Record_Health_Check_Integration_Delivery__c>{
                RHCIntegrationTestDataFactory.createDelivery(route.Id, 'SUCCEEDED'),
                RHCIntegrationTestDataFactory.createDelivery(route.Id, 'DEAD_LETTER'),
                RHCIntegrationTestDataFactory.createDelivery(route.Id, 'SUCCEEDED'),
                RHCIntegrationTestDataFactory.createDelivery(route.Id, 'PENDING'),
                RHCIntegrationTestDataFactory.createDelivery(route.Id, 'RETRY_WAIT')
            };
            deliveries[0].CompletedAt__c = oldCompletion;
            deliveries[1].CompletedAt__c = oldCompletion;
            deliveries[2].CompletedAt__c = recentCompletion;
            deliveries[3].CompletedAt__c = oldCompletion;
            deliveries[4].CompletedAt__c = oldCompletion;
            update deliveries;
            RHCIntegrationDeadLetterController.saveRetentionSettings(30);

            Test.startTest();
            Integer purged = RHCIntegrationDeadLetterController.purgeDeliveries();
            Test.stopTest();

            Assert.areEqual(2, purged, 'Only old completed terminal deliveries are purged.');
            Assert.areEqual(
                3,
                [SELECT COUNT() FROM Record_Health_Check_Integration_Delivery__c],
                'Recent and nonterminal deliveries remain.'
            );
            Assert.areEqual(
                2,
                [SELECT COUNT() FROM Record_Health_Check_Integration_Delivery__c
                    WHERE Status__c IN ('PENDING', 'RETRY_WAIT')],
                'Operational deliveries are never purged even when their timestamp is old.'
            );
        }
    }

    @IsTest
    static void shouldHideAndRejectRetentionManagementWithoutObjectAccess() {
        User viewer = createUser('rhcretvw');
        System.runAs(viewer) {
            RHCIntegrationRetentionService.Settings settings =
                RHCIntegrationDeadLetterController.getRetentionSettings();
            Assert.isFalse(settings.canManage, 'A viewer does not receive retention management controls.');
            Boolean rejected = false;
            try {
                RHCIntegrationDeadLetterController.saveRetentionSettings(30);
            } catch (AuraHandledException expected) {
                rejected = true;
            }
            Assert.isTrue(rejected, 'The server rejects retention changes without object access.');
        }
    }

    private static void assertRetentionRejected(Integer retentionDays) {
        Boolean rejected = false;
        try {
            RHCIntegrationDeadLetterController.saveRetentionSettings(retentionDays);
        } catch (AuraHandledException expected) {
            rejected = true;
        }
        Assert.isTrue(rejected, 'Unsupported retention values must be rejected.');
    }

    private static User createAuthorizedAdministrator(String prefix) {
        User administrator = createUser(prefix);
        PermissionSet adminPermission = [
            SELECT Id FROM PermissionSet WHERE Name = 'RHC_Integrations_Admin' LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = administrator.Id,
            PermissionSetId = adminPermission.Id
        );
        return administrator;
    }

    private static User createUser(String prefix) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueValue = prefix + String.valueOf(Datetime.now().getTime());
        User userRecord = new User(
            Alias = prefix.left(8),
            Email = uniqueValue + '@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Integration Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Chicago',
            Username = uniqueValue + '@example.invalid'
        );
        insert userRecord;
        return userRecord;
    }
}
