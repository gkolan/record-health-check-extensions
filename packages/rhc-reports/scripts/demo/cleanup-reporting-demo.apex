// Irreversibly deletes only the synthetic reporting dataset created by the demo scripts.
// Run in a sandbox/demo org as a System Administrator after preserving any needed evidence.
String checkSetName = 'Opportunity_Close_Readiness';
List<rhc__Record_Health_Check_Daily_Snapshot__c> snapshots = [
    SELECT Id
    FROM rhc__Record_Health_Check_Daily_Snapshot__c
    WHERE rhc__CheckSetQualifiedApiName__c = :checkSetName
];
List<rhc__Record_Health_Check_Report_Result__c> resultFacts = [
    SELECT Id
    FROM rhc__Record_Health_Check_Report_Result__c
    WHERE rhc__EventId__c LIKE 'RHC-DEMO-%'
];
List<rhc__Record_Health_Check_Report_Run__c> runFacts = [
    SELECT Id
    FROM rhc__Record_Health_Check_Report_Run__c
    WHERE rhc__EventId__c LIKE 'RHC-DEMO-%'
];
if (!snapshots.isEmpty()) Database.delete(snapshots, false);
if (!resultFacts.isEmpty()) Database.delete(resultFacts, false);
if (!runFacts.isEmpty()) Database.delete(runFacts, false);
System.debug(
    LoggingLevel.INFO,
    'Deleted synthetic snapshots=' + snapshots.size() +
    ', result facts=' + resultFacts.size() + ', run facts=' + runFacts.size()
);
