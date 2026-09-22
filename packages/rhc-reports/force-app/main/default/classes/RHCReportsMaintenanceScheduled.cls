/**
 * Launches daily aggregation and irreversible retention cleanup from package settings.
 */
public inherited sharing class RHCReportsMaintenanceScheduled implements Schedulable {
    public static final String JOB_NAME = 'RHC Reports Daily Maintenance';
    public static final String CRON_DAILY = '0 15 2 * * ?';
    /**
     * Launches enabled maintenance operations.
     * @param context schedule context
     */
    public void execute(SchedulableContext context) {
        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        if (setting == null) {
            return;
        }
        String timeZoneId = String.isBlank(setting.AggregationTimeZone__c)
            ? 'GMT'
            : setting.AggregationTimeZone__c;
        if (setting.DailyAggregationEnabled__c == true) {
            Date localToday = Date.valueOf(
                Datetime.now().format('yyyy-MM-dd', timeZoneId)
            );
            Date latestCompletedDate = localToday.addDays(-1);
            Date nextSnapshotDate = setting.LastAggregatedDate__c == null ||
                setting.LastAggregatedDate__c >= latestCompletedDate
                ? latestCompletedDate
                : setting.LastAggregatedDate__c.addDays(1);
            System.enqueueJob(
                new RHCReportsDailyAggregationQueueable(
                    nextSnapshotDate,
                    timeZoneId,
                    RHCReportsDailyAggregationQueueable.CatchUpMode.ENABLED
                )
            );
            return;
        }
        if (setting.RetentionCleanupEnabled__c == true) {
            launchRetention(setting);
        }
    }

    /**
     * Starts the ordered retention chain after aggregation is complete or disabled.
     * @param setting effective organization settings
     */
    public static void launchRetention(Record_Health_Check_Report_Setting__c setting) {
        Integer detailDays = setting.DetailedRetentionDays__c == null
            ? 90
            : setting.DetailedRetentionDays__c.intValue();
        Integer snapshotDays = setting.SnapshotRetentionDays__c == null
            ? 730
            : setting.SnapshotRetentionDays__c.intValue();
        Database.executeBatch(
            new RHCReportsRetentionBatch(
                'RESULT',
                Datetime.now().addDays(-detailDays),
                Date.today().addDays(-snapshotDays)
            ),
            200
        );
    }
}
