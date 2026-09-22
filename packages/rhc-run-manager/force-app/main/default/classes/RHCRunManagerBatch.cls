/** Owns population, scoped core execution, capture, correlation, and monitoring. */
public with sharing class RHCRunManagerBatch implements Database.Batchable<SObject>, Database.Stateful {
  @TestVisible private static Boolean forceStartFailure = false;
  @TestVisible private static Boolean forceScopeFailure = false;
  private ExecutionPlan plan;
  private Progress progress = new Progress();

  /** Validated values required to construct one stateful Batch execution. */
  public class LaunchRequest {
    public Id batchRunId;
    public Record_Health_Check_Run_Definition__c definition;
    public RHCRunManagerCoreMetadataGateway.DefinitionInfo coreInfo;
    public String source;
    public List<Id> suppliedIds;
  }

  /**
   * Captures immutable, validated execution inputs.
   * @param request Owned Batch Run, validated definition, core identity, source, and supplied IDs.
   */
  public RHCRunManagerBatch(LaunchRequest request) {
    if (request == null || request.definition == null || request.coreInfo == null) {
      throw new IllegalArgumentException('Batch launch request is incomplete.');
    }
    this.plan = new ExecutionPlan(request);
  }

  /**
   * Discovers records in user mode using core-derived object metadata.
   * @param context Platform batch context.
   * @return User-mode query locator for the validated population.
   */
  public Database.QueryLocator start(Database.BatchableContext context) {
    try {
      if (forceStartFailure) {
        throw new IllegalArgumentException('Forced start failure.');
      }
      RHCRunManagerFilterService.QueryRequest queryRequest = new RHCRunManagerFilterService.QueryRequest();
      queryRequest.objectApiName = plan.targetObjectApiName;
      queryRequest.populationMode = plan.populationMode;
      queryRequest.filterJson = plan.filterJson;
      queryRequest.suppliedIds = plan.suppliedIds;
      RHCRunManagerFilterService.QuerySpec querySpec = RHCRunManagerFilterService.build(queryRequest);
      Database.QueryLocator queryLocator = Database.getQueryLocatorWithBinds(
        querySpec.soql,
        querySpec.binds,
        AccessLevel.USER_MODE
      );
      markBatchRunProcessing(context == null ? null : context.getJobId());
      return queryLocator;
    } catch (Exception error) {
      progress.startError = sanitize(error.getMessage());
      return emptyQueryLocator();
    }
  }

  /**
   * Evaluates and commits one independent framework scope.
   * @param context Platform batch context.
   * @param scope Records selected for this transaction.
   */
  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }
    progress.scopeNumber++;
    progress.submittedCount += scope.size();
    List<Id> recordIds = new List<Id>();
    for (SObject recordValue : scope) {
      recordIds.add((Id) recordValue.get('Id'));
    }
    String correlationId = 'rm-' + plan.batchRunId + '-' + progress.scopeNumber;
    Record_Health_Check_Run__c runRecord;
    try {
      runRecord = createRun(correlationId, recordIds.size());
      if (forceScopeFailure) {
        throw new IllegalArgumentException('Forced scope failure.');
      }
      RecordHealthCheckRequest request = 'CHECK_SET'.equals(plan.selectionType)
        ? RecordHealthCheckRequest.forCheckSet(plan.qualifiedApiName, recordIds)
        : RecordHealthCheckRequest.forCheck(plan.qualifiedApiName, recordIds);
      request = request
        .withResultMode(RecordHealthCheckResultMode.EVALUATION)
        .withRunId(correlationId)
        .withExecutionOrigin(executionOrigin())
        .withEventPublication(eventPublication());
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
      RHCRunManagerCaptureService.Request captureRequest = new RHCRunManagerCaptureService.Request();
      captureRequest.runId = runRecord.Id;
      captureRequest.runCorrelationId = correlationId;
      captureRequest.captureMode = plan.captureMode;
      captureRequest.response = response;
      RHCRunManagerCaptureService.capture(captureRequest);
      completeRun(runRecord, response);
      progress.processedCount += recordIds.size();
      progress.passedTotal += response.summary.passed ?? 0;
      progress.failedTotal += response.summary.failed ?? 0;
      progress.unableTotal += response.summary.unable ?? 0;
      progress.systemErrorTotal += response.summary.systemError ?? 0;
    } catch (Exception error) {
      progress.failedScopeCount++;
      String summary = sanitize(error.getMessage());
      appendScopeError('Scope ' + progress.scopeNumber + ': ' + summary);
      if (runRecord?.Id != null) {
        Database.update(new Record_Health_Check_Run__c(
          Id = runRecord.Id,
          Status__c = 'ERROR',
          CompletedAt__c = System.now(),
          ErrorSummary__c = summary
        ), AccessLevel.USER_MODE);
      }
    }
  }

  /**
   * Finalizes owned job monitoring without treating Check failures as job failures.
   * @param context Platform batch context.
   */
  public void finish(Database.BatchableContext context) {
    // An administrator cancel can land between the last scope and finish; keep that verdict.
    if ('CANCELLED' == [
      SELECT Status__c FROM Record_Health_Check_Batch_Run__c WHERE Id = :plan.batchRunId WITH USER_MODE LIMIT 1
    ].Status__c) {
      return;
    }
    Record_Health_Check_Batch_Run__c updateRecord = new Record_Health_Check_Batch_Run__c(
      Id = plan.batchRunId,
      Status__c = String.isNotBlank(progress.startError) ? 'ERROR' : (progress.failedScopeCount > 0 ? 'PARTIAL_FAILURE' : 'COMPLETED'),
      SubmittedRecordCount__c = progress.submittedCount,
      ProcessedRecordCount__c = progress.processedCount,
      FailedScopeCount__c = progress.failedScopeCount,
      PassedCount__c = progress.passedTotal,
      FailedCount__c = progress.failedTotal,
      UnableCount__c = progress.unableTotal,
      SystemErrorCount__c = progress.systemErrorTotal,
      CompletedAt__c = System.now(),
      ErrorSummary__c = String.isNotBlank(progress.startError) ? progress.startError : progress.scopeErrorSummary
    );
    Database.update(updateRecord, AccessLevel.USER_MODE);
  }

  private Record_Health_Check_Run__c createRun(String correlationId, Integer recordCount) {
    Record_Health_Check_Run__c runRecord = new Record_Health_Check_Run__c(
      BatchRun__c = plan.batchRunId,
      RunId__c = correlationId,
      ScopeNumber__c = progress.scopeNumber,
      Status__c = 'IN_PROGRESS',
      SelectionType__c = plan.selectionType,
      QualifiedApiName__c = plan.qualifiedApiName,
      CheckSetQualifiedApiName__c = plan.checkSetQualifiedApiName,
      RecordCount__c = recordCount,
      OccurredAt__c = System.now()
    );
    Database.insert(runRecord, AccessLevel.USER_MODE);
    return runRecord;
  }

  private void completeRun(
    Record_Health_Check_Run__c runRecord,
    RecordHealthCheckResponse response
  ) {
    Database.update(new Record_Health_Check_Run__c(
      Id = runRecord.Id,
      Status__c = 'COMPLETED',
      PassedCount__c = response.summary.passed,
      FailedCount__c = response.summary.failed,
      SkippedCount__c = response.summary.skipped,
      UnableCount__c = response.summary.unable,
      SystemErrorCount__c = response.summary.systemError,
      CompletedAt__c = System.now()
    ), AccessLevel.USER_MODE);
  }

  private void markBatchRunProcessing(Id asyncJobId) {
    Database.update(new Record_Health_Check_Batch_Run__c(
      Id = plan.batchRunId,
      Status__c = 'PROCESSING',
      AsyncApexJobId__c = asyncJobId == null ? null : String.valueOf(asyncJobId)
    ), AccessLevel.USER_MODE);
  }

  private Database.QueryLocator emptyQueryLocator() {
    return Database.getQueryLocatorWithBinds(
      'SELECT Id FROM Record_Health_Check_Run_Definition__c WHERE Id = :definitionId AND Id = NULL',
      new Map<String, Object>{ 'definitionId' => plan.definitionId },
      AccessLevel.USER_MODE
    );
  }

  private void appendScopeError(String scopeError) {
    progress.scopeErrorSummary = sanitize(
      String.isBlank(progress.scopeErrorSummary)
        ? scopeError
        : progress.scopeErrorSummary + '\n' + scopeError
    );
  }

  private RecordHealthCheckEventPublication eventPublication() {
    return 'FAIL'.equals(plan.captureMode)
      ? RecordHealthCheckEventPublication.ACTIONABLE
      : RecordHealthCheckEventPublication.ALL;
  }

  private RecordHealthCheckExecutionOrigin executionOrigin() {
    if ('SCHEDULED'.equals(plan.source)) {
      return RecordHealthCheckExecutionOrigin.SCHEDULED;
    }
    if ('SUPPLIED_IDS'.equals(plan.source)) {
      return RecordHealthCheckExecutionOrigin.FLOW;
    }
    return RecordHealthCheckExecutionOrigin.USER_INITIATED;
  }

  private static String sanitize(String value) {
    if (String.isBlank(value)) {
      return 'The scope could not be completed.';
    }
    String normalized = value.replaceAll('[\\r\\n]+', ' ');
    return normalized.length() > 1000 ? normalized.substring(0, 1000) : normalized;
  }

  private class ExecutionPlan {
    private Id batchRunId;
    private Id definitionId;
    private String selectionType;
    private String qualifiedApiName;
    private String checkSetQualifiedApiName;
    private String targetObjectApiName;
    private String populationMode;
    private String filterJson;
    private String captureMode;
    private String source;
    private List<Id> suppliedIds;

    private ExecutionPlan(LaunchRequest request) {
      batchRunId = request.batchRunId;
      definitionId = request.definition.Id;
      selectionType = request.coreInfo.selectionType;
      qualifiedApiName = request.coreInfo.qualifiedApiName;
      checkSetQualifiedApiName = request.coreInfo.checkSetQualifiedApiName;
      targetObjectApiName = request.coreInfo.targetObjectApiName;
      populationMode = 'SUPPLIED_IDS'.equals(request.source)
        ? 'SUPPLIED_IDS'
        : request.definition.PopulationMode__c;
      filterJson = request.definition.FilterJson__c;
      captureMode = request.definition.CaptureMode__c;
      source = request.source;
      suppliedIds = request.suppliedIds == null
        ? new List<Id>()
        : new List<Id>(request.suppliedIds);
    }
  }

  private class Progress {
    private Integer scopeNumber = 0;
    private Integer submittedCount = 0;
    private Integer processedCount = 0;
    private Integer failedScopeCount = 0;
    private Integer passedTotal = 0;
    private Integer failedTotal = 0;
    private Integer unableTotal = 0;
    private Integer systemErrorTotal = 0;
    private String startError;
    private String scopeErrorSummary;
  }
}
