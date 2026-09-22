/** Test data factory for RHC Integrations package tests. */
@IsTest
public class RHCIntegrationTestDataFactory {
    /**
     * Creates a standard-user principal for service and subscriber tests.
     *
     * @param stem Unique username stem for the test principal.
     * @return Inserted least-privilege standard user.
     */
    public static User createStandardUser(String stem) {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueValue = stem + String.valueOf(DateTime.now().getTime());
        User principal = new User(
            Alias = stem.left(8),
            Email = uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Integration Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Chicago',
            Username = uniqueValue + '@example.com'
        );
        insert principal;
        return principal;
    }

    /**
     * Creates one active example route from the specification.
     *
     * @return Inserted active example route from the specification.
     */
    public static Record_Health_Check_Integration_Route__c createExampleRoute() {
        return createExampleRoutes(1)[0];
    }

    /**
     * Creates matching active routes for bounded fan-out tests.
     *
     * @param routeCount Number of matching active routes to insert.
     * @return Inserted matching routes.
     */
    public static List<Record_Health_Check_Integration_Route__c> createExampleRoutes(Integer routeCount) {
        List<Record_Health_Check_Integration_Route__c> routes = new List<Record_Health_Check_Integration_Route__c>();
        for (Integer index = 0; index < routeCount; index++) {
            routes.add(new Record_Health_Check_Integration_Route__c(
                Name = 'Service Management Errors ' + index,
                Active__c = true,
                EventTypes__c = 'RESULT',
                SelectionType__c = 'CHECK_SET',
                QualifiedApiName__c = 'Opportunity_Close_Readiness',
                Statuses__c = 'ERROR',
                MinimumSeverity__c = 'CRITICAL',
                NamedCredential__c = 'Service_Management',
                RelativeEndpoint__c = '/api/incidents',
                PayloadProfile__c = 'RHC Error v1',
                RetryPolicy__c = 'STANDARD'
            ));
        }
        insert routes;
        return routes;
    }

    /**
     * Creates a delivery ledger row in the requested state.
     *
     * @param routeId Route for the ledger row.
     * @param status Delivery status.
     * @return Inserted delivery row.
     */
    public static Record_Health_Check_Integration_Delivery__c createDelivery(Id routeId, String status) {
        String eventId = 'event-' + String.valueOf(Crypto.getRandomLong()).replace('-', '0');
        Record_Health_Check_Integration_Delivery__c delivery = new Record_Health_Check_Integration_Delivery__c(
            Route__c = routeId,
            EventId__c = eventId,
            RouteEventKey__c = String.valueOf(routeId) + ':' + eventId,
            EventType__c = 'RESULT',
            ContractVersion__c = '1.0',
            PayloadProfile__c = 'RHC Error v1',
            PayloadProfileVersion__c = '1.0',
            Payload__c = '{"eventId":"' + eventId + '","status":"ERROR"}',
            Status__c = status,
            ErrorCode__c = status == 'DEAD_LETTER' ? 'HTTP_400' : null,
            ErrorDetail__c = status == 'DEAD_LETTER' ? 'Permanent response classification.' : null
        );
        insert delivery;
        return delivery;
    }
}
