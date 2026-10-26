/**
 * Red and war scenarios for Reports: retention boundaries, permission denial and error
 * contracts, aggregate access enforcement, misconfiguration, and bounded-query fail-closed.
 */
@IsTest
private class RHCReportsAdversarialTest {
    private static final String CHECK_SET = 'Opportunity_Close_Readiness';

    private static Record_Health_Check_Report_Result__c resultFact(
        String eventId,
        String status,
        Datetime occurredAt
    ) {
        return RHCReportsTestDataFactory.resultFact(
            new RHCReportsTestDataFactory.ResultFactRequest(
                eventId,
                status,
                occurredAt
            )
        );
    }

    private static Record_Health_Check_Report_Result__c resultFact(
        String eventId,
        String status,
        Datetime occurredAt,
        String recordId
    ) {
        return RHCReportsTestDataFactory.resultFact(
            new RHCReportsTestDataFactory.ResultFactRequest(
                    eventId,
                    status,
                    occurredAt
                )
                .withRecord(recordId)
        );
    }

    // ------------------------------------------------------------ retention boundaries

    @IsTest
    static void shouldDeleteOnlyFactsStrictlyOlderThanTheCutoff() {
        Datetime cutoff = Datetime.now().addDays(-90);
        Record_Health_Check_Report_Result__c older = resultFact(
            'evt-older',
            'FAIL',
            cutoff.addSeconds(-1)
        );
        Record_Health_Check_Report_Result__c atBoundary = resultFact(
            'evt-boundary',
            'FAIL',
            cutoff.addSeconds(1)
        );
        Record_Health_Check_Report_Result__c newer = resultFact(
            'evt-newer',
            'PASS',
            cutoff.addDays(10)
        );
        insert new List<Record_Health_Check_Report_Result__c>{
            older, atBoundary, newer
        };

        Test.startTest();
        Database.executeBatch(
            RHCReportsRetentionBatch.withoutContinuation('RESULT', cutoff, null),
            200
        );
        Test.stopTest();

        Set<Id> remaining = new Set<Id>();
        for (Record_Health_Check_Report_Result__c row : [
            SELECT Id FROM Record_Health_Check_Report_Result__c
        ]) {
            remaining.add(row.Id);
        }
        Assert.isFalse(
            remaining.contains(older.Id),
            'A fact older than the cutoff must be deleted.'
        );
        Assert.isTrue(
            remaining.contains(atBoundary.Id),
            'A fact inside the window by one second must survive.'
        );
        Assert.isTrue(
            remaining.contains(newer.Id),
            'A recent fact must survive.'
        );
        Assert.areEqual(
            2,
            remaining.size(),
            'Exactly the two in-window facts must remain.'
        );
    }

    @IsTest
    static void shouldNotTouchRunFactsWhenPurgingResultFacts() {
        Datetime cutoff = Datetime.now().addDays(-30);
        insert resultFact('evt-expired-result', 'FAIL', cutoff.addDays(-5));
        insert RHCReportsTestDataFactory.runFact(
            'evt-expired-run',
            cutoff.addDays(-5)
        );

        Test.startTest();
        Database.executeBatch(
            RHCReportsRetentionBatch.withoutContinuation('RESULT', cutoff, null),
            200
        );
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Report_Result__c],
            'The targeted Result facts must be removed.'
        );
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Record_Health_Check_Report_Run__c],
            'An equally expired Run fact must survive a RESULT-only purge.'
        );
    }

    @IsTest
    static void shouldNotDeleteSnapshotsNewerThanTheSnapshotCutoff() {
        Date cutoff = Date.today().addDays(-730);
        insert new List<Record_Health_Check_Daily_Snapshot__c>{
            snapshot(cutoff.addDays(-1), 'expired'),
            snapshot(cutoff, 'at-boundary'),
            snapshot(cutoff.addDays(1), 'current')
        };

        Test.startTest();
        Database.executeBatch(
            RHCReportsRetentionBatch.withoutContinuation(
                'SNAPSHOT',
                null,
                cutoff
            ),
            200
        );
        Test.stopTest();

        List<Record_Health_Check_Daily_Snapshot__c> remaining = [
            SELECT SnapshotDate__c
            FROM Record_Health_Check_Daily_Snapshot__c
            ORDER BY SnapshotDate__c
        ];
        Assert.areEqual(
            2,
            remaining.size(),
            'Only the snapshot strictly before the cutoff may be deleted.'
        );
        Assert.areEqual(
            cutoff,
            remaining[0].SnapshotDate__c,
            'The snapshot exactly at the cutoff must survive.'
        );
    }

    @IsTest
    static void shouldFailClosedOnAnUnknownRetentionTarget() {
        Test.startTest();
        try {
            RHCReportsRetentionBatch batch = RHCReportsRetentionBatch.withoutContinuation(
                'NOT_A_TARGET',
                Datetime.now(),
                Date.today()
            );
            batch.start(null);
            Assert.fail('An unknown retention target must be refused.');
        } catch (RHCReportsRetentionBatch.RHCReportsRetentionException error) {
            Assert.isTrue(
                error.getMessage().contains('Unknown retention target'),
                'The refusal must name the misconfiguration: ' + error.getMessage()
            );
        }
        Test.stopTest();
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Report_Result__c],
            'A refused retention target must delete nothing.'
        );
    }

    // ------------------------------------------------------------ permission denial and contracts

    @IsTest
    static void shouldDenyEverySetupEntryPointWithoutTheManagePermission() {
        User standard = RHCReportsTestDataFactory.createStandardUser('rptdeny');
        List<String> messages = new List<String>();
        Integer dmlInside;
        Test.startTest();
        System.runAs(standard) {
            Integer dmlBefore = Limits.getDmlStatements();
            messages.add(denial('getSettings'));
            messages.add(denial('saveSettings'));
            messages.add(denial('runAggregationNow'));
            messages.add(denial('aggregateNow'));
            dmlInside = Limits.getDmlStatements() - dmlBefore;
        }
        Test.stopTest();
        Assert.areEqual(
            0,
            dmlInside,
            'Denied setup calls must perform no DML.'
        );
        for (String message : messages) {
            Assert.areEqual(
                'Manage RHC Reports permission is required.',
                message,
                'Every setup entry point must deny with the stable typed message.'
            );
        }
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Daily_Snapshot__c],
            'A denied caller must not cause aggregation output.'
        );
    }

    @IsTest
    static void shouldSurfaceAdminFacingMessagesRatherThanScriptThrownException() {
        Test.startTest();
        String message = denial('getSettings');
        Test.stopTest();
        // Runs as the test-running admin, who also lacks the custom permission in a
        // scratch org, so the denial text itself is what must survive the Aura boundary.
        Assert.isFalse(
            message.containsIgnoreCase('Script-thrown exception'),
            'The Aura boundary must carry the admin-facing text, not a generic failure.'
        );
        Assert.isFalse(
            message.containsIgnoreCase('Class.RHCReports'),
            'The message must not carry an Apex stack trace: ' + message
        );
        Assert.isFalse(
            message.contains(UserInfo.getOrganizationId()),
            'The message must not leak the org id.'
        );
        Assert.isFalse(
            message.contains(UserInfo.getUserName()),
            'The message must not leak the username.'
        );
    }

    // ------------------------------------------------------------ aggregate access enforcement

    @IsTest
    static void shouldNotReturnObservedCountsToAUserWhoCannotReadFactObjects() {
        insert resultFact('evt-agg', 'FAIL', Datetime.now().addDays(-1));
        insert RHCReportsTestDataFactory.runFact(
            'evt-agg-run',
            Datetime.now().addDays(-1)
        );
        User standard = RHCReportsTestDataFactory.createStandardUser('rptagg');
        Boolean reachedData = true;
        Test.startTest();
        System.runAs(standard) {
            try {
                List<RHCReportsCoverageController.CoverageRow> rows = RHCReportsCoverageController.getCoverage();
                Integer observed = 0;
                for (RHCReportsCoverageController.CoverageRow row : rows) {
                    observed += row.runFactCount == null ? 0 : row.runFactCount;
                }
                reachedData = observed > 0;
            } catch (Exception error) {
                // A hard denial is also an acceptable fail-closed outcome.
                reachedData = false;
            }
        }
        Test.stopTest();
        Assert.isFalse(
            reachedData,
            'A user without read access to the fact objects must observe no aggregate counts.'
        );
    }

    @IsTest
    static void shouldFailClosedWhenABoundedQueryReachesItsSafetyLimit() {
        Test.startTest();
        try {
            RHCReportsAggregationRepository.assertQueryComplete(
                5000,
                5000,
                'Prior Result Fact'
            );
            Assert.fail('Reaching the safety boundary must fail closed.');
        } catch (RHCReportsAggregationService.RHCReportsAggregationException error) {
            Assert.isTrue(
                error.getMessage().contains('No partial snapshot was written'),
                'The refusal must state that nothing partial was persisted: ' +
                error.getMessage()
            );
        }
        // One row below the boundary is a complete, trustworthy result.
        RHCReportsAggregationRepository.assertQueryComplete(
            4999,
            5000,
            'Prior Result Fact'
        );
        Test.stopTest();
    }

    // ------------------------------------------------------------ misconfiguration

    @IsTest
    static void shouldRejectOutOfRangeAndMissingRetentionSettings() {
        User manager = reportsAdmin('rptrange');
        Map<String, List<Integer>> rejected = new Map<String, List<Integer>>{
            'zero detailed' => new List<Integer>{ 0, 730 },
            'negative detailed' => new List<Integer>{ -1, 730 },
            'absurd detailed' => new List<Integer>{ 4000, 730 },
            'null detailed' => new List<Integer>{ null, 730 },
            'zero snapshot' => new List<Integer>{ 90, 0 },
            'absurd snapshot' => new List<Integer>{ 90, 40000 }
        };
        Test.startTest();
        System.runAs(manager) {
            for (String label : rejected.keySet()) {
                List<Integer> days = rejected.get(label);
                String message = saveFailureMessage(
                    days[0],
                    days[1],
                    'America/Chicago'
                );
                Assert.isTrue(
                    message.contains('must be between'),
                    'An out-of-range window must be refused for ' +
                    label +
                    ', got: ' +
                    message
                );
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldRejectMissingAndBogusAggregationTimeZones() {
        User manager = reportsAdmin('rpttz');
        String blank;
        String bogus;
        Test.startTest();
        System.runAs(manager) {
            blank = saveFailureMessage(90, 730, '   ');
            bogus = saveFailureMessage(90, 730, 'Mars/Olympus_Mons');
        }
        Test.stopTest();
        Assert.isTrue(
            blank.contains('time zone is required'),
            'A blank time zone must be refused: ' + blank
        );
        Assert.isTrue(
            bogus.contains('valid Salesforce time-zone ID'),
            'An unknown time zone must be refused: ' + bogus
        );
    }

    @IsTest
    static void shouldRejectAggregatingTodayOrTheFuture() {
        User manager = reportsAdmin('rptday');
        List<String> messages = new List<String>();
        Test.startTest();
        System.runAs(manager) {
            messages.add(aggregateFailureMessage(Date.today()));
            messages.add(aggregateFailureMessage(Date.today().addDays(7)));
            messages.add(aggregateFailureMessage(null));
        }
        Test.stopTest();
        for (String message : messages) {
            Assert.isTrue(
                message.contains('completed date before today'),
                'An incomplete day must never be aggregated: ' + message
            );
        }
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Record_Health_Check_Daily_Snapshot__c],
            'A refused aggregation must write no snapshot.'
        );
    }

    // ------------------------------------------------------------ bulk volume

    @IsTest
    static void shouldAggregateHighFactVolumeWithinQueryAndDmlLimits() {
        List<Record_Health_Check_Report_Result__c> facts = new List<Record_Health_Check_Report_Result__c>();
        Datetime occurredAt = Datetime.now().addDays(-1);
        for (Integer index = 0; index < 251; index++) {
            facts.add(
                resultFact(
                    'evt-bulk-' + index,
                    Math.mod(index, 2) == 0 ? 'PASS' : 'FAIL',
                    occurredAt,
                    RHCReportsTestDataFactory.fakeId(
                        Opportunity.SObjectType,
                        index + 1
                    )
                )
            );
        }
        insert facts;

        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        List<Record_Health_Check_Report_Result__c> selected = RHCReportsAggregationRepository.selectResults(
            occurredAt.addHours(-1),
            occurredAt.addHours(1)
        );
        Integer queriesUsed = Limits.getQueries() - queriesBefore;
        Test.stopTest();

        Assert.areEqual(
            251,
            selected.size(),
            'Every fact in the window must be selected.'
        );
        Assert.areEqual(
            1,
            queriesUsed,
            'Selecting 251 facts must cost exactly one aggregate query.'
        );
    }

    @IsTest
    static void shouldSelectPriorStatusesInOneQueryRegardlessOfKeyCount() {
        List<Record_Health_Check_Report_Result__c> facts = new List<Record_Health_Check_Report_Result__c>();
        Set<String> recordIds = new Set<String>();
        Set<String> checkNames = new Set<String>();
        Datetime occurredAt = Datetime.now().addDays(-5);
        for (Integer index = 0; index < 251; index++) {
            Record_Health_Check_Report_Result__c fact = resultFact(
                'evt-prior-' + index,
                'FAIL',
                occurredAt,
                RHCReportsTestDataFactory.fakeId(
                    Opportunity.SObjectType,
                    index + 1
                )
            );
            facts.add(fact);
            recordIds.add(fact.RecordId__c);
            checkNames.add(fact.CheckQualifiedApiName__c);
        }
        insert facts;

        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        Map<String, String> statuses = RHCReportsAggregationRepository.selectPriorStatuses(
            occurredAt.addDays(1),
            recordIds,
            checkNames
        );
        Integer queriesUsed = Limits.getQueries() - queriesBefore;
        Test.stopTest();

        Assert.areEqual(
            1,
            queriesUsed,
            'Prior-status lookup must stay a single query at volume.'
        );
        Assert.isFalse(
            statuses.isEmpty(),
            'Prior statuses must be resolved for the supplied keys.'
        );
    }

    @IsTest
    static void shouldReturnNoPriorStatusesForEmptyInputWithoutQuerying() {
        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        Map<String, String> noRecords = RHCReportsAggregationRepository.selectPriorStatuses(
            Datetime.now(),
            new Set<String>(),
            new Set<String>{ 'Check_A' }
        );
        Map<String, String> noChecks = RHCReportsAggregationRepository.selectPriorStatuses(
            Datetime.now(),
            new Set<String>{ 'a' },
            new Set<String>()
        );
        Integer queriesUsed = Limits.getQueries() - queriesBefore;
        Test.stopTest();
        Assert.areEqual(0, noRecords.size(), 'Empty record keys must short-circuit.');
        Assert.areEqual(0, noChecks.size(), 'Empty check keys must short-circuit.');
        Assert.areEqual(
            0,
            queriesUsed,
            'An empty key set must not issue SOQL at all.'
        );
    }

    // ------------------------------------------------------------ helpers

    private static Record_Health_Check_Daily_Snapshot__c snapshot(
        Date snapshotDate,
        String key
    ) {
        return new Record_Health_Check_Daily_Snapshot__c(
            SnapshotKey__c = key + '|' + String.valueOf(snapshotDate),
            SnapshotDate__c = snapshotDate,
            AggregationTimeZone__c = 'America/Chicago',
            CheckSetQualifiedApiName__c = CHECK_SET,
            Grain__c = 'CHECK_SET',
            Source__c = 'BATCH',
            RunCount__c = 1
        );
    }

    /**
     * Creates a user holding the packaged Reports admin permission set, so validation
     * rather than the permission gate is what the test exercises.
     * @param stem unique user stem
     * @return permissioned user
     */
    private static User reportsAdmin(String stem) {
        User manager = RHCReportsTestDataFactory.createStandardUser(stem);
        PermissionSet permissionSet = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'RHC_Reports_Admin'
            LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = manager.Id,
            PermissionSetId = permissionSet.Id
        );
        return manager;
    }

    private static String denial(String entryPoint) {
        try {
            if (entryPoint == 'getSettings') {
                RHCReportsSetupController.getSettings();
            } else if (entryPoint == 'saveSettings') {
                RHCReportsSetupController.saveSettings(null);
            } else if (entryPoint == 'runAggregationNow') {
                RHCReportsSetupController.runAggregationNow();
            } else {
                RHCReportsSetupController.aggregateNow(Date.today().addDays(-1));
            }
            return 'NOT_DENIED';
        } catch (AuraHandledException error) {
            return error.getMessage();
        }
    }

    private static String saveFailureMessage(
        Integer detailedDays,
        Integer snapshotDays,
        String timeZoneId
    ) {
        RHCReportsSetupController.SaveSettingsInput input = new RHCReportsSetupController.SaveSettingsInput();
        input.detailedRetentionDays = detailedDays;
        input.snapshotRetentionDays = snapshotDays;
        input.aggregationTimeZone = timeZoneId;
        input.dailyAggregationEnabled = true;
        input.retentionCleanupEnabled = false;
        input.scheduled = false;
        try {
            RHCReportsSetupController.saveSettings(input);
            return 'NOT_REJECTED';
        } catch (AuraHandledException error) {
            return error.getMessage();
        }
    }

    private static String aggregateFailureMessage(Date snapshotDate) {
        try {
            RHCReportsSetupController.aggregateNow(snapshotDate);
            return 'NOT_REJECTED';
        } catch (AuraHandledException error) {
            return error.getMessage();
        }
    }
}
