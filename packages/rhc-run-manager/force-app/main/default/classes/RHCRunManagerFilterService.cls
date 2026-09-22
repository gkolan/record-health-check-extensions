/** Builds user-mode target queries from packaged structured filters. */
public with sharing class RHCRunManagerFilterService {
  private static final Map<String, String> COMPARISON_OPERATOR_TOKENS = new Map<String, String>{
    'EQ' => '=', 'NE' => '!=', 'GT' => '>', 'GTE' => '>=', 'LT' => '<', 'LTE' => '<='
  };
  private static final Set<String> STRING_OPERATORS = new Set<String>{
    'CONTAINS', 'STARTS_WITH'
  };
  private static final Set<Schema.DisplayType> TEXT_FIELD_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.STRING, Schema.DisplayType.TEXTAREA
  };
  private static final Set<Schema.DisplayType> NUMERIC_FIELD_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.CURRENCY,
    Schema.DisplayType.DOUBLE,
    Schema.DisplayType.INTEGER,
    Schema.DisplayType.LONG,
    Schema.DisplayType.PERCENT
  };

  /** Query text and bind values accepted by Database.getQueryLocatorWithBinds. */
  public class QuerySpec {
    public String soql;
    public Map<String, Object> binds = new Map<String, Object>();
    private Integer nextFilterIndex = 0;
  }

  /** Validated inputs used to construct one target-record query. */
  public class QueryRequest {
    public String objectApiName;
    public String populationMode;
    public String filterJson;
    public List<Id> suppliedIds;
  }

  /** Invalid guided-filter input. */
  public class FilterException extends Exception {
  }

  /**
   * Builds a safe ID query for the resolved object and population mode.
   * @param request Core-derived object, population mode, structured filters, and supplied IDs.
   * @return Safe query text and typed bind map.
   */
  public static QuerySpec build(QueryRequest request) {
    if (request == null) {
      throw new FilterException('Query request is required.');
    }
    Schema.DescribeSObjectResult objectDescribe = describeObject(request.objectApiName);
    QuerySpec spec = new QuerySpec();
    spec.soql = 'SELECT Id FROM ' + objectDescribe.getName();
    if ('ALL_ACCESSIBLE'.equals(request.populationMode)) {
      return spec;
    }
    if ('SUPPLIED_IDS'.equals(request.populationMode)) {
      spec.binds.put('targetIds', request.suppliedIds ?? new List<Id>());
      spec.soql += ' WHERE Id IN :targetIds';
      return spec;
    }
    if (!'GUIDED_FILTERED'.equals(request.populationMode)) {
      throw new FilterException('Population Mode is invalid.');
    }
    List<Object> filters = parseFilters(request.filterJson);
    List<String> clauses = new List<String>();
    Integer indexValue = 0;
    for (Object filterValue : filters) {
      spec.nextFilterIndex = indexValue;
      clauses.add(buildClause(objectDescribe, (Map<String, Object>) filterValue, spec));
      indexValue++;
    }
    spec.soql += ' WHERE ' + String.join(clauses, ' AND ');
    return spec;
  }

  /**
   * Validates guided-filter JSON without querying business records.
   * @param objectApiName Core-derived object API name.
   * @param populationMode ALL_ACCESSIBLE, GUIDED_FILTERED, or SUPPLIED_IDS.
   * @param filterJson Packaged structured filter JSON.
   */
  public static void validate(
    String objectApiName,
    String populationMode,
    String filterJson
  ) {
    QueryRequest request = new QueryRequest();
    request.objectApiName = objectApiName;
    request.populationMode = populationMode;
    request.filterJson = filterJson;
    request.suppliedIds = new List<Id>();
    build(request);
  }

  private static String buildClause(
    Schema.DescribeSObjectResult objectDescribe,
    Map<String, Object> filter,
    QuerySpec spec
  ) {
    String operatorName = String.valueOf(filter.get('operator')).toUpperCase();
    Schema.DescribeFieldResult fieldDescribe = describeField(objectDescribe, filter.get('field'));
    if ('IS_NULL'.equals(operatorName)) {
      return fieldDescribe.getName() + ' = NULL';
    }
    String bindName = 'value' + spec.nextFilterIndex;
    Object converted = new ValueConverter().convert(fieldDescribe, filter.get('value'));
    if (STRING_OPERATORS.contains(operatorName)) {
      if (!TEXT_FIELD_TYPES.contains(fieldDescribe.getType())) {
        throw new FilterException('The selected operator requires a text field.');
      }
      String textValue = String.valueOf(converted);
      spec.binds.put(bindName, 'CONTAINS'.equals(operatorName) ? '%' + textValue + '%' : textValue + '%');
      return fieldDescribe.getName() + ' LIKE :' + bindName;
    }
    if (!COMPARISON_OPERATOR_TOKENS.containsKey(operatorName)) {
      throw new FilterException('The guided-filter operator is not supported.');
    }
    spec.binds.put(bindName, converted);
    return fieldDescribe.getName() + ' ' + COMPARISON_OPERATOR_TOKENS.get(operatorName) + ' :' + bindName;
  }

  private static Schema.DescribeFieldResult describeField(
    Schema.DescribeSObjectResult objectDescribe,
    Object requestedField
  ) {
    Schema.SObjectField fieldToken = objectDescribe.fields.getMap().get(String.valueOf(requestedField));
    if (fieldToken == null) {
      throw new FilterException('A guided-filter field does not exist on the target object.');
    }
    Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
    if (!fieldDescribe.isAccessible() || !fieldDescribe.isFilterable()) {
      throw new FilterException('A guided-filter field is not readable and filterable.');
    }
    return fieldDescribe;
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

  private class ValueConverter {
    private Object convert(Schema.DescribeFieldResult fieldDescribe, Object value) {
      if (value == null) {
        return null;
      }
      String textValue = String.valueOf(value);
      Schema.DisplayType fieldType = fieldDescribe.getType();
      try {
        if (fieldType == Schema.DisplayType.BOOLEAN) {
          return Boolean.valueOf(textValue);
        }
        if (fieldType == Schema.DisplayType.DATE) {
          return Date.valueOf(textValue);
        }
        if (fieldType == Schema.DisplayType.DATETIME) {
          return Datetime.valueOfGmt(textValue);
        }
        if (NUMERIC_FIELD_TYPES.contains(fieldType)) {
          return Decimal.valueOf(textValue);
        }
        return textValue;
      } catch (Exception error) {
        throw new FilterException('A guided-filter value does not match its field type.');
      }
    }
  }
}
