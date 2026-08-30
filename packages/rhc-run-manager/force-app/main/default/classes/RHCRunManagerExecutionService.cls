/** Shared launch path for Run Now, schedules, and supplied-ID requests. */
public with sharing class RHCRunManagerExecutionService {
  @TestVisible private static Boolean forceLaunchFailure = false;
  /** Invalid execution request. */
  public class ExecutionException extends Exception {
  }

  /**
   * Starts an owned Batch after validating and resolving its saved definition.
   * @param definitionId Saved Run Definition ID.
   * @param source RUN_NOW, SCHEDULED, or SUPPLIED_IDS.
   * @param scheduleId Optional owned Schedule ID.
   * @param suppliedIds Optional explicit target IDs.
   * @return Owned Batch Run ID.
   */
  public static Id start(
    Id definitionId,
    String source,
    Id scheduleId,
    List<Id> suppliedIds
  ) {
    if (definitionId == null) throw new ExecutionException('Run Definition is required.');
    if (!new Set<String>{ 'RUN_NOW', 'SCHEDULED', 'SUPPLIED_IDS' }.contains(source)) {
      throw new ExecutionException('Execution source is invalid.');
    }
    Record_Health_Check_Run_Definition__c definition = [
      SELECT Id, Active__c, SelectionType__c, QualifiedApiName__c,
        PopulationMode__c, FilterJson__c, BatchSize__c, CaptureMode__c
      FROM Record_Health_Check_Run_Definition__c
      WHERE Id = :definitionId
      WITH USER_MODE
      LIMIT 1
    ];
    if (definition.Active__c != true) throw new ExecutionException('Run Definition is inactive.');
    Boolean suppliedDefinition = 'SUPPLIED_IDS'.equals(definition.PopulationMode__c);
    if ('SUPPLIED_IDS'.equals(source) != suppliedDefinition) {
      throw new ExecutionException(
        suppliedDefinition
          ? 'Supplied-ID definitions must be launched through the packaged Flow action.'
          : 'Supplied-ID execution requires a SUPPLIED_IDS Run Definition.'
      );
    }
    Integer batchSize = definition.BatchSize__c == null ? 0 : Integer.valueOf(definition.BatchSize__c);
    if (batchSize < 1 || batchSize > 200) throw new ExecutionException('Batch Size must be between 1 and 200.');
    RHCRunManagerCoreMetadataGateway.DefinitionInfo coreInfo = RHCRunManagerCoreMetadataGateway.resolve(
      definition.SelectionType__c,
      definition.QualifiedApiName__c
    );
    RHCRunManagerFilterService.validate(coreInfo.targetObjectApiName, definition.PopulationMode__c, definition.FilterJson__c);
    List<Id> normalizedIds = normalizeIds(suppliedIds);
    if ('SUPPLIED_IDS'.equals(source) && normalizedIds.isEmpty()) {
      throw new ExecutionException('At least one supplied target record ID is required.');
    }
    Record_Health_Check_Batch_Run__c batchRun = new Record_Health_Check_Batch_Run__c(
      RunDefinition__c = definition.Id,
      Schedule__c = scheduleId,
      Source__c = source,
      Status__c = 'QUEUED',
      SubmittedRecordCount__c = 0,
      ProcessedRecordCount__c = 0,
      FailedScopeCount__c = 0,
      StartedAt__c = System.now()
    );
    Savepoint launchSavepoint = Database.setSavepoint();
    try {
      Database.insert(batchRun, AccessLevel.USER_MODE);
      if (forceLaunchFailure) throw new ExecutionException('Forced launch failure.');
      Id asyncJobId = Database.executeBatch(
        new RHCRunManagerBatch(batchRun.Id, definition, coreInfo, source, normalizedIds),
        batchSize
      );
      batchRun.AsyncApexJobId__c = String.valueOf(asyncJobId);
      Database.update(batchRun, AccessLevel.USER_MODE);
    } catch (Exception error) {
      Database.rollback(launchSavepoint);
      throw new ExecutionException('Batch execution could not be queued.');
    }
    return batchRun.Id;
  }

  /** Runs a saved definition immediately with its configured population mode. */
  public static Id runNow(Id definitionId) {
    return start(definitionId, 'RUN_NOW', null, null);
  }

  private static List<Id> normalizeIds(List<Id> recordIds) {
    Set<Id> uniqueIds = new Set<Id>();
    if (recordIds != null) uniqueIds.addAll(recordIds);
    uniqueIds.remove(null);
    List<Id> normalized = new List<Id>(uniqueIds);
    normalized.sort();
    return normalized;
  }
}
