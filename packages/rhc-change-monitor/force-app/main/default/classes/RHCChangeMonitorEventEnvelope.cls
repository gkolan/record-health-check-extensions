/**
 * Immutable, disclosure-safe facts extracted from one Salesforce change event.
 * Global visibility is required so subscriber-owned triggers can cross a package namespace.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global class RHCChangeMonitorEventEnvelope {
  /** Exact durable source-object API name. */
  global String sourceObjectApiName { get; private set; }
  /** Exact Salesforce change-event type API name. */
  global String changeEventTypeApiName { get; private set; }
  /** Normalized supported change type, GAP, or UNKNOWN. */
  global String changeType { get; private set; }
  /** Changed field API names disclosed by the event header. */
  global Set<String> changedFields { get; private set; }
  /** Source record IDs disclosed by the event header. */
  global List<String> recordIds { get; private set; }
  /** Stable CDC transaction correlation key. */
  global String transactionKey { get; private set; }
  /** Stable sequence within the CDC transaction. */
  global Long sequenceNumber { get; private set; }
  /** Opaque event-stream replay evidence. */
  global String replayId { get; private set; }
  /** Optional platform event UUID evidence. */
  global String eventUuid { get; private set; }
  /** CDC occurrence time, bounded to the current time when unavailable. */
  global Datetime occurredAt { get; private set; }

  /** Explicit facts used to construct a validated envelope without a long parameter list. */
  global class Facts {
    /** Exact durable source-object API name. */
    global String sourceObjectApiName;
    /** Exact Salesforce change-event type API name. */
    global String changeEventTypeApiName;
    /** Raw CDC change type. */
    global String changeType;
    /** Changed field API names. */
    global Set<String> changedFields;
    /** Source record IDs. */
    global List<String> recordIds;
    /** Stable transaction key. */
    global String transactionKey;
    /** Stable sequence within the transaction. */
    global Long sequenceNumber;
    /** Opaque replay-position evidence. */
    global String replayId;
    /** Optional platform event UUID evidence. */
    global String eventUuid;
    /** CDC occurrence time. */
    global Datetime occurredAt;
  }

  /** Invalid or unsupported change-event input. */
  global class InvalidEventException extends Exception {
  }

  /**
   * Builds a validated envelope from explicit CDC header facts.
   * @param facts Disclosure-safe CDC header facts.
   */
  global RHCChangeMonitorEventEnvelope(Facts facts) {
    if (facts == null) {
      throw new InvalidEventException('Event facts are required.');
    }
    sourceObjectApiName = facts.sourceObjectApiName;
    changeEventTypeApiName = facts.changeEventTypeApiName;
    changeType = normalizeChangeType(facts.changeType);
    changedFields = facts.changedFields == null
      ? new Set<String>()
      : new Set<String>(facts.changedFields);
    recordIds = facts.recordIds == null
      ? new List<String>()
      : new List<String>(facts.recordIds);
    transactionKey = bound(facts.transactionKey, 80);
    sequenceNumber = facts.sequenceNumber;
    replayId = bound(facts.replayId, 80);
    eventUuid = bound(facts.eventUuid, 80);
    occurredAt = facts.occurredAt == null ? System.now() : facts.occurredAt;
    validateSourceIdentity();
    validateStableIdentity();
    validateRecordIds();
  }

  /**
   * Extracts only approved header facts from an actual Salesforce ChangeEvent sObject.
   * @param changeEvent Salesforce standard or custom ChangeEvent record.
   * @return Validated disclosure-safe envelope.
   */
  global static RHCChangeMonitorEventEnvelope fromChangeEvent(SObject changeEvent) {
    return new RHCChangeMonitorEventEnvelope(RHCChangeMonitorEventParser.parse(changeEvent));
  }

  @TestVisible
  private static RHCChangeMonitorEventEnvelope fromHeader(
    String eventType,
    Map<String, Object> header,
    Map<String, Object> evidence
  ) {
    return new RHCChangeMonitorEventEnvelope(
      RHCChangeMonitorEventParser.parseHeader(eventType, header, evidence)
    );
  }

  private void validateSourceIdentity() {
    if (String.isBlank(sourceObjectApiName)) {
      throw new InvalidEventException('Source object is required.');
    }
    if (!sourceObjectApiName.equals(RHCChangeMonitorEventParser.sourceTypeFor(changeEventTypeApiName))) {
      throw new InvalidEventException('Source object and ChangeEvent type must match exactly.');
    }
  }

  private void validateStableIdentity() {
    if (String.isBlank(transactionKey)) {
      throw new InvalidEventException('Stable transaction key is required.');
    }
    if (sequenceNumber == null) {
      throw new InvalidEventException('Stable sequence number is required.');
    }
    if (!'GAP'.equals(changeType) && recordIds.isEmpty()) {
      throw new InvalidEventException('At least one source record ID is required.');
    }
  }

  private void validateRecordIds() {
    for (String recordId : recordIds) {
      if (String.isBlank(recordId)) {
        throw new InvalidEventException('A source record ID is malformed.');
      }
      if (!Pattern.matches('[a-zA-Z0-9]{15}|[a-zA-Z0-9]{18}', recordId)) {
        throw new InvalidEventException('A source record ID is malformed.');
      }
    }
  }

  private static String normalizeChangeType(String value) {
    String normalized = String.isBlank(value) ? '' : value.trim().toUpperCase();
    if (normalized.startsWith('GAP_') || 'GAP'.equals(normalized)) {
      return 'GAP';
    }
    if (new Set<String>{ 'CREATE', 'UPDATE', 'UNDELETE', 'DELETE' }.contains(normalized)) {
      return normalized;
    }
    return 'UNKNOWN';
  }

  private static String bound(String value, Integer maximumLength) {
    if (String.isBlank(value)) {
      return value;
    }
    return value.length() <= maximumLength ? value : value.substring(0, maximumLength);
  }
}
