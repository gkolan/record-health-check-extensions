/**
 * Applies package-owned settings and a permission-gated system-mode boundary for manual cleanup.
 * Direct delete CRUD remains absent from every packaged role.
 */
public without sharing class RHCActionRetentionService {
  private static final Integer DEFAULT_RETENTION_DAYS = 365;
  private static final Integer MIN_RETENTION_DAYS = 1;
  private static final Integer MAX_RETENTION_DAYS = 3650;
  private static final Integer MAX_PURGE_ROWS = 1000;
  private static final String SETTING_NAME = 'Default';
  private static final String RETENTION_PERMISSION = 'RHC_Actions_Manage_Retention';
  private static final Set<String> TERMINAL_ACTION_STATUSES = new Set<String>{
    'SUCCEEDED', 'FAILED', 'SUPPRESSED', 'REJECTED'
  };

  @TestVisible
  private static Boolean retentionPermissionOverride;

  /** Administrator-facing action-retention configuration. */
  public class Settings {
    /** Retention window in whole days. */
    @AuraEnabled public Integer retentionDays;
    /** Whether an administrator explicitly saved the singleton. */
    @AuraEnabled public Boolean configured;
    /** Maximum rows removed across both objects in one request. */
    @AuraEnabled public Integer maxDeleteRows;
    /** Whether the current user may configure and invoke cleanup. */
    @AuraEnabled public Boolean canManage;
  }

  /** Result of one bounded cleanup request. */
  public class PurgeOutcome {
    /** Completed Action History rows removed. */
    @AuraEnabled public Integer historiesDeleted = 0;
    /** Terminal Pending Action rows removed. */
    @AuraEnabled public Integer pendingActionsDeleted = 0;
    /** Total rows removed across both objects. */
    @AuraEnabled public Integer totalDeleted = 0;
  }

  /**
   * Returns saved settings for authorized administrators or a non-authorizing recommendation.
   * @return retention settings and current-user capability
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

    List<RHC_Action_Setting__c> settings = loadSettings();
    result.configured = !settings.isEmpty();
    if (result.configured) {
      result.retentionDays = settings[0].Retention_Days__c.intValue();
    }
    return result;
  }

  /**
   * Saves the singleton retention window through ordinary user-mode CRUD.
   * @param retentionDays whole days from 1 through 3,650
   * @return saved retention settings and current-user capability
   */
  public static Settings saveSettings(Integer retentionDays) {
    requireManageRetention();
    validateRetentionDays(retentionDays);
    List<RHC_Action_Setting__c> settings = loadSettings();
    RHC_Action_Setting__c setting = settings.isEmpty()
      ? new RHC_Action_Setting__c(Name = SETTING_NAME, Setting_Key__c = SETTING_NAME)
      : settings[0];
    setting.Retention_Days__c = retentionDays;
    try {
      if (setting.Id == null) {
        Database.insert(setting, AccessLevel.USER_MODE);
      } else {
        Database.update(setting, AccessLevel.USER_MODE);
      }
      return getSettings();
    } catch (DmlException error) {
      throw handled('Action retention settings could not be saved. Review field access and values.');
    }
  }

  /**
   * Deletes at most 1,000 completed history and terminal pending-action rows outside the window.
   * The custom permission is the explicit boundary for package-owned system-mode deletion.
   * @return counts deleted from each package-owned audit object
   */
  public static PurgeOutcome purge() {
    requireManageRetention();
    List<RHC_Action_Setting__c> settings = loadSettings();
    if (settings.isEmpty()) {
      throw handled('Save action retention settings before purging audit records.');
    }
    Integer retentionDays = settings[0].Retention_Days__c.intValue();
    validateRetentionDays(retentionDays);
    Datetime cutoff = Datetime.now().addDays(-retentionDays);
    PurgeOutcome outcome = new PurgeOutcome();

    outcome.historiesDeleted = deleteHistories(cutoff);
    Integer remainingRows = MAX_PURGE_ROWS - outcome.historiesDeleted;
    if (remainingRows > 0) {
      outcome.pendingActionsDeleted = deletePendingActions(cutoff, remainingRows);
    }
    outcome.totalDeleted = outcome.historiesDeleted + outcome.pendingActionsDeleted;
    return outcome;
  }

  private static Integer deleteHistories(Datetime cutoff) {
    List<RHC_Action_History__c> histories = [
      SELECT Id
      FROM RHC_Action_History__c
      WHERE Completed_At__c < :cutoff
      WITH SYSTEM_MODE
      ORDER BY Completed_At__c ASC, Id ASC
      LIMIT :MAX_PURGE_ROWS
    ];
    try {
      if (!histories.isEmpty()) {
        Database.delete(histories, true, AccessLevel.SYSTEM_MODE);
      }
    } catch (DmlException error) {
      throw handled('Action History records could not be purged. Review dependencies and try again.');
    }
    return histories.size();
  }

  private static Integer deletePendingActions(Datetime cutoff, Integer limitRows) {
    List<RHC_Pending_Action__c> pendingActions = [
      SELECT Id
      FROM RHC_Pending_Action__c
      WHERE Queue_Status__c IN :TERMINAL_ACTION_STATUSES AND Completed_At__c < :cutoff
      WITH SYSTEM_MODE
      ORDER BY Completed_At__c ASC, Id ASC
      LIMIT :limitRows
    ];
    try {
      if (!pendingActions.isEmpty()) {
        Database.delete(pendingActions, true, AccessLevel.SYSTEM_MODE);
      }
    } catch (DmlException error) {
      throw handled('Pending Action records could not be purged. Review dependencies and try again.');
    }
    return pendingActions.size();
  }

  private static List<RHC_Action_Setting__c> loadSettings() {
    return [
      SELECT Id, Retention_Days__c
      FROM RHC_Action_Setting__c
      WHERE Setting_Key__c = :SETTING_NAME
      WITH USER_MODE
      LIMIT 1
    ];
  }

  private static Boolean canManageRetention() {
    Boolean permitted = retentionPermissionOverride == null
      ? FeatureManagement.checkPermission(RETENTION_PERMISSION)
      : retentionPermissionOverride;
    return permitted && Schema.SObjectType.RHC_Action_Setting__c.isAccessible() &&
      Schema.SObjectType.RHC_Action_Setting__c.isCreateable() &&
      Schema.SObjectType.RHC_Action_Setting__c.isUpdateable();
  }

  private static void requireManageRetention() {
    if (!canManageRetention()) {
      throw handled('RHC Actions retention-management permission is required.');
    }
  }

  private static void validateRetentionDays(Integer retentionDays) {
    if (
      retentionDays == null ||
      retentionDays < MIN_RETENTION_DAYS ||
      retentionDays > MAX_RETENTION_DAYS
    ) {
      throw handled('Retention Days must be from 1 through 3650.');
    }
  }

  private static AuraHandledException handled(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }
}
