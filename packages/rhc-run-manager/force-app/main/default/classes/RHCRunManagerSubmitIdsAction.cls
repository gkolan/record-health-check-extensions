/** Bulk Flow action that stages related target IDs for cross-transaction coalescing. */
public with sharing class RHCRunManagerSubmitIdsAction {
  @TestVisible private static Boolean suppressCoalescer = false;
  /**
   * Stages supplied IDs and enqueues at most one coalescer per definition.
   * @param requests Flow requests containing a Run Definition and target IDs.
   * @return One outcome for each input request, in the original order.
   */
  @InvocableMethod(
    label='Submit Record IDs to RHC Run Manager'
    description='Stages current, prior, or collection target IDs for one saved Run Definition.'
    category='Record Health Check'
  )
  public static List<Response> submit(List<Request> requests) {
    List<Response> responses = new List<Response>();
    if (requests == null) {
      return responses;
    }
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
    ValidationContext validationContext = new ValidationContext(
      definitionsById,
      Schema.getGlobalDescribe(),
      idsByDefinition
    );
    RequestValidator validator = new RequestValidator(validationContext);
    for (Request requestValue : requests) {
      responses.add(validator.validateAndCollect(requestValue));
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
      if (requestValue?.runDefinitionId != null) {
        result.add(requestValue.runDefinitionId);
      }
    }
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
    List<Record_Health_Check_Run_Request__c> rows = buildRequestRows(idsByDefinition);
    upsertRequestRows(rows);
    enqueueDefinitions(idsByDefinition);
  }

  private static List<Record_Health_Check_Run_Request__c> buildRequestRows(
    Map<Id, Set<Id>> idsByDefinition
  ) {
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
    return rows;
  }

  private static void upsertRequestRows(List<Record_Health_Check_Run_Request__c> rows) {
    if (rows.isEmpty()) {
      return;
    }
    List<Database.UpsertResult> results = Database.upsert(
      rows,
      Record_Health_Check_Run_Request__c.Fields.RequestKey__c,
      false,
      AccessLevel.USER_MODE
    );
    for (Database.UpsertResult result : results) {
      if (!result.isSuccess()) {
        throw new StagingException('One or more supplied IDs could not be staged.');
      }
    }
  }

  private static void enqueueDefinitions(Map<Id, Set<Id>> idsByDefinition) {
    for (Id definitionId : idsByDefinition.keySet()) {
      if (!suppressCoalescer && !idsByDefinition.get(definitionId).isEmpty()) {
        RHCRunManagerCoalescerQueueable.enqueue(definitionId);
      }
    }
  }

  private static void reject(Response response, String errorType, String errorMessage) {
    response.isSuccess = false;
    response.acceptedRecordCount = 0;
    response.errorType = errorType;
    response.errorMessage = errorMessage;
  }

  private class StagingException extends Exception {}

  private class ValidationContext {
    private Map<Id, Record_Health_Check_Run_Definition__c> definitionsById;
    private Map<String, Schema.SObjectType> globalDescribe;
    private Map<Id, Set<Id>> idsByDefinition;

    private ValidationContext(
      Map<Id, Record_Health_Check_Run_Definition__c> definitionsById,
      Map<String, Schema.SObjectType> globalDescribe,
      Map<Id, Set<Id>> idsByDefinition
    ) {
      this.definitionsById = definitionsById;
      this.globalDescribe = globalDescribe;
      this.idsByDefinition = idsByDefinition;
    }
  }

  private class RequestValidator {
    private ValidationContext validationContext;

    private RequestValidator(ValidationContext validationContext) {
      this.validationContext = validationContext;
    }

    private Response validateAndCollect(Request requestValue) {
      Response response = new Response();
      Record_Health_Check_Run_Definition__c definition = validateDefinition(requestValue, response);
      if (definition == null) {
        return response;
      }
      Set<Id> targetIds = requestIds(requestValue);
      if (!validateTargetIds(targetIds, definition, response)) {
        return response;
      }
      collect(requestValue.runDefinitionId, targetIds);
      response.isSuccess = true;
      response.acceptedRecordCount = targetIds.size();
      return response;
    }

    private Record_Health_Check_Run_Definition__c validateDefinition(
      Request requestValue,
      Response response
    ) {
      if (requestValue == null || requestValue.runDefinitionId == null) {
        reject(response, 'INVALID_INPUT', 'Run Definition is required.');
        return null;
      }
      Record_Health_Check_Run_Definition__c definition = validationContext.definitionsById.get(
        requestValue.runDefinitionId
      );
      if (definition == null) {
        reject(response, 'DEFINITION_UNAVAILABLE', 'Run Definition is unavailable.');
        return null;
      }
      if (definition.Active__c != true || !'SUPPLIED_IDS'.equals(definition.PopulationMode__c)) {
        reject(response, 'INVALID_DEFINITION', 'Run Definition must be active and use supplied IDs.');
        return null;
      }
      return definition;
    }

    private Boolean validateTargetIds(
      Set<Id> targetIds,
      Record_Health_Check_Run_Definition__c definition,
      Response response
    ) {
      if (targetIds.isEmpty()) {
        reject(response, 'INVALID_INPUT', 'At least one Target Record ID is required.');
        return false;
      }
      Schema.SObjectType expectedType = validationContext.globalDescribe.get(
        definition.TargetObjectApiName__c
      );
      if (expectedType == null) {
        reject(response, 'INVALID_DEFINITION', 'Run Definition target object is unavailable.');
        return false;
      }
      if (!allIdsMatchType(targetIds, expectedType)) {
        reject(response, 'INVALID_TARGET_TYPE', 'Every Target Record ID must match the Run Definition target object.');
        return false;
      }
      return true;
    }

    private Set<Id> requestIds(Request requestValue) {
      Set<Id> result = new Set<Id>{ requestValue.targetRecordId, requestValue.priorTargetRecordId };
      if (requestValue.targetRecordIds != null) {
        result.addAll(requestValue.targetRecordIds);
      }
      result.remove(null);
      return result;
    }

    private Boolean allIdsMatchType(Set<Id> targetIds, Schema.SObjectType expectedType) {
      for (Id targetId : targetIds) {
        if (targetId.getSObjectType() != expectedType) {
          return false;
        }
      }
      return true;
    }

    private void collect(Id definitionId, Set<Id> targetIds) {
      if (!validationContext.idsByDefinition.containsKey(definitionId)) {
        validationContext.idsByDefinition.put(definitionId, new Set<Id>());
      }
      validationContext.idsByDefinition.get(definitionId).addAll(targetIds);
    }
  }

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
