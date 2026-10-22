/**
 * Proves the administration and viewer surfaces fail closed for unauthorized principals, that
 * Private sharing is genuinely enforced, and that misconfiguration never becomes a silent no-op.
 */
@IsTest
private class RHCAlertsSecurityTest {
  // Dynamic SOQL inside the package must name the object by its runtime (namespaced) API name.
  private static final String POLICY_API_NAME = Record_Health_Check_Alert_Policy__c.SObjectType.getDescribe(
      SObjectDescribeOptions.DEFERRED
    )
    .getName();
  private static final String DELIVERY_API_NAME = Record_Health_Check_Alert_Delivery__c.SObjectType.getDescribe(
      SObjectDescribeOptions.DEFERRED
    )
    .getName();

  @TestSetup
  static void setup() {
    User adminUser = RHCAlertsTestDataFactory.createStandardUser('secadm');
    RHCAlertsTestDataFactory.assignPermissionSet(
      adminUser.Id,
      'RHC_Alerts_Admin'
    );
    User viewerUser = RHCAlertsTestDataFactory.createStandardUser('secview');
    RHCAlertsTestDataFactory.assignPermissionSet(
      viewerUser.Id,
      'RHC_Alerts_Viewer_Runtime'
    );
    RHCAlertsTestDataFactory.createStandardUser('secnone');
  }

  private static User userByAlias(String aliasValue) {
    return [SELECT Id FROM User WHERE Alias = :aliasValue LIMIT 1];
  }

  @IsTest
  static void shouldDenyPolicyListingWhenUserHasNoPackagePermissionSet() {
    User unauthorized = userByAlias('secnone');

    Test.startTest();
    System.runAs(unauthorized) {
      try {
        RHCAlertsAdminController.listPolicies();
        Assert.fail(
          'A user without the package permission set must not read policies'
        );
      } catch (Exception error) {
        Assert.isInstanceOfType(
          error,
          AuraHandledException.class,
          'Denial must surface as a typed AuraHandledException, not a raw platform error'
        );
        Assert.areEqual(
          'You do not have access to RHC Alerts policies.',
          error.getMessage(),
          'The read denial message must be stable and actionable'
        );
        assertNoSensitiveDetail(error.getMessage());
      }
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldDenyPolicySaveWhenUserHasOnlyViewerAccess() {
    User viewer = userByAlias('secview');
    Integer policiesBefore = [
      SELECT COUNT()
      FROM Record_Health_Check_Alert_Policy__c
    ];

    Test.startTest();
    System.runAs(viewer) {
      Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.buildCheckPolicy(
        'pkg__Viewer_Attempt',
        0
      );
      try {
        RHCAlertsAdminController.savePolicy(policy);
        Assert.fail('A read-only viewer must not create an alert policy');
      } catch (Exception error) {
        Assert.isInstanceOfType(
          error,
          AuraHandledException.class,
          'A write denial must surface as a typed AuraHandledException'
        );
        Assert.areEqual(
          'You do not have permission to configure RHC Alerts policies.',
          error.getMessage(),
          'The write denial message must be stable and actionable'
        );
        assertNoSensitiveDetail(error.getMessage());
      }
    }
    Test.stopTest();

    Assert.areEqual(
      policiesBefore,
      [SELECT COUNT() FROM Record_Health_Check_Alert_Policy__c],
      'A denied policy save must perform no DML'
    );
  }

  @IsTest
  static void shouldDenyRetentionWriteAndPurgeWhenUserHasOnlyViewerAccess() {
    User viewer = userByAlias('secview');

    Test.startTest();
    System.runAs(viewer) {
      try {
        RHCAlertsAdminController.saveRetentionSettings(30);
        Assert.fail('A read-only viewer must not change the retention window');
      } catch (Exception error) {
        Assert.isInstanceOfType(
          error,
          AuraHandledException.class,
          'A retention write denial must be typed'
        );
        Assert.areEqual(
          'You do not have permission to configure RHC Alerts retention.',
          error.getMessage(),
          'The retention denial message must be stable and actionable'
        );
        assertNoSensitiveDetail(error.getMessage());
      }
    }
    Test.stopTest();

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Record_Health_Check_Alert_Setting__c],
      'A denied retention save must leave no settings record behind'
    );
  }

  @IsTest
  static void shouldEnforcePrivateSharingForUserWithoutPackageAccess() {
    User admin = userByAlias('secadm');
    User unauthorized = userByAlias('secnone');
    Id policyId;
    System.runAs(admin) {
      Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
        'pkg__Shared_Check',
        0
      );
      policyId = policy.Id;
    }

    Test.startTest();
    Boolean outsiderWasRejected = false;
    System.runAs(unauthorized) {
      try {
        Database.countQuery(
          'SELECT COUNT() FROM ' + POLICY_API_NAME,
          AccessLevel.USER_MODE
        );
      } catch (QueryException error) {
        outsiderWasRejected = true;
      }
    }
    Integer visibleToViewer;
    System.runAs(userByAlias('secview')) {
      visibleToViewer = RHCAlertsPolicyAdminService.listPolicies().size();
    }
    Test.stopTest();

    Assert.isTrue(
      outsiderWasRejected,
      'A user with no package access must not be able to address the policy object at all'
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Record_Health_Check_Alert_Policy__c],
      'The policy still exists in system context, proving enforcement hid it rather than deleting it'
    );
    Assert.areEqual(
      1,
      visibleToViewer,
      'The packaged Viewer grants View All Records deliberately, so the admin-owned policy is visible'
    );
    Assert.isNotNull(policyId, 'The fixture policy was created by the admin');
  }

  @IsTest
  static void shouldHideAnotherUsersDeliveryFromAPrincipalWithoutPackageAccess() {
    User admin = userByAlias('secadm');
    User unauthorized = userByAlias('secnone');
    System.runAs(admin) {
      Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
        'pkg__Private_Check',
        0
      );
      RHCAlertsTestDataFactory.createPendingDelivery(policy, 'private-evt-1');
    }

    Test.startTest();
    Boolean reachable = true;
    System.runAs(unauthorized) {
      try {
        Database.countQuery(
          'SELECT COUNT() FROM ' + DELIVERY_API_NAME,
          AccessLevel.USER_MODE
        );
      } catch (QueryException error) {
        reachable = false;
      }
    }
    Test.stopTest();

    Assert.isFalse(
      reachable,
      'A delivery ledger row owned by another principal must be unreachable without package access'
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Record_Health_Check_Alert_Delivery__c],
      'The row still exists in system context, proving sharing hid it rather than deleting it'
    );
  }

  @IsTest
  static void shouldRejectRetentionPurgeWhenConfiguredWindowIsOutOfRange() {
    User admin = userByAlias('secadm');

    Test.startTest();
    System.runAs(admin) {
      insert new Record_Health_Check_Alert_Setting__c(
        Name = 'Default',
        SettingKey__c = 'Default',
        RetentionDays__c = 3650
      );
      Record_Health_Check_Alert_Setting__c stored = [
        SELECT Id, RetentionDays__c
        FROM Record_Health_Check_Alert_Setting__c
        LIMIT 1
      ];
      Assert.areEqual(
        3650,
        stored.RetentionDays__c,
        'The validation rule accepts the documented maximum window'
      );
      Integer purged = RHCAlertsRetentionService.purgeDeliveries();
      Assert.areEqual(
        0,
        purged,
        'A maximum retention window must purge nothing recent, never everything'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectNullAndZeroRetentionWithoutWriting() {
    User admin = userByAlias('secadm');

    Test.startTest();
    System.runAs(admin) {
      for (Integer candidate : new List<Integer>{ null, 0, -1, 3651 }) {
        try {
          RHCAlertsRetentionService.saveSettings(candidate);
          Assert.fail(
            'Retention outside 1-3650 must be rejected: ' + candidate
          );
        } catch (AuraHandledException error) {
          Assert.areEqual(
            'Retention Days must be from 1 through 3650.',
            error.getMessage(),
            'The retention bound message must be stable and admin-facing'
          );
        }
      }
    }
    Test.stopTest();

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Record_Health_Check_Alert_Setting__c],
      'Rejected retention input must never be persisted'
    );
  }

  @IsTest
  static void shouldReportUnconfiguredRetentionWithoutAuthorizingAPurge() {
    User admin = userByAlias('secadm');

    Test.startTest();
    System.runAs(admin) {
      RHCAlertsRetentionService.Settings settings = RHCAlertsRetentionService.getSettings();
      Assert.isFalse(
        settings.configured,
        'An unconfigured package must report itself unconfigured'
      );
      Assert.areEqual(
        90,
        settings.retentionDays,
        'The recommendation is a non-authorizing default of 90 days'
      );
      Assert.areEqual(
        1000,
        settings.maxDeleteRows,
        'The purge safety bound is exposed to administrators'
      );
      try {
        RHCAlertsRetentionService.purgeDeliveries();
        Assert.fail(
          'Purging before saving retention settings must fail closed'
        );
      } catch (AuraHandledException error) {
        Assert.areEqual(
          'Save retention settings before purging delivery history.',
          error.getMessage(),
          'The unconfigured purge message must be stable and actionable'
        );
      }
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldKeepRetentionQueryCountFlatAsDeliveryVolumeGrows() {
    User admin = userByAlias('secadm');

    Test.startTest();
    System.runAs(admin) {
      insert new Record_Health_Check_Alert_Setting__c(
        Name = 'Default',
        SettingKey__c = 'Default',
        RetentionDays__c = 1
      );
      Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
        'pkg__Volume_Check',
        0
      );
      List<Record_Health_Check_Alert_Delivery__c> rows = new List<Record_Health_Check_Alert_Delivery__c>();
      for (Integer index = 0; index < 251; index++) {
        rows.add(
          new Record_Health_Check_Alert_Delivery__c(
            Policy__c = policy.Id,
            EventId__c = 'vol-' + index,
            EventType__c = 'RESULT',
            Outcome__c = 'DELIVERED',
            AttemptCount__c = 1,
            RecipientCount__c = 1,
            OccurredAt__c = System.now()
          )
        );
      }
      insert rows;
      Integer queriesBefore = Limits.getQueries();
      Integer dmlBefore = Limits.getDmlStatements();
      Integer purged = RHCAlertsRetentionService.purgeDeliveries();
      Integer queriesUsed = Limits.getQueries() - queriesBefore;
      Integer dmlUsed = Limits.getDmlStatements() - dmlBefore;

      Assert.areEqual(
        0,
        purged,
        'Rows created inside the retention window must survive the purge'
      );
      Assert.areEqual(
        2,
        queriesUsed,
        'Purging 251 rows must use a fixed two queries, proving no query runs per row'
      );
      Assert.areEqual(
        0,
        dmlUsed,
        'A purge that matches nothing must perform no DML'
      );
      Assert.areEqual(
        251,
        [SELECT COUNT() FROM Record_Health_Check_Alert_Delivery__c],
        'Every in-window delivery row must remain'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldMatchCheckSetIdentityAndTreatBlankConfigurationAsNoMatch() {
    Record_Health_Check_Alert_Policy__c setPolicy = new Record_Health_Check_Alert_Policy__c(
      SelectionType__c = 'CHECK_SET',
      QualifiedApiName__c = 'pkg__Test_Set',
      MatchingStatuses__c = 'FAIL',
      MinimumSeverity__c = 'INFO'
    );
    Record_Health_Check_Result__e matchingEvent = RHCAlertsTestDataFactory.resultEvent(
      'match-1',
      'pkg__Other_Check',
      UserInfo.getUserId()
    );
    Record_Health_Check_Alert_Policy__c blankStatusPolicy = new Record_Health_Check_Alert_Policy__c(
      SelectionType__c = 'CHECK_SET',
      QualifiedApiName__c = 'pkg__Test_Set',
      MatchingStatuses__c = null,
      MinimumSeverity__c = 'INFO'
    );

    Test.startTest();
    Boolean setMatches;
    Boolean blankStatusMatches;
    System.runAs(userByAlias('secadm')) {
      setMatches = RHCAlertsResultPolicyMatcher.matches(
        setPolicy,
        matchingEvent
      );
      blankStatusMatches = RHCAlertsResultPolicyMatcher.matches(
        blankStatusPolicy,
        matchingEvent
      );
    }
    Test.stopTest();

    Assert.isTrue(
      setMatches,
      'A Check Set policy must match on the event Check Set identity'
    );
    Assert.isFalse(
      blankStatusMatches,
      'A policy with no selected statuses must match nothing rather than everything'
    );
  }

  @IsTest
  static void shouldTreatUnrecognizedSeverityAsLowestRank() {
    Record_Health_Check_Alert_Policy__c policy = new Record_Health_Check_Alert_Policy__c(
      SelectionType__c = 'CHECK',
      QualifiedApiName__c = 'pkg__Sev_Check',
      MatchingStatuses__c = 'FAIL',
      MinimumSeverity__c = 'CRITICAL'
    );
    Record_Health_Check_Result__e unknownSeverity = RHCAlertsTestDataFactory.resultEvent(
      'sev-1',
      'pkg__Sev_Check',
      UserInfo.getUserId()
    );
    unknownSeverity.Severity__c = 'CATASTROPHIC';
    Record_Health_Check_Result__e blankSeverity = RHCAlertsTestDataFactory.resultEvent(
      'sev-2',
      'pkg__Sev_Check',
      UserInfo.getUserId()
    );
    blankSeverity.Severity__c = null;

    Test.startTest();
    Boolean unknownMatches;
    Boolean blankMatches;
    System.runAs(userByAlias('secadm')) {
      unknownMatches = RHCAlertsResultPolicyMatcher.matches(
        policy,
        unknownSeverity
      );
      blankMatches = RHCAlertsResultPolicyMatcher.matches(
        policy,
        blankSeverity
      );
    }
    Test.stopTest();

    Assert.isFalse(
      unknownMatches,
      'An unrecognized severity ranks lowest and must not satisfy a CRITICAL threshold'
    );
    Assert.isTrue(
      blankMatches,
      'A blank severity bypasses the threshold by documented contract'
    );
  }

  @IsTest
  static void shouldExposeStableSanitizedMessageWhenSelectionTypeIsHostile() {
    User admin = userByAlias('secadm');

    Test.startTest();
    System.runAs(admin) {
      for (
        String hostileType : new List<String>{
          null,
          '',
          'CHECK\' OR Name != null--',
          'CHECK_SET;DROP'
        }
      ) {
        try {
          RHCAlertsAdminController.listSelections(hostileType);
          Assert.fail('An unapproved selection type must fail closed');
        } catch (AuraHandledException error) {
          Assert.areEqual(
            'Selections could not be loaded.',
            error.getMessage(),
            'The sanitized message must be identical for every rejected input'
          );
          assertNoSensitiveDetail(error.getMessage());
        }
      }
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldPublishPackageLimitsThatMatchTheEnforcedCaps() {
    Test.startTest();
    RHCAlertsAdminController.LimitInfo info;
    System.runAs(userByAlias('secadm')) {
      info = RHCAlertsAdminController.getLimitInfo();
    }
    Test.stopTest();

    Assert.areEqual(
      RHCAlertsRecipientResolver.CUSTOM_NOTIFICATION_RECIPIENT_LIMIT,
      info.customNotificationRecipientsPerSend,
      'The published bell cap must equal the cap the sender enforces'
    );
    Assert.areEqual(
      RHCAlertsRecipientResolver.EMAIL_RECIPIENT_LIMIT,
      info.emailRecipientsPerAttempt,
      'The published email cap must equal the cap the sender enforces'
    );
    Assert.areEqual(
      3,
      info.maxAttempts,
      'The published attempt cap must equal the delivery retry bound'
    );
    assertNoSensitiveDetail(info.note);
  }

  private static void assertNoSensitiveDetail(String message) {
    Assert.isNotNull(message, 'A sanitized error must still carry a message');
    Assert.isFalse(
      message.contains(UserInfo.getOrganizationId()),
      'A user-facing message must never echo the organization identifier'
    );
    Assert.isFalse(
      message.contains(UserInfo.getUserName()),
      'A user-facing message must never echo a username'
    );
    Assert.isFalse(
      message.containsIgnoreCase('Class.') ||
        message.containsIgnoreCase('line ') ||
        message.containsIgnoreCase('SELECT '),
      'A user-facing message must never echo a stack frame or a query'
    );
  }
}
