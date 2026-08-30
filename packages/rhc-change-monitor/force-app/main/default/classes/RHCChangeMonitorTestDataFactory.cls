/** Creates isolated Change Monitor contract fixtures. */
@IsTest
public class RHCChangeMonitorTestDataFactory {
  /** Creates a dedicated user and assigns the packaged Change Monitor Admin permission set. */
  public static void createAdminUser() {
    PermissionSet permissionSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'RHC_Change_Monitor_Admin'
      LIMIT 1
    ];
    User userRecord = new User(
      Alias = 'rhcchg',
      Email = 'rhc-change-monitor-test@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Change Monitor Test Admin',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Chicago',
      Username = 'rhc-change-monitor-' + UserInfo.getOrganizationId() + '-' +
        Crypto.getRandomLong() + '@example.invalid'
    );
    insert userRecord;
    insert new PermissionSetAssignment(
      AssigneeId = userRecord.Id,
      PermissionSetId = permissionSet.Id
    );
  }

  /**
   * Returns the permissioned user created by the test setup transaction.
   * @return Dedicated Change Monitor test administrator.
   */
  public static User adminUser() {
    return [SELECT Id FROM User WHERE Alias = 'rhcchg' LIMIT 1];
  }

  /**
   * Creates and inserts one active Account policy.
   * @return Inserted Account change policy.
   */
  public static Record_Health_Check_Change_Policy__c createPolicy() {
    Record_Health_Check_Change_Policy__c policy = new Record_Health_Check_Change_Policy__c(
      DisplayName__c = 'Account change contract',
      Active__c = true,
      SourceObjectApiName__c = 'Account',
      SelectionType__c = 'CHECK_SET',
      QualifiedApiName__c = 'Account_Data_Quality',
      ChangeTypes__c = 'CREATE;UPDATE;UNDELETE',
      ChangedFields__c = 'Name\nIndustry',
      EventPublication__c = 'ACTIONABLE',
      ActiveAfter__c = System.now().addDays(-1)
    );
    insert policy;
    return policy;
  }

  /**
   * Creates and inserts Account records.
   * @param countValue Number of Account records to insert.
   * @return Inserted Account records.
   */
  public static List<Account> createAccounts(Integer countValue) {
    List<Account> accounts = new List<Account>();
    for (Integer indexValue = 0; indexValue < countValue; indexValue++) {
      accounts.add(new Account(Name = 'Change Monitor ' + indexValue));
    }
    insert accounts;
    return accounts;
  }

  /**
   * Creates one validated Account event envelope.
   * @param changeType Raw CDC change type.
   * @param changedFields Changed field API names.
   * @param recordIds Source record IDs.
   * @return Validated Account event envelope.
   */
  public static RHCChangeMonitorEventEnvelope accountEvent(
    String changeType,
    Set<String> changedFields,
    List<String> recordIds
  ) {
    RHCChangeMonitorEventEnvelope.Facts facts = new RHCChangeMonitorEventEnvelope.Facts();
    facts.sourceObjectApiName = 'Account';
    facts.changeEventTypeApiName = 'AccountChangeEvent';
    facts.changeType = changeType;
    facts.changedFields = changedFields;
    facts.recordIds = recordIds;
    facts.transactionKey = '00000000-0000-0000-0000-000000000001';
    facts.sequenceNumber = 1;
    facts.replayId = 'opaque-replay-evidence';
    facts.eventUuid = '00000000-0000-0000-0000-000000000002';
    facts.occurredAt = System.now();
    return new RHCChangeMonitorEventEnvelope(facts);
  }

  /**
   * Inserts one pending claim for dispatcher revalidation tests.
   * @param policy Owning Account change policy.
   * @param account Source Account.
   * @return Inserted pending evaluation claim.
   */
  public static Record_Health_Check_Change_Evaluation__c createPendingClaim(
    Record_Health_Check_Change_Policy__c policy,
    Account account
  ) {
    RHCChangeMonitorEventEnvelope envelope = accountEvent(
      'UPDATE',
      new Set<String>{ 'Name' },
      new List<String>{ String.valueOf(account.Id) }
    );
    Record_Health_Check_Change_Evaluation__c claim =
      new Record_Health_Check_Change_Evaluation__c(
        Policy__c = policy.Id,
        ClaimKey__c = RHCChangeMonitorClaimKey.create(
          envelope,
          policy.Id,
          String.valueOf(account.Id)
        ),
        SourceObjectApiName__c = 'Account',
        RecordId__c = String.valueOf(account.Id),
        ChangeType__c = 'UPDATE',
        TransactionKey__c = envelope.transactionKey,
        SequenceNumber__c = 1,
        ReplayId__c = envelope.replayId,
        OccurredAt__c = System.now(),
        AcceptedAt__c = System.now(),
        Outcome__c = 'PENDING',
        ReasonCode__c = 'ACCEPTED',
        AttemptCount__c = 0,
        ResultCount__c = 0,
        ActionableCount__c = 0
      );
    insert claim;
    return claim;
  }

  /**
   * Creates a minimal core response for dispatcher result-count contract tests.
   * @param statusByRecordId Core status keyed by source record ID.
   * @return Minimal core response with one evaluation per supplied record.
   */
  public static RecordHealthCheckResponse responseFor(Map<Id, String> statusByRecordId) {
    RecordHealthCheckResponse response = new RecordHealthCheckResponse();
    for (Id recordId : statusByRecordId.keySet()) {
      RecordHealthCheckEvaluationResult evaluation = new RecordHealthCheckEvaluationResult();
      evaluation.recordId = recordId;
      evaluation.checkQualifiedApiName = 'Account_Name';
      evaluation.status = statusByRecordId.get(recordId);
      RecordHealthCheckResultItem item = new RecordHealthCheckResultItem();
      item.evaluation = evaluation;
      response.results.add(item);
    }
    return response;
  }
}
