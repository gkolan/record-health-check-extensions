/** LWC facade for Run Definition administration, scheduling, and monitoring. */
public with sharing class RHCRunManagerAdminController {
  /**
   * Returns saved definitions visible to the current user.
   * @return Visible Run Definitions.
   */
  @AuraEnabled
  public static List<Record_Health_Check_Run_Definition__c> getDefinitions() {
    return [
      SELECT Id, Name, DisplayName__c, Active__c, SelectionType__c, QualifiedApiName__c,
        TargetObjectApiName__c, PopulationMode__c, FilterJson__c,
        BatchSize__c, CaptureMode__c, CoalesceDelayMinutes__c
      FROM Record_Health_Check_Run_Definition__c
      WITH USER_MODE
      ORDER BY Name
      LIMIT 500
    ];
  }

  /**
   * Returns active core selections for the metadata-driven picker.
   * @param selectionType CHECK_SET or CHECK.
   * @return Active core selections of the requested type.
   */
  @AuraEnabled(cacheable=true)
  public static List<RHCRunManagerCoreMetadataGateway.SelectionOption> getSelections(String selectionType) {
    try {
      return RHCRunManagerCoreMetadataGateway.listSelections(selectionType);
    } catch (Exception error) {
      throw handled('Active core selections could not be loaded.');
    }
  }

  /**
   * Returns schedules visible to the current administrator.
   * @return Visible Run Manager schedules.
   */
  @AuraEnabled
  public static List<Record_Health_Check_Schedule__c> getSchedules() {
    return [
      SELECT Id, Name, RunDefinition__c, RunDefinition__r.DisplayName__c,
        Active__c, Frequency__c, PreferredStartTime__c, DayOfWeek__c,
        StartDate__c, EndDate__c,
        CronTriggerId__c, LastFiredAt__c
      FROM Record_Health_Check_Schedule__c
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 200
    ];
  }

  /**
   * Returns scope Runs owned by one Batch Run.
   * @param batchRunId Owning Batch Run ID.
   * @return Scope Runs for the selected Batch Run.
   */
  @AuraEnabled
  public static List<Record_Health_Check_Run__c> getRuns(Id batchRunId) {
    if (batchRunId == null) {
      throw handled('Choose a Batch Run.');
    }
    return [
      SELECT Id, Name, ScopeNumber__c, Status__c, RecordCount__c,
        PassedCount__c, FailedCount__c, SkippedCount__c, UnableCount__c,
        SystemErrorCount__c, CompletedAt__c, ErrorSummary__c
      FROM Record_Health_Check_Run__c
      WHERE BatchRun__c = :batchRunId
      WITH USER_MODE
      ORDER BY ScopeNumber__c
      LIMIT 2000
    ];
  }

  /**
   * Returns retained Results owned by one scope Run.
   * @param runId Owning scope Run ID.
   * @return Retained Results for the selected scope Run.
   */
  @AuraEnabled
  public static List<Record_Health_Check_Run_Result__c> getResults(Id runId) {
    if (runId == null) {
      throw handled('Choose a scope Run.');
    }
    return [
      SELECT Id, Name, RecordId__c, CheckQualifiedApiName__c, Status__c,
        Severity__c, ReasonCode__c, DiagnosticSummary__c, RecommendedAction__c,
        OccurredAt__c
      FROM Record_Health_Check_Run_Result__c
      WHERE Run__c = :runId
      WITH USER_MODE
      ORDER BY OccurredAt__c DESC
      LIMIT 2000
    ];
  }

  /**
   * Returns recent owned Batch Runs for monitoring.
   * @return Recent Run Manager Batch Runs.
   */
  @AuraEnabled
  public static List<Record_Health_Check_Batch_Run__c> getBatchRuns() {
    return [
      SELECT Id, Name, RunDefinition__c, RunDefinition__r.Name, Source__c,
        Status__c, AsyncApexJobId__c, SubmittedRecordCount__c,
        ProcessedRecordCount__c, FailedScopeCount__c, PassedCount__c, FailedCount__c,
        UnableCount__c, SystemErrorCount__c, StartedAt__c, CompletedAt__c, ErrorSummary__c
      FROM Record_Health_Check_Batch_Run__c
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 200
    ];
  }

  /**
   * Returns explicit manual-retention settings and current-user capability.
   * @return Current retention settings and current-user capability.
   */
  @AuraEnabled
  public static RHCRunManagerRetentionService.Settings getRetentionSettings() {
    return RHCRunManagerRetentionService.getSettings();
  }

  /**
   * Saves the whole-day retention window without running cleanup.
   * @param retentionDays Whole-day retention window.
   * @return Saved retention settings.
   */
  @AuraEnabled
  public static RHCRunManagerRetentionService.Settings saveRetentionSettings(Integer retentionDays) {
    return RHCRunManagerRetentionService.saveSettings(retentionDays);
  }

  /**
   * Runs one confirmed, bounded cleanup request.
   * @return Counts removed by object type and in total.
   */
  @AuraEnabled
  public static RHCRunManagerRetentionService.PurgeOutcome purgeOperationalRecords() {
    return RHCRunManagerRetentionService.purge();
  }

  /**
   * Resolves selection identity for immediate administrator feedback.
   * @param selectionType CHECK_SET or CHECK.
   * @param qualifiedApiName Exact core metadata identity.
   * @return Resolved selection and target-object identity.
   */
  @AuraEnabled(cacheable=true)
  public static RHCRunManagerCoreMetadataGateway.DefinitionInfo resolveSelection(
    String selectionType,
    String qualifiedApiName
  ) {
    try {
      return RHCRunManagerCoreMetadataGateway.resolve(selectionType, qualifiedApiName);
    } catch (Exception error) {
      throw handled('The core selection could not be resolved.');
    }
  }

  /**
   * Returns readable/filterable fields for the guided-filter picker.
   * @param selectionType CHECK_SET or CHECK.
   * @param qualifiedApiName Exact core metadata identity.
   * @return Sorted fields available to the guided-filter builder.
   */
  @AuraEnabled(cacheable=true)
  public static List<FieldOption> getTargetFields(
    String selectionType,
    String qualifiedApiName
  ) {
    RHCRunManagerCoreMetadataGateway.DefinitionInfo info = RHCRunManagerCoreMetadataGateway.resolve(selectionType, qualifiedApiName);
    Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(info.targetObjectApiName).getDescribe();
    List<FieldOption> options = new List<FieldOption>();
    for (Schema.SObjectField fieldToken : objectDescribe.fields.getMap().values()) {
      Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
      if (fieldDescribe.isAccessible() && fieldDescribe.isFilterable()) {
        FieldOption option = new FieldOption();
        option.label = fieldDescribe.getLabel() + ' (' + fieldDescribe.getName() + ')';
        option.value = fieldDescribe.getName();
        option.dataType = String.valueOf(fieldDescribe.getType());
        options.add(option);
      }
    }
    options.sort();
    return options;
  }

  /**
   * Saves a validated Day-1 Run Definition.
   * @param input Administrator-supplied definition values.
   * @return Saved Run Definition ID.
   */
  @AuraEnabled
  public static Id saveDefinition(DefinitionInput input) {
    return RHCRunManagerAdminCommandService.saveDefinition(input);
  }

  /**
   * Starts Run Now through the shared execution path.
   * @param definitionId Saved Run Definition ID.
   * @return Created Batch Run ID.
   */
  @AuraEnabled
  public static Id runNow(Id definitionId) {
    return RHCRunManagerAdminCommandService.runNow(definitionId);
  }

  /**
   * Aborts the owned platform job of an active Batch Run and records the cancellation.
   * @param batchRunId Active owned Batch Run ID.
   * @return Cancelled Batch Run ID.
   */
  @AuraEnabled
  public static Id cancelBatchRun(Id batchRunId) {
    return RHCRunManagerAdminCommandService.cancelBatchRun(batchRunId);
  }

  /**
   * Saves a human recurrence without accepting CRON.
   * @param input Administrator-supplied schedule values.
   * @return Saved Schedule ID.
   */
  @AuraEnabled
  public static Id saveSchedule(ScheduleInput input) {
    return RHCRunManagerAdminCommandService.saveSchedule(input);
  }

  /**
   * Deactivates a schedule and safely removes only its owned platform job.
   * @param scheduleId Owned Schedule ID.
   * @return Paused Schedule ID.
   */
  @AuraEnabled
  public static Id pauseSchedule(Id scheduleId) {
    return RHCRunManagerAdminCommandService.pauseSchedule(scheduleId);
  }

  private static AuraHandledException handled(String message) {
    return new AuraHandledException(message);
  }

  /** Run Definition editor input. */
  public class DefinitionInput {
    @AuraEnabled public Id id;
    @AuraEnabled public String displayName;
    @AuraEnabled public Boolean active;
    @AuraEnabled public String selectionType;
    @AuraEnabled public String qualifiedApiName;
    @AuraEnabled public String populationMode;
    @AuraEnabled public String filterJson;
    @AuraEnabled public Decimal batchSize;
    @AuraEnabled public String captureMode;
    @AuraEnabled public Decimal coalesceDelayMinutes;
  }

  /** Human schedule editor input. */
  public class ScheduleInput {
    @AuraEnabled public Id id;
    @AuraEnabled public Id runDefinitionId;
    @AuraEnabled public Boolean active;
    @AuraEnabled public String frequency;
    @AuraEnabled public String preferredStartTime;
    @AuraEnabled public String dayOfWeek;
    @AuraEnabled public Date startDate;
    @AuraEnabled public Date endDate;
  }

  /** Guided-filter field option. */
  public class FieldOption implements Comparable {
    @AuraEnabled public String label;
    @AuraEnabled public String value;
    @AuraEnabled public String dataType;

    /**
     * Sorts by user-facing label.
     * @param other Field option being compared.
     * @return Lexicographic comparison result.
     */
    public Integer compareTo(Object other) {
      return label.toLowerCase().compareTo(((FieldOption) other).label.toLowerCase());
    }
  }
}
