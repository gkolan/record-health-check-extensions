/**
 * Supplies the Builder's supported choices, complete-version validation, and publication plan.
 * This class belongs to RHC Builder; the core package does not know about it.
 */
@SuppressWarnings('PMD.CyclomaticComplexity')
// Each branch checks one separate Builder answer. Keeping those checks together makes
// the complete-version rules easier for a Salesforce administrator or developer to review.
public inherited sharing class RecordHealthCheckBuilderContract implements Callable {
  private static final String CONTRACT_VERSION = '1.0';
  private static final String CORE_NAMESPACE = 'rhc';
  private static final Integer SCHEMA_VERSION = 1;
  private static final Integer MAX_CHECKS = 25;
  private static final Set<String> EVALUATION_TYPES = new Set<String>{
    'FORMULA',
    'QUERY',
    'COMPARE_TWO_QUERIES',
    'APEX'
  };
  private static final Set<String> SEVERITIES = new Set<String>{
    'CRITICAL',
    'WARNING',
    'INFO'
  };
  private static final Set<String> COMPARISON_OPERATORS = new Set<String>{
    'EQUALS',
    'NOT_EQUALS',
    'GREATER_THAN',
    'GREATER_THAN_OR_EQUAL',
    'LESS_THAN',
    'LESS_THAN_OR_EQUAL',
    'CONTAINS',
    'DOES_NOT_CONTAIN',
    'IS_BLANK',
    'IS_NOT_BLANK',
    'LIST_CONTAINS_ANY',
    'LIST_CONTAINS_NONE',
    'LISTS_OVERLAP',
    'LISTS_CONTAIN_ALL',
    'LISTS_MATCH_EXACTLY'
  };
  private static final Set<String> EXPECTED_VALUE_SOURCES = new Set<String>{
    'FIXED_VALUE',
    'RECORD_FORMULA',
    'COMPARISON_QUERY'
  };
  private static final Set<String> QUERY_RESULT_HANDLING = new Set<String>{
    'ONE_RESULT',
    'ANY_ROW_PASSES',
    'ALL_ROWS_PASS',
    'COMPARE_AS_LISTS'
  };
  private static final Set<String> EMPTY_RESULTS = new Set<String>{
    'PASS',
    'FAIL',
    'SKIP',
    'UNABLE_TO_EVALUATE'
  };
  private static final Set<String> EMPTY_VALUE_HANDLING = new Set<String>{
    'AS_NO_MATCH',
    'SKIP_RECORD',
    'AS_BLANK'
  };
  private static final Set<String> APPLICABILITY_OPERATORS = new Set<String>{
    'EQUALS',
    'NOT_EQUALS',
    'GREATER_THAN',
    'GREATER_THAN_OR_EQUAL',
    'LESS_THAN',
    'LESS_THAN_OR_EQUAL'
  };
  private static final Set<String> APPLICABILITY_MODES = new Set<String>{
    'ALL_RECORDS',
    'WHEN_FORMULA_TRUE',
    'WHEN_COUNT_QUERY_MATCHES'
  };

  /** Builder validation or publication request that cannot be completed safely. */
  public class BuilderContractException extends Exception {
  }

  /**
   * Runs one supported Builder action.
   * @param action Requested action name.
   * @param arguments Values required by that action.
   * @return JSON for the Builder screen, validation result, or publication plan.
   */
  public Object call(String action, Map<String, Object> arguments) {
    Map<String, Object> safeArguments = arguments == null
      ? new Map<String, Object>()
      : arguments;
    if (action == 'describeContract') {
      return describeContract();
    }
    if (action == 'validateVersion') {
      return RHCBuilderVersionValidator.validate(
        (String) safeArguments.get('canonicalVersionJson')
      );
    }
    if (action == 'buildDeploymentPlan') {
      return buildDeploymentPlan(
        (String) safeArguments.get('canonicalVersionJson'),
        safeArguments.get('activate') == true,
        (String) safeArguments.get('priorActiveVersionJson')
      );
    }
    throw new BuilderContractException(
      'RHC Builder does not support the requested action.'
    );
  }

  private static String describeContract() {
    return JSON.serialize(
      new Map<String, Object>{
        'schemaVersion' => SCHEMA_VERSION,
        'contractVersion' => CONTRACT_VERSION,
        'evaluationTypes' => ordered(EVALUATION_TYPES),
        'allowedValues' => new Map<String, Object>{
          'EvaluationType__c' => ordered(EVALUATION_TYPES),
          'FailureSeverity__c' => ordered(SEVERITIES),
          'CardRunMode__c' => new List<String>{
            'RUN_ON_LOAD',
            'RUN_ON_REQUEST'
          },
          'RunButtonDisplay__c' => new List<String>{
            'LABEL_AND_ICON',
            'LABEL_ONLY',
            'ICON_ONLY',
            'HIDE'
          },
          'CardRevealMode__c' => new List<String>{
            'ALL_AT_ONCE',
            'ONE_BY_ONE'
          },
          'FoundExpectedDisplay__c' => new List<String>{
            'ON_DEMAND',
            'FAILURES_ONLY',
            'ALL_ROWS'
          },
          'PassedChecksDisplay__c' => new List<String>{
            'SHOW_EACH_CHECK',
            'SHOW_COUNT_ONLY'
          },
          'SkippedChecksDisplay__c' => new List<String>{
            'SHOW_EACH_CHECK',
            'SHOW_COUNT_ONLY'
          },
          'SummaryDisplay__c' => new List<String>{ 'TOP', 'BOTTOM' },
          'ComparisonOperator__c' => ordered(COMPARISON_OPERATORS),
          'ExpectedValueSource__c' => ordered(EXPECTED_VALUE_SOURCES),
          'QueryResultHandling__c' => ordered(QUERY_RESULT_HANDLING),
          'NoRowsResult__c' => ordered(EMPTY_RESULTS),
          'EmptyValueHandling__c' => ordered(EMPTY_VALUE_HANDLING),
          'ApplicabilityMode__c' => ordered(APPLICABILITY_MODES),
          'ApplicabilityCountOperator__c' => ordered(
            APPLICABILITY_OPERATORS
          )
        },
        'defaults' => new Map<String, Object>{
          'checkSet' => new Map<String, Object>{
            'CardRunMode__c' => 'RUN_ON_REQUEST',
            'RunButtonDisplay__c' => 'LABEL_AND_ICON',
            'RunButtonLabel__c' => 'Run Checks',
            'RerunButtonLabel__c' => 'Run Again',
            'RunButtonIcon__c' => 'utility:check',
            'CardRevealMode__c' => 'ALL_AT_ONCE',
            'FoundExpectedDisplay__c' => 'ON_DEMAND',
            'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
            'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
            'SummaryDisplay__c' => 'BOTTOM',
            'IsActive__c' => false
          },
          'check' => new Map<String, Object>{
            'FailureSeverity__c' => 'WARNING',
            'ApplicabilityMode__c' => 'ALL_RECORDS',
            'QueryResultHandling__c' => 'ONE_RESULT',
            'NoRowsResult__c' => 'UNABLE_TO_EVALUATE',
            'EmptyValueHandling__c' => 'SKIP_RECORD',
            'MaxQueryRows__c' => 200,
            'IsActive__c' => false
          }
        },
        'limits' => new Map<String, Object>{
          'maximumChecksPerSet' => MAX_CHECKS
        },
        'checkSetFields' => RHCBuilderFieldMapping.CHECK_SET_FIELDS,
        'checkFields' => RHCBuilderFieldMapping.CHECK_FIELDS
      }
    );
  }

  private static String buildDeploymentPlan(
    String versionJson,
    Boolean shouldActivate,
    String priorActiveVersionJson
  ) {
    Map<String, Object> validation = (Map<String, Object>) JSON.deserializeUntyped(
      RHCBuilderVersionValidator.validate(versionJson)
    );
    if (validation.get('isValid') != true) {
      throw new BuilderContractException(
        'Resolve the Builder validation errors before publication.'
      );
    }
    Map<String, Object> version = (Map<String, Object>) JSON.deserializeUntyped(
      RHCBuilderFieldMapping.canonicalize(versionJson)
    );
    List<Object> components = new List<Object>();
    components.add(
      deploymentComponent(
        (Map<String, Object>) version.get('checkSet'),
        metadataType('Record_Health_Check_Set__mdt'),
        shouldActivate
      )
    );
    for (Object rawCheck : (List<Object>) version.get('checks')) {
      components.add(
        deploymentComponent(
          (Map<String, Object>) rawCheck,
          metadataType('Record_Health_Check__mdt'),
          shouldActivate
        )
      );
    }
    appendOmittedCheckDeactivations(
      components,
      version,
      priorActiveVersionJson
    );
    return JSON.serialize(
      new Map<String, Object>{ 'components' => components }
    );
  }

  private static void appendOmittedCheckDeactivations(
    List<Object> components,
    Map<String, Object> targetVersion,
    String priorActiveVersionJson
  ) {
    if (String.isBlank(priorActiveVersionJson)) {
      return;
    }
    Map<String, Object> priorVersion = (Map<String, Object>) JSON.deserializeUntyped(
      RHCBuilderFieldMapping.canonicalize(priorActiveVersionJson)
    );
    Set<String> targetCheckNames = new Set<String>();
    for (Object rawTargetCheck : (List<Object>) targetVersion.get('checks')) {
      targetCheckNames.add(
        (String) ((Map<String, Object>) rawTargetCheck).get('qualifiedApiName')
      );
    }
    for (Object rawPriorCheck : (List<Object>) priorVersion.get('checks')) {
      Map<String, Object> priorCheck = (Map<String, Object>) rawPriorCheck;
      if (!targetCheckNames.contains((String) priorCheck.get('qualifiedApiName'))) {
        components.add(
          deploymentComponent(
            priorCheck,
            metadataType('Record_Health_Check__mdt'),
            false
          )
        );
      }
    }
  }

  private static Map<String, Object> deploymentComponent(
    Map<String, Object> source,
    Schema.SObjectType metadataType,
    Boolean shouldActivate
  ) {
    Schema.DescribeSObjectResult description = metadataType.getDescribe();
    Map<String, Schema.SObjectField> fields = description.fields.getMap();
    Map<String, Object> sourceValues = (Map<String, Object>) source.get(
      'values'
    );
    Map<String, Object> deploymentValues = new Map<String, Object>();
    for (String fieldName : sourceValues.keySet()) {
      Schema.SObjectField field = findField(fields, fieldName);
      if (field == null) {
        throw new BuilderContractException(
          'A selected Record Health Check field is unavailable.'
        );
      }
      deploymentValues.put(
        field.getDescribe().getName(),
        sourceValues.get(fieldName)
      );
    }
    Schema.SObjectField activeField = findField(fields, 'IsActive__c');
    if (activeField == null) {
      throw new BuilderContractException(
        'The installed Record Health Check package does not expose the activation field required by this Builder release.'
      );
    }
    deploymentValues.put(
      activeField.getDescribe().getName(),
      shouldActivate == true
    );
    return new Map<String, Object>{
      'fullName' => description.getName() +
      '.' +
      (String) source.get('qualifiedApiName'),
      'label' => source.get('label'),
      'values' => deploymentValues
    };
  }

  private static List<String> ordered(Set<String> values) {
    List<String> result = new List<String>(values);
    result.sort();
    return result;
  }

  private static Schema.SObjectField findField(
    Map<String, Schema.SObjectField> fields,
    String localFieldName
  ) {
    Schema.SObjectField directMatch = fields.get(localFieldName);
    if (directMatch != null) {
      return directMatch;
    }
    for (Schema.SObjectField candidate : fields.values()) {
      String installedName = candidate.getDescribe().getName();
      if (
        installedName == localFieldName ||
        installedName.endsWith('__' + localFieldName)
      ) {
        return candidate;
      }
    }
    return null;
  }

  private static Schema.SObjectType metadataType(String localTypeName) {
    Map<String, Schema.SObjectType> installedTypes = Schema.getGlobalDescribe();
    Schema.SObjectType result = installedTypes.get(localTypeName);
    if (result == null) {
      result = installedTypes.get(CORE_NAMESPACE + '__' + localTypeName);
    }
    if (result == null) {
      throw new BuilderContractException(
        'Install the Record Health Check package version required by this Builder release.'
      );
    }
    return result;
  }
}
