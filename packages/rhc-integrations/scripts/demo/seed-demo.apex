// Seeds inactive, clearly named subscriber-org demo data. Run only after both managed packages install.
String routeNamePattern = '[RHC Demo]%';
Map<String, rhc__Record_Health_Check_Integration_Route__c> existingRoutesByName = new Map<String, rhc__Record_Health_Check_Integration_Route__c>();
for (rhc__Record_Health_Check_Integration_Route__c route : [
    SELECT Id, Name
    FROM rhc__Record_Health_Check_Integration_Route__c
    WHERE Name LIKE :routeNamePattern
]) {
    existingRoutesByName.put(route.Name, route);
}

List<rhc__Record_Health_Check_Integration_Route__c> desiredRoutes = new List<rhc__Record_Health_Check_Integration_Route__c>{
    new rhc__Record_Health_Check_Integration_Route__c(
        Name = '[RHC Demo] 01 Result Critical Error - Success', rhc__Active__c = false,
        rhc__EventTypes__c = 'RESULT', rhc__SelectionType__c = 'CHECK_SET',
        rhc__QualifiedApiName__c = 'RHC_Demo_Check_Set', rhc__Statuses__c = 'ERROR',
        rhc__MinimumSeverity__c = 'CRITICAL', rhc__NamedCredential__c = 'RHC_Demo_Service',
        rhc__RelativeEndpoint__c = '/demo/success', rhc__PayloadProfile__c = 'RHC Error v1',
        rhc__RetryPolicy__c = 'STANDARD'
    ),
    new rhc__Record_Health_Check_Integration_Route__c(
        Name = '[RHC Demo] 02 Result Warning Failure - Success', rhc__Active__c = false,
        rhc__EventTypes__c = 'RESULT', rhc__SelectionType__c = 'CHECK',
        rhc__QualifiedApiName__c = 'RHC_Demo_Check', rhc__Statuses__c = 'FAIL',
        rhc__MinimumSeverity__c = 'WARNING', rhc__NamedCredential__c = 'RHC_Demo_Service',
        rhc__RelativeEndpoint__c = '/demo/success', rhc__PayloadProfile__c = 'RHC Outcome v1',
        rhc__RetryPolicy__c = 'NONE'
    ),
    new rhc__Record_Health_Check_Integration_Route__c(
        Name = '[RHC Demo] 03 Run Error - Success', rhc__Active__c = false,
        rhc__EventTypes__c = 'RUN', rhc__SelectionType__c = 'CHECK_SET',
        rhc__QualifiedApiName__c = 'RHC_Demo_Check_Set', rhc__Statuses__c = 'ERROR',
        rhc__NamedCredential__c = 'RHC_Demo_Service', rhc__RelativeEndpoint__c = '/demo/success',
        rhc__PayloadProfile__c = 'RHC Run v1', rhc__RetryPolicy__c = 'NONE'
    ),
    new rhc__Record_Health_Check_Integration_Route__c(
        Name = '[RHC Demo] 04 Log Error - Success', rhc__Active__c = false,
        rhc__EventTypes__c = 'LOG', rhc__SelectionType__c = 'CHECK_SET',
        rhc__QualifiedApiName__c = 'RHC_Demo_Check_Set', rhc__Statuses__c = 'ERROR',
        rhc__NamedCredential__c = 'RHC_Demo_Service', rhc__RelativeEndpoint__c = '/demo/success',
        rhc__PayloadProfile__c = 'RHC Log v1', rhc__RetryPolicy__c = 'NONE'
    ),
    new rhc__Record_Health_Check_Integration_Route__c(
        Name = '[RHC Demo] 05 Result Error - Retry 503', rhc__Active__c = false,
        rhc__EventTypes__c = 'RESULT', rhc__SelectionType__c = 'CHECK_SET',
        rhc__QualifiedApiName__c = 'RHC_Demo_Check_Set', rhc__Statuses__c = 'ERROR',
        rhc__MinimumSeverity__c = 'CRITICAL', rhc__NamedCredential__c = 'RHC_Demo_Service',
        rhc__RelativeEndpoint__c = '/demo/503', rhc__PayloadProfile__c = 'RHC Error v1',
        rhc__RetryPolicy__c = 'STANDARD'
    ),
    new rhc__Record_Health_Check_Integration_Route__c(
        Name = '[RHC Demo] 06 Result Error - Permanent 400', rhc__Active__c = false,
        rhc__EventTypes__c = 'RESULT', rhc__SelectionType__c = 'CHECK_SET',
        rhc__QualifiedApiName__c = 'RHC_Demo_Check_Set', rhc__Statuses__c = 'ERROR',
        rhc__MinimumSeverity__c = 'CRITICAL', rhc__NamedCredential__c = 'RHC_Demo_Service',
        rhc__RelativeEndpoint__c = '/demo/400', rhc__PayloadProfile__c = 'RHC Error v1',
        rhc__RetryPolicy__c = 'STANDARD'
    ),
    new rhc__Record_Health_Check_Integration_Route__c(
        Name = '[RHC Demo] 07 Core Opportunity Actionable - Success', rhc__Active__c = false,
        rhc__EventTypes__c = 'RESULT', rhc__SelectionType__c = 'CHECK_SET',
        rhc__QualifiedApiName__c = 'rhc__Example_Opportunity_Deal_Readiness',
        rhc__Statuses__c = 'FAIL;UNABLE_TO_EVALUATE;ERROR',
        rhc__NamedCredential__c = 'RHC_Demo_Service', rhc__RelativeEndpoint__c = '/demo/success',
        rhc__PayloadProfile__c = 'RHC Outcome v1', rhc__RetryPolicy__c = 'NONE'
    )
};

List<rhc__Record_Health_Check_Integration_Route__c> routesToInsert = new List<rhc__Record_Health_Check_Integration_Route__c>();
for (rhc__Record_Health_Check_Integration_Route__c route : desiredRoutes) {
    if (!existingRoutesByName.containsKey(route.Name)) {
        routesToInsert.add(route);
    }
}
if (!routesToInsert.isEmpty()) {
    insert routesToInsert;
}

List<Opportunity> demoOpportunities = [
    SELECT Id
    FROM Opportunity
    WHERE Name = 'RHC Demo - Integration Event Reference'
    ORDER BY CreatedDate
    LIMIT 1
];
if (demoOpportunities.isEmpty()) {
    OpportunityStage demoStage = [
        SELECT MasterLabel
        FROM OpportunityStage
        WHERE IsActive = true
        ORDER BY SortOrder
        LIMIT 1
    ];
    demoOpportunities.add(new Opportunity(
        Name = 'RHC Demo - Integration Event Reference',
        StageName = demoStage.MasterLabel,
        CloseDate = Date.today().addDays(30),
        Amount = 0,
        NextStep = 'Use only for the RHC Integrations demo'
    ));
    insert demoOpportunities;
}

Map<String, rhc__Record_Health_Check_Integration_Route__c> seededRoutesByName = new Map<String, rhc__Record_Health_Check_Integration_Route__c>();
for (rhc__Record_Health_Check_Integration_Route__c route : [
    SELECT Id, Name, rhc__Active__c
    FROM rhc__Record_Health_Check_Integration_Route__c
    WHERE Name LIKE :routeNamePattern
]) {
    seededRoutesByName.put(route.Name, route);
}

Integer activeRouteCount = 0;
for (rhc__Record_Health_Check_Integration_Route__c route : seededRoutesByName.values()) {
    if (route.rhc__Active__c) {
        activeRouteCount++;
    }
}

String fixtureEventId = 'RHC-DEMO-DEAD-LETTER-FIXTURE';
if ([SELECT COUNT() FROM rhc__Record_Health_Check_Integration_Delivery__c WHERE rhc__EventId__c = :fixtureEventId] == 0) {
    Id fixtureRouteId = seededRoutesByName.get('[RHC Demo] 06 Result Error - Permanent 400').Id;
    insert new rhc__Record_Health_Check_Integration_Delivery__c(
        rhc__Route__c = fixtureRouteId,
        rhc__EventId__c = fixtureEventId,
        rhc__RouteEventKey__c = String.valueOf(fixtureRouteId) + ':' + fixtureEventId,
        rhc__EventType__c = 'RESULT',
        rhc__ContractVersion__c = '1.0',
        rhc__PayloadProfile__c = 'RHC Error v1',
        rhc__PayloadProfileVersion__c = '1.0',
        rhc__Payload__c = '{"payloadProfileVersion":"1.0","eventContractVersion":"1.0","eventType":"RESULT","eventId":"RHC-DEMO-DEAD-LETTER-FIXTURE","checkSetQualifiedApiName":"RHC_Demo_Check_Set","status":"ERROR","severity":"CRITICAL"}',
        rhc__Status__c = 'DEAD_LETTER',
        rhc__AttemptCount__c = 1,
        rhc__ReplayCount__c = 0,
        rhc__HttpStatus__c = 400,
        rhc__HttpClassification__c = 'PERMANENT',
        rhc__ErrorCode__c = 'HTTP_400',
        rhc__ErrorDetail__c = 'Demo fixture: correct and activate the route before authorized replay.',
        rhc__LastAttemptAt__c = System.now(),
        rhc__CompletedAt__c = System.now()
    );
}

System.debug(LoggingLevel.INFO, 'RHC_DEMO_SEED_COMPLETE routes=' + seededRoutesByName.size()
    + ' opportunityId=' + demoOpportunities[0].Id + ' activeRouteCount=' + activeRouteCount);
