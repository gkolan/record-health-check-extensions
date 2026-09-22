@IsTest
private class RHCChangeMonitorAdminControllerTest {
  @TestSetup
  static void setupAdmin() {
    User adminUser = new User(
      Alias = 'rhcchg',
      Email = 'rhc-change-monitor-admin@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Change Monitor Admin',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Chicago',
      Username = 'rhc-change-monitor-admin-' +
        UserInfo.getOrganizationId() +
        '@example.invalid'
    );
    insert adminUser;
    PermissionSet adminPermission = [
      SELECT Id FROM PermissionSet WHERE Name = 'RHC_Change_Monitor_Admin' LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = adminUser.Id,
      PermissionSetId = adminPermission.Id
    );
  }

  @IsTest
  static void shouldSummarizeRetryAndPurgeBoundedEvidence() {
    System.runAs(adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      insert new List<Record_Health_Check_Change_Evaluation__c>{
        claim(policy.Id, 'FAILED', System.now()),
        claim(policy.Id, 'EVALUATED', System.now()),
        claim(policy.Id, 'IGNORED', System.now().addDays(-40)),
        claim(policy.Id, 'EVALUATED', System.now().addDays(-40)),
        claim(policy.Id, 'PENDING', System.now().addDays(-40))
      };

      Test.startTest();
      RHCChangeMonitorAdminController.Status before = RHCChangeMonitorAdminController.getStatus();
      Integer retried = RHCChangeMonitorAdminController.retryFailed();
      RHCChangeMonitorAdminController.saveRetentionSettings(30);
      Integer purged = RHCChangeMonitorAdminController.purgeEvaluations();
      Test.stopTest();

      Assert.areEqual(1, before.retryableFailedCount, 'The permission failure is retryable.');
      Assert.areEqual(1, before.pendingCount, 'One claim was pending before retry.');
      Assert.areEqual(1, retried, 'Only the runtime failure is returned to PENDING.');
      Assert.areEqual(2, purged, 'Terminal claims older than 30 days are purged; PENDING is kept.');
      Assert.areEqual(
        2,
        [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c WHERE Outcome__c = 'PENDING'],
        'The retried claim and the old pending claim remain pending.'
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c WHERE Outcome__c = 'EVALUATED'],
        'A recent terminal claim remains inside the retention window.'
      );
    }
  }

  @IsTest
  static void shouldReturnSaveAndValidateRetentionSettings() {
    System.runAs(adminUser()) {
      RHCChangeMonitorRetentionService.Settings recommended =
        RHCChangeMonitorAdminController.getRetentionSettings();
      Assert.areEqual(false, recommended.configured, 'The default is not purge authorization.');
      Assert.areEqual(90, recommended.retentionDays, 'The recommended window is 90 days.');
      Assert.areEqual(1000, recommended.maxDeleteRows, 'A purge transaction is bounded.');

      RHCChangeMonitorAdminController.saveRetentionSettings(45);
      RHCChangeMonitorRetentionService.Settings saved =
        RHCChangeMonitorAdminController.getRetentionSettings();
      Assert.areEqual(true, saved.configured, 'Saving creates the singleton setting.');
      Assert.areEqual(45, saved.retentionDays, 'The saved retention window is returned.');

      RHCChangeMonitorAdminController.saveRetentionSettings(60);
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Record_Health_Check_Change_Setting__c],
        'Saving again updates rather than duplicates the singleton.'
      );
      Assert.areEqual(
        60,
        RHCChangeMonitorAdminController.getRetentionSettings().retentionDays,
        'The updated retention window is returned.'
      );

      Boolean nullRejected = false;
      try {
        RHCChangeMonitorAdminController.saveRetentionSettings(null);
      } catch (AuraHandledException error) {
        nullRejected = true;
      }
      Assert.isTrue(nullRejected, 'A missing retention window is rejected.');

      Boolean lowRejected = false;
      try {
        RHCChangeMonitorAdminController.saveRetentionSettings(0);
      } catch (AuraHandledException error) {
        lowRejected = true;
      }
      Assert.isTrue(lowRejected, 'Retention below one day is rejected.');

      Boolean highRejected = false;
      try {
        RHCChangeMonitorAdminController.saveRetentionSettings(3651);
      } catch (AuraHandledException error) {
        highRejected = true;
      }
      Assert.isTrue(highRejected, 'Retention above 3,650 days is rejected.');
    }
  }

  @IsTest
  static void shouldRequireSavedRetentionBeforePurge() {
    System.runAs(adminUser()) {
      Boolean rejected = false;
      try {
        RHCChangeMonitorAdminController.purgeEvaluations();
      } catch (AuraHandledException error) {
        rejected = true;
      }
      Assert.isTrue(rejected, 'A recommendation alone never authorizes deletion.');
    }
  }

  @IsTest
  static void shouldRollbackRetryWhenDispatchSignalIsRejected() {
    System.runAs(adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      Record_Health_Check_Change_Evaluation__c failed = claim(
        policy.Id,
        'FAILED',
        System.now()
      );
      insert failed;
      RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = false;

      Test.startTest();
      try {
        RHCChangeMonitorAdminController.retryFailed();
        Assert.fail('A rejected dispatch signal must reject the retry transaction.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('could not be re-queued'),
          'The administrator should receive a bounded retry error.'
        );
      } finally {
        RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = null;
      }
      Test.stopTest();

      failed = [
        SELECT Outcome__c, ReasonCode__c, AttemptCount__c, CompletedAt__c
        FROM Record_Health_Check_Change_Evaluation__c
        WHERE Id = :failed.Id
      ];
      Assert.areEqual('FAILED', failed.Outcome__c, 'A failed retry signal must preserve FAILED.');
      Assert.areEqual(
        'RUNTIME_PERMISSION_MISSING',
        failed.ReasonCode__c,
        'A failed retry signal must preserve the original bounded reason.'
      );
      Assert.areEqual(1, failed.AttemptCount__c, 'A failed retry signal must preserve attempts.');
      Assert.isNotNull(failed.CompletedAt__c, 'A failed retry signal must preserve completion.');
    }
  }

  @IsTest
  static void shouldRequestDispatchForPendingClaims() {
    System.runAs(adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      insert claim(policy.Id, 'PENDING', System.now());
      RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = true;

      Test.startTest();
      Integer pendingCount;
      try {
        pendingCount = RHCChangeMonitorAdminController.dispatchPending();
      } finally {
        RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = null;
      }
      Test.stopTest();

      Assert.areEqual(1, pendingCount, 'The recovery signal should report visible pending work.');
    }
  }

  @IsTest
  static void shouldSurfacePendingDispatchRejection() {
    System.runAs(adminUser()) {
      Record_Health_Check_Change_Policy__c policy = RHCChangeMonitorTestDataFactory.createPolicy();
      insert claim(policy.Id, 'PENDING', System.now());
      RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = false;

      Test.startTest();
      try {
        RHCChangeMonitorAdminController.dispatchPending();
        Assert.fail('A rejected recovery signal must be surfaced to the administrator.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('could not be dispatched'),
          'The administrator should receive a bounded dispatch error.'
        );
      } finally {
        RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = null;
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldSkipDispatchSignalWhenNoClaimsArePending() {
    System.runAs(adminUser()) {
      RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = false;

      Test.startTest();
      Integer pendingCount;
      try {
        pendingCount = RHCChangeMonitorAdminController.dispatchPending();
      } finally {
        RHCChangeMonitorDispatchSupport.dispatchPublishSuccessOverride = null;
      }
      Test.stopTest();

      Assert.areEqual(0, pendingCount, 'No pending work should require no dispatch signal.');
    }
  }

  private static Record_Health_Check_Change_Evaluation__c claim(
    Id policyId, String outcome, Datetime acceptedAt
  ) {
    String reason = outcome == 'FAILED'
      ? 'RUNTIME_PERMISSION_MISSING'
      : outcome == 'IGNORED' ? 'RECORD_DELETED' : 'ACCEPTED';
    return new Record_Health_Check_Change_Evaluation__c(
      Policy__c = policyId, ClaimKey__c = outcome + '-' + acceptedAt.getTime(),
      SourceObjectApiName__c = 'Account',
      RecordId__c = String.valueOf(policyId), ChangeType__c = 'CREATE', Outcome__c = outcome,
      ReasonCode__c = reason, AcceptedAt__c = acceptedAt, AttemptCount__c = 1,
      CompletedAt__c = outcome == 'PENDING' ? null : acceptedAt
    );
  }

  private static User adminUser() {
    return [SELECT Id FROM User WHERE Alias = 'rhcchg' LIMIT 1];
  }
}
