/**
 * Red and war scenarios for Run Manager's destructive and replayable paths: retention window
 * boundaries, cancellation state integrity, supplied-ID replay, bulk volume, and error contracts.
 */
@IsTest
private class RHCRunManagerAdversarialTest {
  private static final Integer RETENTION_DAYS = 30;

  @TestSetup
  static void setupUsers() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  private static Record_Health_Check_Batch_Run__c batch(
    Id definitionId,
    String status,
    Datetime completedAt
  ) {
    Record_Health_Check_Batch_Run__c row = new Record_Health_Check_Batch_Run__c(
      RunDefinition__c = definitionId,
      Source__c = 'RUN_NOW',
      Status__c = status,
      StartedAt__c = System.now().addDays(-400),
      CompletedAt__c = completedAt
    );
    insert row;
    return row;
  }

  private static void saveRetention(Integer days) {
    RHCRunManagerRetentionService.retentionPermissionOverride = true;
    RHCRunManagerRetentionService.saveSettings(days);
  }

  private static Set<Id> batchRunIdsRemaining() {
    Set<Id> remaining = new Set<Id>();
    for (
      Record_Health_Check_Batch_Run__c row : [
        SELECT Id
        FROM Record_Health_Check_Batch_Run__c
      ]
    ) {
      remaining.add(row.Id);
    }
    return remaining;
  }

  // ---------------------------------------------------------------- retention boundaries

  @IsTest
  static void shouldDeleteOnlyBatchRunsStrictlyOlderThanTheRetentionBoundary() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      saveRetention(RETENTION_DAYS);
      Datetime boundary = Datetime.now().addDays(-RETENTION_DAYS);
      // One second older than the boundary: eligible.
      Id older = batch(definition.Id, 'COMPLETED', boundary.addSeconds(-1)).Id;
      // Exactly at the boundary: the filter is strict `<`, so it must survive.
      Id exactly = batch(definition.Id, 'COMPLETED', boundary.addSeconds(1)).Id;
      // One day newer: clearly inside the retention window.
      Id newer = batch(definition.Id, 'COMPLETED', boundary.addDays(1)).Id;

      Test.startTest();
      RHCRunManagerRetentionService.PurgeOutcome outcome = RHCRunManagerRetentionService.purge();
      Test.stopTest();

      Set<Id> remaining = batchRunIdsRemaining();
      Assert.isFalse(
        remaining.contains(older),
        'A Batch Run older than the retention window must be deleted.'
      );
      Assert.isTrue(
        remaining.contains(exactly),
        'A Batch Run inside the window by one second must survive.'
      );
      Assert.isTrue(
        remaining.contains(newer),
        'A Batch Run well inside the window must survive.'
      );
      Assert.areEqual(
        1,
        outcome.batchRunsDeleted,
        'Exactly one Batch Run was eligible.'
      );
      Assert.areEqual(
        1,
        outcome.totalDeleted,
        'The reported total must match what was actually removed.'
      );
    }
  }

  @IsTest
  static void shouldNeverDeleteNonTerminalBatchRunsRegardlessOfAge() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      saveRetention(1);
      Datetime ancient = Datetime.now().addDays(-3000);
      Id queued = batch(definition.Id, 'QUEUED', ancient).Id;
      Id processing = batch(definition.Id, 'PROCESSING', ancient).Id;
      Id completed = batch(definition.Id, 'COMPLETED', ancient).Id;

      Test.startTest();
      RHCRunManagerRetentionService.PurgeOutcome outcome = RHCRunManagerRetentionService.purge();
      Test.stopTest();

      Set<Id> remaining = batchRunIdsRemaining();
      Assert.isTrue(
        remaining.contains(queued),
        'A queued Batch Run is live work and must never be purged.'
      );
      Assert.isTrue(
        remaining.contains(processing),
        'A processing Batch Run is live work and must never be purged.'
      );
      Assert.isFalse(
        remaining.contains(completed),
        'A terminal, aged Batch Run is the only eligible row.'
      );
      Assert.areEqual(
        1,
        outcome.totalDeleted,
        'Only the terminal aged Batch Run may be removed.'
      );
    }
  }

  @IsTest
  static void shouldRefusePurgeUntilRetentionIsExplicitlySaved() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerRetentionService.retentionPermissionOverride = true;
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      Id aged = batch(definition.Id, 'COMPLETED', Datetime.now().addDays(-3000))
        .Id;
      String message;
      Test.startTest();
      try {
        RHCRunManagerRetentionService.purge();
        Assert.fail('Purging without saved settings must be refused.');
      } catch (AuraHandledException error) {
        message = error.getMessage();
      }
      Test.stopTest();
      Assert.isTrue(
        message.contains('Save Run Manager retention settings'),
        'An unconfigured purge must fail closed with admin guidance: ' + message
      );
      Assert.isTrue(
        batchRunIdsRemaining().contains(aged),
        'A refused purge must delete nothing at all.'
      );
    }
  }

  @IsTest
  static void shouldDenyPurgeAndSaveWithoutTheRetentionPermission() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      saveRetention(RETENTION_DAYS);
      Id aged = batch(definition.Id, 'COMPLETED', Datetime.now().addDays(-3000))
        .Id;
      RHCRunManagerRetentionService.retentionPermissionOverride = false;
      Integer dmlBefore;
      Test.startTest();
      dmlBefore = Limits.getDmlStatements();
      try {
        RHCRunManagerRetentionService.purge();
        Assert.fail('An unpermitted purge must be refused.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('permission'),
          'The denial must name the missing permission: ' + error.getMessage()
        );
        Assert.areEqual(
          dmlBefore,
          Limits.getDmlStatements(),
          'A denied purge must perform no DML.'
        );
      }
      Test.stopTest();
      Assert.isTrue(
        batchRunIdsRemaining().contains(aged),
        'A denied purge must leave every record in place.'
      );
      Assert.isFalse(
        RHCRunManagerRetentionService.getSettings().canManage,
        'An unpermitted user must not be told they can manage retention.'
      );
    }
  }

  @IsTest
  static void shouldRejectAbsurdRetentionWindowsAtBothEnds() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerRetentionService.retentionPermissionOverride = true;
      Map<String, Integer> rejected = new Map<String, Integer>{
        'null' => null,
        'zero' => 0,
        'negative' => -1,
        'absurdly large' => 100000
      };
      Test.startTest();
      for (String label : rejected.keySet()) {
        try {
          RHCRunManagerRetentionService.saveSettings(rejected.get(label));
          Assert.fail('Expected a refusal for a ' + label + ' retention window.');
        } catch (AuraHandledException error) {
          Assert.isTrue(
            error.getMessage().contains('1 through 3650'),
            'The refusal must state the supported range for ' + label
          );
        }
      }
      // The documented boundaries themselves must remain accepted.
      Assert.areEqual(
        1,
        RHCRunManagerRetentionService.saveSettings(1).retentionDays,
        'One day is the documented minimum.'
      );
      Assert.areEqual(
        3650,
        RHCRunManagerRetentionService.saveSettings(3650).retentionDays,
        'A 3650-day window is the documented maximum.'
      );
      Test.stopTest();
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Record_Health_Check_Run_Setting__c],
        'Retention settings must remain a singleton across saves.'
      );
    }
  }

  // ---------------------------------------------------------------- cancellation integrity

  @IsTest
  static void shouldRefuseCancellingAnAlreadyTerminalBatchRun() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      Record_Health_Check_Batch_Run__c completed = batch(
        definition.Id,
        'COMPLETED',
        Datetime.now()
      );
      Test.startTest();
      try {
        RHCRunManagerCancellationService.cancel(completed.Id);
        Assert.fail('A completed Batch Run must not be cancellable.');
      } catch (RHCRunManagerCancellationService.CancellationException error) {
        Assert.isTrue(
          error.getMessage().contains('queued or processing'),
          'The refusal must explain which states are cancellable: ' +
          error.getMessage()
        );
      }
      Test.stopTest();
      Assert.areEqual(
        'COMPLETED',
        [
          SELECT Status__c
          FROM Record_Health_Check_Batch_Run__c
          WHERE Id = :completed.Id
        ]
        .Status__c,
        'A refused cancellation must not corrupt the terminal status.'
      );
    }
  }

  @IsTest
  static void shouldTreatRepeatedCancellationAsIdempotentRatherThanCorrupting() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      Record_Health_Check_Batch_Run__c queued = batch(
        definition.Id,
        'QUEUED',
        null
      );
      Test.startTest();
      Id firstResult = RHCRunManagerCancellationService.cancel(queued.Id);
      Record_Health_Check_Batch_Run__c afterFirst = [
        SELECT Status__c, CompletedAt__c
        FROM Record_Health_Check_Batch_Run__c
        WHERE Id = :queued.Id
      ];
      try {
        RHCRunManagerCancellationService.cancel(queued.Id);
        Assert.fail('A second cancellation must be refused, not reapplied.');
      } catch (RHCRunManagerCancellationService.CancellationException error) {
        Assert.isTrue(
          error.getMessage().contains('queued or processing'),
          'The second attempt must be refused for the same documented reason.'
        );
      }
      Test.stopTest();
      Record_Health_Check_Batch_Run__c afterSecond = [
        SELECT Status__c, CompletedAt__c
        FROM Record_Health_Check_Batch_Run__c
        WHERE Id = :queued.Id
      ];
      Assert.areEqual(queued.Id, firstResult, 'Cancellation returns its own id.');
      Assert.areEqual(
        'CANCELLED',
        afterSecond.Status__c,
        'The run must stay cancelled.'
      );
      Assert.areEqual(
        afterFirst.CompletedAt__c,
        afterSecond.CompletedAt__c,
        'A replayed cancellation must not move the completion timestamp.'
      );
    }
  }

  @IsTest
  static void shouldNotResurrectACancelledBatchRun() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      Record_Health_Check_Batch_Run__c queued = batch(
        definition.Id,
        'QUEUED',
        null
      );
      Test.startTest();
      RHCRunManagerCancellationService.cancel(queued.Id);
      try {
        RHCRunManagerCancellationService.cancel(queued.Id);
      } catch (RHCRunManagerCancellationService.CancellationException ignored) {
        // Expected: asserted in the idempotency test above.
      }
      Test.stopTest();
      Assert.areEqual(
        1,
        [
          SELECT COUNT()
          FROM Record_Health_Check_Batch_Run__c
          WHERE Status__c = 'CANCELLED'
        ],
        'Cancellation must not create additional Batch Runs.'
      );
    }
  }

  @IsTest
  static void shouldRefuseCancellingABatchRunTheUserCannotSee() {
    Record_Health_Check_Run_Definition__c definition;
    Record_Health_Check_Batch_Run__c queued;
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      queued = batch(definition.Id, 'QUEUED', null);
    }
    User restricted = restrictedUser('rmcancel');
    String message;
    Test.startTest();
    System.runAs(restricted) {
      try {
        RHCRunManagerCancellationService.cancel(queued.Id);
        Assert.fail('A user without access must not cancel a Batch Run.');
      } catch (RHCRunManagerCancellationService.CancellationException error) {
        message = error.getMessage();
      }
    }
    Test.stopTest();
    Assert.isTrue(
      String.isNotBlank(message),
      'The denial must carry a typed, admin-facing message.'
    );
    Assert.isFalse(
      message.contains(String.valueOf(queued.Id)),
      'The denial must not echo the record id back to the caller.'
    );
    Assert.areEqual(
      'QUEUED',
      [
        SELECT Status__c
        FROM Record_Health_Check_Batch_Run__c
        WHERE Id = :queued.Id
      ]
      .Status__c,
      'A denied cancellation must leave the Batch Run untouched.'
    );
  }

  @IsTest
  static void shouldRejectANullBatchRunIdentifier() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Test.startTest();
      try {
        RHCRunManagerCancellationService.cancel(null);
        Assert.fail('A null Batch Run id must be refused.');
      } catch (RHCRunManagerCancellationService.CancellationException error) {
        Assert.areEqual(
          'Choose a Batch Run.',
          error.getMessage(),
          'The null-input refusal must be the stable documented message.'
        );
      }
      Test.stopTest();
    }
  }

  // ---------------------------------------------------------------- supplied-ID replay and volume

  @IsTest
  static void shouldStageSuppliedIdsIdempotentlyWhenTheSameRequestIsReplayed() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerSubmitIdsAction.suppressCoalescer = true;
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      List<Account> accounts = RHCRunManagerTestDataFactory.createAccounts(25);
      List<Id> targetIds = new List<Id>();
      for (Account account : accounts) {
        targetIds.add(account.Id);
      }
      Test.startTest();
      List<RHCRunManagerSubmitIdsAction.Response> first = RHCRunManagerSubmitIdsAction.submit(
        new List<RHCRunManagerSubmitIdsAction.Request>{
          submitRequest(definition.Id, targetIds)
        }
      );
      Integer afterFirst = [SELECT COUNT() FROM Record_Health_Check_Run_Request__c];
      List<RHCRunManagerSubmitIdsAction.Response> second = RHCRunManagerSubmitIdsAction.submit(
        new List<RHCRunManagerSubmitIdsAction.Request>{
          submitRequest(definition.Id, targetIds)
        }
      );
      Integer afterSecond = [SELECT COUNT() FROM Record_Health_Check_Run_Request__c];
      Test.stopTest();
      Assert.isTrue(first[0].isSuccess, 'The first submission must be accepted.');
      Assert.isTrue(
        second[0].isSuccess,
        'A replayed submission must be accepted rather than erroring.'
      );
      Assert.areEqual(
        25,
        afterFirst,
        'Each supplied id must stage exactly one request row.'
      );
      Assert.areEqual(
        afterFirst,
        afterSecond,
        'Replaying the same ids must not double-stage work.'
      );
    }
  }

  @IsTest
  static void shouldKeepStagingCostFlatFrom200To251SuppliedIds() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerSubmitIdsAction.suppressCoalescer = true;
      Record_Health_Check_Run_Definition__c definitionSmall = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      List<Account> accounts = RHCRunManagerTestDataFactory.createAccounts(251);
      List<Id> small = new List<Id>();
      List<Id> large = new List<Id>();
      for (Integer index = 0; index < accounts.size(); index++) {
        if (index < 200) {
          small.add(accounts[index].Id);
        }
        large.add(accounts[index].Id);
      }
      Test.startTest();
      Integer queriesBefore = Limits.getQueries();
      Integer dmlBefore = Limits.getDmlStatements();
      RHCRunManagerSubmitIdsAction.submit(
        new List<RHCRunManagerSubmitIdsAction.Request>{
          submitRequest(definitionSmall.Id, small)
        }
      );
      Integer smallQueries = Limits.getQueries() - queriesBefore;
      Integer smallDml = Limits.getDmlStatements() - dmlBefore;

      queriesBefore = Limits.getQueries();
      dmlBefore = Limits.getDmlStatements();
      RHCRunManagerSubmitIdsAction.submit(
        new List<RHCRunManagerSubmitIdsAction.Request>{
          submitRequest(definitionSmall.Id, large)
        }
      );
      Integer largeQueries = Limits.getQueries() - queriesBefore;
      Integer largeDml = Limits.getDmlStatements() - dmlBefore;
      Test.stopTest();

      Assert.areEqual(
        smallQueries,
        largeQueries,
        'SOQL count must not grow from 200 to 251 supplied ids.'
      );
      Assert.areEqual(
        smallDml,
        largeDml,
        'DML count must not grow from 200 to 251 supplied ids.'
      );
      Assert.areEqual(
        251,
        [SELECT COUNT() FROM Record_Health_Check_Run_Request__c],
        'All 251 distinct ids must be staged exactly once.'
      );
    }
  }

  @IsTest
  static void shouldRejectSubmissionsAgainstAnInactiveOrUnknownDefinition() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      RHCRunManagerSubmitIdsAction.suppressCoalescer = true;
      Record_Health_Check_Run_Definition__c inactive = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      inactive.Active__c = false;
      update inactive;
      Id targetId = RHCRunManagerTestDataFactory.createAccounts(1)[0].Id;
      Test.startTest();
      List<RHCRunManagerSubmitIdsAction.Response> responses = RHCRunManagerSubmitIdsAction.submit(
        new List<RHCRunManagerSubmitIdsAction.Request>{
          submitRequest(inactive.Id, new List<Id>{ targetId })
        }
      );
      Test.stopTest();
      Assert.isFalse(
        responses[0].isSuccess,
        'An inactive Run Definition must not accept work.'
      );
      Assert.isTrue(
        String.isNotBlank(responses[0].errorType),
        'The rejection must carry a stable machine-readable error type.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Record_Health_Check_Run_Request__c],
        'A rejected submission must stage nothing.'
      );
    }
  }

  @IsTest
  static void shouldReturnEmptyForNullRequestListRatherThanThrowing() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Test.startTest();
      List<RHCRunManagerSubmitIdsAction.Response> responses = RHCRunManagerSubmitIdsAction.submit(
        null
      );
      Test.stopTest();
      Assert.areEqual(
        0,
        responses.size(),
        'A null Flow input must yield no responses and no work.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Record_Health_Check_Run_Request__c],
        'A null input must stage nothing.'
      );
    }
  }

  // ---------------------------------------------------------------- uninstall scope

  @IsTest
  static void shouldAbortOnlyRunManagerOwnedScheduledJobs() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      String foreignJobName = 'Unrelated Tenant Job ' + Crypto.getRandomLong();
      Id foreignJobId = System.schedule(
        foreignJobName,
        '0 0 23 * * ?',
        new ForeignSchedulable()
      );
      Test.startTest();
      RHCRunManagerUninstallHandler.abortOwnedJobs();
      Test.stopTest();
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM CronTrigger WHERE Id = :foreignJobId],
        'Uninstall cleanup must never abort a job this package does not own.'
      );
    }
  }

  // ---------------------------------------------------------------- error contracts

  @IsTest
  static void shouldPreserveAdminFacingMessagesAcrossTheCommandFacade() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Test.startTest();
      String definitionMessage = messageFrom('saveDefinition');
      String scheduleMessage = messageFrom('saveSchedule');
      String pauseMessage = messageFrom('pauseSchedule');
      Test.stopTest();
      Assert.areEqual(
        'Run Definition input is required.',
        definitionMessage,
        'A null definition must surface its own admin-facing message, not a generic one.'
      );
      Assert.areEqual(
        'Schedule input is required.',
        scheduleMessage,
        'A null schedule must surface its own admin-facing message.'
      );
      Assert.areEqual(
        'Choose a schedule.',
        pauseMessage,
        'A null schedule id must surface its own admin-facing message.'
      );
    }
  }

  @IsTest
  static void shouldNotLeakRecordOrOrgIdentifiersInCommandFacadeErrors() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'SUPPLIED_IDS',
        'FAIL'
      );
      String message;
      Test.startTest();
      try {
        RHCRunManagerAdminCommandService.runNow(definition.Id);
      } catch (AuraHandledException error) {
        message = error.getMessage();
      }
      Test.stopTest();
      if (String.isNotBlank(message)) {
        Assert.isFalse(
          message.contains(String.valueOf(definition.Id)),
          'An error must not echo the record id: ' + message
        );
        Assert.isFalse(
          message.contains(UserInfo.getOrganizationId()),
          'An error must not echo the org id: ' + message
        );
        Assert.isFalse(
          message.contains(UserInfo.getUserName()),
          'An error must not echo the username: ' + message
        );
        Assert.isFalse(
          message.containsIgnoreCase('Class.RHC'),
          'An error must not carry an Apex stack trace: ' + message
        );
      }
    }
  }

  // ---------------------------------------------------------------- helpers

  private static String messageFrom(String command) {
    try {
      if (command == 'saveDefinition') {
        RHCRunManagerAdminCommandService.saveDefinition(null);
      } else if (command == 'saveSchedule') {
        RHCRunManagerAdminCommandService.saveSchedule(null);
      } else {
        RHCRunManagerAdminCommandService.pauseSchedule(null);
      }
      Assert.fail('Expected a handled refusal for ' + command);
      return null;
    } catch (AuraHandledException error) {
      return error.getMessage();
    }
  }

  private static RHCRunManagerSubmitIdsAction.Request submitRequest(
    Id definitionId,
    List<Id> targetIds
  ) {
    RHCRunManagerSubmitIdsAction.Request request = new RHCRunManagerSubmitIdsAction.Request();
    request.runDefinitionId = definitionId;
    request.targetRecordIds = targetIds;
    return request;
  }

  private static User restrictedUser(String alias) {
    List<Profile> profiles = [
      SELECT Id
      FROM Profile
      WHERE Name IN ('Minimum Access - Salesforce', 'Standard User')
      ORDER BY Name
      LIMIT 1
    ];
    User restricted = new User(
      Alias = alias,
      Email = alias + '@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Denied ' + alias,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id,
      TimeZoneSidKey = 'America/Chicago',
      Username = alias +
        '-denied-' +
        UserInfo.getOrganizationId() +
        '-' +
        Crypto.getRandomLong() +
        '@example.invalid'
    );
    insert restricted;
    return restricted;
  }

  /** Stands in for a tenant job the package does not own. */
  private class ForeignSchedulable implements Schedulable {
    public void execute(SchedulableContext context) {
      // Intentionally empty: the test only needs the job to exist.
    }
  }
}
