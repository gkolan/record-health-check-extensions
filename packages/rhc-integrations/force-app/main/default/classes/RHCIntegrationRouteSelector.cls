/**
 * Encapsulates route queries for the runtime subscriber.
 */
public inherited sharing class RHCIntegrationRouteSelector {
    /**
     * @return Active routes with the complete runtime configuration.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<Record_Health_Check_Integration_Route__c> selectActive() {
        // Intentional system-context read: Platform Event subscribers run as Automated Process,
        // while only administrators can author routes through explicit object/FLS permissions.
        return [
            SELECT Id, Active__c, EventTypes__c, SelectionType__c,
                QualifiedApiName__c, Statuses__c, MinimumSeverity__c,
                NamedCredential__c, RelativeEndpoint__c, PayloadProfile__c,
                RetryPolicy__c
            FROM Record_Health_Check_Integration_Route__c
            WHERE Active__c = TRUE
            ORDER BY Id
            LIMIT 2000
        ];
    }
}
