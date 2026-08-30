// RHC Reports demo source records. Run only in a sandbox or disposable demo org.
// Safe to rerun: records are matched by the exact Description marker.
String marker = 'RHC_REPORTS_DEMO_V1';

List<OpportunityStage> openStages = [
    SELECT MasterLabel, DefaultProbability
    FROM OpportunityStage
    WHERE IsActive = true AND IsClosed = false
    ORDER BY SortOrder
    LIMIT 1
];
if (openStages.isEmpty()) {
    throw new IllegalArgumentException('No active open Opportunity stage is available.');
}

OpportunityStage demoStage = openStages[0];
List<Account> demoAccounts = [
    SELECT Id, Name, Description
    FROM Account
    WHERE Description = :marker
    ORDER BY CreatedDate
    LIMIT 1
];
Account demoAccount;
if (demoAccounts.isEmpty()) {
    demoAccount = new Account(
        Name = 'RHC Reports Demo Account',
        Description = marker
    );
    insert demoAccount;
} else {
    demoAccount = demoAccounts[0];
}

Map<String, Opportunity> existingByName = new Map<String, Opportunity>();
for (Opportunity existing : [
    SELECT Id, Name, Description
    FROM Opportunity
    WHERE Description = :marker
]) {
    existingByName.put(existing.Name, existing);
}

Decimal usableProbability = demoStage.DefaultProbability == null ||
    demoStage.DefaultProbability == 0
    ? 25
    : demoStage.DefaultProbability;
List<Opportunity> desired = new List<Opportunity>{
    new Opportunity(
        Name = '[RHC DEMO] Ready Opportunity',
        AccountId = demoAccount.Id,
        StageName = demoStage.MasterLabel,
        CloseDate = Date.today().addDays(30),
        Amount = 50000,
        Probability = usableProbability,
        NextStep = 'Demo owner sends pricing by Friday',
        Description = marker
    ),
    new Opportunity(
        Name = '[RHC DEMO] Recurring Failure',
        AccountId = demoAccount.Id,
        StageName = demoStage.MasterLabel,
        CloseDate = Date.today().addDays(-7),
        Amount = 0,
        Probability = 0,
        NextStep = null,
        Description = marker
    ),
    new Opportunity(
        Name = '[RHC DEMO] Recovery Candidate',
        AccountId = demoAccount.Id,
        StageName = demoStage.MasterLabel,
        CloseDate = Date.today().addDays(-1),
        Amount = 0,
        Probability = 0,
        NextStep = null,
        Description = marker
    ),
    new Opportunity(
        Name = '[RHC DEMO] Mixed Readiness',
        AccountId = demoAccount.Id,
        StageName = demoStage.MasterLabel,
        CloseDate = Date.today().addDays(14),
        Amount = 25000,
        Probability = usableProbability,
        NextStep = null,
        Description = marker
    )
};

List<Opportunity> inserts = new List<Opportunity>();
List<Opportunity> updates = new List<Opportunity>();
for (Opportunity candidate : desired) {
    Opportunity existing = existingByName.get(candidate.Name);
    if (existing == null) {
        inserts.add(candidate);
    } else {
        candidate.Id = existing.Id;
        updates.add(candidate);
    }
}
Integer failedWrites = 0;
if (!inserts.isEmpty()) {
    for (Database.SaveResult result : Database.insert(inserts, false, AccessLevel.USER_MODE)) {
        if (!result.isSuccess()) failedWrites++;
    }
}
if (!updates.isEmpty()) {
    for (Database.SaveResult result : Database.update(updates, false, AccessLevel.USER_MODE)) {
        if (!result.isSuccess()) failedWrites++;
    }
}
if (failedWrites > 0) {
    throw new IllegalArgumentException(
        'One or more demo Opportunities could not be written. Review required fields and validation rules.'
    );
}

System.debug(LoggingLevel.INFO, 'RHC Reports demo Opportunities are ready. Marker=' + marker);
