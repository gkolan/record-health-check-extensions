@IsTest
private class RHCRunManagerCaptureServiceTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldRetainExactStatusGroupsForEveryCaptureMode() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Assert.isTrue(RHCRunManagerCaptureService.shouldRetain('PASS', RecordHealthCheckStatus.PASS), 'PASS mode retains PASS.');
    Assert.isFalse(RHCRunManagerCaptureService.shouldRetain('PASS', RecordHealthCheckStatus.FAIL), 'PASS mode excludes FAIL.');
    Assert.isTrue(RHCRunManagerCaptureService.shouldRetain('FAIL', RecordHealthCheckStatus.UNABLE_TO_EVALUATE), 'FAIL mode retains unable.');
    Assert.isTrue(RHCRunManagerCaptureService.shouldRetain('BOTH', RecordHealthCheckStatus.ERROR), 'BOTH retains errors.');
    Assert.isFalse(RHCRunManagerCaptureService.shouldRetain('BOTH', RecordHealthCheckStatus.SKIPPED), 'SKIPPED is never retained.');
    }
  }

  @IsTest
  static void shouldUpsertOneResultWhenCaptureRepeated() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'BOTH');
    Record_Health_Check_Batch_Run__c batchRun = RHCRunManagerTestDataFactory.createBatchRun(definition.Id);
    Record_Health_Check_Run__c runRecord = new Record_Health_Check_Run__c(BatchRun__c = batchRun.Id, RunId__c = 'idempotent-run', ScopeNumber__c = 1, Status__c = 'COMPLETED', SelectionType__c = 'CHECK_SET', QualifiedApiName__c = definition.QualifiedApiName__c, RecordCount__c = 1, OccurredAt__c = System.now());
    insert runRecord;
    Account account = new Account(Name = 'Idempotency');
    insert account;
    RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
    evaluation.recordId = account.Id;
    evaluation.checkQualifiedApiName = 'Example_Check';
    evaluation.status = RecordHealthCheckStatus.PASS;
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = evaluation;
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.results.add(item);

    Test.startTest();
    RHCRunManagerCaptureService.Request request = captureRequest(runRecord.Id, 'idempotent-run', response);
    RHCRunManagerCaptureService.capture(request);
    RHCRunManagerCaptureService.capture(request);
    Test.stopTest();

    Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Run_Result__c WHERE Run__c = :runRecord.Id], 'Unique ResultKey should suppress retries and event-equivalent duplicates.');
    }
  }

  @IsTest
  static void shouldRollbackEveryResultWhenOneRetainedRowFailsDml() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
    Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition('ALL_ACCESSIBLE', 'BOTH');
    Record_Health_Check_Batch_Run__c batchRun = RHCRunManagerTestDataFactory.createBatchRun(definition.Id);
    Record_Health_Check_Run__c runRecord = new Record_Health_Check_Run__c(
      BatchRun__c = batchRun.Id,
      RunId__c = 'atomic-capture',
      ScopeNumber__c = 1,
      Status__c = 'IN_PROGRESS',
      SelectionType__c = 'CHECK_SET',
      QualifiedApiName__c = definition.QualifiedApiName__c,
      RecordCount__c = 1,
      OccurredAt__c = System.now()
    );
    insert runRecord;
    Account account = new Account(Name = 'Atomic capture');
    insert account;
    String overlongCheckName = '';
    for (Integer characterIndex = 0; characterIndex < 121; characterIndex++) {
      overlongCheckName += 'x';
    }
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.results.add(resultItem(account.Id, 'Valid_Check'));
    response.results.add(resultItem(account.Id, overlongCheckName));

    Boolean captureFailed = false;
    try {
      RHCRunManagerCaptureService.capture(captureRequest(runRecord.Id, 'atomic-capture', response));
    } catch (RHCRunManagerCaptureService.CaptureException error) {
      captureFailed = true;
    }

    Assert.isTrue(captureFailed, 'Any retained-row DML failure must be surfaced to the owning Batch scope.');
    Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Run_Result__c WHERE Run__c = :runRecord.Id], 'A partial retained-result write must be rolled back.');
    }
  }

  @IsTest
  static void shouldIgnoreNullCaptureRequest() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Test.startTest();
      Integer capturedCount = RHCRunManagerCaptureService.capture(null);
      Test.stopTest();

      Assert.areEqual(0, capturedCount, 'A missing capture request should not write results.');
    }
  }

  private static RHCRunManagerCaptureService.Request captureRequest(
    Id runId,
    String runCorrelationId,
    RecordHealthCheckResponse response
  ) {
    RHCRunManagerCaptureService.Request request = new RHCRunManagerCaptureService.Request();
    request.runId = runId;
    request.runCorrelationId = runCorrelationId;
    request.captureMode = 'BOTH';
    request.response = response;
    return request;
  }

  private static RecordHealthCheckResultItem resultItem(Id recordId, String checkQualifiedApiName) {
    RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
    evaluation.recordId = recordId;
    evaluation.checkQualifiedApiName = checkQualifiedApiName;
    evaluation.status = RecordHealthCheckStatus.PASS;
    RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
    item.evaluation = evaluation;
    return item;
  }
}
