/**
 * Verifies fail-closed Flow eligibility and input-contract validation.
 */
@IsTest
private class RHCActionPolicyServiceTest {
  private class MetadataSourceStub extends RHCActionFlowGateway.MetadataSource {
    public override List<SObject> findDefinitions(String flowApiName) {
      return new List<SObject>{
        flowMetadataRow(
          'FlowDefinitionView',
          new Map<String, Object>{
            'ApiName' => flowApiName,
            'ActiveVersionId' => RHCActionTestDataFactory.syntheticId('301'),
            'ProcessType' => 'AutoLaunchedFlow'
          }
        )
      };
    }

    public override List<SObject> findVariables(String activeVersionId) {
      return new List<SObject>{
        flowMetadataRow(
          'FlowVariableView',
          new Map<String, Object>{
            'ApiName' => 'recordIdV1',
            'DataType' => 'String',
            'IsInput' => true,
            'IsOutput' => false,
            'IsCollection' => false
          }
        )
      };
    }
  }

  private class GatewayStub extends RHCActionFlowGateway {
    private String processType;
    private Boolean active;
    private Boolean includeUnknown;

    GatewayStub(String processType, Boolean active, Boolean includeUnknown) {
      this.processType = processType;
      this.active = active;
      this.includeUnknown = includeUnknown;
    }

    public override FlowDescriptor describeActive(String flowApiName) {
      if (!active) {
        return null;
      }
      FlowDescriptor descriptor = new FlowDescriptor();
      descriptor.apiName = flowApiName;
      descriptor.activeVersionId = RHCActionTestDataFactory.syntheticId('301');
      descriptor.processType = processType;
      for (String name : RHCActionConstants.allowedFlowInputs()) {
        VariableDescriptor variable = new VariableDescriptor();
        variable.apiName = name;
        variable.dataType = 'String';
        variable.isInput = true;
        variable.isOutput = false;
        variable.isCollection = false;
        descriptor.variablesByName.put(name, variable);
      }
      if (includeUnknown) {
        VariableDescriptor unknown = new VariableDescriptor();
        unknown.apiName = 'rawPayload';
        unknown.dataType = 'String';
        unknown.isInput = true;
        unknown.isOutput = false;
        unknown.isCollection = false;
        descriptor.variablesByName.put(unknown.apiName, unknown);
      }
      VariableDescriptor interview = new VariableDescriptor();
      interview.apiName = 'rhcInterviewGuidV1';
      interview.dataType = 'String';
      interview.isInput = false;
      interview.isOutput = true;
      interview.isCollection = false;
      descriptor.variablesByName.put(interview.apiName, interview);
      return descriptor;
    }
  }

  @IsTest
  static void shouldAcceptWhenActiveAutolaunchedContractMatches() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionPolicyService.gateway = new GatewayStub(
        'AutoLaunchedFlow',
        true,
        false
      );
      Test.startTest();
      RHCActionPolicyService.ValidationResult result = RHCActionPolicyService.validate(
        RHCActionTestDataFactory.policy()
      );
      Test.stopTest();
      Assert.isTrue(
        result.valid,
        'The exact version-one contract should be eligible.'
      );
    }
  }

  @IsTest
  static void shouldRejectWhenFlowHasNoActiveVersion() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionPolicyService.gateway = new GatewayStub(
        'AutoLaunchedFlow',
        false,
        false
      );
      Test.startTest();
      RHCActionPolicyService.ValidationResult result = RHCActionPolicyService.validate(
        RHCActionTestDataFactory.policy()
      );
      Test.stopTest();
      Assert.isFalse(result.valid, 'An inactive Flow must fail closed.');
    }
  }

  @IsTest
  static void shouldRejectWhenFlowIsNotAutolaunched() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionPolicyService.gateway = new GatewayStub('Flow', true, false);
      RHCActionPolicyService.ValidationResult result = RHCActionPolicyService.validate(
        RHCActionTestDataFactory.policy()
      );
      Assert.isFalse(result.valid, 'A screen Flow must be ineligible.');
    }
  }

  @IsTest
  static void shouldRejectWhenFlowDeclaresArbitraryInput() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionPolicyService.gateway = new GatewayStub(
        'AutoLaunchedFlow',
        true,
        true
      );
      RHCActionPolicyService.ValidationResult result = RHCActionPolicyService.validate(
        RHCActionTestDataFactory.policy()
      );
      Assert.isFalse(
        result.valid,
        'Arbitrary input variables must be rejected.'
      );
      Assert.isTrue(
        String.join(result.errors, ' ').contains('rawPayload'),
        'The rejected variable should be named safely.'
      );
    }
  }

  @IsTest
  static void shouldRejectWhenAutomaticPolicyLacksExplicitOptIn() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHC_Action_Policy__c policy = RHCActionTestDataFactory.policy();
      policy.Mode__c = 'AUTOMATIC';
      policy.Auto_Execution_Enabled__c = false;
      RHCActionPolicyService.gateway = new GatewayStub(
        'AutoLaunchedFlow',
        true,
        false
      );
      RHCActionPolicyService.ValidationResult result = RHCActionPolicyService.validate(
        policy
      );
      Assert.isFalse(
        result.valid,
        'Automatic mode must require the policy opt-in.'
      );
    }
  }

  @IsTest
  static void shouldReturnNullWhenGatewayFlowNameIsBlank() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      RHCActionFlowGateway.FlowDescriptor descriptor = new RHCActionFlowGateway()
        .describeActive(' ');
      Test.stopTest();
      Assert.isNull(
        descriptor,
        'A blank Flow name must not query setup metadata.'
      );
    }
  }

  @IsTest
  static void shouldReturnNullWhenGatewayFlowDoesNotExist() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      RHCActionFlowGateway.FlowDescriptor descriptor = new RHCActionFlowGateway()
        .describeActive('RHC_Actions_Definitely_Missing');
      Test.stopTest();
      Assert.isNull(descriptor, 'An unknown Flow must not appear eligible.');
    }
  }

  @IsTest
  static void shouldDescribeActiveFlowThroughMetadataBoundary() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHCActionFlowGateway.metadataSource = new MetadataSourceStub();

      Test.startTest();
      RHCActionFlowGateway.FlowDescriptor descriptor = new RHCActionFlowGateway()
        .describeActive(' Example_Autolaunched_Flow ');
      Test.stopTest();

      Assert.areEqual(
        'Example_Autolaunched_Flow',
        descriptor.apiName,
        'The Flow name must be normalized.'
      );
      Assert.areEqual(
        'AutoLaunchedFlow',
        descriptor.processType,
        'The process type must be retained.'
      );
      Assert.areEqual(
        1,
        descriptor.variablesByName.size(),
        'Every declared variable must be described.'
      );
      RHCActionFlowGateway.VariableDescriptor variable = descriptor.variablesByName.get(
        'recordIdV1'
      );
      Assert.isTrue(
        variable.isInput,
        'The input contract flag must be retained.'
      );
      Assert.isFalse(
        variable.isOutput,
        'The output contract flag must be retained.'
      );
      Assert.isFalse(
        variable.isCollection,
        'Scalar contract variables must remain scalar.'
      );
    }
  }

  @IsTest
  static void shouldReturnNoVariablesForUnknownFlowVersion() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      List<SObject> variables = new RHCActionFlowGateway.MetadataSource()
        .findVariables(RHCActionTestDataFactory.syntheticId('301'));
      Test.stopTest();
      Assert.areEqual(
        0,
        variables.size(),
        'An unknown Flow version must not expose an input contract.'
      );
    }
  }

  @IsTest
  static void shouldRejectWhenPolicyBasicsAreUnsafe() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      RHC_Action_Policy__c policy = RHCActionTestDataFactory.policy();
      policy.Active__c = false;
      policy.Check_Qualified_API_Name__c = null;
      policy.Matching_Statuses__c = null;
      policy.Mode__c = 'UNKNOWN';
      policy.Cooldown_Minutes__c = 0;
      policy.Retry_Limit__c = 4;
      policy.Input_Contract_Version__c = '2.0';
      policy.Flow_API_Name__c = null;
      RHCActionPolicyService.ValidationResult result = RHCActionPolicyService.validate(
        policy
      );
      Assert.isFalse(
        result.valid,
        'Unsafe policy basics must fail before Flow execution.'
      );
      Assert.isTrue(
        result.errors.size() >= 7,
        'Every independent policy defect should be reported.'
      );
    }
  }

  private static SObject flowMetadataRow(
    String typeName,
    Map<String, Object> fieldValues
  ) {
    Map<String, Object> serializedValues = new Map<String, Object>(fieldValues);
    serializedValues.put(
      'attributes',
      new Map<String, Object>{ 'type' => typeName }
    );
    return (SObject) JSON.deserialize(
      JSON.serialize(serializedValues),
      SObject.class
    );
  }
}
