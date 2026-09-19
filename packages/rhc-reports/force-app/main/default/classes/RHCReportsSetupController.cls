/**
 * Provides the permission-gated reporting setup assistant API.
 */
public with sharing class RHCReportsSetupController {
    /**
     * Returns effective package settings with Day-1 defaults.
     * @return setup values for the assistant
     */
    @AuraEnabled
    public static SettingDTO getSettings() {
        requireManager();
        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        SettingDTO output = new SettingDTO();
        output.detailedRetentionDays = setting?.DetailedRetentionDays__c == null
            ? 90
            : setting.DetailedRetentionDays__c.intValue();
        output.snapshotRetentionDays = setting?.SnapshotRetentionDays__c == null
            ? 730
            : setting.SnapshotRetentionDays__c.intValue();
        output.dailyAggregationEnabled =
            setting?.DailyAggregationEnabled__c == null
            ? true
            : setting.DailyAggregationEnabled__c;
        output.retentionCleanupEnabled =
            setting?.RetentionCleanupEnabled__c == null
            ? false
            : setting.RetentionCleanupEnabled__c;
        output.aggregationTimeZone = String.isBlank(setting?.AggregationTimeZone__c)
            ? UserInfo.getTimeZone().getID()
            : setting.AggregationTimeZone__c;
        output.lastAggregatedDate = setting?.LastAggregatedDate__c;
        output.lastAggregationAttemptAt = setting?.LastAggregationAttemptAt__c;
        output.lastAggregationStatus = setting?.LastAggregationStatus__c;
        output.lastAggregationErrorType = setting?.LastAggregationErrorType__c;
        output.lastIngestionFailureAt = setting?.LastIngestionFailureAt__c;
        output.lastIngestionErrorCodes = setting?.LastIngestionErrorCodes__c;
        output.cronTriggerId = setting?.CronTriggerId__c;
        output.scheduled = String.isNotBlank(output.cronTriggerId);
        return output;
    }
    /**
     * Queues aggregation of the most recently completed local day (and bounded catch-up of
     * earlier missed days) without waiting for the nightly schedule.
     * @return local snapshot date that was queued
     */
    @AuraEnabled
    public static Date runAggregationNow() {
        requireManager();
        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        String timeZoneId = String.isBlank(setting?.AggregationTimeZone__c)
            ? UserInfo.getTimeZone().getID()
            : setting.AggregationTimeZone__c;
        Date latestCompletedDate = Date.valueOf(
            Datetime.now().format('yyyy-MM-dd', timeZoneId)
        ).addDays(-1);
        Date nextSnapshotDate = setting?.LastAggregatedDate__c == null ||
            setting.LastAggregatedDate__c >= latestCompletedDate
            ? latestCompletedDate
            : setting.LastAggregatedDate__c.addDays(1);
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            throw new AuraHandledException('Too many asynchronous jobs are queued. Try again shortly.');
        }
        System.enqueueJob(new RHCReportsDailyAggregationQueueable(nextSnapshotDate, timeZoneId, true));
        return nextSnapshotDate;
    }

    /**
     * Saves retention and aggregation settings and optionally registers daily maintenance.
     * @param detailedRetentionDays detailed fact retention in days
     * @param snapshotRetentionDays snapshot retention in days
     * @param dailyAggregationEnabled enables prior-local-day aggregation
     * @param retentionCleanupEnabled enables irreversible cleanup
     * @param aggregationTimeZone Salesforce time-zone ID
     * @param scheduled whether the package maintenance job should be registered
     * @return saved effective settings
     */
    @AuraEnabled
    public static SettingDTO saveSettings(
        Integer detailedRetentionDays,
        Integer snapshotRetentionDays,
        Boolean dailyAggregationEnabled,
        Boolean retentionCleanupEnabled,
        String aggregationTimeZone,
        Boolean scheduled
    ) {
        requireManager();
        validateDays(detailedRetentionDays, 'Detailed retention', 1, 3650);
        validateDays(snapshotRetentionDays, 'Snapshot retention', 1, 36500);
        validateTimeZone(aggregationTimeZone);
        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        if (setting == null) {
            setting = new Record_Health_Check_Report_Setting__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        setting.DetailedRetentionDays__c = detailedRetentionDays;
        setting.SnapshotRetentionDays__c = snapshotRetentionDays;
        setting.DailyAggregationEnabled__c = dailyAggregationEnabled == true;
        setting.RetentionCleanupEnabled__c = retentionCleanupEnabled == true;
        setting.AggregationTimeZone__c = aggregationTimeZone;
        abortExisting(setting.CronTriggerId__c);
        setting.CronTriggerId__c = null;
        if (scheduled == true) {
            setting.CronTriggerId__c = System.schedule(
                RHCReportsMaintenanceScheduled.JOB_NAME,
                RHCReportsMaintenanceScheduled.CRON_DAILY,
                new RHCReportsMaintenanceScheduled()
            );
        }
        // The Custom Permission is the write boundary. Direct Custom Setting CRUD is
        // intentionally not granted, so all validated fields and the scheduler ID commit together.
        // code-analyzer-suppress-next-line ApexCRUDViolation: Manage_RHC_Reports is the explicit authorization boundary for this validated, package-owned hierarchy setting; granting direct CRUD/FLS would permit bypassing validation and scheduler consistency.
        upsert setting;
        return getSettings();
    }
    /**
     * Recomputes a selected local day immediately.
     * @param snapshotDate local day to aggregate
     * @return queued job ID
     */
    @AuraEnabled
    public static Id aggregateNow(Date snapshotDate) {
        requireManager();
        if (snapshotDate == null || snapshotDate >= Date.today()) {
            throw new AuraHandledException('Choose a completed date before today.');
        }
        SettingDTO setting = getSettings();
        return System.enqueueJob(
            new RHCReportsDailyAggregationQueueable(
                snapshotDate,
                setting.aggregationTimeZone
            )
        );
    }
    private static void requireManager() {
        if (!FeatureManagement.checkPermission('Manage_RHC_Reports')) {
            throw new AuraHandledException('Manage RHC Reports permission is required.');
        }
    }
    private static void validateDays(
        Integer value,
        String label,
        Integer minimum,
        Integer maximum
    ) {
        if (value == null || value < minimum || value > maximum) {
            throw new AuraHandledException(
                label + ' must be between ' + minimum + ' and ' + maximum + ' days.'
            );
        }
    }
    private static void validateTimeZone(String timeZoneId) {
        if (String.isBlank(timeZoneId)) {
            throw new AuraHandledException('Aggregation time zone is required.');
        }
        TimeZone zone = TimeZone.getTimeZone(timeZoneId);
        if (zone == null || (zone.getID() == 'GMT' && timeZoneId != 'GMT')) {
            throw new AuraHandledException('Enter a valid Salesforce time-zone ID.');
        }
    }
    private static void abortExisting(String cronTriggerId) {
        if (String.isBlank(cronTriggerId)) {
            return;
        }
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger WHERE Id = :cronTriggerId WITH USER_MODE LIMIT 1
        ];
        if (!jobs.isEmpty()) {
            System.abortJob(jobs[0].Id);
        }
    }
    public class SettingDTO {
        @AuraEnabled public Integer detailedRetentionDays { get; set; }
        @AuraEnabled public Integer snapshotRetentionDays { get; set; }
        @AuraEnabled public Boolean dailyAggregationEnabled { get; set; }
        @AuraEnabled public Boolean retentionCleanupEnabled { get; set; }
        @AuraEnabled public String aggregationTimeZone { get; set; }
        @AuraEnabled public Date lastAggregatedDate { get; set; }
        @AuraEnabled public Datetime lastAggregationAttemptAt { get; set; }
        @AuraEnabled public String lastAggregationStatus { get; set; }
        @AuraEnabled public String lastAggregationErrorType { get; set; }
        @AuraEnabled public Datetime lastIngestionFailureAt { get; set; }
        @AuraEnabled public String lastIngestionErrorCodes { get; set; }
        @AuraEnabled public String cronTriggerId { get; set; }
        @AuraEnabled public Boolean scheduled { get; set; }
    }
}
