/** Owns population, scoped core execution, capture, correlation, and monitoring. */
public with sharing class RHCRunManagerBatch implements Database.Batchable<SObject>, Database.Stateful {
  @TestVisible private static Boolean forceStartFailure = false;
  @TestVisible private static Boolean forceScopeFailure = false;
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

  /** Captures immutable, validated execution inputs. */
  public RHCRunManagerBatch(
    Id batchRunId,
    Record_Health_Check_Run_Definition__c definition,
    RHCRunManagerCoreMetadataGateway.DefinitionInfo coreInfo,
    String source,
    List<Id> suppliedIds
  ) {
    this.batchRunId = batchRunId;
    this.definitionId = definition.Id;
    this.selectionType = coreInfo.selectionType;
    this.qualifiedApiName = coreInfo.qualifiedApiName;
    this.checkSetQualifiedApiName = coreInfo.checkSetQualifiedApiName;
    this.targetObjectApiName = coreInfo.targetObjectApiName;
    this.populationMode = 'SUPPLIED_IDS'.equals(source) ? 'SUPPLIED_IDS' : definition.PopulationMode__c;
    this.filterJson = definition.FilterJson__c;
    this.captureMode = definition.CaptureMode__c;
    this.source = source;
    this.suppliedIds = suppliedIds == null ? new List<Id>() : new List<Id>(suppliedIds);
  }

  /** Discovers records in user mode using core-derived object metadata. */
  public Database.QueryLocator start(Database.BatchableContext context) {
    try {
      if (forceStartFailure) throw new IllegalArgumentException('Forced start failure.');
      RHCRunManagerFilterService.QuerySpec querySpec = RHCRunManagerFilterService.build(
        targetObjectApiName,
        populationMode,
        filterJson,
        suppliedIds
      );
      Database.QueryLocator queryLocator = Database.getQueryLocatorWithBinds(
        querySpec.soql,
        querySpec.binds,
        AccessLevel.USER_MODE
      );
      markBatchRunProcessing(context == null ? null : context.getJobId());
      return queryLocator;
    } catch (Exception error) {
      startError = sanitize(error.getMessage());
      return emptyQueryLocator();
    }
  }

  /** Evaluates and commits one independent framework scope. */
  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) return;
    scopeNumber++;
    submittedCount += scope.size();
    List<Id> recordIds = new List<Id>();
    for (SObject recordValue : scope) recordIds.add((Id) recordValue.get('Id'));
    String correlationId = 'rm-' + batchRunId + '-' + scopeNumber;
    Record_Health_Check_Run__c runRecord;
    try {
      runRecord = createRun(correlationId, recordIds.size());
      if (forceScopeFailure) throw new IllegalArgumentException('Forced scope failure.');
      RecordHealthCheckRequest request = 'CHECK_SET'.equals(selectionType)
        ? RecordHealthCheckRequest.forCheckSet(qualifiedApiName, recordIds)
        : RecordHealthCheckRequest.forCheck(qualifiedApiName, recordIds);
      request = request
        .withResultMode(RecordHealthCheckResultMode.EVALUATION)
        .withRunId(correlationId)
        .withExecutionOrigin(executionOrigin())
        .withEventPublication(eventPublication());
      RecordHealthCheckResponse response = RecordHealthCheck.evaluate(request);
      RHCRunManagerCaptureService.capture(runRecord.Id, correlationId, captureMode, response);
      completeRun(runRecord, response);
      processedCount += recordIds.size();
      passedTotal += response.summary.passed ?? 0;
      failedTotal += response.summary.failed ?? 0;
      unableTotal += response.summary.unable ?? 0;
      systemErrorTotal += response.summary.systemError ?? 0;
    } catch (Exception error) {
      failedScopeCount++;
      String summary = sanitize(error.getMessage());
      appendScopeError('Scope ' + scopeNumber + ': ' + summary);
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

  /** Finalizes owned job monitoring without treating Check failures as job failures. */
  public void finish(Database.BatchableContext context) {
    // An administrator cancel can land between the last scope and finish; keep that verdict.
    if ('CANCELLED' == [
      SELECT Status__c FROM Record_Health_Check_Batch_Run__c WHERE Id = :batchRunId WITH USER_MODE LIMIT 1
    ].Status__c) return;
    Record_Health_Check_Batch_Run__c updateRecord = new Record_Health_Check_Batch_Run__c(
      Id = batchRunId,
      Status__c = String.isNotBlank(startError) ? 'ERROR' : (failedScopeCount > 0 ? 'PARTIAL_FAILURE' : 'COMPLETED'),
      SubmittedRecordCount__c = submittedCount,
      ProcessedRecordCount__c = processedCount,
      FailedScopeCount__c = failedScopeCount,
      PassedCount__c = passedTotal,
      FailedCount__c = failedTotal,
      UnableCount__c = unableTotal,
      SystemErrorCount__c = systemErrorTotal,
      CompletedAt__c = System.now(),
      ErrorSummary__c = String.isNotBlank(startError) ? startError : scopeErrorSummary
    );
    Database.update(updateRecord, AccessLevel.USER_MODE);
  }

  private Record_Health_Check_Run__c createRun(String correlationId, Integer recordCount) {
    Record_Health_Check_Run__c runRecord = new Record_Health_Check_Run__c(
      BatchRun__c = batchRunId,
      RunId__c = correlationId,
      ScopeNumber__c = scopeNumber,
      Status__c = 'IN_PROGRESS',
      SelectionType__c = selectionType,
      QualifiedApiName__c = qualifiedApiName,
      CheckSetQualifiedApiName__c = checkSetQualifiedApiName,
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
      Id = batchRunId,
      Status__c = 'PROCESSING',
      AsyncApexJobId__c = asyncJobId == null ? null : String.valueOf(asyncJobId)
    ), AccessLevel.USER_MODE);
  }

  private Database.QueryLocator emptyQueryLocator() {
    return Database.getQueryLocatorWithBinds(
      'SELECT Id FROM Record_Health_Check_Run_Definition__c WHERE Id = :definitionId AND Id = NULL',
      new Map<String, Object>{ 'definitionId' => definitionId },
      AccessLevel.USER_MODE
    );
  }

  private void appendScopeError(String scopeError) {
    scopeErrorSummary = sanitize(
      String.isBlank(scopeErrorSummary) ? scopeError : scopeErrorSummary + '\n' + scopeError
    );
  }

  private RecordHealthCheckEventPublication eventPublication() {
    return 'FAIL'.equals(captureMode)
      ? RecordHealthCheckEventPublication.ACTIONABLE
      : RecordHealthCheckEventPublication.ALL;
  }

  private RecordHealthCheckExecutionOrigin executionOrigin() {
    if ('SCHEDULED'.equals(source)) return RecordHealthCheckExecutionOrigin.SCHEDULED;
    if ('SUPPLIED_IDS'.equals(source)) return RecordHealthCheckExecutionOrigin.FLOW;
    return RecordHealthCheckExecutionOrigin.USER_INITIATED;
  }

  private static String sanitize(String value) {
    if (String.isBlank(value)) return 'The scope could not be completed.';
    String normalized = value.replaceAll('[\\r\\n]+', ' ');
    return normalized.length() > 1000 ? normalized.substring(0, 1000) : normalized;
  }
}
