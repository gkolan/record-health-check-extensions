/**
 * Runs one retry-safe daily aggregation outside the scheduler transaction.
 */
public inherited sharing class RHCReportsDailyAggregationQueueable implements Queueable, Finalizer {
    private static final Integer MAX_CATCH_UP_CHAIN_DEPTH = 5;
    /** Controls whether successful work continues through missed reporting days. */
    public enum CatchUpMode { ENABLED, DISABLED }
    private AggregationRequest request;
    /**
     * Creates a one-day aggregation job without catch-up chaining.
     * @param snapshotDate local date to aggregate
     * @param timeZoneId explicit Salesforce time-zone ID
     */
    public RHCReportsDailyAggregationQueueable(Date snapshotDate, String timeZoneId) {
        this(new AggregationRequest(snapshotDate, timeZoneId));
    }
    /**
     * Creates an aggregation job with explicit catch-up behavior.
     * @param snapshotDate local date to aggregate
     * @param timeZoneId explicit Salesforce time-zone ID
     * @param catchUpMode whether successful work should enqueue the next missed date
     */
    public RHCReportsDailyAggregationQueueable(
        Date snapshotDate,
        String timeZoneId,
        CatchUpMode catchUpMode
    ) {
        this(new AggregationRequest(snapshotDate, timeZoneId));
        this.request.catchUpMode = catchUpMode == null
            ? RHCReportsDailyAggregationQueueable.CatchUpMode.DISABLED
            : catchUpMode;
    }
    private RHCReportsDailyAggregationQueueable(
        AggregationRequest request
    ) {
        this.request = request;
    }
    /**
     * Executes aggregation and records the last completed date.
     * @param context queueable context
     */
    public void execute(QueueableContext context) {
        System.attachFinalizer(this);
        RHCReportsAggregationService.aggregateDate(
            request.snapshotDate,
            request.timeZoneId
        );
    }

    /**
     * Records a durable outcome in a separate transaction and continues catch-up only on success.
     * @param context finalizer context for the completed Queueable
     */
    public void execute(FinalizerContext context) {
        Record_Health_Check_Report_Setting__c setting = loadSetting();
        setting.LastAggregationAttemptAt__c = Datetime.now();
        recordOutcome(setting, context);
        upsert setting;
        if (context.getResult() != System.ParentJobResult.SUCCESS) {
            return;
        }
        continueSuccessfulWork(setting);
    }

    private static Record_Health_Check_Report_Setting__c loadSetting() {
        Record_Health_Check_Report_Setting__c setting =
            Record_Health_Check_Report_Setting__c.getOrgDefaults();
        return setting == null
            ? new Record_Health_Check_Report_Setting__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            )
            : setting;
    }

    private void recordOutcome(
        Record_Health_Check_Report_Setting__c setting,
        FinalizerContext context
    ) {
        if (context.getResult() == System.ParentJobResult.SUCCESS) {
            recordSuccess(setting);
            return;
        }
        setting.LastAggregationStatus__c = 'FAILED';
        Exception failure = context.getException();
        setting.LastAggregationErrorType__c = failure == null
            ? 'UNKNOWN'
            : failure.getTypeName().left(255);
    }

    private void recordSuccess(
        Record_Health_Check_Report_Setting__c setting
    ) {
        if (
            setting.LastAggregatedDate__c == null ||
            request.snapshotDate > setting.LastAggregatedDate__c
        ) {
            setting.LastAggregatedDate__c = request.snapshotDate;
        }
        setting.LastAggregationStatus__c = 'SUCCESS';
        setting.LastAggregationErrorType__c = null;
    }

    private void continueSuccessfulWork(
        Record_Health_Check_Report_Setting__c setting
    ) {
        Boolean catchUpQueued = enqueueNextMissedDate();
        if (
            !catchUpQueued &&
            request.catchUpMode == RHCReportsDailyAggregationQueueable.CatchUpMode.ENABLED &&
            setting.RetentionCleanupEnabled__c == true &&
            request.snapshotDate >= latestCompletedDate()
        ) {
            RHCReportsMaintenanceScheduled.launchRetention(setting);
        }
    }

    private Boolean enqueueNextMissedDate() {
        if (
            request.catchUpMode != RHCReportsDailyAggregationQueueable.CatchUpMode.ENABLED ||
            request.chainDepth >= MAX_CATCH_UP_CHAIN_DEPTH
        ) {
            return false;
        }
        Date latestCompletedDate = latestCompletedDate();
        if (request.snapshotDate < latestCompletedDate) {
            System.enqueueJob(
                new RHCReportsDailyAggregationQueueable(
                    nextCatchUpRequest()
                )
            );
            return true;
        }
        return false;
    }

    private AggregationRequest nextCatchUpRequest() {
        AggregationRequest nextRequest = new AggregationRequest(
            request.snapshotDate.addDays(1),
            request.timeZoneId
        );
        nextRequest.catchUpMode = RHCReportsDailyAggregationQueueable.CatchUpMode.ENABLED;
        nextRequest.chainDepth = request.chainDepth + 1;
        return nextRequest;
    }

    private Date latestCompletedDate() {
        return Date.valueOf(
            Datetime.now().format('yyyy-MM-dd', request.timeZoneId)
        ).addDays(-1);
    }

    private class AggregationRequest {
        private Date snapshotDate;
        private String timeZoneId;
        private CatchUpMode catchUpMode;
        private Integer chainDepth;

        private AggregationRequest(
            Date snapshotDate,
            String timeZoneId
        ) {
            this.snapshotDate = snapshotDate;
            this.timeZoneId = timeZoneId;
            this.catchUpMode = RHCReportsDailyAggregationQueueable.CatchUpMode.DISABLED;
            this.chainDepth = 0;
        }
    }
}
