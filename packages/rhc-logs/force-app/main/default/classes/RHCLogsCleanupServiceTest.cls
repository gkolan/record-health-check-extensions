/**
 * Verifies bounded, exact-scope, boundary-safe, overlap-aware cleanup.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCLogsCleanupServiceTest {
    private static final Datetime FIXED_NOW = Datetime.newInstanceGmt(2026, 8, 25, 12, 0, 0);

    @IsTest
    static void shouldRejectMissingCleanupModeWithoutQueryOrDml() {
        Test.startTest();
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(null);
        Test.stopTest();

        Assert.areEqual('INVALID_MODE', result.status, 'Callers must select an explicit cleanup mode');
        Assert.areEqual(0, Limits.getQueries(), 'Invalid mode must return before querying policy');
        Assert.areEqual(0, Limits.getDmlStatements(), 'Invalid mode must return before DML');
    }

    @IsTest
    static void shouldRejectCleanupWhenViewerLacksRequiredAccess() {
        User viewer = RHCLogsTestDataFactory.createUser('cleanview');
        RHCLogsTestDataFactory.assignPermissionSet(viewer.Id, 'RHC_Logs_Viewer');

        RHCLogsCleanupService.CleanupResult result;
        System.runAs(viewer) {
            Test.startTest();
            result = RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.MANUAL);
            Test.stopTest();
        }

        Assert.areEqual('INSUFFICIENT_ACCESS', result.status, 'Viewer must not execute retention cleanup');
        Assert.areEqual(0, result.deletedCount, 'Rejected cleanup must not delete records');
    }

    @IsTest
    static void shouldDeleteOnlyExpiredPackageLogsWhenManualCleanupRuns() {
        RHCLogsTestDataFactory.createSettings(30, 10, RHCLogsTestDataFactory.AutomationState.DISABLED);
        RHCLogsTestDataFactory.createLog('expired', FIXED_NOW.addDays(-31));
        RHCLogsTestDataFactory.createLog('boundary', FIXED_NOW.addDays(-30));
        RHCLogsTestDataFactory.createLog('recent', FIXED_NOW.addDays(-1));
        Account unrelated = new Account(Name = 'Cleanup must not delete this Account');
        insert unrelated;
        RHCLogsCleanupService.nowOverride = FIXED_NOW;

        Test.startTest();
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.MANUAL);
        Test.stopTest();

        Assert.areEqual('SUCCESS', result.status, 'Configured manual cleanup should succeed');
        Assert.areEqual(1, result.deletedCount, 'Only the record before the exact boundary should be deleted');
        Assert.areEqual(2, [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c], 'Boundary and recent Logs must remain');
        Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Id = :unrelated.Id], 'Cleanup must not delete another object');
    }

    @IsTest
    static void shouldRespectBatchBoundWhenMoreExpiredLogsExist() {
        RHCLogsTestDataFactory.createSettings(7, 2, RHCLogsTestDataFactory.AutomationState.ENABLED);
        List<Record_Health_Check_Diagnostic_Log__c> logs =
            new List<Record_Health_Check_Diagnostic_Log__c>();
        for (Integer indexValue = 0; indexValue < 3; indexValue++) {
            logs.add(RHCLogsTestDataFactory.buildLog(
                'expired-' + indexValue,
                FIXED_NOW.addDays(-10).addMinutes(indexValue)
            ));
        }
        insert logs;
        RHCLogsCleanupService.nowOverride = FIXED_NOW;

        Test.startTest();
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.AUTOMATED);
        Assert.areEqual(2, result.deletedCount, 'One invocation must honor the configured delete bound');
        Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c], 'Remaining work should be retry-safe');
        Assert.areEqual(1, Limits.getQueueableJobs(), 'A full batch must enqueue one continuation');
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c], 'The continuation drains the remaining backlog');
    }

    @IsTest
    static void shouldStopContinuingAtTheLastAllowedHop() {
        RHCLogsTestDataFactory.createSettings(7, 1, RHCLogsTestDataFactory.AutomationState.ENABLED);
        insert new List<Record_Health_Check_Diagnostic_Log__c>{
            RHCLogsTestDataFactory.buildLog('expired-a', FIXED_NOW.addDays(-10)),
            RHCLogsTestDataFactory.buildLog('expired-b', FIXED_NOW.addDays(-10))
        };
        RHCLogsCleanupService.nowOverride = FIXED_NOW;

        Test.startTest();
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(
            RHCLogsCleanupService.CleanupMode.AUTOMATED,
            RHCLogsCleanupService.MAX_CONTINUATIONS
        );
        Integer queued = Limits.getQueueableJobs();
        Test.stopTest();

        Assert.areEqual(1, result.deletedCount, 'The last hop still deletes one bounded batch');
        Assert.areEqual(0, queued, 'The last allowed hop must not enqueue another continuation');
        Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c], 'Remaining rows wait for the next schedule');
    }

    @IsTest
    static void shouldSkipWhenCleanupLockIsActive() {
        Record_Health_Check_Log_Settings__c settingsRecord =
            RHCLogsTestDataFactory.createSettings(30, 10, RHCLogsTestDataFactory.AutomationState.ENABLED);
        settingsRecord.CleanupInProgress__c = true;
        settingsRecord.CleanupRunToken__c = 'active-run';
        settingsRecord.CleanupLockAcquiredAt__c = FIXED_NOW.addMinutes(-5);
        update settingsRecord;
        RHCLogsCleanupService.nowOverride = FIXED_NOW;

        Test.startTest();
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.AUTOMATED);
        Test.stopTest();

        Assert.areEqual('SKIPPED_OVERLAP', result.status, 'An active overlap guard should skip safely');
        Assert.areEqual(0, result.deletedCount, 'Overlap skip must not delete records');
        Record_Health_Check_Log_Settings__c retainedLock = [
            SELECT CleanupInProgress__c, CleanupRunToken__c, CleanupLockAcquiredAt__c
            FROM Record_Health_Check_Log_Settings__c
            WHERE Id = :settingsRecord.Id
        ];
        Assert.isTrue(retainedLock.CleanupInProgress__c, 'Overlap skip must preserve the active lock');
        Assert.areEqual('active-run', retainedLock.CleanupRunToken__c, 'Overlap skip must preserve the owner token');
        Assert.areEqual(
            FIXED_NOW.addMinutes(-5),
            retainedLock.CleanupLockAcquiredAt__c,
            'Overlap skip must preserve the acquisition time'
        );
    }

    @IsTest
    static void shouldRecoverWhenCleanupLockIsStale() {
        Record_Health_Check_Log_Settings__c settingsRecord =
            RHCLogsTestDataFactory.createSettings(30, 10, RHCLogsTestDataFactory.AutomationState.ENABLED);
        settingsRecord.CleanupInProgress__c = true;
        settingsRecord.CleanupLockAcquiredAt__c = FIXED_NOW.addMinutes(-61);
        update settingsRecord;
        RHCLogsTestDataFactory.createLog('expired', FIXED_NOW.addDays(-31));
        RHCLogsCleanupService.nowOverride = FIXED_NOW;

        Test.startTest();
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.AUTOMATED);
        Test.stopTest();

        Assert.areEqual('SUCCESS', result.status, 'A stale overlap guard should be recoverable');
        Assert.areEqual(1, result.deletedCount, 'Recovered cleanup should process eligible Logs');
    }

    @IsTest
    static void shouldRemainDisabledWhenRetentionIsNotConfigured() {
        Test.startTest();
        RHCLogsCleanupService.CleanupResult result = RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.MANUAL);
        Test.stopTest();

        Assert.areEqual('DISABLED_OR_UNCONFIGURED', result.status, 'Cleanup must default disabled');
        Assert.areEqual(0, result.deletedCount, 'Unconfigured cleanup must not delete anything');
    }

    @IsTest
    static void shouldNotDeleteWhenAutomatedCleanupIsDisabled() {
        RHCLogsTestDataFactory.createSettings(30, 10, RHCLogsTestDataFactory.AutomationState.DISABLED);
        RHCLogsTestDataFactory.createLog('disabled-expired', FIXED_NOW.addDays(-31));
        RHCLogsCleanupService.nowOverride = FIXED_NOW;

        Test.startTest();
        RHCLogsCleanupService.CleanupResult result =
            RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.AUTOMATED);
        Test.stopTest();

        Assert.areEqual('DISABLED', result.status, 'Schedule-driven cleanup must honor its enablement flag');
        Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Diagnostic_Log__c], 'Disabled cleanup must retain Logs');
    }
}
