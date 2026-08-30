/** Parses disclosure-safe CDC header facts without retaining event payload values. */
public class RHCChangeMonitorEventParser {
  @SuppressWarnings('PMD.EmptyStatementBlock')
  private RHCChangeMonitorEventParser() {
  }

  /**
   * Parses an actual Salesforce change-event record.
   * @param changeEvent Salesforce standard or custom ChangeEvent record.
   * @return Disclosure-safe event facts.
   */
  public static RHCChangeMonitorEventEnvelope.Facts parse(SObject changeEvent) {
    if (changeEvent == null) {
      throw new RHCChangeMonitorEventEnvelope.InvalidEventException('A change event is required.');
    }
    String eventType = changeEvent.getSObjectType().getDescribe().getName();
    String sourceType = sourceTypeFor(eventType);
    Map<String, Object> header = deserializeHeader(readHeader(changeEvent));
    String headerEntity = asString(valueFor(header, 'entityName'));
    if (!sourceType.equals(headerEntity)) {
      throw new RHCChangeMonitorEventEnvelope.InvalidEventException(
        'ChangeEventHeader entity does not match the event type.'
      );
    }
    Map<String, Object> evidence = new Map<String, Object>{
      'replayId' => safeGet(changeEvent, 'ReplayId'),
      'eventUuid' => safeGet(changeEvent, 'EventUuid')
    };
    return parseHeader(eventType, header, evidence);
  }

  /**
   * Parses explicit header and stream evidence for deterministic tests.
   * @param eventType Exact Salesforce ChangeEvent type API name.
   * @param header Deserialized ChangeEventHeader facts.
   * @param evidence Opaque replay ID and optional event UUID.
   * @return Disclosure-safe event facts.
   */
  public static RHCChangeMonitorEventEnvelope.Facts parseHeader(
    String eventType,
    Map<String, Object> header,
    Map<String, Object> evidence
  ) {
    RHCChangeMonitorEventEnvelope.Facts facts = new RHCChangeMonitorEventEnvelope.Facts();
    facts.sourceObjectApiName = sourceTypeFor(eventType);
    facts.changeEventTypeApiName = eventType;
    facts.changeType = asString(valueFor(header, 'changeType'));
    facts.changedFields = new Set<String>(asStringList(valueFor(header, 'changedFields')));
    facts.recordIds = asStringList(valueFor(header, 'recordIds'));
    facts.transactionKey = asString(valueFor(header, 'transactionKey'));
    facts.sequenceNumber = asLong(valueFor(header, 'sequenceNumber'));
    facts.replayId = asString(valueFor(evidence, 'replayId'));
    facts.eventUuid = asString(valueFor(evidence, 'eventUuid'));
    facts.occurredAt = asDatetime(valueFor(header, 'commitTimestamp'));
    return facts;
  }

  /**
   * Derives the durable source-object API name from a change-event type.
   * @param eventType Exact Salesforce ChangeEvent type API name.
   * @return Exact durable source-object API name.
   */
  public static String sourceTypeFor(String eventType) {
    if (String.isBlank(eventType)) {
      throw new RHCChangeMonitorEventEnvelope.InvalidEventException(
        'ChangeEvent type is required.'
      );
    }
    if (eventType.endsWith('__ChangeEvent')) {
      return eventType.substring(0, eventType.length() - 13) + '__c';
    }
    if (eventType.endsWith('ChangeEvent')) {
      return eventType.substring(0, eventType.length() - 11);
    }
    throw new RHCChangeMonitorEventEnvelope.InvalidEventException(
      'Only Salesforce ChangeEvent sObjects are accepted.'
    );
  }

  private static Object readHeader(SObject changeEvent) {
    Object headerValue;
    try {
      headerValue = changeEvent.get('ChangeEventHeader');
    } catch (SObjectException error) {
      throw new RHCChangeMonitorEventEnvelope.InvalidEventException(
        'The supplied sObject has no ChangeEventHeader.',
        error
      );
    }
    if (headerValue == null) {
      throw new RHCChangeMonitorEventEnvelope.InvalidEventException(
        'ChangeEventHeader is required.'
      );
    }
    return headerValue;
  }

  private static Map<String, Object> deserializeHeader(Object headerValue) {
    return (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(headerValue));
  }

  private static Object valueFor(Map<String, Object> values, String key) {
    if (values == null) {
      return null;
    }
    for (String candidate : values.keySet()) {
      if (candidate.equalsIgnoreCase(key)) {
        return values.get(candidate);
      }
    }
    return null;
  }

  private static Object safeGet(SObject recordValue, String fieldName) {
    if (!recordValue.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
      return null;
    }
    return recordValue.get(fieldName);
  }

  private static String asString(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static Long asLong(Object value) {
    return value == null ? null : Decimal.valueOf(String.valueOf(value)).longValue();
  }

  private static Datetime asDatetime(Object value) {
    if (value == null) {
      return System.now();
    }
    try {
      return Datetime.newInstance(asLong(value));
    } catch (Exception ignored) {
      return System.now();
    }
  }

  private static List<String> asStringList(Object value) {
    List<String> output = new List<String>();
    if (value == null) {
      return output;
    }
    for (Object item : (List<Object>) value) {
      output.add(String.valueOf(item));
    }
    return output;
  }
}
