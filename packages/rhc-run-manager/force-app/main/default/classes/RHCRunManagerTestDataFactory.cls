/** Creates isolated Run Manager test records. */
@IsTest
public class RHCRunManagerTestDataFactory {
  /** Creates a dedicated user and assigns the Run Manager and core Admin permission sets. */
  public static void createAdminUser() {
    List<PermissionSet> permissionSets = [
      SELECT Id, Name
      FROM PermissionSet
      WHERE Name IN ('RHC_Run_Manager_Admin', 'Record_Health_Check_Admin')
    ];
    if (permissionSets.isEmpty()) {
      return;
    }
    User userRecord = new User(
      Alias = 'rhcrun',
      Email = 'rhc-run-manager-test@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Run Manager Test Admin',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Chicago',
      Username = 'rhc-run-manager-' + UserInfo.getOrganizationId() + '-' + Crypto.getRandomLong() + '@example.invalid'
    );
    insert userRecord;
    List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
    for (PermissionSet permissionSet : permissionSets) {
      assignments.add(new PermissionSetAssignment(
        AssigneeId = userRecord.Id,
        PermissionSetId = permissionSet.Id
      ));
    }
    insert assignments;
  }

  /**
   * Returns the permissioned user created by the test setup transaction.
   * @return Dedicated Run Manager administrator.
   */
  public static User adminUser() {
    return [SELECT Id FROM User WHERE Alias = 'rhcrun' LIMIT 1];
  }

  /**
   * Creates a minimum-access user and assigns one packaged Run Manager persona.
   * @param alias Unique short user alias.
   * @param permissionSetName Packaged persona permission-set name.
   */
  public static void createPersonaUser(String alias, String permissionSetName) {
    List<Profile> profiles = [
      SELECT Id
      FROM Profile
      WHERE Name IN ('Minimum Access - Salesforce', 'Standard User')
      ORDER BY Name
      LIMIT 1
    ];
    Id profileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id;
    User userRecord = new User(
      Alias = alias,
      Email = alias + '@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Run Manager ' + alias,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profileId,
      TimeZoneSidKey = 'America/Chicago',
      Username = alias + '-' + UserInfo.getOrganizationId() + '-' + Crypto.getRandomLong() + '@example.invalid'
    );
    insert userRecord;
    PermissionSet permissionSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :permissionSetName
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = userRecord.Id,
      PermissionSetId = permissionSet.Id
    );
  }

  /**
   * Returns a persona user created by test setup.
   * @param alias Short alias assigned when the user was created.
   * @return Matching persona user.
   */
  public static User personaUser(String alias) {
    return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1];
  }

  /**
   * Creates and inserts Account records.
   * @param countValue Number of Account records to create.
   * @return Inserted Account records.
   */
  public static List<Account> createAccounts(Integer countValue) {
    List<Account> accounts = new List<Account>();
    for (Integer indexValue = 0; indexValue < countValue; indexValue++) {
      accounts.add(new Account(Name = 'Run Manager Account ' + indexValue));
    }
    insert accounts;
    return accounts;
  }

  /**
   * Returns one active packaged Account Check Set fixture.
   * @return Active Account Check Set metadata.
   */
  public static Record_Health_Check_Set__mdt accountCheckSet() {
    return [
      SELECT QualifiedApiName, ObjectApiName__c
      FROM Record_Health_Check_Set__mdt
      WHERE ObjectApiName__c = 'Account' AND IsActive__c = TRUE
      ORDER BY QualifiedApiName
      LIMIT 1
    ];
  }

  /**
   * Returns one active Check owned by the fixture Account Check Set.
   * @return Active Account Check metadata.
   */
  public static Record_Health_Check__mdt accountCheck() {
    return [
      SELECT QualifiedApiName, Record_Health_Check_Set__r.QualifiedApiName
      FROM Record_Health_Check__mdt
      WHERE IsActive__c = TRUE AND Record_Health_Check_Set__r.ObjectApiName__c = 'Account'
      ORDER BY QualifiedApiName
      LIMIT 1
    ];
  }

  /**
   * Inserts a valid definition for the requested population and capture modes.
   * @param populationMode Population-selection mode.
   * @param captureMode Detailed-result capture mode.
   * @return Inserted Run Definition.
   */
  public static Record_Health_Check_Run_Definition__c createDefinition(
    String populationMode,
    String captureMode
  ) {
    Record_Health_Check_Set__mdt checkSet = accountCheckSet();
    Record_Health_Check_Run_Definition__c definition = new Record_Health_Check_Run_Definition__c(
      DisplayName__c = 'Account health ' + populationMode,
      Active__c = true,
      SelectionType__c = 'CHECK_SET',
      QualifiedApiName__c = checkSet.QualifiedApiName,
      TargetObjectApiName__c = 'Account',
      PopulationMode__c = populationMode,
      FilterJson__c = populationMode == 'GUIDED_FILTERED'
        ? '[{"field":"Name","operator":"STARTS_WITH","value":"Run Manager"}]'
        : null,
      BatchSize__c = 200,
      CaptureMode__c = captureMode,
      CoalesceDelayMinutes__c = 1
    );
    insert definition;
    return definition;
  }

  /**
   * Inserts a queued Batch Run.
   * @param definitionId Owning Run Definition ID.
   * @return Inserted queued Batch Run.
   */
  public static Record_Health_Check_Batch_Run__c createBatchRun(Id definitionId) {
    Record_Health_Check_Batch_Run__c batchRun = new Record_Health_Check_Batch_Run__c(
      RunDefinition__c = definitionId,
      Source__c = 'RUN_NOW',
      Status__c = 'QUEUED',
      SubmittedRecordCount__c = 0,
      ProcessedRecordCount__c = 0,
      FailedScopeCount__c = 0,
      StartedAt__c = System.now()
    );
    insert batchRun;
    return batchRun;
  }
}
