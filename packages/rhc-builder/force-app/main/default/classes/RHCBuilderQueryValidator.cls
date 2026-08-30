/** Validates Query and Compare Two Queries snapshots against core 2.0.4-2. */
@SuppressWarnings('PMD.ExcessiveParameterList,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
// This class is a validation decision table. Independent query rules keep each field, allowed
// values, safe-shape predicate, and actionable message together; no method exceeds complexity 11.
public inherited sharing class RHCBuilderQueryValidator {
  private static final Set<String> OPERATORS = new Set<String>{
    'EQUALS', 'NOT_EQUALS', 'GREATER_THAN', 'GREATER_THAN_OR_EQUAL',
    'LESS_THAN', 'LESS_THAN_OR_EQUAL', 'CONTAINS', 'DOES_NOT_CONTAIN',
    'IS_BLANK', 'IS_NOT_BLANK', 'LIST_CONTAINS_ANY', 'LIST_CONTAINS_NONE',
    'LISTS_OVERLAP', 'LISTS_CONTAIN_ALL', 'LISTS_MATCH_EXACTLY'
  };
  private static final Set<String> LIST_OPERATORS = new Set<String>{
    'LIST_CONTAINS_ANY', 'LIST_CONTAINS_NONE'
  };
  private static final Set<String> DUAL_QUERY_OPERATORS = new Set<String>{
    'LISTS_OVERLAP', 'LISTS_CONTAIN_ALL', 'LISTS_MATCH_EXACTLY'
  };
  private static final Set<String> UNARY_OPERATORS = new Set<String>{
    'IS_BLANK', 'IS_NOT_BLANK'
  };
  private static final Set<String> VALUE_SOURCES = new Set<String>{
    'FIXED_VALUE', 'RECORD_FORMULA', 'COMPARISON_QUERY'
  };
  private static final Set<String> QUERY_RESULT_HANDLING = new Set<String>{
    'ONE_RESULT', 'ANY_ROW_PASSES', 'ALL_ROWS_PASS', 'COMPARE_AS_LISTS'
  };

  /**
   * Validates one query-based Check.
   * @param values Canonical core Check field values.
   * @param evaluationType QUERY or COMPARE_TWO_QUERIES.
   * @return Builder-shaped issues with local field paths.
   */
  public static List<Object> validate(
    Map<String, Object> values,
    String evaluationType
  ) {
    List<Object> issues = new List<Object>();
    if (evaluationType == 'QUERY') {
      validateSingleQuery(issues, values);
    } else {
      validateCompareQueries(issues, values);
    }
    return issues;
  }

  private static void validateSingleQuery(
    List<Object> issues,
    Map<String, Object> values
  ) {
    String operator = text(values, 'ComparisonOperator__c');
    Boolean isList = LIST_OPERATORS.contains(operator);
    Boolean isUnary = UNARY_OPERATORS.contains(operator);
    if (isList) {
      requireText(issues, values, 'FindInListFormula__c', 'Value To Test is required for list operators.');
      requireQuery(issues, values, 'ComparisonQuery__c', 'Comparison Query is required.');
      requireText(issues, values, 'ComparisonQueryField__c', 'Comparison Query Field is required for list comparison queries.');
    } else {
      requireQuery(issues, values, 'SourceQuery__c', 'Source Query is required for Query checks.');
      requireQueryField(issues, values, 'SourceQuery__c', 'SourceQueryField__c');
    }
    requireChoice(issues, values, 'ComparisonOperator__c', OPERATORS, 'Comparison operator is required and must be recognized.');
    if (DUAL_QUERY_OPERATORS.contains(operator)) {
      addError(issues, 'ComparisonOperator__c', 'This operator requires Evaluation Type Compare two queries.', 'INVALID_OPERATOR');
    }
    requireChoice(
      issues,
      values,
      'QueryResultHandling__c',
      QUERY_RESULT_HANDLING,
      'How To Interpret Query Results is required and must be recognized.'
    );
    if (text(values, 'QueryResultHandling__c') == 'COMPARE_AS_LISTS' && !isList) {
      addError(issues, 'QueryResultHandling__c', 'Compare query results as lists requires a list operator.', 'INVALID_CONFIG');
    }
    if (!isUnary && !isList) {
      requireChoice(
        issues,
        values,
        'ExpectedValueSource__c',
        VALUE_SOURCES,
        'Expected Value Comes From is required and must be recognized.'
      );
    }
    validateTextOperator(issues, values, false);
    validateExpectedValueSource(issues, values);
  }

  private static void validateCompareQueries(
    List<Object> issues,
    Map<String, Object> values
  ) {
    requireQuery(issues, values, 'SourceQuery__c', 'Source Query is required.');
    requireQuery(issues, values, 'ComparisonQuery__c', 'Comparison Query is required.');
    requireQueryField(issues, values, 'SourceQuery__c', 'SourceQueryField__c');
    requireQueryField(issues, values, 'ComparisonQuery__c', 'ComparisonQueryField__c');
    requireChoice(issues, values, 'ComparisonOperator__c', OPERATORS, 'Comparison operator is required and must be recognized.');
    String handling = text(values, 'QueryResultHandling__c');
    if (handling != 'ONE_RESULT' && handling != 'COMPARE_AS_LISTS') {
      addError(issues, 'QueryResultHandling__c', 'Compare two queries requires ONE_RESULT or COMPARE_AS_LISTS.', 'INVALID_CONFIG');
    }
    String operator = text(values, 'ComparisonOperator__c');
    if (handling == 'COMPARE_AS_LISTS' && !DUAL_QUERY_OPERATORS.contains(operator)) {
      addError(issues, 'ComparisonOperator__c', 'Compare-as-lists mode requires a list comparison operator.', 'INVALID_OPERATOR');
    } else if (handling == 'ONE_RESULT' && DUAL_QUERY_OPERATORS.contains(operator)) {
      addError(issues, 'ComparisonOperator__c', 'One-result mode cannot use a list comparison operator.', 'INVALID_OPERATOR');
    }
    validateTextOperator(issues, values, true);
  }

  private static void validateExpectedValueSource(
    List<Object> issues,
    Map<String, Object> values
  ) {
    String source = text(values, 'ExpectedValueSource__c');
    if (source == 'FIXED_VALUE') {
      requireText(issues, values, 'ExpectedFixedValue__c', 'Expected Value is required when the source is a fixed value.');
    } else if (source == 'RECORD_FORMULA') {
      requireText(issues, values, 'ExpectedRecordFormula__c', 'Expected Formula is required when the source is a record formula.');
    } else if (source == 'COMPARISON_QUERY') {
      requireQuery(issues, values, 'ComparisonQuery__c', 'Comparison Query is required when selected as the expected value source.');
      requireQueryField(issues, values, 'ComparisonQuery__c', 'ComparisonQueryField__c');
    }
  }

  private static void requireQuery(
    List<Object> issues,
    Map<String, Object> values,
    String fieldName,
    String message
  ) {
    requireText(issues, values, fieldName, message);
    String query = text(values, fieldName);
    if (
      String.isNotBlank(query) &&
      !Pattern.compile('(?is)^\\s*SELECT\\s+.+\\s+FROM\\s+[A-Za-z][A-Za-z0-9_]*.*$')
        .matcher(query)
        .matches()
    ) {
      addError(issues, fieldName, 'Query must be a complete SELECT statement.', 'INVALID_SOQL_TEMPLATE');
    } else if (String.isNotBlank(query) && !isSupportedBulkShape(query)) {
      addError(
        issues,
        fieldName,
        'Query must use a core-supported scope-safe shape and at most one {!record...} token.',
        'UNSUPPORTED_BULK_QUERY_SHAPE'
      );
    }
  }

  /**
   * Returns whether a query follows the pinned core's scope-safe correlation boundary.
   * @param query Candidate SOQL template.
   * @return True when the query is safe for one scope-wide execution.
   */
  public static Boolean isSupportedBulkShape(String query) {
    if (String.isBlank(query) || Pattern.compile('(?i):[A-Za-z_]').matcher(query).find()) {
      return false;
    }
    Matcher tokenMatcher = Pattern.compile(
        '(?i)\\{!record\\.[A-Za-z_][A-Za-z0-9_.]*(?:\\|[^}]+)?\\}'
      )
      .matcher(query);
    Integer tokenCount = 0;
    Integer tokenStart = -1;
    while (tokenMatcher.find()) {
      tokenCount++;
      tokenStart = tokenMatcher.start();
    }
    if (tokenCount > 1 || (query.contains('{!') && tokenCount == 0)) {
      return false;
    }
    if (tokenCount == 0) {
      return true;
    }
    String beforeToken = query.substring(0, tokenStart);
    if (!Pattern.compile('(?is)[A-Za-z_][A-Za-z0-9_.]*\\s*=\\s*$').matcher(beforeToken).find()) {
      return false;
    }
    Matcher limitMatcher = Pattern.compile('(?i)\\bLIMIT\\s+(\\d+)').matcher(query);
    if (limitMatcher.find() && Integer.valueOf(limitMatcher.group(1)) != 1) {
      return false;
    }
    Matcher orderMatcher = Pattern.compile('(?is)\\bORDER\\s+BY\\s+(.+?)(?:\\bLIMIT\\b|$)')
      .matcher(query);
    return !orderMatcher.find() || !orderMatcher.group(1).contains(',');
  }

  /**
   * Returns whether an applicability query produces one ungrouped COUNT value.
   * @param query Candidate applicability SOQL template.
   * @return True when the query has one ungrouped outer COUNT value.
   */
  public static Boolean isSingleCountQuery(String query) {
    return String.isNotBlank(query) &&
      !Pattern.compile('(?i)\\bGROUP\\s+BY\\b').matcher(query).find() &&
      Pattern.compile(
          '(?is)^\\s*SELECT\\s+COUNT\\s*\\([^,]*\\)\\s*(?:[A-Za-z][A-Za-z0-9_]*)?\\s+FROM\\s+.+$'
        )
        .matcher(query)
        .matches();
  }

  private static void validateTextOperator(
    List<Object> issues,
    Map<String, Object> values,
    Boolean compareTwoQueries
  ) {
    String operator = text(values, 'ComparisonOperator__c');
    if (operator != 'CONTAINS' && operator != 'DOES_NOT_CONTAIN') {
      return;
    }
    Boolean sourceIsText = isTextSelection(
      text(values, 'SourceQuery__c'),
      text(values, 'SourceQueryField__c')
    );
    Boolean comparisonIsText = !compareTwoQueries || isTextSelection(
      text(values, 'ComparisonQuery__c'),
      text(values, 'ComparisonQueryField__c')
    );
    if (!sourceIsText || !comparisonIsText) {
      addError(
        issues,
        'ComparisonOperator__c',
        'Contains operators require text fields from both queries.',
        'TEXT_OPERATOR_REQUIRES_TEXT'
      );
    }
  }

  private static Boolean isTextSelection(String query, String fieldName) {
    if (String.isBlank(query) || String.isBlank(fieldName) || fieldName.contains('.')) {
      return false;
    }
    Matcher rootMatcher = Pattern.compile('(?i)\\bFROM\\s+([A-Za-z][A-Za-z0-9_]*)')
      .matcher(query);
    if (!rootMatcher.find()) {
      return false;
    }
    Schema.SObjectType objectType = Schema.getGlobalDescribe().get(rootMatcher.group(1));
    if (objectType == null) {
      return false;
    }
    Schema.SObjectField field = objectType.getDescribe().fields.getMap().get(fieldName);
    if (field == null) {
      return false;
    }
    Schema.DisplayType dataType = field.getDescribe().getType();
    return new Set<Schema.DisplayType>{
      Schema.DisplayType.STRING,
      Schema.DisplayType.TEXTAREA,
      Schema.DisplayType.EMAIL,
      Schema.DisplayType.PHONE,
      Schema.DisplayType.URL,
      Schema.DisplayType.ENCRYPTEDSTRING
    }.contains(dataType);
  }

  private static void requireQueryField(
    List<Object> issues,
    Map<String, Object> values,
    String queryField,
    String resultField
  ) {
    String query = text(values, queryField);
    if (String.isNotBlank(query) && !isSingleAggregateQuery(query)) {
      requireText(issues, values, resultField, 'Query result field is required for non-aggregate queries.');
    }
  }

  private static Boolean isSingleAggregateQuery(String query) {
    return Pattern.compile(
        '(?is)^\\s*SELECT\\s+(COUNT|SUM|AVG|MIN|MAX)\\s*\\([^,]+\\)\\s*(?:[A-Za-z][A-Za-z0-9_]*)?\\s+FROM\\s+.+$'
      )
      .matcher(query)
      .matches();
  }

  private static void requireText(
    List<Object> issues,
    Map<String, Object> values,
    String fieldName,
    String message
  ) {
    if (String.isBlank(text(values, fieldName))) {
      issues.add(issue(fieldName, message, 'MISSING_REQUIRED_FIELD'));
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
      issues.add(issue(fieldName, message, 'INVALID_CONFIG'));
    }
  }

  private static void addError(
    List<Object> issues,
    String fieldName,
    String message,
    String reasonCode
  ) {
    issues.add(issue(fieldName, message, reasonCode));
  }

  private static Map<String, Object> issue(
    String fieldName,
    String message,
    String reasonCode
  ) {
    return new Map<String, Object>{
      'severity' => 'ERROR',
      'reasonCode' => 'CORE_' + reasonCode,
      'path' => fieldName,
      'userMessage' => message
    };
  }

  private static String text(Map<String, Object> values, String fieldName) {
    Object value = values.get(fieldName);
    return value instanceof String ? (String) value : null;
  }
}
