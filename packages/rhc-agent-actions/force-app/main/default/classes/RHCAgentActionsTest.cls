@IsTest
private class RHCAgentActionsTest {
  private static User agentUser() {
    Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User user = new User(
      Alias = 'rhcagent', Email = 'rhc.agent@example.com', LastName = 'Agent',
      Username = 'rhc.agent.' + System.currentTimeMillis() + '@example.com',
      ProfileId = profile.Id, EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US', TimeZoneSidKey = 'GMT'
    );
    insert user;
    List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
    for (PermissionSet permissionSet : [
      SELECT Id FROM PermissionSet WHERE Name IN ('RHC_Agent_Actions_User', 'Record_Health_Check_User')
    ]) {
      assignments.add(new PermissionSetAssignment(AssigneeId = user.Id, PermissionSetId = permissionSet.Id));
    }
    insert assignments;
    return user;
  }

  private static RecordHealthCheckResponse fakeResponse(Id recordId, Integer failed) {
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    response.summary.passed = 2;
    response.summary.failed = failed;
    for (Integer index = 0; index < failed; index++) {
      RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
      item.evaluation = new RecordHealthCheckEvaluationResult();
      item.evaluation.recordId = recordId;
      item.evaluation.checkQualifiedApiName = 'Check_' + index;
      item.evaluation.status = 'FAIL';
      item.evaluation.severity = 'WARNING';
      item.display = new RecordHealthCheckResultDisplay();
      item.display.renderedMessage = 'Phone is missing';
      item.display.renderedFix = 'Enter a phone number.';
      response.results.add(item);
    }
    RecordHealthCheckResultItem passed = new RecordHealthCheckResultItem();
    passed.evaluation = new RecordHealthCheckEvaluationResult();
    passed.evaluation.status = 'PASS';
    response.results.add(passed);
    return response;
  }

  @IsTest
  static void shouldExplainFailedChecksWithFixTextAndBoundFindings() {
    User user = agentUser();
    System.runAs(user) {
      Account account = new Account(Name = 'Agent explain');
      insert account;
      RHCAgentExplainRecordHealthAction.testResponse = fakeResponse(account.Id, 3);
      RHCAgentExplainRecordHealthAction.Request request = new RHCAgentExplainRecordHealthAction.Request();
      request.recordId = account.Id;
      request.maxFindings = 2;
      request.correlationId = 'agent:test-1';

      Test.startTest();
      RHCAgentExplainRecordHealthAction.Response response =
        RHCAgentExplainRecordHealthAction.explain(new List<RHCAgentExplainRecordHealthAction.Request>{ request })[0];
      Test.stopTest();

      Assert.isTrue(response.success, 'Evaluation succeeds: ' + response.errorMessage);
      Assert.areEqual('FAIL', response.overallStatus, 'A failed check makes the overall status FAIL.');
      Assert.areEqual('Account', response.objectApiName, 'The object is derived from the ID.');
      Assert.isFalse(response.checkSetsEvaluated.isEmpty(), 'Applicable Account Check Sets were evaluated.');
      Assert.areEqual(2, response.findings.size(), 'Findings are capped at Maximum Findings.');
      Assert.areEqual('Enter a phone number.', response.findings[0].fix, 'Fix text is what core renders for the user.');
      Assert.isTrue(response.omittedFindings > 0, 'Omitted findings are counted.');
      Assert.isTrue(response.summaryText.contains('Fix: Enter a phone number.'), 'Summary text carries the fix: ' + response.summaryText);
      Assert.areEqual('agent:test-1', response.correlationId, 'Safe correlation IDs round-trip.');
    }
  }

  @IsTest
  static void shouldRejectUnknownCheckSetAndMultipleRequests() {
    User user = agentUser();
    System.runAs(user) {
      Account account = new Account(Name = 'Agent reject');
      insert account;
      RHCAgentExplainRecordHealthAction.Request request = new RHCAgentExplainRecordHealthAction.Request();
      request.recordId = account.Id;
      request.checkSetQualifiedApiName = 'Not_A_Real_Set';

      RHCAgentExplainRecordHealthAction.Response single =
        RHCAgentExplainRecordHealthAction.explain(new List<RHCAgentExplainRecordHealthAction.Request>{ request })[0];
      List<RHCAgentExplainRecordHealthAction.Response> many =
        RHCAgentExplainRecordHealthAction.explain(new List<RHCAgentExplainRecordHealthAction.Request>{ request, request });

      Assert.isFalse(single.success, 'An unknown Check Set is rejected.');
      Assert.areEqual('VALIDATION', single.errorType, 'The error is a validation error.');
      Assert.areEqual(2, many.size(), 'One aligned response per excessive request.');
      Assert.areEqual('LIMIT', many[0].errorType, 'Multiple requests are rejected as a limit error.');
    }
  }

  @IsTest
  static void shouldDenyWithoutCoreRunPermission() {
    Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User user = new User(
      Alias = 'rhcnorun', Email = 'rhc.norun@example.com', LastName = 'NoRun',
      Username = 'rhc.norun.' + System.currentTimeMillis() + '@example.com',
      ProfileId = profile.Id, EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US', TimeZoneSidKey = 'GMT'
    );
    insert user;
    System.runAs(user) {
      RHCAgentExplainRecordHealthAction.Request request = new RHCAgentExplainRecordHealthAction.Request();
      request.recordId = UserInfo.getUserId();
      RHCAgentExplainRecordHealthAction.Response response =
        RHCAgentExplainRecordHealthAction.explain(new List<RHCAgentExplainRecordHealthAction.Request>{ request })[0];
      Assert.areEqual('AUTHORIZATION', response.errorType, 'Core run permission is required.');
    }
  }

  @IsTest
  static void shouldListApplicableCheckSetsByRecordOrObject() {
    User user = agentUser();
    System.runAs(user) {
      Account account = new Account(Name = 'Agent list');
      insert account;
      RHCAgentListCheckSetsAction.Request byRecord = new RHCAgentListCheckSetsAction.Request();
      byRecord.recordId = account.Id;
      RHCAgentListCheckSetsAction.Request byObject = new RHCAgentListCheckSetsAction.Request();
      byObject.objectApiName = 'Account';
      RHCAgentListCheckSetsAction.Request empty = new RHCAgentListCheckSetsAction.Request();

      List<RHCAgentListCheckSetsAction.Response> responses = RHCAgentListCheckSetsAction.listCheckSets(
        new List<RHCAgentListCheckSetsAction.Request>{ byRecord, byObject, empty }
      );

      Assert.isTrue(responses[0].success && !responses[0].checkSets.isEmpty(), 'Account Check Sets are discovered by record.');
      Assert.areEqual(responses[0].checkSets.size(), responses[1].checkSets.size(), 'Record and object discovery agree.');
      Assert.isTrue(responses[1].summaryText.contains(responses[1].checkSets[0].qualifiedApiName), 'The summary names each Check Set.');
      Assert.isFalse(responses[2].success, 'An empty request is rejected.');
    }
  }

  @IsTest
  static void shouldClassifyCorrelationAndOverallStatus() {
    System.runAs(agentUser()) {
      Assert.isNull(RHCAgentSupport.safeCorrelationId('bad value with spaces'), 'Unsafe characters are dropped.');
      Assert.areEqual('a-b:1', RHCAgentSupport.safeCorrelationId(' a-b:1 '), 'Safe IDs are trimmed.');
      RecordHealthCheckRunSummary summary = new RecordHealthCheckRunSummary();
      Assert.areEqual('PASS', RHCAgentSupport.overallStatus(summary), 'No failures means PASS.');
      summary.unable = 1;
      Assert.areEqual('ATTENTION', RHCAgentSupport.overallStatus(summary), 'Unevaluable checks need attention.');
      summary.failed = 1;
      Assert.areEqual('FAIL', RHCAgentSupport.overallStatus(summary), 'Any failure is FAIL.');
    }
  }
}
