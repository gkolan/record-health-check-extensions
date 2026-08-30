/** Exact allow-list and deterministic serializer for core metadata field maps. */
public inherited sharing class RHCBuilderFieldMapping {
  private static final Integer MAX_CANONICAL_VERSION_LENGTH = 131072;
  /** All 18 core Check Set custom fields, in deterministic serialization order. */
  public static final List<String> CHECK_SET_FIELDS = new List<String>{
    'CardRevealMode__c',
    'CardRunMode__c',
    'CardSubtitle__c',
    'CardTitle__c',
    'FoundExpectedDisplay__c',
    'IsActive__c',
    'ObjectApiName__c',
    'PassedChecksDisplay__c',
    'PublishErrorLogEvent__c',
    'PublishUserRunEvent__c',
    'RerunButtonLabel__c',
    'RunButtonDisplay__c',
    'RunButtonIcon__c',
    'RunButtonLabel__c',
    'ShowDiagnostics__c',
    'SkippedChecksDisplay__c',
    'StopOnSystemError__c',
    'SummaryDisplay__c'
  };

  /** All 44 core Check custom fields, in deterministic serialization order. */
  public static final List<String> CHECK_FIELDS = new List<String>{
    'ActionLabel__c',
    'ActionUrl__c',
    'ApexClass__c',
    'ApexParametersJson__c',
    'ApplicabilityCountOperator__c',
    'ApplicabilityCountQuery__c',
    'ApplicabilityCountThreshold__c',
    'ApplicabilityFormula__c',
    'ApplicabilityMode__c',
    'ApplicabilityNotMetMessage__c',
    'Category__c',
    'CheckDescription__c',
    'CheckTitle__c',
    'ComparisonOperator__c',
    'ComparisonQueryField__c',
    'ComparisonQuery__c',
    'DisplayExpectedFormula__c',
    'DisplayExpectedText__c',
    'DisplayFoundFormula__c',
    'DisplayFoundText__c',
    'DisplayValueFormat__c',
    'EmptyValueHandling__c',
    'EvaluationOrder__c',
    'EvaluationType__c',
    'ExpectedCurrencyIsoCode__c',
    'ExpectedFixedValue__c',
    'ExpectedRecordFormula__c',
    'ExpectedValueSource__c',
    'FailureMessage__c',
    'FailureSeverity__c',
    'FindInListFormula__c',
    'FixMessage__c',
    'FormulaResultType__c',
    'IsActive__c',
    'MaxQueryRows__c',
    'NoRowsResult__c',
    'PassConditionFormula__c',
    'PrerequisiteCheck__c',
    'PublishUserResultEvent__c',
    'QueryResultHandling__c',
    'Record_Health_Check_Set__c',
    'SourceQueryField__c',
    'SourceQuery__c',
    'UnableToEvaluateMessage__c'
  };

  /** Invalid canonical envelope failure. */
  public class MappingException extends Exception {
  }

  /**
   * Validates exact keys and returns deterministic JSON without modifying Qualified API Names or values.
   * @param envelopeJson Candidate complete version JSON.
   * @return Canonical deterministic JSON used for fingerprinting and persistence.
   */
  public static String canonicalize(String envelopeJson) {
    Map<String, Object> envelope = parseEnvelope(envelopeJson);
    assertOnlyKeys(
      envelope,
      new Set<String>{
        'schemaVersion',
        'contractVersion',
        'checkSet',
        'checks'
      },
      'version'
    );
    Map<String, Object> checkSet = asComponent(
      envelope.get('checkSet'),
      'Check Set'
    );
    validateValues(
      (Map<String, Object>) checkSet.get('values'),
      CHECK_SET_FIELDS,
      'Check Set'
    );
    List<Object> checks = requireChecks(envelope.get('checks'));

    JSONGenerator generator = JSON.createGenerator(false);
    generator.writeStartObject();
    generator.writeObjectField('schemaVersion', envelope.get('schemaVersion'));
    generator.writeObjectField(
      'contractVersion',
      envelope.get('contractVersion')
    );
    generator.writeFieldName('checkSet');
    writeComponent(generator, checkSet, CHECK_SET_FIELDS);
    writeChecks(generator, checks);
    generator.writeEndObject();
    return generator.getAsString();
  }

  private static Map<String, Object> parseEnvelope(String envelopeJson) {
    if (
      String.isBlank(envelopeJson) ||
      envelopeJson.length() > MAX_CANONICAL_VERSION_LENGTH
    ) {
      throw new MappingException(
        'The Check Set Version is empty or too large.'
      );
    }
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(envelopeJson);
    } catch (Exception error) {
      throw new MappingException(
        'The Check Set Version JSON is malformed.',
        error
      );
    }
  }

  private static List<Object> requireChecks(Object rawChecks) {
    List<Object> checks = rawChecks instanceof List<Object>
      ? (List<Object>) rawChecks
      : null;
    if (checks == null || checks.isEmpty()) {
      throw new MappingException(
        'A Check Set Version must contain at least one Check.'
      );
    }
    return checks;
  }

  private static void writeChecks(
    JSONGenerator generator,
    List<Object> checks
  ) {
    generator.writeFieldName('checks');
    generator.writeStartArray();
    for (Object rawCheck : checks) {
      Map<String, Object> check = asComponent(rawCheck, 'Check');
      validateValues(
        (Map<String, Object>) check.get('values'),
        CHECK_FIELDS,
        'Check'
      );
      writeComponent(generator, check, CHECK_FIELDS);
    }
    generator.writeEndArray();
  }

  private static Map<String, Object> asComponent(Object raw, String label) {
    if (!(raw instanceof Map<String, Object>)) {
      throw new MappingException(label + ' metadata is missing.');
    }
    Map<String, Object> component = (Map<String, Object>) raw;
    assertOnlyKeys(
      component,
      new Set<String>{ 'qualifiedApiName', 'label', 'values' },
      label
    );
    if (
      String.isBlank((String) component.get('qualifiedApiName')) ||
      String.isBlank((String) component.get('label')) ||
      !(component.get('values') instanceof Map<String, Object>)
    ) {
      throw new MappingException(label + ' identity and values are required.');
    }
    return component;
  }

  private static void validateValues(
    Map<String, Object> values,
    List<String> allowedFields,
    String label
  ) {
    assertOnlyKeys(values, new Set<String>(allowedFields), label + ' values');
  }

  private static void assertOnlyKeys(
    Map<String, Object> values,
    Set<String> allowed,
    String label
  ) {
    if (values == null) {
      throw new MappingException(label + ' is missing.');
    }
    Set<String> unsupported = new Set<String>(values.keySet());
    unsupported.removeAll(allowed);
    if (!unsupported.isEmpty()) {
      throw new MappingException(label + ' contains unsupported fields.');
    }
  }

  private static void writeComponent(
    JSONGenerator generator,
    Map<String, Object> component,
    List<String> orderedFields
  ) {
    generator.writeStartObject();
    generator.writeObjectField(
      'qualifiedApiName',
      component.get('qualifiedApiName')
    );
    generator.writeObjectField('label', component.get('label'));
    generator.writeFieldName('values');
    generator.writeStartObject();
    Map<String, Object> values = (Map<String, Object>) component.get('values');
    for (String fieldName : orderedFields) {
      if (values.containsKey(fieldName)) {
        generator.writeObjectField(fieldName, values.get(fieldName));
      }
    }
    generator.writeEndObject();
    generator.writeEndObject();
  }
}
