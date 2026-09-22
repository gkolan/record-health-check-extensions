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
    Map<String, CoverageRow> rowsByCheckSet = loadConfiguredRows();
    applyConfiguredCheckCounts(rowsByCheckSet);
    applyObservedRunCounts(rowsByCheckSet);
    applyObservedResultCounts(rowsByCheckSet);
    return finalizeRows(rowsByCheckSet);
  }

  private static Map<String, CoverageRow> loadConfiguredRows() {
    Map<String, CoverageRow> rowsByCheckSet = new Map<String, CoverageRow>();
    for (Record_Health_Check_Set__mdt checkSet : [
      SELECT QualifiedApiName, Label, PublishUserRunEvent__c
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE
      WITH USER_MODE
      ORDER BY Label
    ]) {
      CoverageRow row = new CoverageRow();
      row.checkSetQualifiedApiName = checkSet.QualifiedApiName;
      row.label = checkSet.Label;
      row.userRunPublicationEnabled = checkSet.PublishUserRunEvent__c;
      rowsByCheckSet.put(row.checkSetQualifiedApiName, row);
    }
    return rowsByCheckSet;
  }

  private static void applyConfiguredCheckCounts(
    Map<String, CoverageRow> rowsByCheckSet
  ) {
    for (Record_Health_Check__mdt check : [
      SELECT
        Record_Health_Check_Set__r.QualifiedApiName,
        PublishUserResultEvent__c
      FROM Record_Health_Check__mdt
      WHERE IsActive__c = TRUE
      WITH USER_MODE
    ]) {
      String checkSetName = check.Record_Health_Check_Set__r?.QualifiedApiName;
      CoverageRow row = rowsByCheckSet.get(checkSetName);
      if (row != null) {
        row.activeCheckCount++;
        if (check.PublishUserResultEvent__c == true) {
          row.userPublishedCheckCount++;
        }
      }
    }
  }

  @SuppressWarnings('PMD.AvoidNonRestrictiveQueries')
  private static void applyObservedRunCounts(
    Map<String, CoverageRow> rowsByCheckSet
  ) {
    for (AggregateResult aggregate : [
      SELECT
        CheckSetQualifiedApiName__c checkSetName,
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
  }

  @SuppressWarnings('PMD.AvoidNonRestrictiveQueries')
  private static void applyObservedResultCounts(
    Map<String, CoverageRow> rowsByCheckSet
  ) {
    for (AggregateResult aggregate : [
      SELECT
        CheckSetQualifiedApiName__c checkSetName,
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
  }

  private static List<CoverageRow> finalizeRows(
    Map<String, CoverageRow> rowsByCheckSet
  ) {
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
    if (hasNoEvents(row)) {
      setState(
        row,
        isPublicationDisabled(row)
          ? 'PUBLICATION_DISABLED'
          : 'NO_EVENTS_RECEIVED',
        isPublicationDisabled(row)
          ? 'Publication disabled'
          : 'No events received'
      );
      return;
    }
    if (hasFullCoverage(row)) {
      setState(row, 'FULL_ALL_COVERAGE', 'Full ALL coverage');
      return;
    }
    if (hasNoFailures(row)) {
      setState(row, 'NO_FAILURES', 'No failures');
      return;
    }
    if (hasActionableOnlyCoverage(row)) {
      setState(
        row,
        'PARTIAL_ACTIONABLE_COVERAGE',
        'Partial ACTIONABLE coverage'
      );
      return;
    }
    setState(
      row,
      'EVENTS_RECEIVED',
      'Events received; coverage still converging'
    );
  }
  private static Boolean hasNoEvents(CoverageRow row) {
    return row.runFactCount == 0 && row.resultFactCount == 0;
  }
  private static Boolean isPublicationDisabled(CoverageRow row) {
    return row.configurationAvailable &&
      row.userRunPublicationEnabled == false &&
      row.userPublishedCheckCount == 0;
  }
  private static Boolean hasFullCoverage(CoverageRow row) {
    return row.evaluatedCount > 0 && row.resultFactCount >= row.evaluatedCount;
  }
  private static Boolean hasNoFailures(CoverageRow row) {
    return row.runFactCount > 0 &&
      row.failureCount + row.unableCount + row.errorCount == 0;
  }
  private static Boolean hasActionableOnlyCoverage(CoverageRow row) {
    return row.resultFactCount > 0 &&
      row.passDetailCount == 0 &&
      row.skippedDetailCount == 0;
  }
  private static void setState(
    CoverageRow row,
    String state,
    String stateLabel
  ) {
    row.state = state;
    row.stateLabel = stateLabel;
  }
  private static Integer integerValue(Object value) {
    return value == null
      ? 0
      : Decimal.valueOf(String.valueOf(value)).intValue();
  }
  /** Serializable coverage summary returned to the setup experience. */
  @SuppressWarnings('PMD.AvoidBooleanMethodParameters')
  public class CoverageRow implements Comparable {
    /** Core Check Set qualified API name. */
    @AuraEnabled
    public String checkSetQualifiedApiName { get; set; }
    /** Display label for configured or observed coverage. */
    @AuraEnabled
    public String label { get; set; }
    /** Whether current core metadata describes the Check Set. */
    @AuraEnabled
    public Boolean configurationAvailable { get; set; }
    /** Whether the Check Set publishes interactive Run events. */
    @AuraEnabled
    public Boolean userRunPublicationEnabled { get; set; }
    /** Number of active Checks in the configured Check Set. */
    @AuraEnabled
    public Integer activeCheckCount { get; set; }
    /** Number of active Checks publishing interactive Result events. */
    @AuraEnabled
    public Integer userPublishedCheckCount { get; set; }
    /** Number of observed Run fact rows. */
    @AuraEnabled
    public Integer runFactCount { get; set; }
    /** Number of observed Result fact rows. */
    @AuraEnabled
    public Integer resultFactCount { get; set; }
    /** Number of evaluated Checks reported by Run events. */
    @AuraEnabled
    public Integer evaluatedCount { get; set; }
    /** Number of failed Checks reported by Run events. */
    @AuraEnabled
    public Integer failureCount { get; set; }
    /** Number of unable-to-evaluate Checks reported by Run events. */
    @AuraEnabled
    public Integer unableCount { get; set; }
    /** Number of system-error Checks reported by Run events. */
    @AuraEnabled
    public Integer errorCount { get; set; }
    /** Number of PASS Result facts. */
    @AuraEnabled
    public Integer passDetailCount { get; set; }
    /** Number of SKIPPED Result facts. */
    @AuraEnabled
    public Integer skippedDetailCount { get; set; }
    /** Latest Run or Result event timestamp observed. */
    @AuraEnabled
    public Datetime latestEventAt { get; set; }
    /** Stable machine-readable coverage state. */
    @AuraEnabled
    public String state { get; set; }
    /** Human-readable coverage state. */
    @AuraEnabled
    public String stateLabel { get; set; }
    /** Initializes a coverage row with safe zero-value counters. */
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
      return String.valueOf(label)
        .toLowerCase()
        .compareTo(String.valueOf(that.label).toLowerCase());
    }
  }
}
