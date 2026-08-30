/** Bulk Flow action that stages related target IDs for cross-transaction coalescing. */
public with sharing class RHCRunManagerSubmitIdsAction {
  @TestVisible private static Boolean suppressCoalescer = false;
  /** Stages supplied IDs and enqueues at most one coalescer per definition. */
  @InvocableMethod(
    label='Submit Record IDs to RHC Run Manager'
    description='Stages current, prior, or collection target IDs for one saved Run Definition.'
    category='Record Health Check'
  )
  public static List<Response> submit(List<Request> requests) {
    List<Response> responses = new List<Response>();
    if (requests == null) return responses;
    Set<Id> requestedDefinitionIds = definitionIds(requests);
    Map<Id, Record_Health_Check_Run_Definition__c> definitionsById;
    try {
      definitionsById = new Map<Id, Record_Health_Check_Run_Definition__c>([
        SELECT Id, Active__c, PopulationMode__c, TargetObjectApiName__c
        FROM Record_Health_Check_Run_Definition__c
        WHERE Id IN :requestedDefinitionIds
        WITH USER_MODE
      ]);
    } catch (Exception error) {
      return rejectedResponses(requests.size(), 'DEFINITION_ACCESS_ERROR', 'Run Definitions could not be validated.');
    }
    Map<Id, Set<Id>> idsByDefinition = new Map<Id, Set<Id>>();
    Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    for (Request requestValue : requests) {
      responses.add(validateAndCollect(requestValue, definitionsById, globalDescribe, idsByDefinition));
    }
    Savepoint stagingSavepoint = Database.setSavepoint();
    try {
      stage(idsByDefinition);
    } catch (Exception error) {
      Database.rollback(stagingSavepoint);
      for (Response response : responses) {
        if (response.isSuccess == true) {
          response.isSuccess = false;
          response.errorType = 'STAGING_ERROR';
          response.errorMessage = 'Supplied IDs could not be staged.';
          response.acceptedRecordCount = 0;
        }
      }
    }
    return responses;
  }

  private static Set<Id> definitionIds(List<Request> requests) {
    Set<Id> result = new Set<Id>();
    for (Request requestValue : requests) {
      if (requestValue?.runDefinitionId != null) result.add(requestValue.runDefinitionId);
    }
    return result;
  }

  private static Response validateAndCollect(
    Request requestValue,
    Map<Id, Record_Health_Check_Run_Definition__c> definitionsById,
    Map<String, Schema.SObjectType> globalDescribe,
    Map<Id, Set<Id>> idsByDefinition
  ) {
    Response response = new Response();
    if (requestValue == null || requestValue.runDefinitionId == null) {
      reject(response, 'INVALID_INPUT', 'Run Definition is required.');
      return response;
    }
    Record_Health_Check_Run_Definition__c definition = definitionsById.get(requestValue.runDefinitionId);
    if (definition == null) {
      reject(response, 'DEFINITION_UNAVAILABLE', 'Run Definition is unavailable.');
      return response;
    }
    if (definition.Active__c != true || !'SUPPLIED_IDS'.equals(definition.PopulationMode__c)) {
      reject(response, 'INVALID_DEFINITION', 'Run Definition must be active and use supplied IDs.');
      return response;
    }
    Set<Id> requestIds = requestIds(requestValue);
    if (requestIds.isEmpty()) {
      reject(response, 'INVALID_INPUT', 'At least one Target Record ID is required.');
      return response;
    }
    Schema.SObjectType expectedType = globalDescribe.get(definition.TargetObjectApiName__c);
    if (expectedType == null) {
      reject(response, 'INVALID_DEFINITION', 'Run Definition target object is unavailable.');
      return response;
    }
    for (Id targetId : requestIds) {
      if (targetId.getSObjectType() != expectedType) {
        reject(response, 'INVALID_TARGET_TYPE', 'Every Target Record ID must match the Run Definition target object.');
        return response;
      }
    }
    if (!idsByDefinition.containsKey(requestValue.runDefinitionId)) {
      idsByDefinition.put(requestValue.runDefinitionId, new Set<Id>());
    }
    idsByDefinition.get(requestValue.runDefinitionId).addAll(requestIds);
    response.isSuccess = true;
    response.acceptedRecordCount = requestIds.size();
    return response;
  }

  private static Set<Id> requestIds(Request requestValue) {
    Set<Id> result = new Set<Id>{ requestValue.targetRecordId, requestValue.priorTargetRecordId };
    if (requestValue.targetRecordIds != null) result.addAll(requestValue.targetRecordIds);
    result.remove(null);
    return result;
  }

  private static List<Response> rejectedResponses(Integer size, String errorType, String errorMessage) {
    List<Response> responses = new List<Response>();
    for (Integer responseIndex = 0; responseIndex < size; responseIndex++) {
      Response response = new Response();
      reject(response, errorType, errorMessage);
      responses.add(response);
    }
    return responses;
  }

  private static void stage(Map<Id, Set<Id>> idsByDefinition) {
    List<Record_Health_Check_Run_Request__c> rows = new List<Record_Health_Check_Run_Request__c>();
    for (Id definitionId : idsByDefinition.keySet()) {
      for (Id targetId : idsByDefinition.get(definitionId)) {
        rows.add(new Record_Health_Check_Run_Request__c(
          RunDefinition__c = definitionId,
          RequestKey__c = definitionId + '|' + targetId,
          RecordId__c = String.valueOf(targetId),
          Status__c = 'PENDING',
          RequestedAt__c = System.now()
        ));
      }
    }
    if (!rows.isEmpty()) {
      List<Database.UpsertResult> results = Database.upsert(
        rows,
        Record_Health_Check_Run_Request__c.Fields.RequestKey__c,
        false,
        AccessLevel.USER_MODE
      );
      Integer failureCount = 0;
      for (Database.UpsertResult result : results) {
        if (!result.isSuccess()) failureCount++;
      }
      if (failureCount > 0) {
        throw new StagingException('One or more supplied IDs could not be staged.');
      }
    }
    for (Id definitionId : idsByDefinition.keySet()) {
      if (!suppressCoalescer && !idsByDefinition.get(definitionId).isEmpty()) RHCRunManagerCoalescerQueueable.enqueue(definitionId);
    }
  }

  private static void reject(Response response, String errorType, String errorMessage) {
    response.isSuccess = false;
    response.acceptedRecordCount = 0;
    response.errorType = errorType;
    response.errorMessage = errorMessage;
  }

  private class StagingException extends Exception {}

  /** Flow inputs. Current and prior IDs support related-record change handling. */
  public class Request {
    @InvocableVariable(label='Run Definition ID' required=true)
    public Id runDefinitionId;
    @InvocableVariable(label='Target Record ID')
    public Id targetRecordId;
    @InvocableVariable(label='Prior Target Record ID')
    public Id priorTargetRecordId;
    @InvocableVariable(label='Target Record IDs')
    public List<Id> targetRecordIds;
  }

  /** Flow outcome for each input. */
  public class Response {
    @InvocableVariable(label='Success') public Boolean isSuccess;
    @InvocableVariable(label='Accepted Record Count') public Integer acceptedRecordCount;
    @InvocableVariable(label='Error Message') public String errorMessage;
    @InvocableVariable(label='Error Type') public String errorType;
  }
}
