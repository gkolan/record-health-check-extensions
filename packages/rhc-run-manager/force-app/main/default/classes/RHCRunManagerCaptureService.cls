/** Persists canonical core response fields according to one capture mode. */
public with sharing class RHCRunManagerCaptureService {
  /**
   * Captures approved response facts with partial-success user-mode DML.
   * @param runId Owned Run record ID.
   * @param runCorrelationId Core correlation ID.
   * @param captureMode PASS, FAIL, or BOTH.
   * @param response Core response envelope.
   * @return Number of retained Result rows accepted for DML.
   */
  public static Integer capture(
    Id runId,
    String runCorrelationId,
    String captureMode,
    RecordHealthCheckResponse response
  ) {
    if (runId == null || response == null || response.results == null) return 0;
    List<Record_Health_Check_Run_Result__c> results = new List<Record_Health_Check_Run_Result__c>();
    for (RecordHealthCheckResultItem item : response.results) {
      RecordHealthCheckEvaluationResult evaluation = item?.evaluation;
      if (evaluation == null || !shouldRetain(captureMode, evaluation.status)) continue;
      results.add(new Record_Health_Check_Run_Result__c(
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
      ));
    }
    if (!results.isEmpty()) {
      Savepoint captureSavepoint = Database.setSavepoint();
      List<Database.UpsertResult> upsertResults = Database.upsert(
        results,
        Record_Health_Check_Run_Result__c.Fields.ResultKey__c,
        false,
        AccessLevel.USER_MODE
      );
      Integer failureCount = 0;
      for (Database.UpsertResult upsertResult : upsertResults) {
        if (!upsertResult.isSuccess()) failureCount++;
      }
      if (failureCount > 0) {
        Database.rollback(captureSavepoint);
        throw new CaptureException('One or more retained results could not be persisted.');
      }
    }
    return results.size();
  }

  /** Signals an atomic capture failure without disclosing row-level data. */
  public class CaptureException extends Exception {}

  @TestVisible
  private static Boolean shouldRetain(String captureMode, String status) {
    if (RecordHealthCheckStatus.SKIPPED == status) return false;
    if ('PASS'.equals(captureMode)) return RecordHealthCheckStatus.PASS == status;
    if ('FAIL'.equals(captureMode)) return RecordHealthCheckStatus.isActionable(status);
    if ('BOTH'.equals(captureMode)) return RecordHealthCheckStatus.PASS == status || RecordHealthCheckStatus.isActionable(status);
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
