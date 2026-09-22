/**
 * Setup and operations API for the Change Monitor console: outcome summary, recent evidence,
 * bounded retry of failed claims, and package-governed purge of terminal claims.
 */
public with sharing class RHCChangeMonitorAdminController {
  private static final Integer RECENT_LIMIT = 50;
  private static final Integer RETRY_LIMIT = 2000;
  private static final Set<String> RETRYABLE_REASONS = new Set<String>{
    'RUNTIME_PERMISSION_MISSING', 'TRANSIENT_RETRY', 'RETRY_EXHAUSTED', 'DISPATCH_CHAIN_EXHAUSTED'
  };

  /** One outcome/reason bucket over the recent window. */
  public class OutcomeCount {
    @AuraEnabled public String outcome;
    @AuraEnabled public String reasonCode;
    @AuraEnabled public Integer count;
  }

  /** Console snapshot. */
  public class Status {
    @AuraEnabled public List<OutcomeCount> lastSevenDays = new List<OutcomeCount>();
    @AuraEnabled public Integer pendingCount;
    @AuraEnabled public Integer retryableFailedCount;
    @AuraEnabled public Boolean dispatcherQueued;
    @AuraEnabled public Boolean currentUserCanRunCore;
    @AuraEnabled public List<Record_Health_Check_Change_Policy__c> policies;
    @AuraEnabled public List<Record_Health_Check_Change_Evaluation__c> recent;
  }

  /**
   * Builds the current Change Monitor operational snapshot.
   * @return evidence-based operational snapshot for administrators and viewers
   */
  @AuraEnabled
  public static Status getStatus() {
    requireRead();
    Status status = new Status();
    Datetime windowStart = System.now().addDays(-7);
    for (AggregateResult row : [
      SELECT Outcome__c outcome, ReasonCode__c reason, COUNT(Id) total
      FROM Record_Health_Check_Change_Evaluation__c
      WHERE AcceptedAt__c >= :windowStart
      WITH USER_MODE
      GROUP BY Outcome__c, ReasonCode__c
      ORDER BY COUNT(Id) DESC
      LIMIT 50
    ]) {
      OutcomeCount bucket = new OutcomeCount();
      bucket.outcome = (String) row.get('outcome');
      bucket.reasonCode = (String) row.get('reason');
      bucket.count = (Integer) row.get('total');
      status.lastSevenDays.add(bucket);
    }
    status.pendingCount = [
      SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c
      WHERE Outcome__c = 'PENDING' WITH USER_MODE
    ];
    status.retryableFailedCount = [
      SELECT COUNT() FROM Record_Health_Check_Change_Evaluation__c
      WHERE Outcome__c = 'FAILED' AND ReasonCode__c IN :RETRYABLE_REASONS WITH USER_MODE
    ];
    status.dispatcherQueued = ![
      SELECT Id FROM AsyncApexJob
      WHERE ApexClass.Name = 'RHCChangeMonitorDispatcherQueueable'
        AND Status IN ('Queued', 'Holding', 'Preparing', 'Processing')
      WITH USER_MODE LIMIT 1
    ].isEmpty();
    status.currentUserCanRunCore = FeatureManagement.checkPermission('Record_Health_Check_Run');
    status.policies = [
      SELECT Id, Name, DisplayName__c, Active__c, SourceObjectApiName__c, SelectionType__c,
        QualifiedApiName__c, ChangeTypes__c, EventPublication__c
      FROM Record_Health_Check_Change_Policy__c
      WITH USER_MODE ORDER BY DisplayName__c LIMIT 200
    ];
    status.recent = [
      SELECT Id, Name, ChangeType__c, Outcome__c, ReasonCode__c, SourceObjectApiName__c,
        RecordId__c, AttemptCount__c, ResultCount__c, ActionableCount__c, AcceptedAt__c,
        CompletedAt__c, Policy__r.DisplayName__c
      FROM Record_Health_Check_Change_Evaluation__c
      WITH USER_MODE ORDER BY AcceptedAt__c DESC, Id DESC LIMIT :RECENT_LIMIT
    ];
    return status;
  }

  /**
   * Re-queues failed claims whose reason is a runtime or capacity condition (never a routing or
   * configuration verdict) and publishes one dispatch event.
   * @return number of claims returned to PENDING
   */
  @AuraEnabled
  public static Integer retryFailed() {
    requireEdit();
    List<Record_Health_Check_Change_Evaluation__c> claims = [
      SELECT Id FROM Record_Health_Check_Change_Evaluation__c
      WHERE Outcome__c = 'FAILED' AND ReasonCode__c IN :RETRYABLE_REASONS
      WITH USER_MODE ORDER BY AcceptedAt__c LIMIT :RETRY_LIMIT
    ];
    for (Record_Health_Check_Change_Evaluation__c claim : claims) {
      claim.Outcome__c = 'PENDING';
      claim.ReasonCode__c = 'ACCEPTED';
      claim.CompletedAt__c = null;
      claim.AttemptCount__c = 0;
    }
    if (!claims.isEmpty()) {
      Savepoint retrySavepoint = Database.setSavepoint();
      Database.update(claims, AccessLevel.USER_MODE);
      try {
        RHCChangeMonitorDispatchSupport.publishDispatch(claims.size());
      } catch (RHCChangeMonitorDispatchSupport.DispatchSignalException error) {
        Database.rollback(retrySavepoint);
        throw sanitized('Failed claims could not be re-queued. Try again.');
      }
    }
    return claims.size();
  }

  /**
   * Publishes one idempotent wake-up signal for all currently pending claims.
   * @return number of pending claims visible to the administrator
   */
  @AuraEnabled
  public static Integer dispatchPending() {
    requireEdit();
    Integer pendingCount = [
      SELECT COUNT()
      FROM Record_Health_Check_Change_Evaluation__c
      WHERE Outcome__c = 'PENDING'
      WITH USER_MODE
    ];
    try {
      RHCChangeMonitorDispatchSupport.publishDispatch(pendingCount);
    } catch (RHCChangeMonitorDispatchSupport.DispatchSignalException error) {
      throw sanitized('Pending claims could not be dispatched. Try again.');
    }
    return pendingCount;
  }

  /**
   * Loads the package-owned retention policy.
   * @return administrator-facing retention settings
   */
  @AuraEnabled
  public static RHCChangeMonitorRetentionService.Settings getRetentionSettings() {
    return RHCChangeMonitorRetentionService.getSettings();
  }

  /**
   * Saves the package-owned retention window.
   * @param retentionDays whole days from 1 through 3,650
   */
  @AuraEnabled
  public static void saveRetentionSettings(Integer retentionDays) {
    RHCChangeMonitorRetentionService.saveSettings(retentionDays);
  }

  /**
   * Deletes one bounded batch of terminal claims outside the saved retention window.
   * @return number of Change Evaluations deleted
   */
  @AuraEnabled
  public static Integer purgeEvaluations() {
    return RHCChangeMonitorRetentionService.purgeEvaluations();
  }

  private static void requireRead() {
    if (!Schema.SObjectType.Record_Health_Check_Change_Evaluation__c.isAccessible()) {
      throw sanitized('You do not have access to Change Monitor evidence.');
    }
  }

  private static void requireEdit() {
    requireRead();
    if (!Schema.SObjectType.Record_Health_Check_Change_Evaluation__c.isUpdateable()) {
      throw sanitized('You do not have permission to operate Change Monitor.');
    }
  }

  private static AuraHandledException sanitized(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }
}
