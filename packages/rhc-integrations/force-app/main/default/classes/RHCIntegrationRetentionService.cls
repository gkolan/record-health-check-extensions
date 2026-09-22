/** Applies package-owned settings and safety bounds for manual Integration Delivery cleanup. */
public with sharing class RHCIntegrationRetentionService {
    private static final Integer DEFAULT_RETENTION_DAYS = 90;
    private static final Integer MIN_RETENTION_DAYS = 1;
    private static final Integer MAX_RETENTION_DAYS = 3650;
    private static final Integer MAX_PURGE_ROWS = 1000;
    private static final String SETTING_NAME = 'Default';

    /** Administrator-facing Integration Delivery retention configuration. */
    public class Settings {
        @AuraEnabled public Integer retentionDays;
        @AuraEnabled public Boolean configured;
        @AuraEnabled public Integer maxDeleteRows;
        @AuraEnabled public Boolean canManage;
    }

    /**
     * Returns the configured window for managers or a non-authorizing recommendation for viewers.
     * @return retention configuration for the Dead Letters interface
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

        List<Record_Health_Check_Integration_Setting__c> settings = loadSettings();
        result.configured = !settings.isEmpty();
        if (result.configured) {
            result.retentionDays = settings[0].RetentionDays__c.intValue();
        }
        return result;
    }

    /**
     * Saves the singleton retention window after field sanitization and in user mode.
     * @param retentionDays whole days from 1 through 3,650
     */
    public static void saveSettings(Integer retentionDays) {
        requireManageRetention();
        validateRetentionDays(retentionDays);
        List<Record_Health_Check_Integration_Setting__c> settings = loadSettings();
        Record_Health_Check_Integration_Setting__c setting = settings.isEmpty()
            ? new Record_Health_Check_Integration_Setting__c(
                Name = SETTING_NAME,
                SettingKey__c = SETTING_NAME
            )
            : settings[0];
        setting.RetentionDays__c = retentionDays;
        try {
            AccessType accessType = setting.Id == null
                ? AccessType.CREATABLE
                : AccessType.UPDATABLE;
            SObjectAccessDecision accessDecision = Security.stripInaccessible(
                accessType,
                new List<Record_Health_Check_Integration_Setting__c>{ setting }
            );
            Record_Health_Check_Integration_Setting__c accessibleSetting =
                (Record_Health_Check_Integration_Setting__c) accessDecision.getRecords()[0];
            if (setting.Id == null) {
                Database.insert(accessibleSetting, AccessLevel.USER_MODE);
            } else {
                Database.update(accessibleSetting, AccessLevel.USER_MODE);
            }
        } catch (DmlException error) {
            throw handled('Retention settings could not be saved. Review field access and values.');
        }
    }

    /**
     * Deletes at most 1,000 oldest completed terminal deliveries outside the configured window.
     * PENDING and RETRY_WAIT deliveries are never deleted.
     * @return number of Integration Delivery rows deleted
     */
    public static Integer purgeDeliveries() {
        requireManageRetention();
        List<Record_Health_Check_Integration_Setting__c> settings = loadSettings();
        if (settings.isEmpty()) {
            throw handled('Save retention settings before purging Integration Deliveries.');
        }
        Integer retentionDays = settings[0].RetentionDays__c.intValue();
        validateRetentionDays(retentionDays);
        Datetime cutoff = Datetime.now().addDays(-retentionDays);
        List<Record_Health_Check_Integration_Delivery__c> deliveries = [
            SELECT Id
            FROM Record_Health_Check_Integration_Delivery__c
            WHERE Status__c IN ('SUCCEEDED', 'DEAD_LETTER') AND CompletedAt__c < :cutoff
            WITH USER_MODE
            ORDER BY CompletedAt__c ASC, Id ASC
            LIMIT :MAX_PURGE_ROWS
        ];
        if (!deliveries.isEmpty()) {
            try {
                Database.delete(deliveries, true, AccessLevel.USER_MODE);
            } catch (DmlException error) {
                throw handled(
                    'Integration Deliveries could not be purged. Review record access and try again.'
                );
            }
        }
        return deliveries.size();
    }

    private static List<Record_Health_Check_Integration_Setting__c> loadSettings() {
        return [
            SELECT Id, RetentionDays__c
            FROM Record_Health_Check_Integration_Setting__c
            WHERE SettingKey__c = :SETTING_NAME
            WITH USER_MODE
            LIMIT 1
        ];
    }

    private static Boolean canManageRetention() {
        Schema.DescribeSObjectResult settingObject =
            Schema.SObjectType.Record_Health_Check_Integration_Setting__c;
        Schema.DescribeFieldResult nameField =
            Schema.SObjectType.Record_Health_Check_Integration_Setting__c.fields.Name;
        Schema.DescribeFieldResult keyField =
            Schema.SObjectType.Record_Health_Check_Integration_Setting__c.fields.SettingKey__c;
        Schema.DescribeFieldResult retentionField =
            Schema.SObjectType.Record_Health_Check_Integration_Setting__c.fields.RetentionDays__c;
        return settingObject.isAccessible() &&
            settingObject.isCreateable() &&
            settingObject.isUpdateable() &&
            nameField.isCreateable() &&
            keyField.isAccessible() &&
            keyField.isCreateable() &&
            retentionField.isAccessible() &&
            retentionField.isCreateable() &&
            retentionField.isUpdateable() &&
            Schema.SObjectType.Record_Health_Check_Integration_Delivery__c.isDeletable();
    }

    private static void requireManageRetention() {
        if (!canManageRetention()) {
            throw handled('You do not have permission to manage Integration Delivery retention.');
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
