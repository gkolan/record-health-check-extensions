/** Applies explicit settings and bounded, child-first cleanup to Run Manager-owned records. */
public without sharing class RHCRunManagerRetentionService {
  private static final Integer DEFAULT_RETENTION_DAYS = 365;
  private static final Integer MIN_RETENTION_DAYS = 1;
  private static final Integer MAX_RETENTION_DAYS = 3650;
  private static final Integer MAX_PURGE_ROWS = 1000;
  private static final String SETTING_NAME = 'Default';
  private static final String RETENTION_PERMISSION = 'RHC_Run_Manager_Manage_Retention';
  private static final Set<String> TERMINAL_BATCH_STATUSES = new Set<String>{
    'COMPLETED', 'PARTIAL_FAILURE', 'ERROR', 'CANCELLED'
  };
  private static final Set<String> TERMINAL_RUN_STATUSES = new Set<String>{ 'COMPLETED', 'ERROR' };

  @TestVisible
  private static Boolean retentionPermissionOverride;

  /** Administrator-facing retention configuration and capability. */
  public class Settings {
    @AuraEnabled public Integer retentionDays;
    @AuraEnabled public Boolean configured;
    @AuraEnabled public Integer maxDeleteRows;
    @AuraEnabled public Boolean canManage;
  }

  /** Counts removed by one bounded manual cleanup request. */
  public class PurgeOutcome {
    @AuraEnabled public Integer resultsDeleted = 0;
    @AuraEnabled public Integer runsDeleted = 0;
    @AuraEnabled public Integer batchRunsDeleted = 0;
    @AuraEnabled public Integer requestsDeleted = 0;
    @AuraEnabled public Integer totalDeleted = 0;
  }

  /**
   * Returns the saved singleton or a conservative, non-authorizing recommendation.
   * @return Current retention settings and current-user capability.
   */
  public static Settings getSettings() {
    Settings result = new Settings();
    result.canManage = canManageRetention();
    result.configured = false;
    result.retentionDays = DEFAULT_RETENTION_DAYS;
    result.maxDeleteRows = MAX_PURGE_ROWS;
    if (!result.canManage) {
      return result;
    }

    List<Record_Health_Check_Run_Setting__c> settings = loadSettings();
    result.configured = !settings.isEmpty();
    if (result.configured) {
      result.retentionDays = settings[0].RetentionDays__c.intValue();
    }
    return result;
  }

  /**
   * Saves the package-owned singleton through ordinary user-mode CRUD.
   * @param retentionDays Whole-day retention window.
   * @return Saved retention settings.
   */
  public static Settings saveSettings(Integer retentionDays) {
    requireManageRetention();
    validateRetentionDays(retentionDays);
    List<Record_Health_Check_Run_Setting__c> settings = loadSettings();
    Record_Health_Check_Run_Setting__c setting = settings.isEmpty()
      ? new Record_Health_Check_Run_Setting__c(Name = SETTING_NAME, SettingKey__c = SETTING_NAME)
      : settings[0];
    setting.RetentionDays__c = retentionDays;
    try {
      if (setting.Id == null) {
        Database.insert(setting, AccessLevel.USER_MODE);
      } else {
        Database.update(setting, AccessLevel.USER_MODE);
      }
      return getSettings();
    } catch (DmlException error) {
      throw handled('Run Manager retention settings could not be saved. Review field access and values.');
    }
  }

  /**
   * Deletes at most 1,000 eligible rows, always draining children before their parents.
   * Active Batch Runs, active scope Runs, and pending supplied-ID Requests are never eligible.
   * @return Counts removed by object type and in total.
   */
  public static PurgeOutcome purge() {
    requireManageRetention();
    List<Record_Health_Check_Run_Setting__c> settings = loadSettings();
    if (settings.isEmpty()) {
      throw handled('Save Run Manager retention settings before purging records.');
    }
    Integer retentionDays = settings[0].RetentionDays__c.intValue();
    validateRetentionDays(retentionDays);
    Datetime cutoff = Datetime.now().addDays(-retentionDays);
    PurgeOutcome outcome = new PurgeOutcome();
    Integer remaining = MAX_PURGE_ROWS;

    outcome.resultsDeleted = deleteResults(cutoff, remaining);
    remaining -= outcome.resultsDeleted;
    if (remaining > 0) {
      outcome.runsDeleted = deleteRuns(cutoff, remaining);
      remaining -= outcome.runsDeleted;
    }
    if (remaining > 0) {
      outcome.batchRunsDeleted = deleteBatchRuns(cutoff, remaining);
      remaining -= outcome.batchRunsDeleted;
    }
    if (remaining > 0) {
      outcome.requestsDeleted = deleteRequests(cutoff, remaining);
    }
    outcome.totalDeleted = outcome.resultsDeleted + outcome.runsDeleted +
      outcome.batchRunsDeleted + outcome.requestsDeleted;
    return outcome;
  }

  private static Integer deleteResults(Datetime cutoff, Integer limitRows) {
    List<Record_Health_Check_Run_Result__c> rows = [
      SELECT Id
      FROM Record_Health_Check_Run_Result__c
      WHERE Run__r.Status__c IN :TERMINAL_RUN_STATUSES
        AND Run__r.BatchRun__r.Status__c IN :TERMINAL_BATCH_STATUSES
        AND Run__r.BatchRun__r.CompletedAt__c < :cutoff
      WITH USER_MODE
      ORDER BY CreatedDate ASC, Id ASC
      LIMIT :limitRows
    ];
    deleteRows(rows, 'Run Results');
    return rows.size();
  }

  private static Integer deleteRuns(Datetime cutoff, Integer limitRows) {
    List<Record_Health_Check_Run__c> rows = [
      SELECT Id
      FROM Record_Health_Check_Run__c
      WHERE Status__c IN :TERMINAL_RUN_STATUSES
        AND BatchRun__r.Status__c IN :TERMINAL_BATCH_STATUSES
        AND BatchRun__r.CompletedAt__c < :cutoff
        AND Id NOT IN (SELECT Run__c FROM Record_Health_Check_Run_Result__c)
      WITH USER_MODE
      ORDER BY CompletedAt__c ASC NULLS LAST, Id ASC
      LIMIT :limitRows
    ];
    deleteRows(rows, 'scope Runs');
    return rows.size();
  }

  private static Integer deleteBatchRuns(Datetime cutoff, Integer limitRows) {
    List<Record_Health_Check_Batch_Run__c> rows = [
      SELECT Id
      FROM Record_Health_Check_Batch_Run__c
      WHERE Status__c IN :TERMINAL_BATCH_STATUSES
        AND CompletedAt__c < :cutoff
        AND Id NOT IN (SELECT BatchRun__c FROM Record_Health_Check_Run__c)
      WITH USER_MODE
      ORDER BY CompletedAt__c ASC, Id ASC
      LIMIT :limitRows
    ];
    deleteRows(rows, 'Batch Runs');
    return rows.size();
  }

  private static Integer deleteRequests(Datetime cutoff, Integer limitRows) {
    List<Record_Health_Check_Run_Request__c> rows = [
      SELECT Id
      FROM Record_Health_Check_Run_Request__c
      WHERE Status__c = 'SUBMITTED' AND RequestedAt__c < :cutoff
      WITH USER_MODE
      ORDER BY RequestedAt__c ASC, Id ASC
      LIMIT :limitRows
    ];
    deleteRows(rows, 'submitted Run Requests');
    return rows.size();
  }

  private static void deleteRows(List<SObject> rows, String recordLabel) {
    try {
      if (!rows.isEmpty()) {
        Database.delete(rows, true, AccessLevel.USER_MODE);
      }
    } catch (DmlException error) {
      throw handled(recordLabel + ' could not be purged. Review dependencies and access, then try again.');
    }
  }

  private static List<Record_Health_Check_Run_Setting__c> loadSettings() {
    return [
      SELECT Id, RetentionDays__c
      FROM Record_Health_Check_Run_Setting__c
      WHERE SettingKey__c = :SETTING_NAME
      WITH USER_MODE
      LIMIT 1
    ];
  }

  private static Boolean canManageRetention() {
    Boolean permitted = retentionPermissionOverride == null
      ? FeatureManagement.checkPermission(RETENTION_PERMISSION)
      : retentionPermissionOverride;
    return permitted && Schema.SObjectType.Record_Health_Check_Run_Setting__c.isAccessible() &&
      Schema.SObjectType.Record_Health_Check_Run_Setting__c.isCreateable() &&
      Schema.SObjectType.Record_Health_Check_Run_Setting__c.isUpdateable() &&
      Schema.SObjectType.Record_Health_Check_Run_Result__c.isDeletable() &&
      Schema.SObjectType.Record_Health_Check_Run__c.isDeletable() &&
      Schema.SObjectType.Record_Health_Check_Batch_Run__c.isDeletable() &&
      Schema.SObjectType.Record_Health_Check_Run_Request__c.isDeletable();
  }

  private static void requireManageRetention() {
    if (!canManageRetention()) {
      throw handled('RHC Run Manager retention-management permission is required.');
    }
  }

  private static void validateRetentionDays(Integer retentionDays) {
    if (retentionDays == null || retentionDays < MIN_RETENTION_DAYS || retentionDays > MAX_RETENTION_DAYS) {
      throw handled('Retention Days must be from 1 through 3650.');
    }
  }

  private static AuraHandledException handled(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }
}
