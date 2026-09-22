/** Shared launch path for Run Now, schedules, and supplied-ID requests. */
public with sharing class RHCRunManagerExecutionService {
  private static final String SUPPLIED_IDS = 'SUPPLIED_IDS';
  private static final Set<String> EXECUTION_SOURCES = new Set<String>{
    'RUN_NOW', 'SCHEDULED', SUPPLIED_IDS
  };
  @TestVisible private static Boolean forceLaunchFailure = false;

  /** Inputs required to launch one owned Batch Run. */
  public class Request {
    public Id definitionId;
    public String source;
    public Id scheduleId;
    public List<Id> suppliedIds;
  }

  /** Invalid execution request. */
  public class ExecutionException extends Exception {
  }

  /**
   * Starts an owned Batch after validating and resolving its saved definition.
   * @param request Saved definition, source, optional schedule, and optional supplied IDs.
   * @return Owned Batch Run ID.
   */
  public static Id start(Request request) {
    validateStartRequest(request);
    Record_Health_Check_Run_Definition__c definition = loadDefinition(request.definitionId);
    validateDefinition(definition, request.source);
    Integer batchSize = validatedBatchSize(definition.BatchSize__c);
    RHCRunManagerCoreMetadataGateway.DefinitionInfo coreInfo = RHCRunManagerCoreMetadataGateway.resolve(
      definition.SelectionType__c,
      definition.QualifiedApiName__c
    );
    RHCRunManagerFilterService.validate(coreInfo.targetObjectApiName, definition.PopulationMode__c, definition.FilterJson__c);
    List<Id> normalizedIds = normalizeIds(request.suppliedIds);
    validateSuppliedIds(request.source, normalizedIds);
    Record_Health_Check_Batch_Run__c batchRun = newBatchRun(definition.Id, request.scheduleId, request.source);
    Savepoint launchSavepoint = Database.setSavepoint();
    try {
      Database.insert(batchRun, AccessLevel.USER_MODE);
      if (forceLaunchFailure) {
        throw new ExecutionException('Forced launch failure.');
      }
      RHCRunManagerBatch.LaunchRequest launchRequest = new RHCRunManagerBatch.LaunchRequest();
      launchRequest.batchRunId = batchRun.Id;
      launchRequest.definition = definition;
      launchRequest.coreInfo = coreInfo;
      launchRequest.source = request.source;
      launchRequest.suppliedIds = normalizedIds;
      Id asyncJobId = Database.executeBatch(
        new RHCRunManagerBatch(launchRequest),
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

  private static void validateStartRequest(Request request) {
    if (request == null || request.definitionId == null) {
      throw new ExecutionException('Run Definition is required.');
    }
    if (!EXECUTION_SOURCES.contains(request.source)) {
      throw new ExecutionException('Execution source is invalid.');
    }
  }

  private static Record_Health_Check_Run_Definition__c loadDefinition(Id definitionId) {
    return [
      SELECT Id, Active__c, SelectionType__c, QualifiedApiName__c,
        PopulationMode__c, FilterJson__c, BatchSize__c, CaptureMode__c
      FROM Record_Health_Check_Run_Definition__c
      WHERE Id = :definitionId
      WITH USER_MODE
      LIMIT 1
    ];
  }

  private static void validateDefinition(
    Record_Health_Check_Run_Definition__c definition,
    String source
  ) {
    if (definition.Active__c != true) {
      throw new ExecutionException('Run Definition is inactive.');
    }
    Boolean suppliedDefinition = SUPPLIED_IDS.equals(definition.PopulationMode__c);
    if (SUPPLIED_IDS.equals(source) != suppliedDefinition) {
      throw new ExecutionException(
        suppliedDefinition
          ? 'Supplied-ID definitions must be launched through the packaged Flow action.'
          : 'Supplied-ID execution requires a SUPPLIED_IDS Run Definition.'
      );
    }
    // Supplied-ID launches are already serialized per definition by the coalescer.
    if (!SUPPLIED_IDS.equals(source) && hasActiveBatchRun(definition.Id)) {
      throw new ExecutionException('A Batch Run for this Run Definition is already in progress.');
    }
  }

  private static Integer validatedBatchSize(Decimal configuredBatchSize) {
    Integer batchSize = configuredBatchSize == null ? 0 : Integer.valueOf(configuredBatchSize);
    if (batchSize < 1 || batchSize > 200) {
      throw new ExecutionException('Batch Size must be between 1 and 200.');
    }
    return batchSize;
  }

  private static void validateSuppliedIds(String source, List<Id> normalizedIds) {
    if (SUPPLIED_IDS.equals(source) && normalizedIds.isEmpty()) {
      throw new ExecutionException('At least one supplied target record ID is required.');
    }
  }

  private static Record_Health_Check_Batch_Run__c newBatchRun(
    Id definitionId,
    Id scheduleId,
    String source
  ) {
    return new Record_Health_Check_Batch_Run__c(
      RunDefinition__c = definitionId,
      Schedule__c = scheduleId,
      Source__c = source,
      Status__c = 'QUEUED',
      SubmittedRecordCount__c = 0,
      ProcessedRecordCount__c = 0,
      FailedScopeCount__c = 0,
      StartedAt__c = System.now()
    );
  }

  private static Boolean hasActiveBatchRun(Id definitionId) {
    return ![
      SELECT Id
      FROM Record_Health_Check_Batch_Run__c
      WHERE RunDefinition__c = :definitionId AND Status__c IN ('QUEUED', 'PROCESSING')
      WITH USER_MODE
      LIMIT 1
    ].isEmpty();
  }

  /**
   * Runs a saved definition immediately with its configured population mode.
   * @param definitionId Saved Run Definition ID.
   * @return Created Batch Run ID.
   */
  public static Id runNow(Id definitionId) {
    Request request = new Request();
    request.definitionId = definitionId;
    request.source = 'RUN_NOW';
    return start(request);
  }

  private static List<Id> normalizeIds(List<Id> recordIds) {
    Set<Id> uniqueIds = new Set<Id>();
    if (recordIds != null) {
      uniqueIds.addAll(recordIds);
    }
    uniqueIds.remove(null);
    List<Id> normalized = new List<Id>(uniqueIds);
    normalized.sort();
    return normalized;
  }
}
