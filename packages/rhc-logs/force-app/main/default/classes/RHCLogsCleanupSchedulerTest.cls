/**
 * Verifies single-job scheduling and scheduled cleanup delegation.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCLogsCleanupSchedulerTest {
    @IsTest
    static void shouldCreateOnlyOneJobWhenScheduledRepeatedly() {
        Test.startTest();
        Id firstJobId = RHCLogsCleanupScheduler.scheduleDaily();
        Id secondJobId = RHCLogsCleanupScheduler.scheduleDaily();
        Test.stopTest();

        Assert.areEqual(firstJobId, secondJobId, 'Repeated scheduling should return the same package job');
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :RHCLogsCleanupScheduler.JOB_NAME],
            'At most one package-owned daily job should exist'
        );
    }

    @IsTest
    static void shouldDisableOnlyPackageJobWhenRequested() {
        Test.startTest();
        RHCLogsCleanupScheduler.scheduleDaily();
        RHCLogsCleanupScheduler.disable();
        Test.stopTest();

        Assert.isFalse(RHCLogsCleanupScheduler.isScheduled(), 'Disabling should remove the package-owned schedule');
    }
}
