/** Least-privilege delivery-history endpoint for administrators and read-only viewers. */
public with sharing class RHCAlertsViewerController {
  /**
   * Returns recent bounded delivery evidence without raw event payloads.
   * @return At most 500 delivery rows visible in user mode.
   */
  @AuraEnabled(cacheable=true)
  public static List<Record_Health_Check_Alert_Delivery__c> listDeliveries() {
    return [
      SELECT
        Id,
        Name,
        Policy__r.DisplayName__c,
        EventId__c,
        EventType__c,
        CheckSetQualifiedApiName__c,
        CheckQualifiedApiName__c,
        Status__c,
        Severity__c,
        Outcome__c,
        SuppressionReason__c,
        FailureClass__c,
        ErrorCode__c,
        AttemptCount__c,
        RecipientCount__c,
        OccurredAt__c,
        AttemptedAt__c,
        DeliveredAt__c
      FROM Record_Health_Check_Alert_Delivery__c
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 500
    ];
  }
}
