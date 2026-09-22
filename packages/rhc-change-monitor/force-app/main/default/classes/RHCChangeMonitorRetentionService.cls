/** Applies package-owned settings and safety bounds for manual Change Evaluation cleanup. */
public with sharing class RHCChangeMonitorRetentionService {
  private static final Integer DEFAULT_RETENTION_DAYS = 90;
  private static final Integer MIN_RETENTION_DAYS = 1;
  private static final Integer MAX_RETENTION_DAYS = 3650;
  private static final Integer MAX_PURGE_ROWS = 1000;
  private static final String SETTING_NAME = 'Default';

  /** Administrator-facing Change Evaluation retention configuration. */
  public class Settings {
    @AuraEnabled public Integer retentionDays;
    @AuraEnabled public Boolean configured;
    @AuraEnabled public Integer maxDeleteRows;
  }

  /**
   * Returns the configured window or a non-authorizing recommendation.
   * @return retention configuration for the administrator interface
   */
  public static Settings getSettings() {
    List<Record_Health_Check_Change_Setting__c> settings = loadSettings();
    Settings result = new Settings();
    result.configured = !settings.isEmpty();
    result.retentionDays = settings.isEmpty()
      ? DEFAULT_RETENTION_DAYS
      : settings[0].RetentionDays__c.intValue();
    result.maxDeleteRows = MAX_PURGE_ROWS;
    return result;
  }

  /**
   * Saves the singleton retention window in user mode.
   * @param retentionDays whole days from 1 through 3,650
   */
  public static void saveSettings(Integer retentionDays) {
    validateRetentionDays(retentionDays);
    List<Record_Health_Check_Change_Setting__c> settings = loadSettings();
    Record_Health_Check_Change_Setting__c setting = settings.isEmpty()
      ? new Record_Health_Check_Change_Setting__c(
          Name = SETTING_NAME,
          SettingKey__c = SETTING_NAME
        )
      : settings[0];
    setting.RetentionDays__c = retentionDays;
    try {
      if (setting.Id == null) {
        Database.insert(setting, AccessLevel.USER_MODE);
      } else {
        Database.update(setting, AccessLevel.USER_MODE);
      }
    } catch (DmlException error) {
      throw handled('Retention settings could not be saved. Review field access and values.');
    }
  }

  /**
   * Deletes at most 1,000 oldest terminal Change Evaluations outside the configured window.
   * PENDING claims are never deleted.
   * @return number of Change Evaluation rows deleted
   */
  public static Integer purgeEvaluations() {
    List<Record_Health_Check_Change_Setting__c> settings = loadSettings();
    if (settings.isEmpty()) {
      throw handled('Save retention settings before purging Change Evaluations.');
    }
    Integer retentionDays = settings[0].RetentionDays__c.intValue();
    validateRetentionDays(retentionDays);
    Datetime cutoff = Datetime.now().addDays(-retentionDays);
    List<Record_Health_Check_Change_Evaluation__c> evaluations = [
      SELECT Id
      FROM Record_Health_Check_Change_Evaluation__c
      WHERE Outcome__c != 'PENDING' AND AcceptedAt__c < :cutoff
      WITH USER_MODE
      ORDER BY AcceptedAt__c ASC, Id ASC
      LIMIT :MAX_PURGE_ROWS
    ];
    if (!evaluations.isEmpty()) {
      try {
        Database.delete(evaluations, true, AccessLevel.USER_MODE);
      } catch (DmlException error) {
        throw handled(
          'Change Evaluations could not be purged. Review record access and try again.'
        );
      }
    }
    return evaluations.size();
  }

  private static List<Record_Health_Check_Change_Setting__c> loadSettings() {
    return [
      SELECT Id, RetentionDays__c
      FROM Record_Health_Check_Change_Setting__c
      WHERE SettingKey__c = :SETTING_NAME
      WITH USER_MODE
      LIMIT 1
    ];
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
