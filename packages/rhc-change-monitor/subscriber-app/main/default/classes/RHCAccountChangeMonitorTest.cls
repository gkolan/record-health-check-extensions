/**
 * Verifies the subscriber-owned no-namespace Account CDC adapter.
 */
@IsTest
private class RHCAccountChangeMonitorTest {
  private static final String USER_ALIAS = 'rhccdc';

  @TestSetup
  static void createPermissionedUser() {
    User userRecord = new User(
      Alias = USER_ALIAS,
      Email = 'rhc-cdc-adapter@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC CDC Adapter Test',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Chicago',
      Username = 'rhc-cdc-adapter-' + UserInfo.getOrganizationId() + '-' + Crypto.getRandomLong() + '@example.invalid'
    );
    insert userRecord;

    Map<String, Id> permissionSetIdByName = new Map<String, Id>();
    for (PermissionSet permissionSet : [
      SELECT Id, Name
      FROM PermissionSet
      WHERE Name IN ('Record_Health_Check_Admin', 'RHC_Change_Monitor_Admin')
    ]) {
      permissionSetIdByName.put(permissionSet.Name, permissionSet.Id);
    }
    Assert.areEqual(2, permissionSetIdByName.size(), 'Both administrator permission sets must exist.');
    insert new List<PermissionSetAssignment>{
      new PermissionSetAssignment(
        AssigneeId = userRecord.Id,
        PermissionSetId = permissionSetIdByName.get('Record_Health_Check_Admin')
      ),
      new PermissionSetAssignment(
        AssigneeId = userRecord.Id,
        PermissionSetId = permissionSetIdByName.get('RHC_Change_Monitor_Admin')
      )
    };

    System.runAs(userRecord) {
      List<Account> lifecycleAccounts = new List<Account>{
        new Account(Name = 'RHC CDC matching baseline'),
        new Account(Name = 'RHC CDC nonmatching baseline'),
        new Account(Name = 'RHC CDC delete baseline'),
        new Account(Name = 'RHC CDC undelete baseline')
      };
      insert lifecycleAccounts;
      delete lifecycleAccounts[3];
    }
  }

  @IsTest
  static void shouldClaimCreateWhenAccountIsInserted() {
    System.runAs(adapterUser()) {
      prepareCdcScenario();
      createPolicy('CREATE', null);

      Test.startTest();
      Account account = new Account(Name = 'RHC CDC create');
      insert account;
      Test.getEventBus().deliver();
      Test.stopTest();

      Record_Health_Check_Change_Evaluation__c claim = claimFor(account.Id);
      Assert.areEqual('CREATE', claim.ChangeType__c, 'CREATE must cross the concrete adapter.');
      Assert.areEqual(String.valueOf(account.Id), claim.RecordId__c, 'The durable source ID must be retained.');
    }
  }

  @IsTest
  static void shouldClaimMatchingUpdateWhenSelectedFieldChanges() {
    System.runAs(adapterUser()) {
      Account account = accountNamed('RHC CDC matching baseline', false);
      prepareCdcScenario();
      createPolicy('UPDATE', 'Name');

      Test.startTest();
      account.Name = 'RHC CDC update after';
      update account;
      Test.getEventBus().deliver();
      Test.stopTest();

      Record_Health_Check_Change_Evaluation__c claim = claimFor(account.Id);
      Assert.areEqual('UPDATE', claim.ChangeType__c, 'UPDATE must cross the concrete adapter.');
      Assert.areNotEqual('CHANGED_FIELDS_NOT_MATCHED', claim.ReasonCode__c, 'A selected Name change must dispatch.');
    }
  }

  @IsTest
  static void shouldIgnoreNonmatchingUpdateWhenSelectedFieldDoesNotChange() {
    System.runAs(adapterUser()) {
      Account account = accountNamed('RHC CDC nonmatching baseline', false);
      prepareCdcScenario();
      createPolicy('UPDATE', 'Name');

      Test.startTest();
      account.Phone = '312-555-0100';
      update account;
      Test.getEventBus().deliver();
      Test.stopTest();

      Record_Health_Check_Change_Evaluation__c claim = claimFor(account.Id);
      Assert.areEqual('IGNORED', claim.Outcome__c, 'A nonmatching update must be terminal.');
      Assert.areEqual('CHANGED_FIELDS_NOT_MATCHED', claim.ReasonCode__c, 'The bounded reason must explain routing.');
    }
  }

  @IsTest
  static void shouldIgnoreDeleteWhenAccountIsDeleted() {
    System.runAs(adapterUser()) {
      Account account = accountNamed('RHC CDC delete baseline', false);
      prepareCdcScenario();
      createPolicy('DELETE', null);

      Test.startTest();
      delete account;
      Test.getEventBus().deliver();
      Test.stopTest();

      Record_Health_Check_Change_Evaluation__c claim = claimFor(account.Id);
      Assert.areEqual('DELETE', claim.ChangeType__c, 'DELETE must cross the concrete adapter.');
      Assert.areEqual('IGNORED', claim.Outcome__c, 'Deleted records cannot be evaluated durably.');
      Assert.areEqual('RECORD_DELETED', claim.ReasonCode__c, 'The bounded reason must explain deletion.');
    }
  }

  @IsTest
  static void shouldClaimUndeleteWhenAccountIsRestored() {
    System.runAs(adapterUser()) {
      Account account = accountNamed('RHC CDC undelete baseline', true);
      prepareCdcScenario();
      createPolicy('UNDELETE', null);

      Test.startTest();
      undelete account;
      Test.getEventBus().deliver();
      Test.stopTest();

      Record_Health_Check_Change_Evaluation__c claim = claimFor(account.Id);
      Assert.areEqual('UNDELETE', claim.ChangeType__c, 'UNDELETE must cross the concrete adapter.');
    }
  }

  @IsTest
  static void shouldClaimEveryRecordWhen251AccountsAreInserted() {
    System.runAs(adapterUser()) {
      prepareCdcScenario();
      createPolicy('DELETE', null);
      List<Account> accounts = new List<Account>();
      for (Integer indexValue = 0; indexValue < 251; indexValue++) {
        accounts.add(new Account(Name = 'RHC CDC bulk ' + indexValue));
      }
      Test.startTest();
      insert accounts;
      Test.getEventBus().deliver();
      Test.stopTest();

      Integer claimCount = [
        SELECT COUNT()
        FROM Record_Health_Check_Change_Evaluation__c
        WHERE ChangeType__c = 'CREATE'
      ];
      Assert.areEqual(251, claimCount, 'Every header record ID must receive one durable claim.');
    }
  }

  private static User adapterUser() {
    return [SELECT Id FROM User WHERE Alias = :USER_ALIAS LIMIT 1];
  }

  private static void prepareCdcScenario() {
    Test.enableChangeDataCapture();
    Test.getEventBus().deliver();
    List<Record_Health_Check_Change_Evaluation__c> setupClaims = [
      SELECT Id
      FROM Record_Health_Check_Change_Evaluation__c
      WHERE CreatedDate = TODAY
      LIMIT 10000
    ];
    if (!setupClaims.isEmpty()) {
      delete setupClaims;
    }
  }

  private static Account accountNamed(String accountName, Boolean includeDeleted) {
    if (includeDeleted) {
      return [SELECT Id, Name, Phone FROM Account WHERE Name = :accountName ALL ROWS];
    }
    return [SELECT Id, Name, Phone FROM Account WHERE Name = :accountName LIMIT 1];
  }

  private static Record_Health_Check_Change_Policy__c createPolicy(
    String changeTypes,
    String changedFields
  ) {
    Record_Health_Check_Change_Policy__c policy = new Record_Health_Check_Change_Policy__c(
      DisplayName__c = 'Account adapter contract',
      Active__c = true,
      SourceObjectApiName__c = 'Account',
      SelectionType__c = 'CHECK',
      QualifiedApiName__c = 'Example_Profile_Industry_Classified',
      ChangeTypes__c = changeTypes,
      ChangedFields__c = changedFields,
      EventPublication__c = 'NONE',
      ActiveAfter__c = System.now().addMinutes(-1)
    );
    insert policy;
    return policy;
  }

  private static Record_Health_Check_Change_Evaluation__c claimFor(Id accountId) {
    String accountIdValue = String.valueOf(accountId);
    return [
      SELECT RecordId__c, ChangeType__c, Outcome__c, ReasonCode__c,
        TransactionKey__c, SequenceNumber__c, ReplayId__c
      FROM Record_Health_Check_Change_Evaluation__c
      WHERE RecordId__c = :accountIdValue
      ORDER BY AcceptedAt__c DESC
      LIMIT 1
    ];
  }
}
