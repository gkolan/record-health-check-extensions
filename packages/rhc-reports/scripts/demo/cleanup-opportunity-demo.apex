// Irreversibly removes only source records carrying the exact demo marker.
// This does not delete RHC Reports historical facts; former Record IDs remain by design.
String marker = 'RHC_REPORTS_DEMO_V1';
List<Opportunity> demoOpportunities = [
    SELECT Id
    FROM Opportunity
    WHERE Description = :marker
];
if (!demoOpportunities.isEmpty()) {
    Database.delete(demoOpportunities, false, AccessLevel.USER_MODE);
}
List<Account> demoAccounts = [
    SELECT Id
    FROM Account
    WHERE Description = :marker
];
if (!demoAccounts.isEmpty()) {
    Database.delete(demoAccounts, false, AccessLevel.USER_MODE);
}
System.debug(LoggingLevel.INFO, 'RHC Reports marked demo source records were removed.');
