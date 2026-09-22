/**
 * Shared, user-mode helpers for the RHC Agent Actions package: Check Set discovery through core's
 * public Custom Metadata, bounded correlation IDs, and plain-language summaries for an agent.
 */
public with sharing class RHCAgentSupport {
  public static final String CONTRACT_VERSION = '1.0';
  public static final Integer MAX_CHECK_SETS_PER_RECORD = 5;
  private static final Integer MAX_CORRELATION_LENGTH = 120;

  /** One applicable Check Set as an agent-safe projection. */
  public class CheckSetInfo {
    @InvocableVariable(label='Check Set Qualified API Name')
    public String qualifiedApiName;
    @InvocableVariable(label='Label')
    public String label;
    @InvocableVariable(label='Object API Name')
    public String objectApiName;
    @InvocableVariable(label='Description')
    public String description;
  }

  @SuppressWarnings('PMD.EmptyStatementBlock')
  private RHCAgentSupport() {
  }

  /**
   * Resolves a record ID to its object API name.
   * @param recordId Any Salesforce record ID
   * @return the record's object API name, or null when the ID is not a known object
   */
  public static String objectApiNameOf(Id recordId) {
    return recordId == null ? null : String.valueOf(recordId.getSobjectType());
  }

  /**
   * Lists active Check Sets whose target object matches, in a deterministic order.
   * @param objectApiName exact object API name
   * @param bound maximum rows
   * @return applicable Check Sets; empty when the user cannot read core metadata
   */
  public static List<CheckSetInfo> applicableCheckSets(String objectApiName, Integer bound) {
    List<CheckSetInfo> infos = new List<CheckSetInfo>();
    if (String.isBlank(objectApiName)
      || !Schema.SObjectType.Record_Health_Check_Set__mdt.isAccessible()) {
      return infos;
    }
    for (Record_Health_Check_Set__mdt item : [
      SELECT QualifiedApiName, MasterLabel, ObjectApiName__c, CardSubtitle__c
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE AND ObjectApiName__c = :objectApiName
      WITH USER_MODE
      ORDER BY QualifiedApiName
      LIMIT :bound
    ]) {
      CheckSetInfo info = new CheckSetInfo();
      info.qualifiedApiName = item.QualifiedApiName;
      info.label = item.MasterLabel;
      info.objectApiName = item.ObjectApiName__c;
      info.description = item.CardSubtitle__c;
      infos.add(info);
    }
    return infos;
  }

  /**
   * Finds one active Check Set for an object.
   * @param objectApiName exact object API name
   * @param qualifiedApiName exact opaque Check Set identity; namespace text is never rewritten
   * @return the matching active Check Set, or null
   */
  public static CheckSetInfo findCheckSet(String objectApiName, String qualifiedApiName) {
    for (CheckSetInfo info : applicableCheckSets(objectApiName, 200)) {
      if (info.qualifiedApiName == qualifiedApiName) {
        return info;
      }
    }
    return null;
  }

  /**
   * Normalizes an optional correlation identifier.
   * @param value caller-supplied correlation text
   * @return a bounded, character-restricted correlation ID, or null when unusable
   */
  public static String safeCorrelationId(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String trimmed = value.trim();
    return trimmed.length() <= MAX_CORRELATION_LENGTH
      && Pattern.matches('[A-Za-z0-9._:-]+', trimmed)
      ? trimmed
      : null;
  }

  /**
   * Maps a core summary to the single word an agent should use.
   * @param summary core run summary
   * @return PASS, FAIL, or ATTENTION (something could not be evaluated)
   */
  public static String overallStatus(RecordHealthCheckRunSummary summary) {
    if (summary.failed > 0) {
      return 'FAIL';
    }
    if (summary.unable > 0 || summary.systemError > 0) {
      return 'ATTENTION';
    }
    return 'PASS';
  }
}
