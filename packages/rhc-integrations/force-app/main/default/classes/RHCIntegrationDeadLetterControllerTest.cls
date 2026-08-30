@isTest
private class RHCIntegrationDeadLetterControllerTest {
    @isTest
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

    @isTest
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

    @isTest
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

    @isTest
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
