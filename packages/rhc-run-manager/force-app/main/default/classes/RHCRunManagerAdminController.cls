/** LWC facade for Run Definition administration, scheduling, and monitoring. */
public with sharing class RHCRunManagerAdminController {
  /** Returns saved definitions visible to the current user. */
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

  /** Returns active core selections for the metadata-driven picker. */
  @AuraEnabled(cacheable=true)
  public static List<RHCRunManagerCoreMetadataGateway.SelectionOption> getSelections(String selectionType) {
    try {
      return RHCRunManagerCoreMetadataGateway.listSelections(selectionType);
    } catch (Exception error) {
      throw handled('Active core selections could not be loaded.');
    }
  }

  /** Returns schedules visible to the current administrator. */
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

  /** Returns scope Runs owned by one Batch Run. */
  @AuraEnabled
  public static List<Record_Health_Check_Run__c> getRuns(Id batchRunId) {
    if (batchRunId == null) throw handled('Choose a Batch Run.');
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

  /** Returns retained Results owned by one scope Run. */
  @AuraEnabled
  public static List<Record_Health_Check_Run_Result__c> getResults(Id runId) {
    if (runId == null) throw handled('Choose a scope Run.');
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

  /** Returns recent owned Batch Runs for monitoring. */
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

  /** Resolves selection identity for immediate administrator feedback. */
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

  /** Returns readable/filterable fields for the guided-filter picker. */
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

  /** Saves a validated Day-1 Run Definition. */
  @AuraEnabled
  public static Id saveDefinition(DefinitionInput input) {
    if (input == null) throw handled('Run Definition input is required.');
    try {
      validateDefinitionInput(input);
      RHCRunManagerCoreMetadataGateway.DefinitionInfo coreInfo = RHCRunManagerCoreMetadataGateway.resolve(
        input.selectionType,
        input.qualifiedApiName
      );
      RHCRunManagerFilterService.validate(coreInfo.targetObjectApiName, input.populationMode, input.filterJson);
      Record_Health_Check_Run_Definition__c definition = new Record_Health_Check_Run_Definition__c(
        Id = input.id,
        DisplayName__c = input.displayName?.trim(),
        Active__c = input.active,
        SelectionType__c = input.selectionType,
        QualifiedApiName__c = coreInfo.qualifiedApiName,
        TargetObjectApiName__c = coreInfo.targetObjectApiName,
        PopulationMode__c = input.populationMode,
        FilterJson__c = input.filterJson,
        BatchSize__c = input.batchSize,
        CaptureMode__c = input.captureMode,
        CoalesceDelayMinutes__c = input.coalesceDelayMinutes
      );
      if (definition.Id == null) Database.insert(definition, AccessLevel.USER_MODE);
      else Database.update(definition, AccessLevel.USER_MODE);
      return definition.Id;
    } catch (AuraHandledException error) {
      throw error;
    } catch (Exception error) {
      throw handled('The Run Definition could not be saved.');
    }
  }

  /** Starts Run Now through the shared execution path. */
  @AuraEnabled
  public static Id runNow(Id definitionId) {
    try {
      return RHCRunManagerExecutionService.runNow(definitionId);
    } catch (RHCRunManagerExecutionService.ExecutionException error) {
      throw handled(error.getMessage());
    } catch (Exception error) {
      throw handled('The Run Definition could not be started.');
    }
  }

  /** Aborts the owned platform job of an active Batch Run and records the cancellation. */
  @AuraEnabled
  public static Id cancelBatchRun(Id batchRunId) {
    if (batchRunId == null) throw handled('Choose a Batch Run.');
    List<Record_Health_Check_Batch_Run__c> rows = [
      SELECT Id, Status__c, AsyncApexJobId__c
      FROM Record_Health_Check_Batch_Run__c
      WHERE Id = :batchRunId
      WITH USER_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) throw handled('The Batch Run is not visible to you.');
    Record_Health_Check_Batch_Run__c batchRun = rows[0];
    if (batchRun.Status__c != 'QUEUED' && batchRun.Status__c != 'PROCESSING') {
      throw handled('Only a queued or processing Batch Run can be cancelled.');
    }
    // Abort only while the platform still lists the job as active; a job that finished between the
    // status read and this query needs no abort and the CANCELLED verdict still stands.
    for (AsyncApexJob job : [
      SELECT Id FROM AsyncApexJob
      WHERE Id = :batchRun.AsyncApexJobId__c AND Status IN ('Queued', 'Holding', 'Preparing', 'Processing')
      WITH USER_MODE
      LIMIT 1
    ]) {
      System.abortJob(job.Id);
    }
    try {
      Database.update(new Record_Health_Check_Batch_Run__c(
        Id = batchRun.Id,
        Status__c = 'CANCELLED',
        CompletedAt__c = System.now(),
        ErrorSummary__c = 'Cancelled by ' + UserInfo.getName()
      ), AccessLevel.USER_MODE);
    } catch (Exception error) {
      throw handled('The Batch Run could not be cancelled.');
    }
    return batchRun.Id;
  }

  /** Saves a human recurrence without accepting CRON. */
  @AuraEnabled
  public static Id saveSchedule(ScheduleInput input) {
    if (input == null) throw handled('Schedule input is required.');
    try {
      return RHCRunManagerScheduleService.save(
        input.id,
        input.runDefinitionId,
        input.active,
        input.frequency,
        input.preferredStartTime,
        input.dayOfWeek,
        input.startDate,
        input.endDate
      );
    } catch (Exception error) {
      throw handled('The schedule could not be saved.');
    }
  }

  /** Deactivates a schedule and safely removes only its owned platform job. */
  @AuraEnabled
  public static Id pauseSchedule(Id scheduleId) {
    if (scheduleId == null) throw handled('Choose a schedule.');
    try {
      Record_Health_Check_Schedule__c existing = [
        SELECT Id, RunDefinition__c, Frequency__c, PreferredStartTime__c, DayOfWeek__c,
          StartDate__c, EndDate__c
        FROM Record_Health_Check_Schedule__c
        WHERE Id = :scheduleId
        WITH USER_MODE
        LIMIT 1
      ];
      return RHCRunManagerScheduleService.save(
        existing.Id,
        existing.RunDefinition__c,
        false,
        existing.Frequency__c,
        existing.PreferredStartTime__c,
        existing.DayOfWeek__c,
        existing.StartDate__c,
        existing.EndDate__c
      );
    } catch (Exception error) {
      throw handled('The schedule could not be paused.');
    }
  }

  private static void validateDefinitionInput(DefinitionInput input) {
    if (String.isBlank(input.displayName) || input.displayName.trim().length() > 80) throw handled('Name is required and must be 80 characters or fewer.');
    if (!new Set<String>{ 'CHECK_SET', 'CHECK' }.contains(input.selectionType)) throw handled('Selection Type is invalid.');
    if (!new Set<String>{ 'ALL_ACCESSIBLE', 'GUIDED_FILTERED', 'SUPPLIED_IDS' }.contains(input.populationMode)) throw handled('Population Mode is invalid.');
    if (!new Set<String>{ 'PASS', 'FAIL', 'BOTH' }.contains(input.captureMode)) throw handled('Capture Mode is invalid.');
    if (input.batchSize == null || input.batchSize < 1 || input.batchSize > 200 || input.batchSize != input.batchSize.setScale(0)) throw handled('Batch Size must be a whole number from 1 through 200.');
    if (input.coalesceDelayMinutes == null || input.coalesceDelayMinutes < 1 || input.coalesceDelayMinutes > 10 || input.coalesceDelayMinutes != input.coalesceDelayMinutes.setScale(0)) throw handled('Coalesce delay must be a whole number from 1 through 10.');
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

    /** Sorts by user-facing label. */
    public Integer compareTo(Object other) {
      return label.toLowerCase().compareTo(((FieldOption) other).label.toLowerCase());
    }
  }
}
