/** Red-scenario tests: callout classification, route safety, payload allow-listing, and dead-letter permissions. */
@IsTest
private class RHCIntegrationHardeningTest {
  private static final String SECRET = 'SECRET-BODY-9c1e';

  private class ThrowingMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      throw new CalloutException('Read timed out calling ' + request.getEndpoint() + ' ' + SECRET);
    }
  }

  private static Record_Health_Check_Integration_Route__c route(String policy) {
    return new Record_Health_Check_Integration_Route__c(
      Active__c = true, NamedCredential__c = 'Service_Management', RelativeEndpoint__c = '/api/incidents', RetryPolicy__c = policy
    );
  }

  private static Record_Health_Check_Integration_Delivery__c delivery(Integer attempts, String policy) {
    return new Record_Health_Check_Integration_Delivery__c(
      EventId__c = 'event-1', Payload__c = '{"eventId":"event-1"}', Status__c = 'PENDING',
      AttemptCount__c = attempts, Route__r = route(policy)
    );
  }

  private static Record_Health_Check_Integration_Delivery__c sendBody(Integer status, String body) {
    Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(status, body));
    Record_Health_Check_Integration_Delivery__c row = delivery(0, 'STANDARD');
    RHCIntegrationDeliveryPolicy.process(row);
    return row;
  }

  private static Record_Health_Check_Integration_Delivery__c send(Integer status, Integer attempts, String policy) {
    Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(status, SECRET));
    Record_Health_Check_Integration_Delivery__c row = delivery(attempts, policy);
    RHCIntegrationDeliveryPolicy.process(row);
    return row;
  }

  private static void assertNoLeak(Record_Health_Check_Integration_Delivery__c row) {
    String detail = row.ErrorDetail__c ?? '';
    Assert.isFalse(detail.contains(SECRET), 'The response body is never retained.');
    Assert.isFalse(detail.contains('Service_Management') || detail.contains('/api/incidents'), 'No endpoint detail is retained.');
    Assert.isFalse(detail.contains('callout:'), 'No callout URL is retained.');
  }

  @IsTest
  static void shouldClassifyEveryStatusFamilyWithoutLeakingBodies() {
    for (Integer code : new List<Integer>{ 200, 201, 202, 204, 299 }) {
      Record_Health_Check_Integration_Delivery__c row = send(code, 0, 'STANDARD');
      Assert.areEqual('SUCCEEDED', row.Status__c, 'Success for ' + code);
      Assert.areEqual(1, row.AttemptCount__c, 'One attempt for ' + code);
      assertNoLeak(row);
    }
    for (Integer code : new List<Integer>{ 408, 425, 429, 500, 502, 503, 504 }) {
      Record_Health_Check_Integration_Delivery__c row = send(code, 0, 'STANDARD');
      Assert.areEqual('RETRY_WAIT', row.Status__c, 'Retry for ' + code);
      Assert.areEqual('HTTP_' + code, row.ErrorCode__c, 'Bounded code for ' + code);
      Assert.isNotNull(row.NextAttemptAt__c, 'A retry time is set for ' + code);
      assertNoLeak(row);
    }
    for (Integer code : new List<Integer>{ 301, 302, 304, 400, 401, 403, 404, 409, 422 }) {
      Record_Health_Check_Integration_Delivery__c row = send(code, 0, 'STANDARD');
      Assert.areEqual('DEAD_LETTER', row.Status__c, 'Permanent for ' + code);
      Assert.areEqual('PERMANENT', row.HttpClassification__c, 'Classification for ' + code);
      Assert.areEqual(code, row.HttpStatus__c, 'Status retained for ' + code);
      Assert.isNull(row.NextAttemptAt__c, 'No retry for ' + code);
      assertNoLeak(row);
    }
  }

  @IsTest
  static void shouldTolerateEmptyAndMalformedBodies() {
    Assert.areEqual('SUCCEEDED', sendBody(200, '').Status__c, 'An empty 200 body succeeds.');
    Assert.areEqual('SUCCEEDED', sendBody(200, null).Status__c, 'A null 200 body succeeds.');
    Assert.areEqual('SUCCEEDED', sendBody(200, '{"unterminated":').Status__c, 'Malformed JSON is never parsed.');
    Assert.areEqual('RETRY_WAIT', sendBody(500, '<html>' + SECRET).Status__c, 'A malformed 500 still retries.');
  }

  @IsTest
  static void shouldRetryTransportFailuresWithoutLeakingExceptionText() {
    Test.setMock(HttpCalloutMock.class, new ThrowingMock());
    Record_Health_Check_Integration_Delivery__c row = delivery(0, 'STANDARD');
    RHCIntegrationDeliveryPolicy.process(row);
    Assert.areEqual('RETRY_WAIT', row.Status__c, 'A timeout is retryable.');
    Assert.areEqual('TRANSPORT_ERROR', row.ErrorCode__c, 'Bounded transport code.');
    Assert.areEqual('TRANSPORT', row.HttpClassification__c, 'Transport classification.');
    assertNoLeak(row);
    Assert.isFalse(row.ErrorDetail__c.contains('timed out'), 'The platform exception text is not retained.');
    row = delivery(0, 'NONE');
    RHCIntegrationDeliveryPolicy.process(row);
    Assert.areEqual('DEAD_LETTER', row.Status__c, 'NONE policy dead-letters the first transport failure.');
  }

  @IsTest
  static void shouldHonorRetryBackoffAndExhaustionContract() {
    Assert.areEqual(1, RHCIntegrationDeliveryPolicy.nextDelayMinutes('STANDARD', 0), 'Standard floor.');
    Assert.areEqual(1, RHCIntegrationDeliveryPolicy.nextDelayMinutes('STANDARD', 1), 'Standard first.');
    Assert.areEqual(5, RHCIntegrationDeliveryPolicy.nextDelayMinutes('STANDARD', 2), 'Standard second.');
    Assert.areEqual(5, RHCIntegrationDeliveryPolicy.nextDelayMinutes('STANDARD', 99), 'Standard ceiling.');
    Assert.areEqual(new List<Integer>{ 1, 2, 5, 10, 10 }, new List<Integer>{
      RHCIntegrationDeliveryPolicy.nextDelayMinutes('AGGRESSIVE', 1), RHCIntegrationDeliveryPolicy.nextDelayMinutes('AGGRESSIVE', 2),
      RHCIntegrationDeliveryPolicy.nextDelayMinutes('AGGRESSIVE', 3), RHCIntegrationDeliveryPolicy.nextDelayMinutes('AGGRESSIVE', 4),
      RHCIntegrationDeliveryPolicy.nextDelayMinutes('AGGRESSIVE', 50)
    }, 'Aggressive schedule is bounded at 10 minutes.');
    Datetime before = System.now();
    Record_Health_Check_Integration_Delivery__c second = send(503, 1, 'STANDARD');
    Assert.areEqual('RETRY_WAIT', second.Status__c, 'Attempt 2 of 3 retries.');
    Assert.isTrue(second.NextAttemptAt__c >= before.addMinutes(5) && second.NextAttemptAt__c <= System.now().addMinutes(5), 'Second delay is 5 minutes.');
    Assert.areEqual('DEAD_LETTER', send(503, 2, 'STANDARD').Status__c, 'Attempt 3 of 3 dead-letters.');
    Assert.areEqual('RETRY_WAIT', send(503, 3, 'AGGRESSIVE').Status__c, 'Aggressive allows five attempts.');
    Assert.areEqual('RETRY_WAIT', send(503, 3, 'MISSING').Status__c, 'An unknown policy retries under the bounded default.');
    Assert.areEqual('DEAD_LETTER', send(503, 4, 'AGGRESSIVE').Status__c, 'Aggressive exhausts at five.');
    Assert.areEqual('DEAD_LETTER', send(503, 0, 'NONE').Status__c, 'NONE never retries.');
  }

  @IsTest
  static void shouldFailClosedWithoutCalloutForUnsafeRoutes() {
    List<List<Object>> unsafe = new List<List<Object>>{
      new List<Object>{ 'Service_Management', null }, new List<Object>{ 'Service_Management', '' },
      new List<Object>{ 'Service_Management', 'api' }, new List<Object>{ 'Service_Management', '//evil.example/x' },
      new List<Object>{ 'Service_Management', '/a://b' }, new List<Object>{ 'Service_Management', '/a?x=1' },
      new List<Object>{ 'Service_Management', '/a#f' }, new List<Object>{ 'Service_Management', '/a/../b' },
      new List<Object>{ 'Service_Management', '/a\\b' }, new List<Object>{ 'Service_Management', '/a/%2e%2e/b' },
      new List<Object>{ null, '/a' }, new List<Object>{ '', '/a' }, new List<Object>{ '1bad', '/a' },
      new List<Object>{ 'bad-name', '/a' }, new List<Object>{ 'bad name', '/a' }, new List<Object>{ 'a'.repeat(81), '/a' }
    };
    for (List<Object> pair : unsafe) {
      Record_Health_Check_Integration_Route__c candidate = route('STANDARD');
      candidate.NamedCredential__c = (String) pair[0];
      candidate.RelativeEndpoint__c = (String) pair[1];
      Assert.isFalse(RHCIntegrationDeliveryPolicy.isSafeRoute(candidate), 'Unsafe: ' + pair);
    }
    Record_Health_Check_Integration_Route__c inactive = route('STANDARD');
    inactive.Active__c = false;
    Assert.isFalse(RHCIntegrationDeliveryPolicy.isSafeRoute(inactive), 'An inactive route is unsafe.');
    Assert.isTrue(RHCIntegrationDeliveryPolicy.isSafeRoute(route('STANDARD')), 'The approved shape is safe.');

    RHCIntegrationHttpMock.capturedRequest = null;
    Test.setMock(HttpCalloutMock.class, new RHCIntegrationHttpMock(200, ''));
    Record_Health_Check_Integration_Delivery__c row = delivery(0, 'STANDARD');
    row.Route__r.RelativeEndpoint__c = '/a?token=1';
    RHCIntegrationDeliveryPolicy.process(row);
    Assert.areEqual('DEAD_LETTER', row.Status__c, 'An unsafe route is dead-lettered.');
    Assert.areEqual('CONFIGURATION_INVALID', row.ErrorCode__c, 'Bounded configuration code.');
    Assert.isNull(RHCIntegrationHttpMock.capturedRequest, 'No callout is attempted for an unsafe route.');
  }

  @IsTest
  static void shouldMatchRoutesFailClosedOnMisconfiguration() {
    RHCIntegrationEventDTO dto = new RHCIntegrationEventDTO();
    dto.eventType = 'RESULT';
    dto.eventId = 'e1';
    dto.checkSetQualifiedApiName = 'Set_A';
    dto.status = 'ERROR';
    dto.severity = 'CRITICAL';
    dto.contractVersion = '1.0';
    Record_Health_Check_Integration_Route__c matching = new Record_Health_Check_Integration_Route__c(
      Active__c = true, EventTypes__c = 'RESULT;RUN', SelectionType__c = 'CHECK_SET', QualifiedApiName__c = 'Set_A',
      Statuses__c = 'ERROR', PayloadProfile__c = 'RHC Error v1'
    );
    List<RHCIntegrationEventDTO> events = new List<RHCIntegrationEventDTO>{ dto };
    Assert.areEqual(1, RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 10).size(), 'A blank minimum severity matches all.');

    matching.MinimumSeverity__c = 'BOGUS';
    Assert.areEqual(0, RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 10).size(), 'An unknown minimum severity fails closed.');
    matching.MinimumSeverity__c = 'WARNING';
    dto.severity = 'INFO';
    Assert.areEqual(0, RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 10).size(), 'Below-minimum severity is skipped.');
    dto.severity = null;
    Assert.areEqual(0, RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 10).size(), 'A missing severity cannot satisfy a minimum.');
    dto.severity = 'CRITICAL';
    matching.EventTypes__c = null;
    Assert.areEqual(0, RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 10).size(), 'A route without event types matches nothing.');
    matching.EventTypes__c = 'RESULT';
    matching.Statuses__c = null;
    Assert.areEqual(0, RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 10).size(), 'A route without statuses matches nothing.');
    matching.Statuses__c = 'ERROR';
    dto.eventId = '';
    Assert.areEqual(0, RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 10).size(), 'An event without an ID is skipped.');
    dto.eventId = 'e1';
    dto.contractVersion = '9.9';
    List<Record_Health_Check_Integration_Delivery__c> built = RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 10);
    Assert.areEqual('DEAD_LETTER', built[0].Status__c, 'An unknown contract is dead-lettered, never sent.');
    Assert.areEqual('UNSUPPORTED_EVENT_CONTRACT', built[0].ErrorCode__c, 'Bounded contract code.');
    try {
      RHCIntegrationDeliveryFactory.build(events, new List<Record_Health_Check_Integration_Route__c>{ matching }, 0);
      Assert.fail('Fan-out above the limit must throw.');
    } catch (RHCIntegrationEventHandler.FanoutLimitException error) {
      Assert.isFalse(error.getMessage().contains('e1'), 'No event data in the message.');
    }
  }

  @IsTest
  static void shouldBuildOnlyAllowListedPayloadFields() {
    RHCIntegrationEventDTO dto = new RHCIntegrationEventDTO();
    dto.eventType = 'LOG';
    dto.eventId = 'e1';
    dto.code = 'CODE_1';
    dto.checkQualifiedApiName = SECRET;
    dto.reasonCode = SECRET;
    dto.recordId = SECRET;
    String log = RHCIntegrationPayloadBuilder.build('RHC Log v1', dto);
    Assert.isFalse(log.contains(SECRET), 'The Log profile excludes restricted fields.');
    Assert.isTrue(((Map<String, Object>) JSON.deserializeUntyped(log)).containsKey('code'), 'The code is included.');
    dto.eventType = 'RUN';
    dto.systemErrorCount = 2;
    Assert.isTrue(RHCIntegrationPayloadBuilder.build('RHC Run v1', dto).contains('"systemErrorCount":2'), 'The Run profile carries counts.');
    dto.eventType = 'RESULT';
    dto.status = 'PASS';
    Assert.isNotNull(RHCIntegrationPayloadBuilder.build('RHC Outcome v1', dto), 'Outcome accepts any RESULT.');
    Assert.isNull(RHCIntegrationPayloadBuilder.build('RHC Error v1', dto), 'Error requires ERROR status.');
    Assert.isNull(RHCIntegrationPayloadBuilder.build('RHC Run v1', dto), 'Run requires a RUN event.');
    Assert.isNull(RHCIntegrationPayloadBuilder.build('RHC Log v1', dto), 'Log requires a LOG event.');
    Assert.isNull(RHCIntegrationPayloadBuilder.build('Custom Template', dto), 'Unknown profiles are refused.');
    Assert.isNull(RHCIntegrationPayloadBuilder.build(null, dto), 'A null profile is refused.');
    Assert.isNull(RHCIntegrationPayloadBuilder.build('RHC Log v1', null), 'A null event is refused.');
    dto.eventId = null;
    Assert.isNull(RHCIntegrationPayloadBuilder.build('RHC Outcome v1', dto), 'An event without ID is refused.');
    dto.eventId = 'e"1\\},{"x":"y';
    String hostile = RHCIntegrationPayloadBuilder.build('RHC Outcome v1', dto);
    Assert.areEqual(dto.eventId, ((Map<String, Object>) JSON.deserializeUntyped(hostile)).get('eventId'), 'Hostile values are escaped, not interpreted.');
  }

  @IsTest
  static void shouldClassifyOnlyPlatformTransientStatusesAsRetryable() {
    Assert.isTrue(RHCIntegrationIngestionService.isRetryable(StatusCode.UNABLE_TO_LOCK_ROW), 'Lock contention retries.');
    Assert.isTrue(RHCIntegrationIngestionService.isRetryable(StatusCode.UNKNOWN_EXCEPTION), 'Unknown platform errors retry.');
    Assert.isFalse(RHCIntegrationIngestionService.isRetryable(StatusCode.REQUIRED_FIELD_MISSING), 'Data errors are permanent.');
    RHCIntegrationIngestionService.persistAndEnqueue(new List<Record_Health_Check_Integration_Delivery__c>());
  }

  @IsTest
  static void shouldKeepDeadLetterReviewPayloadFreeAndPermissionGated() {
    User viewer = RHCIntegrationTestDataFactory.createStandardUser('rhchvw1');
    insert new PermissionSetAssignment(
      AssigneeId = viewer.Id,
      PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'RHC_Integrations_Viewer' LIMIT 1].Id
    );
    Id deliveryId;
    System.runAs(RHCIntegrationTestDataFactory.createStandardUser('rhchad1')) {
      Record_Health_Check_Integration_Route__c exampleRoute = RHCIntegrationTestDataFactory.createExampleRoute();
      Record_Health_Check_Integration_Delivery__c row = RHCIntegrationTestDataFactory.createDelivery(exampleRoute.Id, 'DEAD_LETTER');
      row.Payload__c = '{"secretPayload":"' + SECRET + '"}';
      update row;
      deliveryId = row.Id;
    }
    System.runAs(viewer) {
      String projected = JSON.serialize(RHCIntegrationDeadLetterController.getDeadLetters());
      Assert.isFalse(projected.contains(SECRET), 'The review projection never carries payloads.');
      for (List<Id> ids : new List<List<Id>>{ new List<Id>{ deliveryId }, new List<Id>(), null }) {
        try {
          RHCIntegrationDeadLetterController.replayAll(ids);
          Assert.fail('A viewer cannot replay.');
        } catch (AuraHandledException error) {
          Assert.areEqual('You do not have permission to replay deliveries.', error.getMessage(), 'Stable denial.');
        }
      }
      try {
        RHCIntegrationDeadLetterController.purgeDeliveries();
        Assert.fail('A viewer cannot purge.');
      } catch (AuraHandledException error) {
        Assert.areEqual('You do not have permission to manage Integration Delivery retention.', error.getMessage(), 'Stable denial.');
      }
    }
    Record_Health_Check_Integration_Delivery__c after = [SELECT Status__c, ReplayCount__c FROM Record_Health_Check_Integration_Delivery__c WHERE Id = :deliveryId];
    Assert.areEqual('DEAD_LETTER', after.Status__c, 'Denied replay changes nothing.');
    Assert.areEqual(0, after.ReplayCount__c ?? 0, 'No replay was counted.');
  }

  private static Id fakeId(Integer suffix) {
    return Id.valueOf(Record_Health_Check_Integration_Delivery__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() + '000000000' + String.valueOf(suffix));
  }

  @IsTest
  static void shouldBoundReplayRequestsAndSkipUnknownIds() {
    User administrator = RHCIntegrationTestDataFactory.createStandardUser('rhchad2');
    insert new PermissionSetAssignment(
      AssigneeId = administrator.Id,
      PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'RHC_Integrations_Admin' LIMIT 1].Id
    );
    System.runAs(administrator) {
      List<Id> tooMany = new List<Id>();
      for (Integer i = 0; i < 51; i++) {
        tooMany.add(fakeId(100 + i));
      }
      try {
        RHCIntegrationDeadLetterController.replayAll(tooMany);
        Assert.fail('More than 50 ids must be rejected.');
      } catch (AuraHandledException error) {
        Assert.areEqual('Replay at most 50 deliveries at once.', error.getMessage(), 'Stable bound message.');
      }
      try {
        RHCIntegrationDeadLetterController.replayAll(new List<Id>{ fakeId(100) });
        Assert.fail('An id that is not a dead letter must be rejected.');
      } catch (AuraHandledException error) {
        Assert.areEqual('Only an accessible dead-letter delivery can be replayed.', error.getMessage(), 'Stable message with no id echo.');
      }
      try {
        RHCIntegrationDeadLetterController.replay(null);
        Assert.fail('A null id must be rejected.');
      } catch (AuraHandledException error) {
        Assert.areEqual('Select a delivery to replay.', error.getMessage(), 'Stable message.');
      }
    }
  }
}
