/** Red-scenario contract tests: hostile CDC input, claim-key idempotency, routing, and failure classification. */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCChangeMonitorHardeningTest {
  private static final String SENTINEL = 'SENSITIVE-PAYLOAD-7f3a';
  private static final String ACCOUNT_ID = fakeId(Account.SObjectType, 1);
  private static final Id POLICY_ID = fakeId(Record_Health_Check_Change_Policy__c.SObjectType, 2);

  private static String fakeId(Schema.SObjectType type, Integer suffix) {
    return type.getDescribe().getKeyPrefix() + String.valueOf(suffix).leftPad(12, '0');
  }

  @TestSetup
  static void assignPermissions() {
    RHCChangeMonitorTestDataFactory.createAdminUser();
  }

  private static Map<String, Object> header(Object sequence, Object recordIds) {
    return new Map<String, Object>{
      'entityName' => 'Account',
      'changeType' => 'UPDATE',
      'changedFields' => new List<Object>{ 'Name' },
      'recordIds' => recordIds,
      'transactionKey' => 'tx-1',
      'sequenceNumber' => sequence,
      'commitTimestamp' => 1700000000000L
    };
  }

  private static String expectInvalid(Map<String, Object> input) {
    try {
      RHCChangeMonitorEventEnvelope.fromHeader('AccountChangeEvent', input, new Map<String, Object>());
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      return error.getMessage();
    }
    Assert.fail('InvalidEventException was expected.');
    return null;
  }

  @IsTest
  static void shouldRejectNonNumericSequenceWithTypedException() {
    String message = expectInvalid(header(SENTINEL, new List<Object>{ ACCOUNT_ID }));
    Assert.isFalse(message.contains(SENTINEL), 'The rejected value must not be echoed.');
  }

  @IsTest
  static void shouldRejectRecordIdsThatAreNotAListWithTypedException() {
    Assert.isFalse(expectInvalid(header(1, SENTINEL)).contains(SENTINEL), 'The rejected value must not be echoed.');
  }

  @IsTest
  static void shouldRejectMissingHeaderAndEvidenceWithTypedException() {
    try {
      RHCChangeMonitorEventEnvelope.fromHeader('AccountChangeEvent', null, null);
      Assert.fail('A missing header must be rejected.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.areEqual('Stable transaction key is required.', error.getMessage(), 'The contract message is stable.');
    }
  }

  @IsTest
  static void shouldRejectMalformedRecordIdWithoutEchoingIt() {
    String message = expectInvalid(header(1, new List<Object>{ 'bad-' + SENTINEL }));
    Assert.areEqual('A source record ID is malformed.', message, 'The message is stable and value-free.');
  }

  @IsTest
  static void shouldNeverRetainPayloadValuesInTheEnvelope() {
    Map<String, Object> hostile = header(1, new List<Object>{ ACCOUNT_ID });
    hostile.put('Name', SENTINEL);
    hostile.put('payload', new Map<String, Object>{ 'secret' => SENTINEL });
    RHCChangeMonitorEventEnvelope envelope = RHCChangeMonitorEventEnvelope.fromHeader(
      'AccountChangeEvent', hostile, new Map<String, Object>()
    );
    Assert.isFalse(JSON.serialize(envelope).contains(SENTINEL), 'Only approved header facts are retained.');
    Assert.areEqual('Account', envelope.sourceObjectApiName, 'Approved facts survive.');
  }

  @IsTest
  static void shouldBoundOversizedIdentityStrings() {
    Map<String, Object> input = header(1, new List<Object>{ ACCOUNT_ID });
    input.put('transactionKey', 'x'.repeat(500));
    RHCChangeMonitorEventEnvelope envelope = RHCChangeMonitorEventEnvelope.fromHeader(
      'AccountChangeEvent', input, new Map<String, Object>{ 'replayId' => 'r'.repeat(500), 'eventUuid' => 'u'.repeat(500) }
    );
    Assert.areEqual(80, envelope.transactionKey.length(), 'Transaction key is bounded.');
    Assert.areEqual(80, envelope.replayId.length(), 'Replay ID is bounded.');
    Assert.areEqual(80, envelope.eventUuid.length(), 'Event UUID is bounded.');
  }

  @IsTest
  static void shouldMapUnknownChangeTypeAndGapSafely() {
    Map<String, Object> input = header(1, new List<Object>());
    input.put('changeType', 'GAP_OVERFLOW');
    Assert.areEqual('GAP', RHCChangeMonitorEventEnvelope.fromHeader('AccountChangeEvent', input, null).changeType, 'GAP_* normalizes.');
    input.put('changeType', 'NEW_FUTURE_TYPE');
    input.put('recordIds', new List<Object>{ ACCOUNT_ID });
    Assert.areEqual('UNKNOWN', RHCChangeMonitorEventEnvelope.fromHeader('AccountChangeEvent', input, null).changeType, 'Unknown types fail closed.');
    input.put('changeType', null);
    Assert.areEqual('UNKNOWN', RHCChangeMonitorEventEnvelope.fromHeader('AccountChangeEvent', input, null).changeType, 'Null type fails closed.');
  }

  @IsTest
  static void shouldFallBackToNowWhenTimestampIsHostile() {
    Map<String, Object> input = header(1, new List<Object>{ ACCOUNT_ID });
    input.put('commitTimestamp', 'not-a-number');
    Datetime before = System.now().addMinutes(-1);
    Assert.isTrue(RHCChangeMonitorEventEnvelope.fromHeader('AccountChangeEvent', input, null).occurredAt >= before, 'A bad timestamp is bounded to now.');
  }

  @IsTest
  static void shouldRejectInvalidEventTypesAndInputs() {
    for (String bad : new List<String>{ null, '', '  ', 'Account', 'ChangeEventX' }) {
      try {
        RHCChangeMonitorEventParser.sourceTypeFor(bad);
        Assert.fail('Rejected: ' + bad);
      } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
        Assert.isTrue(String.isNotBlank(error.getMessage()), 'A message is provided.');
      }
    }
    Assert.areEqual('Order__c', RHCChangeMonitorEventParser.sourceTypeFor('Order__ChangeEvent'), 'Custom objects map to __c.');
    Assert.areEqual('Account', RHCChangeMonitorEventParser.sourceTypeFor('AccountChangeEvent'), 'Standard objects map by suffix.');
    try {
      RHCChangeMonitorEventParser.parse(null);
      Assert.fail('A null event must be rejected.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.areEqual('A change event is required.', error.getMessage(), 'Stable message.');
    }
    try {
      RHCChangeMonitorEventEnvelope.fromChangeEvent(new Account(Name = SENTINEL));
      Assert.fail('A business sObject must be rejected.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.isFalse(error.getMessage().contains(SENTINEL), 'No field value is echoed.');
    }
    try {
      new RHCChangeMonitorEventEnvelope(null);
      Assert.fail('Null facts must be rejected.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.areEqual('Event facts are required.', error.getMessage(), 'Stable message.');
    }
  }

  @IsTest
  static void shouldRejectSourceAndEventTypeMismatch() {
    RHCChangeMonitorEventEnvelope.Facts facts = new RHCChangeMonitorEventEnvelope.Facts();
    facts.sourceObjectApiName = 'Contact';
    facts.changeEventTypeApiName = 'AccountChangeEvent';
    facts.changeType = 'UPDATE';
    facts.recordIds = new List<String>{ ACCOUNT_ID };
    facts.transactionKey = 'tx';
    facts.sequenceNumber = 1;
    try {
      new RHCChangeMonitorEventEnvelope(facts);
      Assert.fail('A mismatch must be rejected.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.areEqual('Source object and ChangeEvent type must match exactly.', error.getMessage(), 'Stable message.');
    }
    facts.sourceObjectApiName = null;
    try {
      new RHCChangeMonitorEventEnvelope(facts);
      Assert.fail('A blank source must be rejected.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.areEqual('Source object is required.', error.getMessage(), 'Stable message.');
    }
  }

  @IsTest
  static void shouldProduceStableDelimiterSafeClaimKeys() {
    Id policyId = POLICY_ID;
    RHCChangeMonitorEventEnvelope base = RHCChangeMonitorTestDataFactory.accountEvent('UPDATE', new Set<String>{ 'Name' }, new List<String>{ ACCOUNT_ID });
    String key = RHCChangeMonitorClaimKey.create(base, policyId, ACCOUNT_ID);
    Assert.areEqual(key, RHCChangeMonitorClaimKey.create(base, policyId, ACCOUNT_ID), 'A replay yields the identical key.');
    Assert.isTrue(Pattern.matches('[0-9a-f]{64}', key), 'The key is lowercase SHA-256 hex.');
    Assert.areNotEqual(key, RHCChangeMonitorClaimKey.create(base, policyId, null), 'Gap and record claims differ.');
    Assert.areNotEqual(
      RHCChangeMonitorClaimKey.create(base, policyId, null),
      RHCChangeMonitorClaimKey.create(base, policyId, '-'),
      'A null component is distinct from a literal dash.'
    );
    Assert.areNotEqual(key, RHCChangeMonitorClaimKey.create(base, policyId, fakeId(Account.SObjectType, 9)), 'Record ID participates.');
    RHCChangeMonitorEventEnvelope other = RHCChangeMonitorTestDataFactory.accountEvent('CREATE', new Set<String>(), new List<String>{ ACCOUNT_ID });
    Assert.areNotEqual(key, RHCChangeMonitorClaimKey.create(other, policyId, ACCOUNT_ID), 'Change type participates.');
    try {
      RHCChangeMonitorClaimKey.create(null, policyId, ACCOUNT_ID);
      Assert.fail('A null envelope must be rejected.');
    } catch (IllegalArgumentException error) {
      Assert.areEqual('An event envelope and policy ID are required.', error.getMessage(), 'Stable message.');
    }
  }

  @IsTest
  static void shouldFailClosedWhenRoutingIsMisconfigured() {
    Record_Health_Check_Change_Policy__c policy = new Record_Health_Check_Change_Policy__c(
      Active__c = true, SourceObjectApiName__c = 'Account', ChangeTypes__c = null, ChangedFields__c = null
    );
    RHCChangeMonitorEventEnvelope updateEvent = RHCChangeMonitorTestDataFactory.accountEvent('UPDATE', new Set<String>{ 'Name' }, new List<String>{ ACCOUNT_ID });
    Assert.areEqual('CHANGE_TYPE_NOT_SELECTED', RHCChangeMonitorRoutingService.route(policy, updateEvent).reasonCode, 'No selected types means nothing dispatches.');
    policy.ChangeTypes__c = 'update ,, CREATE';
    Assert.isTrue(RHCChangeMonitorRoutingService.route(policy, updateEvent).shouldDispatch, 'Case and delimiters are tolerated; blank fields mean any update.');
    policy.ChangedFields__c = '\n  \nIndustry\r\n';
    Assert.areEqual('CHANGED_FIELDS_NOT_MATCHED', RHCChangeMonitorRoutingService.route(policy, updateEvent).reasonCode, 'Unmatched field filter ignores.');
    policy.Active__c = null;
    Assert.areEqual('POLICY_INACTIVE', RHCChangeMonitorRoutingService.route(policy, updateEvent).reasonCode, 'A null Active flag is inactive.');
    policy.Active__c = true;
    policy.SourceObjectApiName__c = 'Contact';
    Assert.areEqual('CORE_CONFIGURATION_INVALID', RHCChangeMonitorRoutingService.route(policy, updateEvent).reasonCode, 'A source mismatch is invalid configuration.');
    policy.SourceObjectApiName__c = 'Account';
    policy.ActiveAfter__c = System.now().addDays(1);
    Assert.areEqual('EVENT_BEFORE_ACTIVATION', RHCChangeMonitorRoutingService.route(policy, updateEvent).reasonCode, 'Events before activation are ignored.');
    for (List<Object> args : new List<List<Object>>{ new List<Object>{ null, updateEvent }, new List<Object>{ policy, null } }) {
      try {
        RHCChangeMonitorRoutingService.route((Record_Health_Check_Change_Policy__c) args[0], (RHCChangeMonitorEventEnvelope) args[1]);
        Assert.fail('Null inputs must be rejected.');
      } catch (IllegalArgumentException error) {
        Assert.areEqual('Policy and event envelope are required.', error.getMessage(), 'Stable message.');
      }
    }
  }

  @IsTest
  static void shouldClassifyDispatchFailuresNarrowly() {
    Assert.areEqual('TERMINAL', RHCChangeMonitorDispatchSupport.failureKind(null), 'Null is terminal.');
    Assert.areEqual('TERMINAL', RHCChangeMonitorDispatchSupport.failureKind(new IllegalArgumentException('boom')), 'Unknown errors are terminal.');
    Assert.areEqual('TRANSIENT', RHCChangeMonitorDispatchSupport.failureKind(new IllegalArgumentException('x UNABLE_TO_LOCK_ROW y')), 'Row locks retry.');
    List<Record_Health_Check_Change_Evaluation__c> claims = new List<Record_Health_Check_Change_Evaluation__c>{
      new Record_Health_Check_Change_Evaluation__c(AttemptCount__c = null),
      new Record_Health_Check_Change_Evaluation__c(AttemptCount__c = 3)
    };
    List<Record_Health_Check_Change_Evaluation__c> retried = RHCChangeMonitorDispatchSupport.failureUpdates(claims, 'TRANSIENT', 3);
    Assert.areEqual('PENDING', retried[0].Outcome__c, 'Under the cap retries.');
    Assert.areEqual('TRANSIENT_RETRY', retried[0].ReasonCode__c, 'Retry reason.');
    Assert.areEqual('FAILED', retried[1].Outcome__c, 'At the cap fails.');
    Assert.areEqual('RETRY_EXHAUSTED', retried[1].ReasonCode__c, 'Exhaustion reason.');
    Assert.isNotNull(retried[1].CompletedAt__c, 'Terminal failures are completed.');
    Assert.areEqual('FAILED', RHCChangeMonitorDispatchSupport.failureUpdates(claims, 'TERMINAL', 3)[0].Outcome__c, 'Terminal never retries.');
  }

  @IsTest
  static void shouldRevalidateMutablePolicyFacts() {
    Record_Health_Check_Change_Evaluation__c claim = new Record_Health_Check_Change_Evaluation__c(SourceObjectApiName__c = 'Account', OccurredAt__c = System.now());
    Assert.areEqual('POLICY_INACTIVE', RHCChangeMonitorDispatchSupport.revalidationReason(claim), 'No policy is inactive.');
    claim.Policy__r = new Record_Health_Check_Change_Policy__c(Active__c = true, SourceObjectApiName__c = 'Contact');
    claim.Policy__c = POLICY_ID;
    Assert.areEqual('CORE_CONFIGURATION_INVALID', RHCChangeMonitorDispatchSupport.revalidationReason(claim), 'Source drift is invalid.');
    claim.Policy__r.SourceObjectApiName__c = 'Account';
    claim.Policy__r.ActiveAfter__c = System.now().addDays(1);
    Assert.areEqual('EVENT_BEFORE_ACTIVATION', RHCChangeMonitorDispatchSupport.revalidationReason(claim), 'Late activation ignores old events.');
    claim.Policy__r.ActiveAfter__c = null;
    Assert.isNull(RHCChangeMonitorDispatchSupport.revalidationReason(claim), 'A valid claim dispatches.');
  }

  @IsTest
  static void shouldHandleDispatchSignalEdgesAndSummaries() {
    Integer dmlBefore = Limits.getDmlStatements();
    RHCChangeMonitorDispatchSupport.publishDispatch(null);
    RHCChangeMonitorDispatchSupport.publishDispatch(0);
    RHCChangeMonitorDispatchSupport.publishDispatch(-5);
    Assert.areEqual(dmlBefore, Limits.getDmlStatements(), 'Non-positive counts publish nothing.');
    RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = false;
    try {
      RHCChangeMonitorDispatchSupport.publishDispatch(1);
      Assert.fail('A rejected publish must throw.');
    } catch (RHCChangeMonitorDispatchSupport.DispatchSignalException error) {
      Assert.areEqual('The Change Monitor dispatch signal was rejected.', error.getMessage(), 'Stable message.');
    }
    RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = null;
    RHCChangeMonitorDispatchSupport.publishDispatch(1);
    RHCChangeMonitorDispatchSupport.ResultCounts counts = RHCChangeMonitorDispatchSupport.summarize(
      new List<RecordHealthCheckResultItem>{ null, new RecordHealthCheckResultItem() }
    );
    Assert.isTrue(counts.totalByRecord.isEmpty(), 'Null items and null record IDs are skipped.');
  }

  @IsTest
  static void shouldDeduplicateReplayedAndFlatBulkClaims() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      RHCChangeMonitorTestDataFactory.createPolicy();
      List<Account> accounts = RHCChangeMonitorTestDataFactory.createAccounts(200);
      List<String> ids = new List<String>();
      for (Account account : accounts) {
        ids.add(String.valueOf(account.Id));
      }
      RHCChangeMonitorEventEnvelope small = RHCChangeMonitorTestDataFactory.accountEvent('UPDATE', new Set<String>{ 'Name' }, new List<String>{ ids[0] });
      RHCChangeMonitorEventEnvelope big = RHCChangeMonitorTestDataFactory.accountEvent('CREATE', new Set<String>(), ids);

      Integer queries = Limits.getQueries();
      Integer dml = Limits.getDmlStatements();
      RHCChangeMonitorIntake.acceptEnvelopes(new List<RHCChangeMonitorEventEnvelope>{ small, small });
      Integer smallQueries = Limits.getQueries() - queries;
      Integer smallDml = Limits.getDmlStatements() - dml;
      Assert.areEqual(1, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c], 'A replay in one batch yields one claim.');

      queries = Limits.getQueries();
      dml = Limits.getDmlStatements();
      RHCChangeMonitorIntake.acceptEnvelopes(new List<RHCChangeMonitorEventEnvelope>{ big });
      Assert.areEqual(smallQueries, Limits.getQueries() - queries, 'SOQL count must not grow with volume.');
      Assert.areEqual(smallDml, Limits.getDmlStatements() - dml, 'DML count must not grow with volume.');
      Assert.areEqual(201, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c], 'Every record is claimed once.');
    }
  }

  @IsTest
  static void shouldCreateNoClaimsForNullEmptyOrInactivePolicies() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      RHCChangeMonitorIntake.accept(null);
      RHCChangeMonitorIntake.accept(new List<SObject>());
      RHCChangeMonitorIntake.acceptEnvelopes(null);
      policy.Active__c = false;
      update policy;
      RHCChangeMonitorIntake.acceptEnvelopes(new List<RHCChangeMonitorEventEnvelope>{
        RHCChangeMonitorTestDataFactory.accountEvent('UPDATE', new Set<String>{ 'Name' }, new List<String>{ ACCOUNT_ID })
      });
      Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c], 'Inactive policies create no claims.');
    }
  }

  @IsTest
  static void shouldRejectBusinessSObjectBatchAtomically() {
    System.runAs(RHCChangeMonitorTestDataFactory.adminUser()) {
      RHCChangeMonitorTestDataFactory.createPolicy();
      try {
        RHCChangeMonitorIntake.accept(new List<SObject>{ new Account(Name = SENTINEL) });
        Assert.fail('A non-ChangeEvent batch must be rejected.');
      } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
        Assert.isFalse(error.getMessage().contains(SENTINEL), 'No payload value is echoed.');
      }
      Assert.areEqual(0, [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c], 'Nothing is persisted.');
    }
  }
}
