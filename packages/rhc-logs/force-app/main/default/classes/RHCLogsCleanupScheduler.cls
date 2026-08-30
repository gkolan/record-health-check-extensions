/**
 * Runs the deliberately enabled RHC Logs bounded cleanup once daily.
 */
public with sharing class RHCLogsCleanupScheduler implements Schedulable {
    public static final String JOB_NAME = 'RHC Logs Daily Cleanup';
    public static final String DAILY_CRON = '0 0 2 * * ?';

    /**
     * Invoked by Salesforce Scheduled Apex.
     * @param context scheduler context
     */
    public void execute(SchedulableContext context) {
        RHCLogsCleanupService.run(RHCLogsCleanupService.CleanupMode.AUTOMATED);
    }

    /**
     * Creates the single package-owned daily cleanup job when absent.
     * @return scheduled job ID, or the existing job ID
     */
    public static Id scheduleDaily() {
        List<CronTrigger> existing = findJobs();
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        return System.schedule(JOB_NAME, DAILY_CRON, new RHCLogsCleanupScheduler());
    }

    /**
     * Aborts only package-owned cleanup jobs with the exact package job name.
     */
    public static void disable() {
        for (CronTrigger job : findJobs()) {
            System.abortJob(job.Id);
        }
    }

    /**
     * Reports whether the package-owned schedule exists.
     * @return true when the package-owned schedule exists
     */
    public static Boolean isScheduled() {
        return !findJobs().isEmpty();
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static List<CronTrigger> findJobs() {
        if (!Schema.SObjectType.CronTrigger.isAccessible()) {
            return new List<CronTrigger>();
        }
        return [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
              AND State != 'DELETED'
            ORDER BY CreatedDate ASC
            LIMIT 2
        ];
    }
}
