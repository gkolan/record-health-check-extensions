@IsTest
private class RHCIntegrationEventHandlerTest {
  @TestSetup
  static void setupTestData() {
    RHCIntegrationTestDataFactory.createExampleRoute();
  }

  @IsTest
  static void shouldDeliverOnlyExactIdentityStatusAndSeverityMatch() {
    User principal = RHCIntegrationTestDataFactory.createStandardUser(
      'rhcevt1'
    );
    System.runAs(principal) {
      Test.setMock(
        HttpCalloutMock.class,
        new RHCIntegrationHttpMock(202, '{"accepted":true}')
      );
      Record_Health_Check_Result__e matching = resultEvent(
        'event-match',
        'Opportunity_Close_Readiness',
        'ERROR',
        'CRITICAL'
      );
      Record_Health_Check_Result__e wrongSeverity = resultEvent(
        'event-info',
        'Opportunity_Close_Readiness',
        'ERROR',
        'INFO'
      );
      Record_Health_Check_Result__e wrongIdentity = resultEvent(
        'event-other',
        'Other_Check_Set',
        'ERROR',
        'CRITICAL'
      );

      Test.startTest();
      RHCIntegrationEventHandler.handleResults(
        new List<Record_Health_Check_Result__e>{
          matching,
          wrongSeverity,
          wrongIdentity
        }
      );
      Test.stopTest();

      List<Record_Health_Check_Integration_Delivery__c> deliveries = [
        SELECT EventId__c, Status__c
        FROM Record_Health_Check_Integration_Delivery__c
      ];
      Assert.areEqual(
        1,
        deliveries.size(),
        'Only the exact route match should create a delivery'
      );
      Assert.areEqual(
        'event-match',
        deliveries[0].EventId__c,
        'The matching Event ID should be retained'
      );
      Assert.areEqual(
        'SUCCEEDED',
        deliveries[0].Status__c,
        'A 202 response should succeed'
      );
    }
  }

  @IsTest
  static void shouldCreateOneLogicalDeliveryWhenEventIdIsRepeated() {
    User principal = RHCIntegrationTestDataFactory.createStandardUser(
      'rhcevt2'
    );
    System.runAs(principal) {
      Test.setMock(
        HttpCalloutMock.class,
        new RHCIntegrationHttpMock(200, '{}')
      );
      Record_Health_Check_Result__e eventRecord = resultEvent(
        'event-duplicate',
        'Opportunity_Close_Readiness',
        'ERROR',
        'CRITICAL'
      );
      Test.startTest();
      RHCIntegrationEventHandler.handleResults(
        new List<Record_Health_Check_Result__e>{ eventRecord }
      );
      RHCIntegrationEventHandler.handleResults(
        new List<Record_Health_Check_Result__e>{ eventRecord }
      );
      Test.stopTest();
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Record_Health_Check_Integration_Delivery__c],
        'The route-plus-Event-ID unique key should suppress duplicate delivery work'
      );
    }
  }

  @IsTest
  static void shouldBulkCreateDeliveriesWhen251DistinctEventsMatch() {
    User principal = RHCIntegrationTestDataFactory.createStandardUser(
      'rhcevt3'
    );
    System.runAs(principal) {
      Test.setMock(
        HttpCalloutMock.class,
        new RHCIntegrationHttpMock(200, '{}')
      );
      List<RHCIntegrationEventDTO> eventRecords = bulkEventDtos(251);
      Test.startTest();
      RHCIntegrationEventHandler.handleDtos(eventRecords);
      Test.stopTest();
      Assert.areEqual(
        251,
        [SELECT COUNT() FROM Record_Health_Check_Integration_Delivery__c],
        'All 251 distinct matching events should be persisted with one root queueable'
      );
    }
  }

  @IsTest
  static void shouldRejectSubscriberBatchWhenFanoutExceedsSafeLimit() {
    User principal = RHCIntegrationTestDataFactory.createStandardUser(
      'rhcevt4'
    );
    System.runAs(principal) {
      RHCIntegrationTestDataFactory.createExampleRoutes(4);
      List<RHCIntegrationEventDTO> eventRecords = bulkEventDtos(251);

      Test.startTest();
      try {
        RHCIntegrationEventHandler.handleDtos(eventRecords);
        Assert.fail('Expected unsafe event-to-route fan-out to be rejected');
      } catch (RHCIntegrationEventHandler.FanoutLimitException expected) {
        Assert.isTrue(
          expected.getMessage().contains('safe per-transaction limit'),
          'The failure should explain the bounded subscriber limit'
        );
      }
      Test.stopTest();

      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Record_Health_Check_Integration_Delivery__c],
        'A rejected subscriber batch must not create partial delivery work'
      );
    }
  }

  @IsTest
  static void shouldRaiseIngestionFailureWhenLedgerInsertIsNotDuplicate() {
    User principal = RHCIntegrationTestDataFactory.createStandardUser(
      'rhcevt5'
    );
    System.runAs(principal) {
      RHCIntegrationEventDTO eventRecord = bulkEventDtos(1)[0];
      eventRecord.eventId = longString(81);

      Test.startTest();
      try {
        RHCIntegrationEventHandler.handleDtos(
          new List<RHCIntegrationEventDTO>{ eventRecord }
        );
        Assert.fail(
          'Expected a non-duplicate ledger insert error to fail ingestion'
        );
      } catch (RHCIntegrationIngestionService.IngestionException expected) {
        Assert.isTrue(
          expected.getMessage().contains('STRING_TOO_LONG'),
          'The failure should retain only the bounded platform status category'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldClassifyOnlyTransientPlatformFailuresForRedelivery() {
    User principal = RHCIntegrationTestDataFactory.createStandardUser(
      'rhcevt6'
    );
    System.runAs(principal) {
      Test.startTest();
      Assert.isTrue(
        RHCIntegrationIngestionService.isRetryable(
          StatusCode.UNABLE_TO_LOCK_ROW
        ),
        'Row-lock contention should request Platform Event redelivery'
      );
      Assert.isTrue(
        RHCIntegrationIngestionService.isRetryable(
          StatusCode.UNKNOWN_EXCEPTION
        ),
        'Unknown platform failures should request bounded redelivery'
      );
      Assert.isFalse(
        RHCIntegrationIngestionService.isRetryable(StatusCode.STRING_TOO_LONG),
        'Permanent contract failures must not enter a futile retry loop'
      );
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldProduceNoDeliveryWhenNoEventExists() {
    User principal = RHCIntegrationTestDataFactory.createStandardUser(
      'rhcevt7'
    );
    System.runAs(principal) {
      Test.startTest();
      RHCIntegrationEventHandler.handleResults(
        new List<Record_Health_Check_Result__e>()
      );
      Test.stopTest();
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Record_Health_Check_Integration_Delivery__c],
        'Publication NONE has no event and therefore no delivery'
      );
    }
  }

  @SuppressWarnings('PMD.ExcessiveParameterList')
  private static Record_Health_Check_Result__e resultEvent(
    String eventId,
    String checkSetName,
    String status,
    String severity
  ) {
    return new Record_Health_Check_Result__e(
      EventId__c = eventId,
      RunId__c = 'run-001',
      CheckSetQualifiedApiName__c = checkSetName,
      CheckQualifiedApiName__c = 'Close_Date_Is_Ready',
      Status__c = status,
      Severity__c = severity,
      OccurredAt__c = System.now(),
      Source__c = 'APEX_API',
      ContractVersion__c = '1.0',
      FrameworkVersion__c = '2.0.4'
    );
  }

  private static List<RHCIntegrationEventDTO> bulkEventDtos(
    Integer eventCount
  ) {
    List<RHCIntegrationEventDTO> eventRecords = new List<RHCIntegrationEventDTO>();
    for (Integer index = 0; index < eventCount; index++) {
      RHCIntegrationEventDTO eventRecord = new RHCIntegrationEventDTO();
      eventRecord.eventType = 'RESULT';
      eventRecord.eventId = 'bulk-event-' + index;
      eventRecord.runId = 'bulk-run';
      eventRecord.checkSetQualifiedApiName = 'Opportunity_Close_Readiness';
      eventRecord.checkQualifiedApiName = 'Close_Date_Is_Ready';
      eventRecord.status = 'ERROR';
      eventRecord.severity = 'CRITICAL';
      eventRecord.contractVersion = '1.0';
      eventRecord.frameworkVersion = '2.0.4';
      eventRecord.occurredAt = System.now();
      eventRecords.add(eventRecord);
    }
    return eventRecords;
  }

  private static String longString(Integer length) {
    String value = '';
    for (Integer index = 0; index < length; index++) {
      value += 'x';
    }
    return value;
  }
}
