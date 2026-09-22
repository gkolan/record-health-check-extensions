/** Persists canonical core response fields according to one capture mode. */
public with sharing class RHCRunManagerCaptureService {
  /** Inputs required to capture one core response. */
  public class Request {
    public Id runId;
    public String runCorrelationId;
    public String captureMode;
    public RecordHealthCheckResponse response;
  }

  /**
   * Captures approved response facts with partial-success user-mode DML.
   * @param request Owned Run identity, correlation ID, capture mode, and core response.
   * @return Number of retained Result rows accepted for DML.
   */
  public static Integer capture(Request request) {
    if (request == null || request.runId == null || request.response == null || request.response.results == null) {
      return 0;
    }
    List<Record_Health_Check_Run_Result__c> results = new List<Record_Health_Check_Run_Result__c>();
    for (RecordHealthCheckResultItem item : request.response.results) {
      RecordHealthCheckEvaluationResult evaluation = item?.evaluation;
      if (evaluation == null || !shouldRetain(request.captureMode, evaluation.status)) {
        continue;
      }
      results.add(buildResult(request.runId, request.runCorrelationId, evaluation));
    }
    persistResults(results);
    return results.size();
  }

  private static void persistResults(List<Record_Health_Check_Run_Result__c> results) {
    if (results.isEmpty()) {
      return;
    }
    Savepoint captureSavepoint = Database.setSavepoint();
    List<Database.UpsertResult> upsertResults = Database.upsert(
      results,
      Record_Health_Check_Run_Result__c.Fields.ResultKey__c,
      false,
      AccessLevel.USER_MODE
    );
    Integer failureCount = 0;
    for (Database.UpsertResult upsertResult : upsertResults) {
      if (!upsertResult.isSuccess()) {
        failureCount++;
      }
    }
    if (failureCount > 0) {
      Database.rollback(captureSavepoint);
      throw new CaptureException('One or more retained results could not be persisted.');
    }
  }

  private static Record_Health_Check_Run_Result__c buildResult(
    Id runId,
    String runCorrelationId,
    RecordHealthCheckEvaluationResult evaluation
  ) {
    return new Record_Health_Check_Run_Result__c(
      Run__c = runId,
      ResultKey__c = resultKey(runCorrelationId, evaluation),
      RecordId__c = evaluation.recordId == null ? null : String.valueOf(evaluation.recordId),
      CheckQualifiedApiName__c = evaluation.checkQualifiedApiName,
      Status__c = evaluation.status,
      Severity__c = evaluation.severity,
      ReasonCode__c = evaluation.reasonCode,
      ComparisonOperator__c = evaluation.comparisonOperator,
      FoundValueJson__c = evaluation.found == null ? null : JSON.serialize(evaluation.found),
      ExpectedValueJson__c = evaluation.expected == null ? null : JSON.serialize(evaluation.expected),
      DiagnosticId__c = evaluation.diagnosticId,
      DiagnosticCategory__c = evaluation.diagnosticCategory,
      DiagnosticSummary__c = evaluation.diagnosticSummary,
      RecommendedAction__c = evaluation.recommendedAction,
      OccurredAt__c = System.now()
    );
  }

  /** Signals an atomic capture failure without disclosing row-level data. */
  public class CaptureException extends Exception {}

  @TestVisible
  private static Boolean shouldRetain(String captureMode, String status) {
    if (RecordHealthCheckStatus.SKIPPED == status) {
      return false;
    }
    if ('PASS'.equals(captureMode)) {
      return RecordHealthCheckStatus.PASS == status;
    }
    if ('FAIL'.equals(captureMode)) {
      return RecordHealthCheckStatus.isActionable(status);
    }
    if ('BOTH'.equals(captureMode)) {
      return RecordHealthCheckStatus.PASS == status || RecordHealthCheckStatus.isActionable(status);
    }
    return false;
  }

  private static String resultKey(
    String runCorrelationId,
    RecordHealthCheckEvaluationResult evaluation
  ) {
    return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(
      runCorrelationId + '|' + evaluation.recordId + '|' + evaluation.checkQualifiedApiName
    )));
  }
}
