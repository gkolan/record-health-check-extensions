/**
 * Validates policy safety, Flow eligibility, and the versioned input contract.
 */
// Individual methods remain below PMD complexity thresholds; the aggregate
// class score reflects validation of every independent policy invariant.
@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class RHCActionPolicyService {
  @TestVisible
  private static RHCActionFlowGateway gateway = new RHCActionFlowGateway();

  /** Result returned to administrators and execution callers. */
  public class ValidationResult {
    @AuraEnabled
    public Boolean valid = true;
    @AuraEnabled
    public List<String> errors = new List<String>();

    /** @param message Safe validation failure */
    public void reject(String message) {
      valid = false;
      errors.add(message);
    }
  }

  /**
   * @param policy Policy to validate
   * @return Complete validation result
   */
  public static ValidationResult validate(RHC_Action_Policy__c policy) {
    ValidationResult result = new ValidationResult();
    if (policy == null) {
      result.reject('Policy is required.');
      return result;
    }
    validatePolicyFields(policy, result);
    if (String.isBlank(policy.Flow_API_Name__c)) {
      return result;
    }
    RHCActionFlowGateway.FlowDescriptor descriptor = describeFlow(
      policy.Flow_API_Name__c,
      result
    );
    if (descriptor == null) {
      return result;
    }
    validateFlowType(descriptor, result);
    validateDeclaredInputs(descriptor, result);
    validateSelectedInputs(policy, descriptor, result);
    validateInterviewOutput(descriptor, result);
    return result;
  }

  private static void validatePolicyFields(
    RHC_Action_Policy__c policy,
    ValidationResult result
  ) {
    validateIdentityAndMode(policy, result);
    validateLimitsAndContract(policy, result);
  }

  private static void validateIdentityAndMode(
    RHC_Action_Policy__c policy,
    ValidationResult result
  ) {
    if (policy.Active__c != true) {
      result.reject('Policy must be active.');
    }
    if (String.isBlank(policy.Check_Qualified_API_Name__c)) {
      result.reject('Check Qualified API Name is required.');
    }
    if (String.isBlank(policy.Matching_Statuses__c)) {
      result.reject('At least one matching status is required.');
    }
    if (!isSupportedMode(policy.Mode__c)) {
      result.reject('Mode must be MANUAL_APPROVAL or AUTOMATIC.');
    }
    if (
      policy.Mode__c == RHCActionConstants.MODE_AUTOMATIC &&
      policy.Auto_Execution_Enabled__c != true
    ) {
      result.reject('Automatic mode requires the explicit policy opt-in.');
    }
  }

  private static void validateLimitsAndContract(
    RHC_Action_Policy__c policy,
    ValidationResult result
  ) {
    if (policy.Cooldown_Minutes__c == null || policy.Cooldown_Minutes__c < 1) {
      result.reject('Cooldown must be at least one minute.');
    }
    if (!isSupportedRetryLimit(policy.Retry_Limit__c)) {
      result.reject('Retry limit must be between zero and three.');
    }
    if (
      policy.Input_Contract_Version__c !=
      RHCActionConstants.FLOW_CONTRACT_VERSION
    ) {
      result.reject('Only Flow input contract version 1.0 is supported.');
    }
    if (String.isBlank(policy.Flow_API_Name__c)) {
      result.reject('Flow API Name is required.');
    }
  }

  private static Boolean isSupportedMode(String mode) {
    return mode == RHCActionConstants.MODE_MANUAL ||
      mode == RHCActionConstants.MODE_AUTOMATIC;
  }

  private static Boolean isSupportedRetryLimit(Decimal retryLimit) {
    return retryLimit != null &&
      retryLimit >= 0 &&
      retryLimit <= RHCActionConstants.MAX_RETRY_LIMIT;
  }

  private static RHCActionFlowGateway.FlowDescriptor describeFlow(
    String flowApiName,
    ValidationResult result
  ) {
    try {
      RHCActionFlowGateway.FlowDescriptor descriptor = gateway.describeActive(
        flowApiName
      );
      if (descriptor == null || String.isBlank(descriptor.activeVersionId)) {
        result.reject('The Flow has no active version.');
        return null;
      }
      return descriptor;
    } catch (Exception ex) {
      result.reject(
        'Flow metadata could not be inspected with the current execution identity.'
      );
      return null;
    }
  }

  private static void validateFlowType(
    RHCActionFlowGateway.FlowDescriptor descriptor,
    ValidationResult result
  ) {
    if (descriptor.processType != 'AutoLaunchedFlow') {
      result.reject('Only autolaunched Flows are eligible.');
    }
  }

  private static void validateDeclaredInputs(
    RHCActionFlowGateway.FlowDescriptor descriptor,
    ValidationResult result
  ) {
    Set<String> allowedInputs = RHCActionConstants.allowedFlowInputs();
    for (String declaredName : descriptor.variablesByName.keySet()) {
      RHCActionFlowGateway.VariableDescriptor declared = descriptor.variablesByName.get(
        declaredName
      );
      if (declared.isInput == true && !allowedInputs.contains(declaredName)) {
        result.reject(
          'Flow declares an input outside the RHC Actions contract: ' +
          declaredName
        );
      }
    }
  }

  private static void validateSelectedInputs(
    RHC_Action_Policy__c policy,
    RHCActionFlowGateway.FlowDescriptor descriptor,
    ValidationResult result
  ) {
    for (String selectedName : selectedInputs(policy)) {
      RHCActionFlowGateway.VariableDescriptor variable = descriptor.variablesByName.get(
        selectedName
      );
      if (!isTextInput(variable)) {
        result.reject(
          'Mapped input must be a non-collection Text input: ' + selectedName
        );
      }
    }
  }

  private static Boolean isTextInput(
    RHCActionFlowGateway.VariableDescriptor variable
  ) {
    return variable != null &&
      variable.isInput == true &&
      variable.isCollection != true &&
      variable.dataType == 'String';
  }

  private static void validateInterviewOutput(
    RHCActionFlowGateway.FlowDescriptor descriptor,
    ValidationResult result
  ) {
    RHCActionFlowGateway.VariableDescriptor variable = descriptor.variablesByName.get(
      'rhcInterviewGuidV1'
    );
    if (
      variable == null ||
      variable.isOutput != true ||
      variable.isCollection == true ||
      variable.dataType != 'String'
    ) {
      result.reject(
        'Flow must expose rhcInterviewGuidV1 as a non-collection Text output.'
      );
    }
  }

  /**
   * @param policy Policy mapping selections
   * @return Selected version-one input names
   */
  public static Set<String> selectedInputs(RHC_Action_Policy__c policy) {
    Set<String> selected = new Set<String>();
    if (policy.Map_Record_Id__c == true) {
      selected.add('rhcRecordIdV1');
    }
    if (policy.Map_Run_Id__c == true) {
      selected.add('rhcRunIdV1');
    }
    if (policy.Map_Check_Set__c == true) {
      selected.add('rhcCheckSetQualifiedApiNameV1');
    }
    if (policy.Map_Check__c == true) {
      selected.add('rhcCheckQualifiedApiNameV1');
    }
    if (policy.Map_Status__c == true) {
      selected.add('rhcStatusV1');
    }
    if (policy.Map_Severity__c == true) {
      selected.add('rhcSeverityV1');
    }
    if (policy.Map_Reason_Code__c == true) {
      selected.add('rhcReasonCodeV1');
    }
    if (policy.Map_Event_Id__c == true) {
      selected.add('rhcEventIdV1');
    }
    return selected;
  }
}
