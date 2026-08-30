/**
 * Reports configured interactive publication and observed analytical coverage.
 */
public with sharing class RHCReportsCoverageController {
    /**
     * Returns one coverage row per active Check Set.
     * @return configured and observed coverage rows
     */
    @AuraEnabled(cacheable=true)
    public static List<CoverageRow> getCoverage() {
        Map<String, CoverageRow> rowsByCheckSet = new Map<String, CoverageRow>();
        for (Record_Health_Check_Set__mdt checkSet : [
            SELECT QualifiedApiName, Label, PublishUserRunEvent__c
            FROM Record_Health_Check_Set__mdt
            WHERE IsActive__c = true
            WITH USER_MODE
            ORDER BY Label
        ]) {
            CoverageRow row = new CoverageRow();
            row.checkSetQualifiedApiName = checkSet.QualifiedApiName;
            row.label = checkSet.Label;
            row.userRunPublicationEnabled = checkSet.PublishUserRunEvent__c;
            rowsByCheckSet.put(row.checkSetQualifiedApiName, row);
        }
        for (Record_Health_Check__mdt check : [
            SELECT Record_Health_Check_Set__r.QualifiedApiName,
                PublishUserResultEvent__c
            FROM Record_Health_Check__mdt
            WHERE IsActive__c = true
            WITH USER_MODE
        ]) {
            String checkSetName =
                check.Record_Health_Check_Set__r?.QualifiedApiName;
            CoverageRow row = rowsByCheckSet.get(checkSetName);
            if (row != null) {
                row.activeCheckCount++;
                if (check.PublishUserResultEvent__c == true) {
                    row.userPublishedCheckCount++;
                }
            }
        }
        for (AggregateResult aggregate : [
            SELECT CheckSetQualifiedApiName__c checkSetName,
                COUNT(Id) runCount,
                MAX(OccurredAt__c) latestEvent,
                SUM(EvaluatedCheckCount__c) evaluatedCount,
                SUM(FailedCount__c) failedCount,
                SUM(UnableCount__c) unableCount,
                SUM(SystemErrorCount__c) errorCount
            FROM Record_Health_Check_Report_Run__c
            WITH USER_MODE
            GROUP BY CheckSetQualifiedApiName__c
        ]) {
            CoverageRow row = ensureObservedRow(
                rowsByCheckSet,
                (String) aggregate.get('checkSetName')
            );
            row.runFactCount = integerValue(aggregate.get('runCount'));
            row.latestEventAt = (Datetime) aggregate.get('latestEvent');
            row.evaluatedCount = integerValue(aggregate.get('evaluatedCount'));
            row.failureCount = integerValue(aggregate.get('failedCount'));
            row.unableCount = integerValue(aggregate.get('unableCount'));
            row.errorCount = integerValue(aggregate.get('errorCount'));
        }
        for (AggregateResult aggregate : [
            SELECT CheckSetQualifiedApiName__c checkSetName,
                Status__c status,
                COUNT(Id) resultCount,
                MAX(OccurredAt__c) latestEvent
            FROM Record_Health_Check_Report_Result__c
            WITH USER_MODE
            GROUP BY CheckSetQualifiedApiName__c, Status__c
        ]) {
            CoverageRow row = ensureObservedRow(
                rowsByCheckSet,
                (String) aggregate.get('checkSetName')
            );
            Integer countValue = integerValue(aggregate.get('resultCount'));
            row.resultFactCount += countValue;
            String status = (String) aggregate.get('status');
            if (status == 'PASS') {
                row.passDetailCount += countValue;
            } else if (status == 'SKIPPED') {
                row.skippedDetailCount += countValue;
            }
            Datetime latestResult = (Datetime) aggregate.get('latestEvent');
            if (row.latestEventAt == null || latestResult > row.latestEventAt) {
                row.latestEventAt = latestResult;
            }
        }
        List<CoverageRow> rows = rowsByCheckSet.values();
        for (CoverageRow row : rows) {
            classify(row);
        }
        rows.sort();
        return rows;
    }
    private static CoverageRow ensureObservedRow(
        Map<String, CoverageRow> rowsByCheckSet,
        String checkSetName
    ) {
        if (!rowsByCheckSet.containsKey(checkSetName)) {
            CoverageRow row = new CoverageRow();
            row.checkSetQualifiedApiName = checkSetName;
            row.label = checkSetName;
            row.configurationAvailable = false;
            rowsByCheckSet.put(checkSetName, row);
        }
        return rowsByCheckSet.get(checkSetName);
    }
    private static void classify(CoverageRow row) {
        Boolean noEvents = row.runFactCount == 0 && row.resultFactCount == 0;
        Boolean publicationDisabled =
            row.configurationAvailable &&
            row.userRunPublicationEnabled == false &&
            row.userPublishedCheckCount == 0;
        if (noEvents && publicationDisabled) {
            row.state = 'PUBLICATION_DISABLED';
            row.stateLabel = 'Publication disabled';
        } else if (noEvents) {
            row.state = 'NO_EVENTS_RECEIVED';
            row.stateLabel = 'No events received';
        } else if (
            row.evaluatedCount > 0 &&
            row.resultFactCount >= row.evaluatedCount
        ) {
            row.state = 'FULL_ALL_COVERAGE';
            row.stateLabel = 'Full ALL coverage';
        } else if (
            row.runFactCount > 0 &&
            row.failureCount + row.unableCount + row.errorCount == 0
        ) {
            row.state = 'NO_FAILURES';
            row.stateLabel = 'No failures';
        } else if (
            row.resultFactCount > 0 &&
            row.passDetailCount == 0 &&
            row.skippedDetailCount == 0
        ) {
            row.state = 'PARTIAL_ACTIONABLE_COVERAGE';
            row.stateLabel = 'Partial ACTIONABLE coverage';
        } else {
            row.state = 'EVENTS_RECEIVED';
            row.stateLabel = 'Events received; coverage still converging';
        }
    }
    private static Integer integerValue(Object value) {
        return value == null ? 0 : Decimal.valueOf(String.valueOf(value)).intValue();
    }
    public class CoverageRow implements Comparable {
        @AuraEnabled public String checkSetQualifiedApiName { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Boolean configurationAvailable { get; set; }
        @AuraEnabled public Boolean userRunPublicationEnabled { get; set; }
        @AuraEnabled public Integer activeCheckCount { get; set; }
        @AuraEnabled public Integer userPublishedCheckCount { get; set; }
        @AuraEnabled public Integer runFactCount { get; set; }
        @AuraEnabled public Integer resultFactCount { get; set; }
        @AuraEnabled public Integer evaluatedCount { get; set; }
        @AuraEnabled public Integer failureCount { get; set; }
        @AuraEnabled public Integer unableCount { get; set; }
        @AuraEnabled public Integer errorCount { get; set; }
        @AuraEnabled public Integer passDetailCount { get; set; }
        @AuraEnabled public Integer skippedDetailCount { get; set; }
        @AuraEnabled public Datetime latestEventAt { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String stateLabel { get; set; }
        public CoverageRow() {
            configurationAvailable = true;
            userRunPublicationEnabled = false;
            activeCheckCount = 0;
            userPublishedCheckCount = 0;
            runFactCount = 0;
            resultFactCount = 0;
            evaluatedCount = 0;
            failureCount = 0;
            unableCount = 0;
            errorCount = 0;
            passDetailCount = 0;
            skippedDetailCount = 0;
        }
        /**
         * Sorts rows by display label.
         * @param other row to compare
         * @return lexical comparison result
         */
        public Integer compareTo(Object other) {
            CoverageRow that = (CoverageRow) other;
            return String.valueOf(label).toLowerCase().compareTo(
                String.valueOf(that.label).toLowerCase()
            );
        }
    }
}
