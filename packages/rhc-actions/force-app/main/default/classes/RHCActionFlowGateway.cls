/**
 * Validates and starts approved same-org autolaunched Flows.
 */
public virtual with sharing class RHCActionFlowGateway {
  @TestVisible
  private static MetadataSource metadataSource = new MetadataSource();

  /** Queries Flow setup metadata behind a replaceable test boundary. */
  public virtual with sharing class MetadataSource {
    /**
     * Finds definitions matching one normalized Flow API name.
     *
     * @param flowApiName Flow developer name
     * @return Matching Flow definitions
     */
    public virtual List<SObject> findDefinitions(String flowApiName) {
      Map<String, Object> binds = new Map<String, Object>{
        'apiName' => flowApiName
      };
      return Database.queryWithBinds(
        'SELECT ApiName, ActiveVersionId, ProcessType FROM FlowDefinitionView WHERE ApiName = :apiName LIMIT 1',
        binds,
        AccessLevel.USER_MODE
      );
    }

    /**
     * Finds the variables declared by one active Flow version.
     *
     * @param activeVersionId Active Flow version identity
     * @return Variables declared by the active Flow version
     */
    public virtual List<SObject> findVariables(String activeVersionId) {
      Map<String, Object> binds = new Map<String, Object>{
        'versionId' => activeVersionId
      };
      return Database.queryWithBinds(
        'SELECT ApiName, DataType, IsInput, IsOutput, IsCollection FROM FlowVariableView WHERE FlowVersionViewId = :versionId',
        binds,
        AccessLevel.USER_MODE
      );
    }
  }

  /**
   * Describes one active Flow and its declared input variables.
   */
  public class FlowDescriptor {
    @AuraEnabled
    public String apiName;
    @AuraEnabled
    public String processType;
    @AuraEnabled
    public String activeVersionId;
    @AuraEnabled
    public Map<String, VariableDescriptor> variablesByName = new Map<String, VariableDescriptor>();
  }

  /**
   * Describes a Flow variable used by contract validation.
   */
  public class VariableDescriptor {
    @AuraEnabled
    public String apiName;
    @AuraEnabled
    public String dataType;
    @AuraEnabled
    public Boolean isInput;
    @AuraEnabled
    public Boolean isOutput;
    @AuraEnabled
    public Boolean isCollection;
  }

  /**
   * Describes the active version of a same-org Flow.
   *
   * @param flowApiName Flow developer name
   * @return Active Flow descriptor, or null when none is active
   */
  public virtual FlowDescriptor describeActive(String flowApiName) {
    if (String.isBlank(flowApiName)) {
      return null;
    }
    List<SObject> definitions = metadataSource.findDefinitions(
      flowApiName.trim()
    );
    if (
      definitions.isEmpty() || definitions[0].get('ActiveVersionId') == null
    ) {
      return null;
    }
    FlowDescriptor descriptor = new FlowDescriptor();
    descriptor.apiName = String.valueOf(definitions[0].get('ApiName'));
    descriptor.activeVersionId = String.valueOf(
      definitions[0].get('ActiveVersionId')
    );
    descriptor.processType = String.valueOf(definitions[0].get('ProcessType'));
    List<SObject> variables = metadataSource.findVariables(
      descriptor.activeVersionId
    );
    for (SObject variable : variables) {
      VariableDescriptor item = new VariableDescriptor();
      item.apiName = String.valueOf(variable.get('ApiName'));
      item.dataType = String.valueOf(variable.get('DataType'));
      item.isInput = Boolean.valueOf(String.valueOf(variable.get('IsInput')));
      item.isOutput = Boolean.valueOf(String.valueOf(variable.get('IsOutput')));
      item.isCollection = Boolean.valueOf(
        String.valueOf(variable.get('IsCollection'))
      );
      descriptor.variablesByName.put(item.apiName, item);
    }
    return descriptor;
  }

  /**
   * Starts an approved same-org Flow with allow-listed inputs.
   *
   * @param flowApiName Approved Flow API name
   * @param inputs Allow-listed versioned inputs
   * @return Flow interview identity
   */
  public virtual String start(String flowApiName, Map<String, Object> inputs) {
    Flow.Interview interview = Flow.Interview.createInterview(
      flowApiName,
      inputs
    );
    interview.start();
    return String.valueOf(interview.getVariableValue('rhcInterviewGuidV1'));
  }
}
