/** Test data factory for RHC Integrations package tests. */
@isTest
public class RHCIntegrationTestDataFactory {
    /** @return Inserted active example route from the specification. */
    public static Record_Health_Check_Integration_Route__c createExampleRoute() {
        return createExampleRoutes(1)[0];
    }

    /**
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
