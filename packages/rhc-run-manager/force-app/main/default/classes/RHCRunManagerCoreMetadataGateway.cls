/** Resolves public core metadata without coupling to core implementation classes. */
// Public Custom Metadata is readable without object CRUD; PMD cannot distinguish
// these metadata queries from data-object queries.
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class RHCRunManagerCoreMetadataGateway {
  /** Metadata-driven selection option returned to administrator clients. */
  public class SelectionOption implements Comparable {
    @AuraEnabled public String label;
    @AuraEnabled public String value;
    @AuraEnabled public String targetObjectApiName;

    /**
     * Sorts options by their administrator-facing label.
     * @param other Selection option being compared.
     * @return Lexicographic comparison result.
     */
    public Integer compareTo(Object other) {
      return label.toLowerCase().compareTo(((SelectionOption) other).label.toLowerCase());
    }
  }

  /**
   * Lists active Check Sets or Checks for a metadata-driven administrator picker.
   * @param selectionType CHECK_SET or CHECK.
   * @return Sorted active selections of the requested type.
   */
  public static List<SelectionOption> listSelections(String selectionType) {
    if (!new Set<String>{ 'CHECK_SET', 'CHECK' }.contains(selectionType)) {
      throw new ResolutionException('Selection Type must be CHECK_SET or CHECK.');
    }
    List<SelectionOption> options = new List<SelectionOption>();
    if ('CHECK_SET'.equals(selectionType)) {
      for (Record_Health_Check_Set__mdt item : [
        SELECT MasterLabel, QualifiedApiName, ObjectApiName__c
        FROM Record_Health_Check_Set__mdt
        WHERE IsActive__c = TRUE
        LIMIT 1000
      ]) {
        options.add(createSelectionOption(item.MasterLabel, item.QualifiedApiName, item.ObjectApiName__c));
      }
    } else {
      for (Record_Health_Check__mdt item : [
        SELECT MasterLabel, QualifiedApiName, Record_Health_Check_Set__r.ObjectApiName__c
        FROM Record_Health_Check__mdt
        WHERE IsActive__c = TRUE AND Record_Health_Check_Set__r.IsActive__c = TRUE
        LIMIT 1000
      ]) {
        options.add(createSelectionOption(item.MasterLabel, item.QualifiedApiName, item.Record_Health_Check_Set__r.ObjectApiName__c));
      }
    }
    options.sort();
    return options;
  }

  private static SelectionOption createSelectionOption(String label, String value, String targetObjectApiName) {
    SelectionOption option = new SelectionOption();
    option.label = label + ' — ' + value + ' (' + targetObjectApiName + ')';
    option.value = value;
    option.targetObjectApiName = targetObjectApiName;
    return option;
  }
  /** Resolved identity and owning target object. */
  public class DefinitionInfo {
    @AuraEnabled public String selectionType;
    @AuraEnabled public String qualifiedApiName;
    @AuraEnabled public String checkSetQualifiedApiName;
    @AuraEnabled public String targetObjectApiName;
  }

  /** Invalid or inactive core metadata selection. */
  public class ResolutionException extends Exception {
  }

  /**
   * Resolves an exact Check Set or Check QualifiedApiName through public core metadata.
   * @param selectionType CHECK_SET or CHECK.
   * @param qualifiedApiName Exact opaque QualifiedApiName.
   * @return Resolved owning Check Set and target object.
   */
  public static DefinitionInfo resolve(
    String selectionType,
    String qualifiedApiName
  ) {
    validateInput(selectionType, qualifiedApiName);
    if ('CHECK_SET'.equals(selectionType)) {
      return resolveCheckSet(qualifiedApiName.trim());
    }
    return resolveCheck(qualifiedApiName.trim());
  }

  private static DefinitionInfo resolveCheckSet(String qualifiedApiName) {
    List<Record_Health_Check_Set__mdt> matches = [
      SELECT QualifiedApiName, ObjectApiName__c, IsActive__c
      FROM Record_Health_Check_Set__mdt
      WHERE QualifiedApiName = :qualifiedApiName
      LIMIT 2
    ];
    if (matches.size() != 1 || matches[0].IsActive__c != true) {
      throw new ResolutionException('The active Check Set could not be resolved.');
    }
    return createCheckSetInfo(matches[0]);
  }

  private static DefinitionInfo resolveCheck(String qualifiedApiName) {
    List<Record_Health_Check__mdt> matches = [
      SELECT
        QualifiedApiName,
        IsActive__c,
        Record_Health_Check_Set__r.QualifiedApiName,
        Record_Health_Check_Set__r.ObjectApiName__c,
        Record_Health_Check_Set__r.IsActive__c
      FROM Record_Health_Check__mdt
      WHERE QualifiedApiName = :qualifiedApiName
      LIMIT 2
    ];
    if (
      matches.size() != 1 ||
      matches[0].IsActive__c != true ||
      matches[0].Record_Health_Check_Set__r?.IsActive__c != true
    ) {
      throw new ResolutionException('The active Check could not be resolved.');
    }
    return createCheckInfo(matches[0]);
  }

  private static DefinitionInfo createCheckSetInfo(Record_Health_Check_Set__mdt item) {
    DefinitionInfo info = new DefinitionInfo();
    info.selectionType = 'CHECK_SET';
    info.qualifiedApiName = item.QualifiedApiName;
    info.checkSetQualifiedApiName = item.QualifiedApiName;
    info.targetObjectApiName = item.ObjectApiName__c;
    validateTargetObject(info.targetObjectApiName);
    return info;
  }

  private static DefinitionInfo createCheckInfo(Record_Health_Check__mdt item) {
    DefinitionInfo info = new DefinitionInfo();
    info.selectionType = 'CHECK';
    info.qualifiedApiName = item.QualifiedApiName;
    info.checkSetQualifiedApiName = item.Record_Health_Check_Set__r.QualifiedApiName;
    info.targetObjectApiName = item.Record_Health_Check_Set__r.ObjectApiName__c;
    validateTargetObject(info.targetObjectApiName);
    return info;
  }

  private static void validateTargetObject(String targetObjectApiName) {
    if (String.isBlank(targetObjectApiName)) {
      throw new ResolutionException('Core metadata has no target object.');
    }
    Schema.SObjectType targetType = Schema.getGlobalDescribe().get(
      targetObjectApiName
    );
    if (targetType == null || !targetType.getDescribe().isQueryable()) {
      throw new ResolutionException('The derived target object is unavailable.');
    }
  }

  private static void validateInput(
    String selectionType,
    String qualifiedApiName
  ) {
    if (!new Set<String>{ 'CHECK_SET', 'CHECK' }.contains(selectionType)) {
      throw new ResolutionException('Selection Type must be CHECK_SET or CHECK.');
    }
    if (String.isBlank(qualifiedApiName) || qualifiedApiName.length() > 120) {
      throw new ResolutionException('A Qualified API Name of 1-120 characters is required.');
    }
  }
}
