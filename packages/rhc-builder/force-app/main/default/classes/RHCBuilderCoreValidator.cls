/** Validates Builder snapshots against the pinned core metadata contract. */
@SuppressWarnings('PMD.ExcessiveParameterList,PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
// This class is a declarative validation decision table. Its methods remain independently small;
// the aggregate class score reflects the number of intentionally separate contract rules.
public inherited sharing class RHCBuilderCoreValidator {
  private static final String CORE_NAMESPACE = 'rhc';
  private static final Integer FRAMEWORK_MAX_ROWS = 2000;
  private static final Set<String> DISPLAY_MODES = new Set<String>{
    'SHOW_EACH_CHECK', 'SHOW_COUNT_ONLY'
  };
  private static final Set<String> SUMMARY_DISPLAYS = new Set<String>{
    'TOP', 'BOTTOM'
  };
  private static final Set<String> TRIGGER_MODES = new Set<String>{
    'RUN_ON_LOAD', 'RUN_ON_REQUEST'
  };
  private static final Set<String> RUN_BUTTON_DISPLAYS = new Set<String>{
    'LABEL_AND_ICON', 'LABEL_ONLY', 'ICON_ONLY', 'HIDE'
  };
  private static final Set<String> REVEAL_MODES = new Set<String>{
    'ALL_AT_ONCE', 'ONE_BY_ONE'
  };
  private static final Set<String> COMPARISON_DISPLAYS = new Set<String>{
    'ON_DEMAND', 'FAILURES_ONLY', 'ALL_ROWS'
  };
  private static final Set<String> EMPTY_RESULTS = new Set<String>{
    'PASS', 'FAIL', 'SKIP', 'UNABLE_TO_EVALUATE'
  };
  private static final Set<String> EMPTY_VALUES = new Set<String>{
    'AS_NO_MATCH', 'SKIP_RECORD', 'AS_BLANK'
  };
  private static final Set<String> APPLICABILITY_MODES = new Set<String>{
    'ALL_RECORDS', 'WHEN_FORMULA_TRUE', 'WHEN_COUNT_QUERY_MATCHES'
  };
  private static final Set<String> APPLICABILITY_OPERATORS = new Set<String>{
    'EQUALS', 'NOT_EQUALS', 'GREATER_THAN', 'GREATER_THAN_OR_EQUAL',
    'LESS_THAN', 'LESS_THAN_OR_EQUAL'
  };

  /**
   * Validates one Check Set value map against core 2.0.4-2 rules.
   * @param values Canonical core Check Set field values.
   * @return Builder-shaped validation issues.
   */
  public static List<Object> validateCheckSet(Map<String, Object> values) {
    List<Object> issues = new List<Object>();
    requireText(issues, values, 'ObjectApiName__c', 'Base Object API Name is required.');
    String objectApiName = text(values, 'ObjectApiName__c');
    if (
      String.isNotBlank(objectApiName) &&
      !Schema.getGlobalDescribe().containsKey(objectApiName)
    ) {
      addError(issues, 'ObjectApiName__c', 'Object API Name does not identify an object in this org.', 'INVALID_CONFIG');
    }
    requireText(issues, values, 'CardTitle__c', 'Card Title is required.');
    requireChoice(issues, values, 'PassedChecksDisplay__c', DISPLAY_MODES, 'Passed Checks Display is not recognized.');
    requireChoice(issues, values, 'SkippedChecksDisplay__c', DISPLAY_MODES, 'Skipped Checks Display is not recognized.');
    requireChoice(issues, values, 'CardRunMode__c', TRIGGER_MODES, 'When Checks Run is not recognized.');
    requireChoice(issues, values, 'CardRevealMode__c', REVEAL_MODES, 'Reveal Mode is not recognized.');
    optionalChoice(issues, values, 'SummaryDisplay__c', SUMMARY_DISPLAYS, 'Summary Display is not recognized.');
    optionalChoice(issues, values, 'FoundExpectedDisplay__c', COMPARISON_DISPLAYS, 'Found/Expected Display is not recognized.');
    String runButtonDisplay = text(values, 'RunButtonDisplay__c');
    if (String.isBlank(runButtonDisplay)) {
      runButtonDisplay = 'LABEL_AND_ICON';
    }
    if (!RUN_BUTTON_DISPLAYS.contains(runButtonDisplay)) {
      addError(issues, 'RunButtonDisplay__c', 'Run Button Display is not recognized.', 'INVALID_CONFIG');
    } else if (
      text(values, 'CardRunMode__c') == 'RUN_ON_REQUEST' &&
      runButtonDisplay == 'HIDE'
    ) {
      addError(
        issues,
        'RunButtonDisplay__c',
        'Run Button Display cannot be Hide when checks run only after a user clicks Run.',
        'INVALID_CONFIG'
      );
    }
    return prefixIssues(issues, 'checkSet.values');
  }

  /**
   * Validates one Check value map against core 2.0.4-2 rules.
   * @param values Canonical core Check field values.
   * @param evaluationType Builder evaluation type.
   * @param checkPath Path of the Check in the complete-version envelope.
   * @return Builder-shaped validation issues.
   */
  public static List<Object> validateCheck(
    Map<String, Object> values,
    String evaluationType,
    String checkPath
  ) {
    List<Object> issues = new List<Object>();
    requireText(issues, values, 'CheckTitle__c', 'Check Title is required.');
    requireText(issues, values, 'FailureMessage__c', 'Message When Check Fails is required.');
    validateApplicability(issues, values);
    if (evaluationType == 'FORMULA') {
      requireText(issues, values, 'PassConditionFormula__c', 'Formula is required for Formula checks.');
    } else if (
      evaluationType == 'QUERY' ||
      evaluationType == 'COMPARE_TWO_QUERIES'
    ) {
      issues.addAll(RHCBuilderQueryValidator.validate(values, evaluationType));
    } else if (evaluationType == 'APEX') {
      validateApex(issues, values);
    }
    validateLimitsAndEmptyBehavior(issues, values);
    return prefixIssues(issues, checkPath + '.values');
  }

  private static void validateApplicability(List<Object> issues, Map<String, Object> values) {
    String mode = text(values, 'ApplicabilityMode__c');
    if (String.isBlank(mode)) {
      return;
    }
    if (!APPLICABILITY_MODES.contains(mode)) {
      addError(issues, 'ApplicabilityMode__c', 'Applicability Mode is not recognized.', 'INVALID_CONFIG');
      return;
    }
    if (mode == 'WHEN_FORMULA_TRUE') {
      requireText(issues, values, 'ApplicabilityFormula__c', 'Applicability Formula is required when Applicability Mode is Formula.');
    } else if (mode == 'WHEN_COUNT_QUERY_MATCHES') {
      requireText(issues, values, 'ApplicabilityCountQuery__c', 'Applicability SOQL is required when Applicability Mode is SOQL.');
      String applicabilityQuery = text(values, 'ApplicabilityCountQuery__c');
      if (
        String.isNotBlank(applicabilityQuery) &&
        !RHCBuilderQueryValidator.isSingleCountQuery(applicabilityQuery)
      ) {
        addError(
          issues,
          'ApplicabilityCountQuery__c',
          'Applicability SOQL must return one ungrouped COUNT value.',
          'INVALID_SOQL_TEMPLATE'
        );
      } else if (
        String.isNotBlank(applicabilityQuery) &&
        !RHCBuilderQueryValidator.isSupportedBulkShape(applicabilityQuery)
      ) {
        addError(
          issues,
          'ApplicabilityCountQuery__c',
          'Applicability SOQL must use a core-supported scope-safe query shape.',
          'UNSUPPORTED_BULK_QUERY_SHAPE'
        );
      }
      requireChoice(
        issues,
        values,
        'ApplicabilityCountOperator__c',
        APPLICABILITY_OPERATORS,
        'Applicability comparison operator is required and must be recognized.'
      );
      if (values.get('ApplicabilityCountThreshold__c') == null) {
        addError(
          issues,
          'ApplicabilityCountThreshold__c',
          'Applicability Comparison Value is required when Applicability Mode is SOQL.',
          'MISSING_REQUIRED_FIELD'
        );
      }
    }
  }

  private static void validateApex(List<Object> issues, Map<String, Object> values) {
    requireText(issues, values, 'ApexClass__c', 'Apex Class is required for Apex checks.');
    String className = text(values, 'ApexClass__c');
    if (String.isNotBlank(className) && !isValidApexPlugin(className)) {
      addError(
        issues,
        'ApexClass__c',
        'Apex Class must exist and implement RecordHealthCheckPlugin.',
        'INVALID_CONFIG'
      );
    }
    String parameters = text(values, 'ApexParametersJson__c');
    if (String.isNotBlank(parameters)) {
      try {
        if (!(JSON.deserializeUntyped(parameters) instanceof Map<String, Object>)) {
          addError(issues, 'ApexParametersJson__c', 'Apex Parameters must be a JSON object.', 'INVALID_JSON');
        }
      } catch (Exception error) {
        addError(issues, 'ApexParametersJson__c', 'Apex Parameters must be a JSON object.', 'INVALID_JSON');
      }
    }
  }

  private static Boolean isValidApexPlugin(String className) {
    Savepoint before = Database.setSavepoint();
    Integer dmlBefore = Limits.getDmlStatements();
    Integer dmlRowsBefore = Limits.getDmlRows();
    Integer calloutsBefore = Limits.getCallouts();
    Integer queueableBefore = Limits.getQueueableJobs();
    Integer futureBefore = Limits.getFutureCalls();
    Integer emailBefore = Limits.getEmailInvocations();
    Object instance;
    Type pluginType;
    try {
      String normalized = className.trim();
      pluginType = normalized.contains('.')
        ? Type.forName(normalized.substringBefore('.'), normalized.substringAfter('.'))
        : Type.forName(normalized);
      if (pluginType == null && !normalized.contains('.')) {
        pluginType = Type.forName('', normalized);
      }
      if (pluginType == null && !normalized.contains('.')) {
        pluginType = Type.forName(CORE_NAMESPACE, normalized);
      }
      if (pluginType != null) {
        instance = pluginType.newInstance();
      }
    } catch (Exception error) {
      instance = null;
    }
    Boolean hadSideEffect =
      Limits.getDmlStatements() > dmlBefore ||
      Limits.getDmlRows() > dmlRowsBefore ||
      Limits.getCallouts() > calloutsBefore ||
      Limits.getQueueableJobs() > queueableBefore ||
      Limits.getFutureCalls() > futureBefore ||
      Limits.getEmailInvocations() > emailBefore;
    if (hadSideEffect) {
      Database.rollback(before);
    }
    Database.releaseSavepoint(before);
    Type pluginInterface = Type.forName('', 'RecordHealthCheckPlugin');
    if (pluginInterface == null) {
      pluginInterface = Type.forName(
        CORE_NAMESPACE,
        'RecordHealthCheckPlugin'
      );
    }
    return
      !hadSideEffect &&
      instance != null &&
      pluginType != null &&
      pluginInterface != null &&
      pluginInterface.isAssignableFrom(pluginType);
  }

  private static void validateLimitsAndEmptyBehavior(List<Object> issues, Map<String, Object> values) {
    Decimal maxRows = decimalValue(values.get('MaxQueryRows__c'));
    if (
      maxRows != null &&
      (maxRows <= 0 || maxRows > FRAMEWORK_MAX_ROWS || maxRows != maxRows.intValue())
    ) {
      addError(issues, 'MaxQueryRows__c', 'Maximum Query Rows must be a whole number from 1 through 2000.', 'INVALID_CONFIG');
    }
    optionalChoice(issues, values, 'NoRowsResult__c', EMPTY_RESULTS, 'No Rows Result is not recognized.');
    optionalChoice(issues, values, 'EmptyValueHandling__c', EMPTY_VALUES, 'Empty Value Handling is not recognized.');
  }

  private static void requireText(
    List<Object> issues,
    Map<String, Object> values,
    String fieldName,
    String message
  ) {
    if (String.isBlank(text(values, fieldName))) {
      addError(issues, fieldName, message, 'MISSING_REQUIRED_FIELD');
    }
  }

  private static void requireChoice(
    List<Object> issues,
    Map<String, Object> values,
    String fieldName,
    Set<String> allowed,
    String message
  ) {
    String value = text(values, fieldName);
    if (String.isBlank(value) || !allowed.contains(value)) {
      addError(issues, fieldName, message, 'INVALID_CONFIG');
    }
  }

  private static void optionalChoice(
    List<Object> issues,
    Map<String, Object> values,
    String fieldName,
    Set<String> allowed,
    String message
  ) {
    String value = text(values, fieldName);
    if (String.isNotBlank(value) && !allowed.contains(value)) {
      addError(issues, fieldName, message, 'INVALID_CONFIG');
    }
  }

  private static void addError(
    List<Object> issues,
    String fieldName,
    String message,
    String reasonCode
  ) {
    issues.add(
      new Map<String, Object>{
        'severity' => 'ERROR',
        'reasonCode' => 'CORE_' + reasonCode,
        'path' => fieldName,
        'userMessage' => message
      }
    );
  }

  private static List<Object> prefixIssues(List<Object> issues, String pathPrefix) {
    for (Object rawIssue : issues) {
      Map<String, Object> issue = (Map<String, Object>) rawIssue;
      issue.put('path', pathPrefix + '.' + (String) issue.get('path'));
    }
    return issues;
  }

  private static String text(Map<String, Object> values, String fieldName) {
    Object value = values.get(fieldName);
    return value instanceof String ? (String) value : null;
  }

  private static Decimal decimalValue(Object value) {
    if (value == null) {
      return null;
    }
    try {
      return Decimal.valueOf(String.valueOf(value));
    } catch (Exception error) {
      return null;
    }
  }
}
