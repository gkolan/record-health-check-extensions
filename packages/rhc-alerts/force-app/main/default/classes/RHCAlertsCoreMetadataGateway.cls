/** Reads the two public core Custom Metadata contracts used by the setup assistant. */
// Public Custom Metadata has no object CRUD permission. Policy reads are explicitly USER_MODE.
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class RHCAlertsCoreMetadataGateway {
  /** One administrator-selectable core definition. */
  public class SelectionOption implements Comparable {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
    @AuraEnabled
    public Boolean interactiveResultPublicationEnabled;

    /**
     * Sorts by the human label while preserving the opaque value.
     * @param other SelectionOption to compare with this option.
     * @return Negative, zero, or positive according to label sort order.
     */
    public Integer compareTo(Object other) {
      return label.toLowerCase()
        .compareTo(((SelectionOption) other).label.toLowerCase());
    }
  }

  /** One actionable publication-coverage finding. */
  public class CoverageGap {
    @AuraEnabled
    public String severity;
    @AuraEnabled
    public String code;
    @AuraEnabled
    public String message;
  }

  /**
   * Lists exact active Check Set or Check QualifiedApiName values.
   * @param selectionType CHECK_SET or CHECK.
   * @return Sorted active core definitions for the requested type.
   */
  public static List<SelectionOption> listSelections(String selectionType) {
    validateSelectionType(selectionType);
    List<SelectionOption> options = new List<SelectionOption>();
    if ('CHECK_SET'.equals(selectionType)) {
      for (Record_Health_Check_Set__mdt item : [
        SELECT MasterLabel, QualifiedApiName, PublishUserRunEvent__c
        FROM Record_Health_Check_Set__mdt
        WHERE IsActive__c = TRUE
        LIMIT 1000
      ]) {
        options.add(
          option(
            item.MasterLabel,
            item.QualifiedApiName,
            item.PublishUserRunEvent__c
          )
        );
      }
    } else {
      for (Record_Health_Check__mdt item : [
        SELECT MasterLabel, QualifiedApiName, PublishUserResultEvent__c
        FROM Record_Health_Check__mdt
        WHERE
          IsActive__c = TRUE
          AND Record_Health_Check_Set__r.IsActive__c = TRUE
        LIMIT 1000
      ]) {
        options.add(
          option(
            item.MasterLabel,
            item.QualifiedApiName,
            item.PublishUserResultEvent__c
          )
        );
      }
    }
    options.sort();
    return options;
  }

  /**
   * Reports interactive and programmatic event-publication coverage gaps for active policies.
   * @return Coverage gaps and contract guidance for active policies.
   */
  public static List<CoverageGap> analyzeCoverage() {
    return RHCAlertsCoverageAnalyzer.analyzeCoverage();
  }

  private static SelectionOption option(
    String label,
    String value,
    Boolean enabled
  ) {
    SelectionOption result = new SelectionOption();
    result.label = label + ' — ' + value;
    result.value = value;
    result.interactiveResultPublicationEnabled = enabled;
    return result;
  }

  private static void validateSelectionType(String selectionType) {
    if (!new Set<String>{ 'CHECK_SET', 'CHECK' }.contains(selectionType)) {
      throw new IllegalArgumentException(
        'Selection Type must be CHECK_SET or CHECK.'
      );
    }
  }
}
