/**
 * Matches canonical core events to active routes and creates idempotent delivery work.
 */
public with sharing class RHCIntegrationEventHandler {
  @TestVisible
  private static final Integer MAX_DELIVERIES_PER_SUBSCRIBER_TRANSACTION = 1000;

  /** Raised when one subscriber transaction would create an unsafe amount of fan-out. */
  public class FanoutLimitException extends Exception {
  }

  /**
   * Maps canonical Check Result events into the shared integration event contract.
   *
   * @param events Canonical Check Result events.
   */
  public static void handleResults(List<Record_Health_Check_Result__e> events) {
    List<RHCIntegrationEventDTO> eventRecords = new List<RHCIntegrationEventDTO>();
    for (Record_Health_Check_Result__e sourceEvent : events) {
      RHCIntegrationEventDTO eventRecord = new RHCIntegrationEventDTO();
      eventRecord.eventType = 'RESULT';
      eventRecord.eventId = sourceEvent.EventId__c;
      eventRecord.runId = sourceEvent.RunId__c;
      eventRecord.checkSetQualifiedApiName = sourceEvent.CheckSetQualifiedApiName__c;
      eventRecord.checkQualifiedApiName = sourceEvent.CheckQualifiedApiName__c;
      eventRecord.recordId = sourceEvent.RecordId__c;
      eventRecord.status = sourceEvent.Status__c;
      eventRecord.severity = sourceEvent.Severity__c;
      eventRecord.reasonCode = sourceEvent.ReasonCode__c;
      eventRecord.occurredAt = sourceEvent.OccurredAt__c;
      eventRecord.source = sourceEvent.Source__c;
      eventRecord.contractVersion = sourceEvent.ContractVersion__c;
      eventRecord.frameworkVersion = sourceEvent.FrameworkVersion__c;
      eventRecords.add(eventRecord);
    }
    handleDtos(eventRecords);
  }

  /**
   * Maps canonical Check Set Run events into the shared integration event contract.
   *
   * @param events Canonical Check Set Run events.
   */
  public static void handleRuns(List<Record_Health_Check_Set_Run__e> events) {
    List<RHCIntegrationEventDTO> eventRecords = new List<RHCIntegrationEventDTO>();
    for (Record_Health_Check_Set_Run__e sourceEvent : events) {
      RHCIntegrationEventDTO eventRecord = new RHCIntegrationEventDTO();
      eventRecord.eventType = 'RUN';
      eventRecord.eventId = sourceEvent.EventId__c;
      eventRecord.runId = sourceEvent.RunId__c;
      eventRecord.checkSetQualifiedApiName = sourceEvent.CheckSetQualifiedApiName__c;
      eventRecord.recordId = sourceEvent.RecordId__c;
      eventRecord.status = deriveRunStatus(sourceEvent);
      eventRecord.occurredAt = sourceEvent.OccurredAt__c;
      eventRecord.source = sourceEvent.Source__c;
      eventRecord.contractVersion = sourceEvent.ContractVersion__c;
      eventRecord.frameworkVersion = sourceEvent.FrameworkVersion__c;
      eventRecord.eligibleCount = sourceEvent.EligibleCheckCount__c;
      eventRecord.evaluatedCount = sourceEvent.EvaluatedCheckCount__c;
      eventRecord.passedCount = sourceEvent.PassedCount__c;
      eventRecord.failedCount = sourceEvent.FailedCount__c;
      eventRecord.skippedCount = sourceEvent.SkippedCount__c;
      eventRecord.unableCount = sourceEvent.UnableCount__c;
      eventRecord.systemErrorCount = sourceEvent.SystemErrorCount__c;
      eventRecords.add(eventRecord);
    }
    handleDtos(eventRecords);
  }

  /**
   * Subscribes to approved Log events while deliberately excluding restricted diagnostic fields.
   * @param events Canonical Log events.
   */
  public static void handleLogs(List<Record_Health_Check_Log__e> events) {
    List<RHCIntegrationEventDTO> eventRecords = new List<RHCIntegrationEventDTO>();
    for (Record_Health_Check_Log__e sourceEvent : events) {
      RHCIntegrationEventDTO eventRecord = new RHCIntegrationEventDTO();
      eventRecord.eventType = 'LOG';
      eventRecord.eventId = sourceEvent.EventId__c;
      eventRecord.runId = sourceEvent.RunId__c;
      eventRecord.checkSetQualifiedApiName = sourceEvent.CheckSetDeveloperName__c;
      eventRecord.checkQualifiedApiName = sourceEvent.CheckDeveloperName__c;
      eventRecord.status = 'ERROR';
      eventRecord.occurredAt = sourceEvent.OccurredAt__c;
      eventRecord.contractVersion = sourceEvent.ContractVersion__c;
      eventRecord.frameworkVersion = sourceEvent.FrameworkVersion__c;
      eventRecord.code = sourceEvent.Code__c;
      eventRecords.add(eventRecord);
    }
    handleDtos(eventRecords);
  }

  @TestVisible
  private static void handleDtos(List<RHCIntegrationEventDTO> eventRecords) {
    if (eventRecords == null || eventRecords.isEmpty()) {
      return;
    }
    List<Record_Health_Check_Integration_Route__c> routes = RHCIntegrationRouteSelector.selectActive();
    if (routes.isEmpty()) {
      return;
    }
    List<Record_Health_Check_Integration_Delivery__c> deliveries = RHCIntegrationDeliveryFactory.build(
      eventRecords,
      routes,
      MAX_DELIVERIES_PER_SUBSCRIBER_TRANSACTION
    );
    RHCIntegrationIngestionService.persistAndEnqueue(deliveries);
  }

  private static String deriveRunStatus(
    Record_Health_Check_Set_Run__e sourceEvent
  ) {
    if (sourceEvent.SystemErrorCount__c > 0) {
      return 'ERROR';
    }
    if (sourceEvent.UnableCount__c > 0) {
      return 'UNABLE_TO_EVALUATE';
    }
    if (sourceEvent.FailedCount__c > 0) {
      return 'FAIL';
    }
    if (sourceEvent.PassedCount__c > 0) {
      return 'PASS';
    }
    return 'SKIPPED';
  }
}
