// Changes only the marked recovery candidate from failing data to passing data.
String marker = 'RHC_REPORTS_DEMO_V1';
List<Opportunity> candidates = [
    SELECT Id, CloseDate, Amount, Probability, NextStep
    FROM Opportunity
    WHERE Description = :marker
        AND Name = '[RHC DEMO] Recovery Candidate'
    LIMIT 1
];
if (candidates.isEmpty()) {
    throw new IllegalArgumentException(
        'Run scripts/demo/create-opportunity-demo.apex before repairing the candidate.'
    );
}
Opportunity candidate = candidates[0];
candidate.CloseDate = Date.today().addDays(45);
candidate.Amount = 75000;
candidate.Probability = 50;
candidate.NextStep = 'Demo owner confirms decision meeting next Tuesday';
Database.SaveResult result = Database.update(
    new List<Opportunity>{ candidate },
    false,
    AccessLevel.USER_MODE
)[0];
if (!result.isSuccess()) {
    throw new IllegalArgumentException('The recovery candidate could not be updated.');
}
System.debug(LoggingLevel.INFO, 'RHC Reports recovery candidate now contains passing data.');
