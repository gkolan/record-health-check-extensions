@IsTest
private class RHCAlertsAdminControllerTest {
  @TestSetup
  static void setup() {
    User adminUser = new User(
      Alias = 'rhcalrt',
      Email = 'rhc-alerts-admin@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Alerts Admin',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Chicago',
      Username = 'rhc-alerts-admin-' +
        UserInfo.getOrganizationId() +
        '@example.invalid'
    );
    insert adminUser;
    PermissionSet permissionValue = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'RHC_Alerts_Admin'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = adminUser.Id,
      PermissionSetId = permissionValue.Id
    );
  }

  @IsTest
  static void shouldExposeConservativePlatformLimits() {
    System.runAs(adminUser()) {
      Test.startTest();
      RHCAlertsAdminController.LimitInfo limits = RHCAlertsAdminController.getLimitInfo();
      Test.stopTest();
      Assert.areEqual(
        500,
        limits.customNotificationRecipientsPerSend,
        'Custom notification cap should be visible.'
      );
      Assert.areEqual(
        10,
        limits.emailRecipientsPerAttempt,
        'Email cap should be visible.'
      );
      Assert.isTrue(
        limits.note.contains('Company Information'),
        'Administrators should be directed to live org allocations.'
      );
    }
  }

  @IsTest
  static void shouldRejectPolicyWithoutExactIdentity() {
    Record_Health_Check_Alert_Policy__c policy = new Record_Health_Check_Alert_Policy__c(
      SelectionType__c = 'CHECK',
      QualifiedApiName__c = ''
    );
    System.runAs(adminUser()) {
      Test.startTest();
      try {
        RHCAlertsAdminController.savePolicy(policy);
        Assert.fail('A blank Qualified API Name should be rejected.');
      } catch (AuraHandledException expected) {
        Assert.isTrue(
          expected.getMessage().contains('Qualified API Name'),
          'The administrator should receive a safe validation message.'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldServeAdministratorSetupAndHistoryPaths() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'rhcalrt' LIMIT 1];
    System.runAs(adminUser) {
      List<RHCAlertsCoreMetadataGateway.SelectionOption> checks = RHCAlertsAdminController.listSelections(
        'CHECK'
      );
      List<RHCAlertsCoreMetadataGateway.SelectionOption> sets = RHCAlertsAdminController.listSelections(
        'CHECK_SET'
      );
      Assert.isFalse(
        checks.isEmpty(),
        'The installed core package should expose active Checks.'
      );
      Assert.isFalse(
        sets.isEmpty(),
        'The installed core package should expose active Check Sets.'
      );

      List<RHCAlertsAdminController.RecipientOption> users = RHCAlertsAdminController.listRecipients(
        'USER'
      );
      Assert.isFalse(
        users.isEmpty(),
        'Active human Users should be available to the picker.'
      );
      RHCAlertsTestDataFactory.createCheckPolicy('missing__Coverage_Check', 15);
      Record_Health_Check_Alert_Policy__c setPolicy = RHCAlertsTestDataFactory.createCheckPolicy(
        'missing__Coverage_Set',
        15
      );
      setPolicy.SelectionType__c = 'CHECK_SET';
      update setPolicy;

      Test.startTest();
      List<Record_Health_Check_Alert_Policy__c> policies = RHCAlertsAdminController.listPolicies();
      List<Record_Health_Check_Alert_Delivery__c> deliveries = RHCAlertsAdminController.listDeliveries();
      List<RHCAlertsCoreMetadataGateway.CoverageGap> gaps = RHCAlertsAdminController.analyzeCoverage();
      Test.stopTest();

      Assert.isFalse(policies.isEmpty(), 'Saved policies should be listed.');
      Assert.areEqual(
        0,
        deliveries.size(),
        'No event means no delivery history.'
      );
      Assert.isNotNull(gaps, 'Coverage assistant should always return a list.');
      Assert.isTrue(
        gaps.size() >= 3,
        'Missing exact definitions and caller publication guidance should be visible.'
      );
    }
  }

  @IsTest
  static void shouldSendTestAlertToCurrentUserWithoutLedgerRow() {
    System.runAs(adminUser()) {
      Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy('pkg__Safe_Check', 0);
      Test.startTest();
      RHCAlertsAdminController.sendTestAlert(policy.Id);
      Integer emails = Limits.getEmailInvocations();
      Test.stopTest();
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Record_Health_Check_Alert_Delivery__c],
        'A test send never writes to Delivery History.'
      );
      Assert.isTrue(
        policy.NotificationChannel__c != 'EMAIL' || emails == 1,
        'An email policy sends exactly one test message.'
      );
    }
  }

  @IsTest
  static void shouldRejectUnsupportedPickerValues() {
    System.runAs(adminUser()) {
      Test.startTest();
      try {
        RHCAlertsAdminController.listRecipients('QUEUE');
        Assert.fail(
          'System-to-system or queue recipients must not be accepted.'
        );
      } catch (AuraHandledException expected) {
        Assert.isTrue(
          expected.getMessage().contains('USER or PUBLIC_GROUP'),
          'Only supported human recipient types should be shown.'
        );
      }
      try {
        RHCAlertsCoreMetadataGateway.listSelections('UNKNOWN');
        Assert.fail('Unknown selection type should be rejected.');
      } catch (IllegalArgumentException expected) {
        Assert.isTrue(
          expected.getMessage().contains('CHECK_SET or CHECK'),
          'Selection validation should be explicit.'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldListPublicGroupsAndSortRecipientOptions() {
    insert new Group(
      Name = 'RHC Alerts Coverage Group',
      DeveloperName = 'RHC_Alerts_Coverage_Group',
      Type = 'Regular'
    );
    System.runAs(adminUser()) {
      Test.startTest();
      List<RHCAlertsAdminController.RecipientOption> groups = RHCAlertsAdminController.listRecipients(
        'PUBLIC_GROUP'
      );
      RHCAlertsAdminController.RecipientOption later = new RHCAlertsAdminController.RecipientOption();
      later.label = 'Zulu';
      RHCAlertsAdminController.RecipientOption earlier = new RHCAlertsAdminController.RecipientOption();
      earlier.label = 'alpha';
      Integer comparison = later.compareTo(earlier);
      Test.stopTest();

      Assert.isTrue(
        groups.size() >= 1,
        'The public group picker should return configured regular groups.'
      );
      Assert.isTrue(
        comparison > 0,
        'Recipient labels should sort case-insensitively.'
      );
    }
  }

  @IsTest
  static void shouldRejectInvalidGenericPolicyUpdate() {
    System.runAs(adminUser()) {
      Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
        'pkg__Validated_Check',
        0
      );
      policy.CooldownMinutes__c = -1;

      Test.startTest();
      try {
        update policy;
        Assert.fail(
          'Metadata validation must protect generic Salesforce edit paths.'
        );
      } catch (DmlException expected) {
        Assert.isTrue(
          expected.getMessage().contains('Cooldown Minutes'),
          'The validation rule should provide a bounded administrator message.'
        );
      }
      Test.stopTest();
    }
  }

  private static User adminUser() {
    return [SELECT Id FROM User WHERE Alias = 'rhcalrt' LIMIT 1];
  }
}
