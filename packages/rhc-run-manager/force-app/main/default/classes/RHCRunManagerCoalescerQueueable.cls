/** Delayed, duplicate-signature coalescer for supplied target IDs. */
public with sharing class RHCRunManagerCoalescerQueueable implements Queueable, Finalizer {
  private static final Integer MAX_DRAIN_SIZE = 9000;
  private static final Integer MAX_RETRY_ATTEMPTS = 2;
  @TestVisible private static Integer drainSize = MAX_DRAIN_SIZE;
  private Id definitionId;
  private Integer retryAttempt;

  /**
   * Creates a first-attempt coalescer for one supplied-ID definition.
   * @param definitionId Saved supplied-ID definition.
   */
  public RHCRunManagerCoalescerQueueable(Id definitionId) {
    this(definitionId, 0);
  }

  private RHCRunManagerCoalescerQueueable(Id definitionId, Integer retryAttempt) {
    this.definitionId = definitionId;
    this.retryAttempt = retryAttempt;
  }

  /**
   * Enqueues one delayed coalescer per definition.
   * @param definitionId Saved supplied-ID definition.
   * @return Queueable job ID, or null when the duplicate signature already exists.
   */
  public static Id enqueue(Id definitionId) {
    if (definitionId == null) {
      throw new IllegalArgumentException('Run Definition is required.');
    }
    AsyncOptions options = new AsyncOptions();
    options.MinimumQueueableDelayInMinutes = coalesceDelay(definitionId);
    options.DuplicateSignature = new System.QueueableDuplicateSignature.Builder()
      .addString('RHCRM')
      .addId(definitionId)
      .build();
    try {
      return System.enqueueJob(new RHCRunManagerCoalescerQueueable(definitionId), options);
    } catch (DuplicateMessageException error) {
      return null;
    }
  }

  /**
   * Drains one governor-safe page of committed pending IDs into a shared Batch launch.
   * @param context Queueable execution context; null only during direct unit execution.
   */
  public void execute(QueueableContext context) {
    if (context != null) {
      System.attachFinalizer(this);
    }
    Integer effectiveDrainSize = Math.max(1, Math.min(MAX_DRAIN_SIZE, drainSize));
    List<Record_Health_Check_Run_Request__c> pending = pendingRequests(effectiveDrainSize);
    if (pending.isEmpty()) {
      return;
    }
    List<Id> targetIds = collectTargetIds(pending);
    if (!targetIds.isEmpty()) {
      RHCRunManagerExecutionService.Request request = new RHCRunManagerExecutionService.Request();
      request.definitionId = definitionId;
      request.source = 'SUPPLIED_IDS';
      request.suppliedIds = targetIds;
      RHCRunManagerExecutionService.start(request);
    }
    transitionSubmitted(pending);
    if (pending.size() == effectiveDrainSize) {
      System.enqueueJob(new RHCRunManagerCoalescerQueueable(definitionId));
    }
  }

  private List<Record_Health_Check_Run_Request__c> pendingRequests(Integer effectiveDrainSize) {
    return [
      SELECT Id, RecordId__c
      FROM Record_Health_Check_Run_Request__c
      WHERE RunDefinition__c = :definitionId AND Status__c = 'PENDING'
      WITH USER_MODE
      LIMIT :effectiveDrainSize
      FOR UPDATE
    ];
  }

  private static List<Id> collectTargetIds(
    List<Record_Health_Check_Run_Request__c> pending
  ) {
    List<Id> targetIds = new List<Id>();
    for (Record_Health_Check_Run_Request__c requestValue : pending) {
      try {
        targetIds.add((Id) requestValue.RecordId__c);
      } catch (StringException error) {
        requestValue.Status__c = 'SUBMITTED';
      }
    }
    return targetIds;
  }

  private static void transitionSubmitted(
    List<Record_Health_Check_Run_Request__c> pending
  ) {
    for (Record_Health_Check_Run_Request__c requestValue : pending) {
      requestValue.Status__c = 'SUBMITTED';
    }
    List<Database.SaveResult> updateResults = Database.update(pending, false, AccessLevel.USER_MODE);
    for (Database.SaveResult updateResult : updateResults) {
      if (!updateResult.isSuccess()) {
        throw new CoalescerException('One or more staged requests could not be transitioned.');
      }
    }
  }

  /**
   * Retries an unhandled failure with a strict serialized attempt bound.
   * @param context Finalizer outcome for the completed Queueable job.
   */
  public void execute(FinalizerContext context) {
    if (isRetryEligible(context.getResult(), retryAttempt)) {
      System.enqueueJob(new RHCRunManagerCoalescerQueueable(definitionId, retryAttempt + 1));
    }
  }

  @TestVisible
  private static Boolean isRetryEligible(ParentJobResult result, Integer attempt) {
    return result == ParentJobResult.UNHANDLED_EXCEPTION && attempt < MAX_RETRY_ATTEMPTS;
  }

  private class CoalescerException extends Exception {}

  private static Integer coalesceDelay(Id definitionId) {
    Record_Health_Check_Run_Definition__c definition = [
      SELECT CoalesceDelayMinutes__c
      FROM Record_Health_Check_Run_Definition__c
      WHERE Id = :definitionId
      WITH USER_MODE
      LIMIT 1
    ];
    Integer delay = definition.CoalesceDelayMinutes__c == null ? 1 : Integer.valueOf(definition.CoalesceDelayMinutes__c);
    return Math.max(1, Math.min(10, delay));
  }
}
