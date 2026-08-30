@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCChangeMonitorEventEnvelopeTest {
  @IsTest
  static void shouldRejectBusinessSObjectWhenPassedToAdapterBoundary() {
    Test.startTest();
    try {
      RHCChangeMonitorEventEnvelope.fromChangeEvent(new Account(Name = 'Not an event'));
      Assert.fail('A durable business record must not be accepted as a ChangeEvent.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.isTrue(
        error.getMessage().contains('ChangeEvent'),
        'Failure should identify the event boundary.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectMalformedRecordIdWhenEnvelopeConstructed() {
    RHCChangeMonitorEventEnvelope.Facts facts = accountFacts(
      'UPDATE',
      new List<String>{ 'not-an-id' }
    );
    Test.startTest();
    try {
      new RHCChangeMonitorEventEnvelope(facts);
      Assert.fail('Malformed source identity must not be accepted.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.isTrue(
        error.getMessage().contains('malformed'),
        'Failure should identify malformed identity.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectMissingStableIdentityWhenEnvelopeConstructed() {
    Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
    RHCChangeMonitorEventEnvelope.Facts facts = accountFacts(
      'CREATE',
      new List<String>{ String.valueOf(account.Id) }
    );
    facts.transactionKey = null;
    facts.sequenceNumber = null;
    Test.startTest();
    try {
      new RHCChangeMonitorEventEnvelope(facts);
      Assert.fail('A claim without stable event identity must not be accepted.');
    } catch (RHCChangeMonitorEventEnvelope.InvalidEventException error) {
      Assert.isTrue(
        error.getMessage().contains('transaction'),
        'Failure should identify stable identity.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldNormalizeApprovedFactsWhenHeaderIsValid() {
    Account account = RHCChangeMonitorTestDataFactory.createAccounts(1)[0];
    Map<String, Object> header = new Map<String, Object>{
      'entityName' => 'Account',
      'changeType' => 'UPDATE',
      'changedFields' => new List<Object>{ 'Name', 'Industry' },
      'recordIds' => new List<Object>{ String.valueOf(account.Id) },
      'transactionKey' => 'stable-transaction',
      'sequenceNumber' => 9,
      'commitTimestamp' => System.now().getTime()
    };

    Test.startTest();
    RHCChangeMonitorEventEnvelope eventEnvelope = RHCChangeMonitorEventEnvelope.fromHeader(
      'AccountChangeEvent',
      header,
      new Map<String, Object>{
        'replayId' => 'opaque-replay',
        'eventUuid' => 'event-uuid'
      }
    );
    Test.stopTest();

    Assert.areEqual('Account', eventEnvelope.sourceObjectApiName, 'Header entity should remain exact.');
    Assert.areEqual('UPDATE', eventEnvelope.changeType, 'Supported change type should remain explicit.');
    Assert.areEqual(
      new Set<String>{ 'Name', 'Industry' },
      eventEnvelope.changedFields,
      'Only field identities should be copied.'
    );
    Assert.areEqual(
      Long.valueOf('9'),
      eventEnvelope.sequenceNumber,
      'Stable sequence should be retained.'
    );
    Assert.areEqual(
      'opaque-replay',
      eventEnvelope.replayId,
      'Replay ID should remain opaque evidence.'
    );
  }

  private static RHCChangeMonitorEventEnvelope.Facts accountFacts(
    String changeType,
    List<String> recordIds
  ) {
    RHCChangeMonitorEventEnvelope.Facts facts = new RHCChangeMonitorEventEnvelope.Facts();
    facts.sourceObjectApiName = 'Account';
    facts.changeEventTypeApiName = 'AccountChangeEvent';
    facts.changeType = changeType;
    facts.changedFields = new Set<String>{ 'Name' };
    facts.recordIds = recordIds;
    facts.transactionKey = 'transaction';
    facts.sequenceNumber = 1;
    facts.occurredAt = System.now();
    return facts;
  }
}
