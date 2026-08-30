/** Validates complete Builder envelopes and delegates runtime rules to core. */
public inherited sharing class RHCBuilderVersionValidator {
  private static final Integer SCHEMA_VERSION = 1;
  private static final String CONTRACT_VERSION = '1.0';
  private static final Integer MAXIMUM_CHECKS = 25;
  private static final Integer MAX_QUALIFIED_API_NAME_LENGTH = 255;
  private static final Integer MAX_CHECK_VALUES_LENGTH = 32768;
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
  private static final Pattern QUALIFIED_API_NAME = Pattern.compile(
    '^[A-Za-z][A-Za-z0-9_]*$'
  );

  private class ValidationState {
    List<Object> issues;
    String checkSetQualifiedApiName;
    Set<String> qualifiedNames = new Set<String>();
    Set<Decimal> evaluationOrders = new Set<Decimal>();

    ValidationState(List<Object> issues, String checkSetQualifiedApiName) {
      this.issues = issues;
      this.checkSetQualifiedApiName = checkSetQualifiedApiName;
    }
  }

  /**
   * Validates one complete canonical Check Set Version.
   * @param versionJson Candidate version JSON.
   * @return Serialized validation response with field-level issues.
   */
  public static String validate(String versionJson) {
    List<Object> issues = new List<Object>();
    Map<String, Object> version;
    try {
      version = (Map<String, Object>) JSON.deserializeUntyped(
        RHCBuilderFieldMapping.canonicalize(versionJson)
      );
    } catch (Exception error) {
      issues.add(issue('VERSION_FORMAT_INVALID', 'version', error.getMessage()));
      return validationResult(issues);
    }
    validateVersionIdentity(issues, version);
    validateComponents(issues, version);
    return validationResult(issues);
  }

  private static void validateVersionIdentity(
    List<Object> issues,
    Map<String, Object> version
  ) {
    if (integerValue(version.get('schemaVersion')) != SCHEMA_VERSION) {
      issues.add(
        issue(
          'SCHEMA_VERSION_UNSUPPORTED',
          'schemaVersion',
          'Use Builder schema version 1.'
        )
      );
    }
    if (String.valueOf(version.get('contractVersion')) != CONTRACT_VERSION) {
      issues.add(
        issue(
          'CONTRACT_VERSION_UNSUPPORTED',
          'contractVersion',
          'Use Builder contract version 1.0.'
        )
      );
    }
  }

  private static void validateComponents(
    List<Object> issues,
    Map<String, Object> version
  ) {
    Map<String, Object> checkSet = (Map<String, Object>) version.get(
      'checkSet'
    );
    Map<String, Object> setValues = (Map<String, Object>) checkSet.get(
      'values'
    );
    ValidationState state = new ValidationState(
      issues,
      textValue(checkSet.get('qualifiedApiName'))
    );
    validateIdentity(
      issues,
      state.checkSetQualifiedApiName,
      'checkSet.qualifiedApiName'
    );
    issues.addAll(RHCBuilderCoreValidator.validateCheckSet(setValues));

    List<Object> checks = (List<Object>) version.get('checks');
    if (checks.size() > MAXIMUM_CHECKS) {
      issues.add(
        issue(
          'CHECK_LIMIT_EXCEEDED',
          'checks',
          'A Check Set Version can contain no more than ' +
            String.valueOf(MAXIMUM_CHECKS) +
            ' Checks.'
        )
      );
    }
    for (Integer index = 0; index < checks.size(); index++) {
      validateCheck(state, (Map<String, Object>) checks[index], index);
    }
  }

  private static void validateCheck(
    ValidationState state,
    Map<String, Object> check,
    Integer index
  ) {
    String path = 'checks[' + String.valueOf(index) + ']';
    String qualifiedName = textValue(check.get('qualifiedApiName'));
    validateIdentity(state.issues, qualifiedName, path + '.qualifiedApiName');
    if (state.qualifiedNames.contains(qualifiedName)) {
      state.issues.add(
        issue(
          'DUPLICATE_CHECK_NAME',
          path + '.qualifiedApiName',
          'Use a unique Qualified API Name.'
        )
      );
    }
    state.qualifiedNames.add(qualifiedName);

    Map<String, Object> values = (Map<String, Object>) check.get('values');
    if (JSON.serialize(values).length() > MAX_CHECK_VALUES_LENGTH) {
      state.issues.add(
        issue(
          'CHECK_VALUES_TOO_LARGE',
          path + '.values',
          'Reduce this Check configuration before saving the version.'
        )
      );
    }
    String evaluationType = textValue(values.get('EvaluationType__c'));
    if (!EVALUATION_TYPES.contains(evaluationType)) {
      state.issues.add(
        issue(
          'EVALUATION_TYPE_INVALID',
          path + '.values.EvaluationType__c',
          'Choose a supported evaluation type.'
        )
      );
    }
    if (
      !SEVERITIES.contains(
        textValue(values.get('FailureSeverity__c'))
      )
    ) {
      state.issues.add(
        issue(
          'SEVERITY_INVALID',
          path + '.values.FailureSeverity__c',
          'Choose Critical, Warning, or Info.'
        )
      );
    }
    validateCheckPlacement(state, values, path);
    state.issues.addAll(
      RHCBuilderCoreValidator.validateCheck(values, evaluationType, path)
    );
  }

  private static void validateCheckPlacement(
    ValidationState state,
    Map<String, Object> values,
    String path
  ) {
    if (
      textValue(values.get('Record_Health_Check_Set__c')) !=
      state.checkSetQualifiedApiName
    ) {
      state.issues.add(
        issue(
          'CHECK_SET_REFERENCE_INVALID',
          path + '.values.Record_Health_Check_Set__c',
          'Select this Check Set.'
        )
      );
    }
    Decimal order = decimalValue(values.get('EvaluationOrder__c'));
    if (order == null || order <= 0 || state.evaluationOrders.contains(order)) {
      state.issues.add(
        issue(
          'EVALUATION_ORDER_INVALID',
          path + '.values.EvaluationOrder__c',
          'Use a unique positive order.'
        )
      );
    } else {
      state.evaluationOrders.add(order);
    }
  }

  private static void validateIdentity(
    List<Object> issues,
    String qualifiedApiName,
    String path
  ) {
    if (
      String.isBlank(qualifiedApiName) ||
      qualifiedApiName.length() >
      MAX_QUALIFIED_API_NAME_LENGTH ||
      !QUALIFIED_API_NAME.matcher(qualifiedApiName).matches()
    ) {
      issues.add(
        issue(
          'QUALIFIED_API_NAME_INVALID',
          path,
          'Use an exact Salesforce Qualified API Name of 255 characters or fewer.'
        )
      );
    } else if (qualifiedApiName.contains('__')) {
      issues.add(
        issue(
          'NAMESPACED_IDENTITY_NOT_AUTHORABLE',
          path,
          'Use an unprefixed subscriber-owned Developer Name. Builder cannot create or replace package-owned metadata.'
        )
      );
    }
  }

  private static Map<String, Object> issue(
    String reasonCode,
    String path,
    String userMessage
  ) {
    return new Map<String, Object>{
      'severity' => 'ERROR',
      'reasonCode' => reasonCode,
      'path' => path,
      'userMessage' => userMessage
    };
  }

  private static String validationResult(List<Object> issues) {
    Boolean isValid = true;
    for (Object rawIssue : issues) {
      if (((Map<String, Object>) rawIssue).get('severity') == 'ERROR') {
        isValid = false;
        break;
      }
    }
    return JSON.serialize(
      new Map<String, Object>{ 'isValid' => isValid, 'issues' => issues }
    );
  }

  private static Integer integerValue(Object value) {
    Decimal decimalResult = decimalValue(value);
    return decimalResult == null ? null : decimalResult.intValue();
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

  private static String textValue(Object value) {
    return value instanceof String ? (String) value : null;
  }
}
