/**
 * Explains one record's health to an Agentforce agent: which checks failed, what the running
 * user would see on the record page, and what to do. Evaluates through core's public API in
 * user mode and never modifies the record.
 */
public with sharing class RHCAgentExplainRecordHealthAction {
  private static final Integer DEFAULT_MAX_FINDINGS = 10;
  private static final Integer MAX_FINDINGS_CEILING = 25;
  private static final String PERMISSION_DENIED = 'You do not have permission to run Record Health Checks.';
  @TestVisible private static RecordHealthCheckResponse testResponse;

  /** One explanation request for one record. */
  public class Request {
    @InvocableVariable(
      required=true
      label='Record ID'
      description='ID of the single Salesforce record to explain.'
    )
    public Id recordId;
    @InvocableVariable(
      label='Check Set Qualified API Name'
      description='Optional exact QualifiedApiName of one Record Health Check Set. When omitted, every active Check Set for the record object is evaluated, up to five.'
    )
    public String checkSetQualifiedApiName;
    @InvocableVariable(
      label='Maximum Findings'
      description='Optional cap on findings returned (1-25, default 10). Passed checks are counted but not listed.'
    )
    public Integer maxFindings;
    @InvocableVariable(
      label='Correlation ID'
      description='Optional safe identifier of at most 120 characters for operational correlation.'
    )
    public String correlationId;
  }

  /** One check outcome the user would see on the record page. */
  public class Finding {
    @InvocableVariable(label='Check Set Qualified API Name')
    public String checkSetQualifiedApiName;
    @InvocableVariable(label='Check Qualified API Name')
    public String checkQualifiedApiName;
    @InvocableVariable(label='Status')
    public String status;
    @InvocableVariable(label='Severity')
    public String severity;
    @InvocableVariable(label='Message')
    public String message;
    @InvocableVariable(label='Fix')
    public String fix;
    @InvocableVariable(label='Found')
    public String found;
    @InvocableVariable(label='Expected')
    public String expected;
    @InvocableVariable(label='Action Label')
    public String actionLabel;
    @InvocableVariable(label='Action URL')
    public String actionUrl;
  }

  /** Structured explanation plus a plain-language summary. */
  public class Response {
    @InvocableVariable(label='Contract Version')
    public String contractVersion = RHCAgentSupport.CONTRACT_VERSION;
    @InvocableVariable(label='Correlation ID')
    public String correlationId;
    @InvocableVariable(label='Success')
    public Boolean success;
    @InvocableVariable(label='Overall Status')
    public String overallStatus;
    @InvocableVariable(label='Object API Name')
    public String objectApiName;
    @InvocableVariable(label='Check Sets Evaluated')
    public List<String> checkSetsEvaluated = new List<String>();
    @InvocableVariable(label='Passed Count')
    public Integer passed = 0;
    @InvocableVariable(label='Failed Count')
    public Integer failed = 0;
    @InvocableVariable(label='Skipped Count')
    public Integer skipped = 0;
    @InvocableVariable(label='Unable Count')
    public Integer unable = 0;
    @InvocableVariable(label='System Error Count')
    public Integer systemError = 0;
    @InvocableVariable(label='Findings')
    public List<Finding> findings = new List<Finding>();
    @InvocableVariable(label='Omitted Findings Count')
    public Integer omittedFindings = 0;
    @InvocableVariable(label='Summary Text')
    public String summaryText;
    @InvocableVariable(label='Error Type')
    public String errorType;
    @InvocableVariable(label='Error Message')
    public String errorMessage;
  }

  /**
   * @param requests Agentforce request list; exactly one item is supported
   * @return one structured response
   */
  @InvocableMethod(
    label='Explain Record Health for Agentforce'
    description='Use when a user asks what is wrong with a record, why a health check failed, or how to fix it. Returns each failed or unevaluable check with its message and fix text, plus counts. Never changes the record. FAIL is a business finding; ATTENTION means something could not be evaluated.'
    category='Record Health Check'
  )
  public static List<Response> explain(List<Request> requests) {
    List<Response> responses = new List<Response>();
    if (requests == null || requests.isEmpty()) {
      return responses;
    }
    if (requests.size() != 1) {
      for (Request ignored : requests) {
        responses.add(error(null, 'LIMIT', 'AGENT_SINGLE_RECORD_REQUIRED: supply exactly one request.'));
      }
      return responses;
    }
    responses.add(respond(requests[0]));
    return responses;
  }

  private static Response respond(Request input) {
    String correlationId = RHCAgentSupport.safeCorrelationId(input?.correlationId);
    if (input?.recordId == null) {
      return error(correlationId, 'VALIDATION', 'Record ID is required.');
    }
    if (!FeatureManagement.checkPermission('Record_Health_Check_Run')) {
      return error(correlationId, 'AUTHORIZATION', PERMISSION_DENIED);
    }
    String objectApiName = RHCAgentSupport.objectApiNameOf(input.recordId);
    List<RHCAgentSupport.CheckSetInfo> checkSets = selectCheckSets(objectApiName, input.checkSetQualifiedApiName);
    if (checkSets.isEmpty()) {
      return error(
        correlationId,
        'VALIDATION',
        String.isBlank(input.checkSetQualifiedApiName)
          ? 'No active Record Health Check Set applies to ' + objectApiName + '.'
          : 'Check Set ' + input.checkSetQualifiedApiName + ' is not an active Check Set for ' + objectApiName + '.'
      );
    }
    Response response = new Response();
    response.correlationId = correlationId;
    response.objectApiName = objectApiName;
    Integer maxFindings = boundedMaxFindings(input.maxFindings);
    try {
      for (RHCAgentSupport.CheckSetInfo checkSet : checkSets) {
        RecordHealthCheckResponse coreResponse = evaluate(input.recordId, checkSet.qualifiedApiName, correlationId);
        response.checkSetsEvaluated.add(checkSet.qualifiedApiName);
        accumulate(response, checkSet.qualifiedApiName, coreResponse, maxFindings);
      }
    } catch (Exception failure) {
      // Core already sanitizes its own diagnostics; the agent receives a bounded classification only.
      return error(correlationId, 'EXECUTION', 'The record could not be evaluated. Ask an administrator to review RHC diagnostics.');
    }
    response.success = true;
    RecordHealthCheckRunSummary totals = new RecordHealthCheckRunSummary();
    totals.passed = response.passed;
    totals.failed = response.failed;
    totals.unable = response.unable;
    totals.systemError = response.systemError;
    response.overallStatus = RHCAgentSupport.overallStatus(totals);
    response.summaryText = summarize(response);
    return response;
  }

  private static List<RHCAgentSupport.CheckSetInfo> selectCheckSets(String objectApiName, String requested) {
    if (String.isNotBlank(requested)) {
      RHCAgentSupport.CheckSetInfo match = RHCAgentSupport.findCheckSet(objectApiName, requested.trim());
      return match == null ? new List<RHCAgentSupport.CheckSetInfo>() : new List<RHCAgentSupport.CheckSetInfo>{ match };
    }
    return RHCAgentSupport.applicableCheckSets(objectApiName, RHCAgentSupport.MAX_CHECK_SETS_PER_RECORD);
  }

  private static RecordHealthCheckResponse evaluate(Id recordId, String checkSetQualifiedApiName, String correlationId) {
    if (Test.isRunningTest() && testResponse != null) {
      return testResponse;
    }
    RecordHealthCheckRequest request = RecordHealthCheckRequest.forCheckSet(
      checkSetQualifiedApiName,
      new List<Id>{ recordId }
    ).withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY);
    if (correlationId != null) {
      request = request.withRunId(correlationId);
    }
    return RecordHealthCheck.evaluate(request);
  }

  private static void accumulate(
    Response response,
    String checkSetQualifiedApiName,
    RecordHealthCheckResponse coreResponse,
    Integer maxFindings
  ) {
    response.passed += coreResponse.summary.passed;
    response.failed += coreResponse.summary.failed;
    response.skipped += coreResponse.summary.skipped;
    response.unable += coreResponse.summary.unable;
    response.systemError += coreResponse.summary.systemError;
    for (RecordHealthCheckResultItem item : coreResponse.results) {
      if (item?.evaluation == null || item.evaluation.status == 'PASS' || item.evaluation.status == 'SKIPPED') {
        continue;
      }
      if (response.findings.size() >= maxFindings) {
        response.omittedFindings++;
        continue;
      }
      response.findings.add(finding(checkSetQualifiedApiName, item));
    }
  }

  private static Finding finding(String checkSetQualifiedApiName, RecordHealthCheckResultItem item) {
    Finding finding = new Finding();
    finding.checkSetQualifiedApiName = checkSetQualifiedApiName;
    finding.checkQualifiedApiName = item.evaluation.checkQualifiedApiName;
    finding.status = item.evaluation.status;
    finding.severity = item.evaluation.severity;
    // Display text is what core renders for this user on the record page; admin detail is excluded.
    finding.message = item.display?.renderedMessage;
    finding.fix = item.display?.renderedFix;
    finding.found = item.display?.foundDisplayValue;
    finding.expected = item.display?.expectedDisplayValue;
    finding.actionLabel = item.display?.actionLabel;
    finding.actionUrl = item.display?.actionUrl;
    return finding;
  }

  @TestVisible
  private static String summarize(Response response) {
    String lead = response.overallStatus == 'PASS'
      ? 'All ' + response.passed + ' evaluated checks passed.'
      : response.failed + ' check(s) failed, ' + response.passed + ' passed'
        + (response.unable + response.systemError > 0
          ? ', ' + (response.unable + response.systemError) + ' could not be evaluated.'
          : '.');
    List<String> lines = new List<String>{ lead };
    for (Finding finding : response.findings) {
      String line = '- ' + finding.status + (String.isBlank(finding.severity) ? '' : ' (' + finding.severity + ')')
        + ': ' + (String.isBlank(finding.message) ? finding.checkQualifiedApiName : finding.message);
      if (String.isNotBlank(finding.fix)) {
        line += ' Fix: ' + finding.fix;
      }
      lines.add(line);
    }
    if (response.omittedFindings > 0) {
      lines.add('- ...and ' + response.omittedFindings + ' more finding(s) not listed.');
    }
    return String.join(lines, '\n');
  }

  private static Integer boundedMaxFindings(Integer requested) {
    return requested == null ? DEFAULT_MAX_FINDINGS : Math.max(1, Math.min(MAX_FINDINGS_CEILING, requested));
  }

  private static Response error(String correlationId, String errorType, String message) {
    Response response = new Response();
    response.correlationId = correlationId;
    response.success = false;
    response.errorType = errorType;
    response.errorMessage = message;
    response.summaryText = message;
    return response;
  }
}
