// Publishes a deterministic, synthetic RHC Reports dataset through the canonical core events.
// Run only in a sandbox/demo org after both packages are installed.
// Safe to rerun: Event IDs are stable, so RHC Reports must upsert rather than duplicate facts.
String marker = 'RHC_REPORTS_DEMO_V1';
String checkSetName = 'Opportunity_Close_Readiness';
List<Opportunity> opportunities = [
    SELECT Id, Name
    FROM Opportunity
    WHERE Description = :marker
    ORDER BY Name
];
if (opportunities.size() != 4) {
    throw new IllegalArgumentException(
        'Expected four marked demo Opportunities. Run create-opportunity-demo.apex first.'
    );
}

Map<String, Id> recordIdByName = new Map<String, Id>();
for (Opportunity opportunityRecord : opportunities) {
    recordIdByName.put(opportunityRecord.Name, opportunityRecord.Id);
}

List<String> opportunityNames = new List<String>{
    '[RHC DEMO] Ready Opportunity',
    '[RHC DEMO] Recurring Failure',
    '[RHC DEMO] Recovery Candidate',
    '[RHC DEMO] Mixed Readiness'
};
List<String> checkNames = new List<String>{
    'Opportunity_Amount_Positive',
    'Opportunity_Close_Date_Current',
    'Opportunity_Next_Step_Documented',
    'Opportunity_Probability_Meaningful'
};
List<String> sources = new List<String>{
    'USER_INITIATED', 'FLOW', 'BATCH', 'QUEUEABLE', 'SCHEDULED', 'APEX_API'
};

List<rhc__Record_Health_Check_Set_Run__e> runEvents =
    new List<rhc__Record_Health_Check_Set_Run__e>();
List<rhc__Record_Health_Check_Result__e> resultEvents =
    new List<rhc__Record_Health_Check_Result__e>();

for (Integer weekIndex = 5; weekIndex >= 0; weekIndex--) {
    Date sampleDate = Date.today().addDays(-(weekIndex * 7 + 1));
    Datetime occurredAt = Datetime.newInstanceGMT(
        sampleDate,
        Time.newInstance(12, 0, 0, 0)
    );
    String source = sources[Math.mod(weekIndex, sources.size())];
    for (Integer recordIndex = 0; recordIndex < opportunityNames.size(); recordIndex++) {
        String opportunityName = opportunityNames[recordIndex];
        Id recordId = recordIdByName.get(opportunityName);
        String runId = 'RHC-DEMO-' + String.valueOf(sampleDate) + '-' + recordIndex;
        List<String> statuses;
        if (recordIndex == 0) {
            statuses = new List<String>{ 'PASS', 'PASS', 'PASS', 'PASS' };
        } else if (recordIndex == 1) {
            statuses = new List<String>{ 'FAIL', 'FAIL', 'FAIL', 'FAIL' };
        } else if (recordIndex == 2) {
            String recoveryStatus = weekIndex >= 3 ? 'FAIL' : 'PASS';
            statuses = new List<String>{
                recoveryStatus, recoveryStatus, recoveryStatus, recoveryStatus
            };
        } else {
            statuses = new List<String>{
                'PASS', 'ERROR', 'UNABLE_TO_EVALUATE', 'SKIPPED'
            };
        }

        Integer passed = 0;
        Integer failed = 0;
        Integer skipped = 0;
        Integer unable = 0;
        Integer systemError = 0;
        for (String status : statuses) {
            if (status == 'PASS') passed++;
            else if (status == 'FAIL') failed++;
            else if (status == 'SKIPPED') skipped++;
            else if (status == 'UNABLE_TO_EVALUATE') unable++;
            else if (status == 'ERROR') systemError++;
        }

        String runEventId = runId + '-RUN';
        runEvents.add(new rhc__Record_Health_Check_Set_Run__e(
            rhc__EventId__c = runEventId,
            rhc__RunId__c = runId,
            rhc__CheckSetQualifiedApiName__c = checkSetName,
            rhc__RecordId__c = recordId,
            rhc__OccurredAt__c = occurredAt,
            rhc__Source__c = source,
            rhc__ContractVersion__c = '1.0',
            rhc__FrameworkVersion__c = '2.0.4',
            rhc__Phase__c = 'COMPLETED',
            rhc__SubmittedRecordCount__c = 1,
            rhc__ProcessedRecordCount__c = 1,
            rhc__EligibleCheckCount__c = 4,
            rhc__EvaluatedCheckCount__c = 4,
            rhc__PassedCount__c = passed,
            rhc__FailedCount__c = failed,
            rhc__SkippedCount__c = skipped,
            rhc__UnableCount__c = unable,
            rhc__SystemErrorCount__c = systemError
        ));

        for (Integer checkIndex = 0; checkIndex < checkNames.size(); checkIndex++) {
            String status = statuses[checkIndex];
            String reasonCode;
            if (status == 'SKIPPED') reasonCode = 'NOT_APPLICABLE_BY_FORMULA';
            else if (status == 'UNABLE_TO_EVALUATE') reasonCode = 'INVALID_FORMULA';
            else if (status == 'ERROR') reasonCode = 'CLIENT_CALL_FAILED';
            String severity = status == 'FAIL'
                ? (checkIndex == 0 ? 'CRITICAL' : 'WARNING')
                : null;
            resultEvents.add(new rhc__Record_Health_Check_Result__e(
                rhc__EventId__c = runId + '-RESULT-' + checkIndex,
                rhc__RunId__c = runId,
                rhc__CheckSetQualifiedApiName__c = checkSetName,
                rhc__CheckQualifiedApiName__c = checkNames[checkIndex],
                rhc__RecordId__c = recordId,
                rhc__Status__c = status,
                rhc__Severity__c = severity,
                rhc__ReasonCode__c = reasonCode,
                rhc__OccurredAt__c = occurredAt,
                rhc__Source__c = source,
                rhc__ContractVersion__c = '1.0',
                rhc__FrameworkVersion__c = '2.0.4',
                rhc__ContainsRestrictedDetail__c = false
            ));
        }
    }
}

Datetime coverageOccurredAt = Datetime.now();
Id coverageRecordId = recordIdByName.get('[RHC DEMO] Ready Opportunity');
runEvents.add(new rhc__Record_Health_Check_Set_Run__e(
    rhc__EventId__c = 'RHC-DEMO-NO-FAILURES-RUN',
    rhc__RunId__c = 'RHC-DEMO-NO-FAILURES',
    rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_No_Failures',
    rhc__RecordId__c = coverageRecordId,
    rhc__OccurredAt__c = coverageOccurredAt,
    rhc__Source__c = 'FLOW',
    rhc__ContractVersion__c = '1.0',
    rhc__FrameworkVersion__c = '2.0.4',
    rhc__Phase__c = 'COMPLETED',
    rhc__SubmittedRecordCount__c = 1,
    rhc__ProcessedRecordCount__c = 1,
    rhc__EligibleCheckCount__c = 4,
    rhc__EvaluatedCheckCount__c = 4,
    rhc__PassedCount__c = 4,
    rhc__FailedCount__c = 0,
    rhc__SkippedCount__c = 0,
    rhc__UnableCount__c = 0,
    rhc__SystemErrorCount__c = 0
));
runEvents.add(new rhc__Record_Health_Check_Set_Run__e(
    rhc__EventId__c = 'RHC-DEMO-ACTIONABLE-RUN',
    rhc__RunId__c = 'RHC-DEMO-ACTIONABLE',
    rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Actionable',
    rhc__RecordId__c = coverageRecordId,
    rhc__OccurredAt__c = coverageOccurredAt,
    rhc__Source__c = 'FLOW',
    rhc__ContractVersion__c = '1.0',
    rhc__FrameworkVersion__c = '2.0.4',
    rhc__Phase__c = 'COMPLETED',
    rhc__SubmittedRecordCount__c = 1,
    rhc__ProcessedRecordCount__c = 1,
    rhc__EligibleCheckCount__c = 4,
    rhc__EvaluatedCheckCount__c = 4,
    rhc__PassedCount__c = 3,
    rhc__FailedCount__c = 1,
    rhc__SkippedCount__c = 0,
    rhc__UnableCount__c = 0,
    rhc__SystemErrorCount__c = 0
));
resultEvents.add(new rhc__Record_Health_Check_Result__e(
    rhc__EventId__c = 'RHC-DEMO-ACTIONABLE-RESULT',
    rhc__RunId__c = 'RHC-DEMO-ACTIONABLE',
    rhc__CheckSetQualifiedApiName__c = 'RHC_Demo_Actionable',
    rhc__CheckQualifiedApiName__c = 'Opportunity_Close_Date_Current',
    rhc__RecordId__c = coverageRecordId,
    rhc__Status__c = 'FAIL',
    rhc__Severity__c = 'WARNING',
    rhc__OccurredAt__c = coverageOccurredAt,
    rhc__Source__c = 'FLOW',
    rhc__ContractVersion__c = '1.0',
    rhc__FrameworkVersion__c = '2.0.4',
    rhc__ContainsRestrictedDetail__c = false
));

// Duplicate one Run and one Result in the same delivery. Stable Event IDs must collapse them.
runEvents.add((rhc__Record_Health_Check_Set_Run__e) runEvents[0].clone(false, true, false, false));
resultEvents.add((rhc__Record_Health_Check_Result__e) resultEvents[0].clone(false, true, false, false));

List<Database.SaveResult> runPublishResults = EventBus.publish(runEvents);
List<Database.SaveResult> resultPublishResults = EventBus.publish(resultEvents);
Integer failedPublishes = 0;
for (Database.SaveResult publishResult : runPublishResults) {
    if (!publishResult.isSuccess()) failedPublishes++;
}
for (Database.SaveResult publishResult : resultPublishResults) {
    if (!publishResult.isSuccess()) failedPublishes++;
}
if (failedPublishes > 0) {
    throw new IllegalArgumentException(
        'One or more synthetic Platform Events were not accepted for publication.'
    );
}
System.debug(
    LoggingLevel.INFO,
    'Accepted demo events: runs=' + runEvents.size() + ', results=' + resultEvents.size() +
    '. Subscriber processing remains asynchronous.'
);
