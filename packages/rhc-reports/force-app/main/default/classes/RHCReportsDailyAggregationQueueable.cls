/**
 * Runs one retry-safe daily aggregation outside the scheduler transaction.
 */
public inherited sharing class RHCReportsDailyAggregationQueueable implements Queueable, Finalizer {
    private static final Integer MAX_CATCH_UP_CHAIN_DEPTH = 5;
    private Date snapshotDate;
    private String timeZoneId;
    private Boolean catchUpEnabled;
    private Integer chainDepth;
    /**
     * @param snapshotDate local date to aggregate
     * @param timeZoneId explicit Salesforce time-zone ID
     */
    public RHCReportsDailyAggregationQueueable(Date snapshotDate, String timeZoneId) {
        this(snapshotDate, timeZoneId, false, 0);
    }
    /**
     * @param snapshotDate local date to aggregate
     * @param timeZoneId explicit Salesforce time-zone ID
     * @param catchUpEnabled whether successful work should enqueue the next missed date
     */
    public RHCReportsDailyAggregationQueueable(
        Date snapshotDate,
        String timeZoneId,
        Boolean catchUpEnabled
    ) {
        this(snapshotDate, timeZoneId, catchUpEnabled, 0);
    }
    private RHCReportsDailyAggregationQueueable(
        Date snapshotDate,
        String timeZoneId,
        Boolean catchUpEnabled,
        Integer chainDepth
    ) {
        this.snapshotDate = snapshotDate;
        this.timeZoneId = timeZoneId;
        this.catchUpEnabled = catchUpEnabled;
        this.chainDepth = chainDepth;
    }
    /**
     * Executes aggregation and records the last completed date.
     * @param context queueable context
     */
    public void execute(QueueableContext context) {
        System.attachFinalizer(this);
        RHCReportsAggregationService.aggregateDate(snapshotDate, timeZoneId);
    }

    /**
     * Records a durable outcome in a separate transaction and continues catch-up only on success.
     * @param context finalizer context for the completed Queueable
     */
    public void execute(FinalizerContext context) {
        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        if (setting == null) {
            setting = new Record_Health_Check_Report_Setting__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        setting.LastAggregationAttemptAt__c = Datetime.now();
        if (context.getResult() == System.ParentJobResult.SUCCESS) {
            if (
                setting.LastAggregatedDate__c == null ||
                snapshotDate > setting.LastAggregatedDate__c
            ) {
                setting.LastAggregatedDate__c = snapshotDate;
            }
            setting.LastAggregationStatus__c = 'SUCCESS';
            setting.LastAggregationErrorType__c = null;
        } else {
            setting.LastAggregationStatus__c = 'FAILED';
            Exception failure = context.getException();
            setting.LastAggregationErrorType__c = failure == null
                ? 'UNKNOWN'
                : failure.getTypeName().left(255);
        }
        upsert setting;
        if (context.getResult() == System.ParentJobResult.SUCCESS) {
            Boolean catchUpQueued = enqueueNextMissedDate();
            if (
                !catchUpQueued &&
                catchUpEnabled == true &&
                setting.RetentionCleanupEnabled__c == true &&
                snapshotDate >= latestCompletedDate()
            ) {
                RHCReportsMaintenanceScheduled.launchRetention(setting);
            }
        }
    }

    private Boolean enqueueNextMissedDate() {
        if (catchUpEnabled != true || chainDepth >= MAX_CATCH_UP_CHAIN_DEPTH) {
            return false;
        }
        Date latestCompletedDate = latestCompletedDate();
        if (snapshotDate < latestCompletedDate) {
            System.enqueueJob(
                new RHCReportsDailyAggregationQueueable(
                    snapshotDate.addDays(1),
                    timeZoneId,
                    true,
                    chainDepth + 1
                )
            );
            return true;
        }
        return false;
    }

    private Date latestCompletedDate() {
        return Date.valueOf(
            Datetime.now().format('yyyy-MM-dd', timeZoneId)
        ).addDays(-1);
    }
}
