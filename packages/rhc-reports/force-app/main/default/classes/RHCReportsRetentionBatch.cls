/**
 * Deletes expired package-owned analytical data in bounded Batch Apex scopes.
 */
public inherited sharing class RHCReportsRetentionBatch implements Database.Batchable<SObject> {
    /** Controls whether a completed batch launches the next retention target. */
    public enum ContinuationMode { ENABLED, DISABLED }
    private String targetName;
    private Datetime factCutoff;
    private Date snapshotCutoff;
    private ContinuationMode executionMode;
    /**
     * @param targetName RUN, RESULT, or SNAPSHOT
     * @param factCutoff exclusive fact occurrence cutoff
     * @param snapshotCutoff exclusive snapshot date cutoff
     */
    public RHCReportsRetentionBatch(
        String targetName,
        Datetime factCutoff,
        Date snapshotCutoff
    ) {
        this(targetName, factCutoff, snapshotCutoff, ContinuationMode.ENABLED);
    }
    /**
     * Creates a retention batch with explicit continuation behavior.
     * @param targetName RUN, RESULT, or SNAPSHOT
     * @param factCutoff exclusive fact occurrence cutoff
     * @param snapshotCutoff exclusive snapshot date cutoff
     * @param requestedMode whether finish launches the next target
     */
    public RHCReportsRetentionBatch(
        String targetName,
        Datetime factCutoff,
        Date snapshotCutoff,
        ContinuationMode requestedMode
    ) {
        this.targetName = targetName;
        this.factCutoff = factCutoff;
        this.snapshotCutoff = snapshotCutoff;
        this.executionMode = requestedMode == null
            ? ContinuationMode.ENABLED
            : requestedMode;
    }
    /**
     * Starts the selected cleanup query.
     * @param context batch context
     * @return query locator for expired records
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (targetName == 'RUN') {
            return Database.getQueryLocator([
                SELECT Id FROM Record_Health_Check_Report_Run__c
                WHERE OccurredAt__c < :factCutoff
            ]);
        }
        if (targetName == 'RESULT') {
            return Database.getQueryLocator([
                SELECT Id FROM Record_Health_Check_Report_Result__c
                WHERE OccurredAt__c < :factCutoff
            ]);
        }
        if (targetName == 'SNAPSHOT') {
            return Database.getQueryLocator([
                SELECT Id FROM Record_Health_Check_Daily_Snapshot__c
                WHERE SnapshotDate__c < :snapshotCutoff
            ]);
        }
        throw new RHCReportsRetentionException('Unknown retention target: ' + targetName);
    }
    /**
     * Irreversibly deletes the current expired scope with partial success.
     * @param context batch context
     * @param scope expired package-owned records
     */
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        if (!scope.isEmpty()) {
            Database.DeleteResult[] results = Database.delete(scope, false);
            Integer failureCount = 0;
            Set<String> statusCodes = new Set<String>();
            for (Database.DeleteResult result : results) {
                if (result.isSuccess()) {
                    continue;
                }
                failureCount++;
                for (Database.Error error : result.getErrors()) {
                    statusCodes.add(String.valueOf(error.getStatusCode()));
                }
            }
            if (failureCount > 0) {
                throw new RHCReportsRetentionException(
                    'Unable to delete ' + failureCount +
                    ' expired reporting records. Status codes: ' +
                    String.join(new List<String>(statusCodes), ', ')
                );
            }
        }
    }
    /**
     * Chains the next object so all three stores are cleaned by one maintenance run.
     * @param context batch context
     */
    public void finish(Database.BatchableContext context) {
        if (executionMode == ContinuationMode.DISABLED) {
            return;
        }
        String nextTarget = nextTargetName(targetName);
        if (nextTarget != null) {
            Database.executeBatch(
                new RHCReportsRetentionBatch(
                    nextTarget,
                    factCutoff,
                    snapshotCutoff,
                    ContinuationMode.ENABLED
                ),
                200
            );
        }
    }
    @TestVisible
    private static String nextTargetName(String currentTarget) {
        if (currentTarget == 'RESULT') {
            return 'RUN';
        }
        return currentTarget == 'RUN' ? 'SNAPSHOT' : null;
    }
    /** Indicates an invalid target or failed retention delete. */
    public class RHCReportsRetentionException extends Exception {}
}
