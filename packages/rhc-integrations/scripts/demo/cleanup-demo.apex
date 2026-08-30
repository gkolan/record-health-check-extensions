// Deletes only records created by the RHC Integrations demo kit.
String routeNamePattern = '[RHC Demo]%';
String eventIdPattern = 'RHC-DEMO-%';
List<rhc__Record_Health_Check_Integration_Route__c> demoRoutes = [
    SELECT Id
    FROM rhc__Record_Health_Check_Integration_Route__c
    WHERE Name LIKE :routeNamePattern
];
Set<Id> demoRouteIds = new Map<Id, rhc__Record_Health_Check_Integration_Route__c>(demoRoutes).keySet();

List<rhc__Record_Health_Check_Integration_Delivery__c> demoDeliveries;
if (demoRouteIds.isEmpty()) {
    demoDeliveries = [
        SELECT Id FROM rhc__Record_Health_Check_Integration_Delivery__c WHERE rhc__EventId__c LIKE :eventIdPattern
    ];
} else {
    demoDeliveries = [
        SELECT Id
        FROM rhc__Record_Health_Check_Integration_Delivery__c
        WHERE rhc__Route__c IN :demoRouteIds OR rhc__EventId__c LIKE :eventIdPattern
    ];
}
if (!demoDeliveries.isEmpty()) {
    delete demoDeliveries;
}
if (!demoRoutes.isEmpty()) {
    delete demoRoutes;
}

List<Opportunity> demoOpportunities = [
    SELECT Id
    FROM Opportunity
    WHERE Name = 'RHC Demo - Integration Event Reference'
];
if (!demoOpportunities.isEmpty()) {
    delete demoOpportunities;
}

System.debug(LoggingLevel.INFO, 'RHC_DEMO_CLEANUP_COMPLETE deliveries=' + demoDeliveries.size()
    + ' routes=' + demoRoutes.size() + ' opportunities=' + demoOpportunities.size());
