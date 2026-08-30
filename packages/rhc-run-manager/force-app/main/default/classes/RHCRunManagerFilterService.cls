/** Builds user-mode target queries from packaged structured filters. */
public with sharing class RHCRunManagerFilterService {
  private static final Set<String> COMPARISON_OPERATORS = new Set<String>{
    'EQ', 'NE', 'GT', 'GTE', 'LT', 'LTE'
  };
  private static final Set<String> STRING_OPERATORS = new Set<String>{
    'CONTAINS', 'STARTS_WITH'
  };

  /** Query text and bind values accepted by Database.getQueryLocatorWithBinds. */
  public class QuerySpec {
    public String soql;
    public Map<String, Object> binds = new Map<String, Object>();
  }

  /** Invalid guided-filter input. */
  public class FilterException extends Exception {
  }

  /**
   * Builds a safe ID query for the resolved object and population mode.
   * @param objectApiName Core-derived object API name.
   * @param populationMode ALL_ACCESSIBLE, GUIDED_FILTERED, or SUPPLIED_IDS.
   * @param filterJson Packaged structured filter JSON.
   * @param suppliedIds Explicit supplied IDs.
   * @return Safe query text and typed bind map.
   */
  public static QuerySpec build(
    String objectApiName,
    String populationMode,
    String filterJson,
    List<Id> suppliedIds
  ) {
    Schema.DescribeSObjectResult objectDescribe = describeObject(objectApiName);
    QuerySpec spec = new QuerySpec();
    spec.soql = 'SELECT Id FROM ' + objectDescribe.getName();
    if ('ALL_ACCESSIBLE'.equals(populationMode)) {
      return spec;
    }
    if ('SUPPLIED_IDS'.equals(populationMode)) {
      spec.binds.put('targetIds', suppliedIds ?? new List<Id>());
      spec.soql += ' WHERE Id IN :targetIds';
      return spec;
    }
    if (!'GUIDED_FILTERED'.equals(populationMode)) {
      throw new FilterException('Population Mode is invalid.');
    }
    List<Object> filters = parseFilters(filterJson);
    List<String> clauses = new List<String>();
    Integer indexValue = 0;
    for (Object filterValue : filters) {
      clauses.add(buildClause(objectDescribe, (Map<String, Object>) filterValue, indexValue, spec.binds));
      indexValue++;
    }
    spec.soql += ' WHERE ' + String.join(clauses, ' AND ');
    return spec;
  }

  /** Validates guided-filter JSON without querying business records. */
  public static void validate(
    String objectApiName,
    String populationMode,
    String filterJson
  ) {
    build(objectApiName, populationMode, filterJson, new List<Id>());
  }

  private static String buildClause(
    Schema.DescribeSObjectResult objectDescribe,
    Map<String, Object> filter,
    Integer indexValue,
    Map<String, Object> binds
  ) {
    String fieldName = String.valueOf(filter.get('field'));
    String operatorName = String.valueOf(filter.get('operator')).toUpperCase();
    Schema.SObjectField fieldToken = objectDescribe.fields.getMap().get(fieldName);
    if (fieldToken == null) {
      throw new FilterException('A guided-filter field does not exist on the target object.');
    }
    Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
    if (!fieldDescribe.isAccessible() || !fieldDescribe.isFilterable()) {
      throw new FilterException('A guided-filter field is not readable and filterable.');
    }
    if ('IS_NULL'.equals(operatorName)) {
      return fieldDescribe.getName() + ' = NULL';
    }
    String bindName = 'value' + indexValue;
    Object converted = convertValue(fieldDescribe, filter.get('value'));
    if (STRING_OPERATORS.contains(operatorName)) {
      if (fieldDescribe.getType() != Schema.DisplayType.STRING && fieldDescribe.getType() != Schema.DisplayType.TEXTAREA) {
        throw new FilterException('The selected operator requires a text field.');
      }
      String textValue = String.valueOf(converted);
      binds.put(bindName, 'CONTAINS'.equals(operatorName) ? '%' + textValue + '%' : textValue + '%');
      return fieldDescribe.getName() + ' LIKE :' + bindName;
    }
    if (!COMPARISON_OPERATORS.contains(operatorName)) {
      throw new FilterException('The guided-filter operator is not supported.');
    }
    binds.put(bindName, converted);
    return fieldDescribe.getName() + ' ' + operatorToken(operatorName) + ' :' + bindName;
  }

  private static List<Object> parseFilters(String filterJson) {
    if (String.isBlank(filterJson)) {
      throw new FilterException('At least one guided filter is required.');
    }
    Object parsed;
    try {
      parsed = JSON.deserializeUntyped(filterJson);
    } catch (JSONException error) {
      throw new FilterException('Guided filter JSON is invalid.');
    }
    if (!(parsed instanceof List<Object>) || ((List<Object>) parsed).isEmpty() || ((List<Object>) parsed).size() > 10) {
      throw new FilterException('Guided filters require 1-10 conditions.');
    }
    return (List<Object>) parsed;
  }

  private static Schema.DescribeSObjectResult describeObject(String objectApiName) {
    Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
    if (objectType == null || !objectType.getDescribe().isQueryable() || !objectType.getDescribe().isAccessible()) {
      throw new FilterException('The target object is not queryable by this user.');
    }
    return objectType.getDescribe();
  }

  private static String operatorToken(String operatorName) {
    Map<String, String> tokens = new Map<String, String>{
      'EQ' => '=', 'NE' => '!=', 'GT' => '>', 'GTE' => '>=', 'LT' => '<', 'LTE' => '<='
    };
    return tokens.get(operatorName);
  }

  private static Object convertValue(
    Schema.DescribeFieldResult fieldDescribe,
    Object value
  ) {
    if (value == null) {
      return null;
    }
    String textValue = String.valueOf(value);
    Schema.DisplayType fieldType = fieldDescribe.getType();
    try {
      if (fieldType == Schema.DisplayType.BOOLEAN) return Boolean.valueOf(textValue);
      if (fieldType == Schema.DisplayType.DATE) return Date.valueOf(textValue);
      if (fieldType == Schema.DisplayType.DATETIME) return Datetime.valueOfGmt(textValue);
      if (new Set<Schema.DisplayType>{ Schema.DisplayType.CURRENCY, Schema.DisplayType.DOUBLE, Schema.DisplayType.INTEGER, Schema.DisplayType.LONG, Schema.DisplayType.PERCENT }.contains(fieldType)) return Decimal.valueOf(textValue);
      return textValue;
    } catch (Exception error) {
      throw new FilterException('A guided-filter value does not match its field type.');
    }
  }
}
