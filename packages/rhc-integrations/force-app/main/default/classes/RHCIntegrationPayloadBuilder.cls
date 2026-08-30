/**
 * Builds only packaged, versioned payload profiles from canonical event fields.
 */
public with sharing class RHCIntegrationPayloadBuilder {
    public static final String PROFILE_VERSION = '1.0';
    private static final String ERROR_PROFILE = 'RHC Error v1';
    private static final String OUTCOME_PROFILE = 'RHC Outcome v1';
    private static final String RUN_PROFILE = 'RHC Run v1';
    private static final String LOG_PROFILE = 'RHC Log v1';

    /**
     * Builds an allow-listed payload without consulting customer code or templates.
     * @param profileName Packaged profile selected by the route.
     * @param eventRecord Canonical event shape.
     * @return Serialized JSON payload, or null when the profile is incompatible.
     */
    public static String build(String profileName, RHCIntegrationEventDTO eventRecord) {
        if (eventRecord == null || String.isBlank(eventRecord.eventId)) {
            return null;
        }
        Map<String, Object> payload = commonFields(eventRecord);
        return addProfileFields(profileName, payload, eventRecord) ? JSON.serialize(payload) : null;
    }

    private static Boolean addProfileFields(
        String profileName,
        Map<String, Object> payload,
        RHCIntegrationEventDTO eventRecord
    ) {
        if (profileName == ERROR_PROFILE) {
            return addErrorProfile(payload, eventRecord);
        }
        if (profileName == OUTCOME_PROFILE) {
            return addOutcomeProfile(payload, eventRecord);
        }
        if (profileName == RUN_PROFILE) {
            return addRunProfile(payload, eventRecord);
        }
        if (profileName == LOG_PROFILE) {
            return addLogProfile(payload, eventRecord);
        }
        return false;
    }

    private static Boolean addErrorProfile(Map<String, Object> payload, RHCIntegrationEventDTO eventRecord) {
        if (eventRecord.status != 'ERROR') {
            return false;
        }
        addOutcomeFields(payload, eventRecord);
        return true;
    }

    private static Boolean addOutcomeProfile(Map<String, Object> payload, RHCIntegrationEventDTO eventRecord) {
        if (eventRecord.eventType != 'RESULT') {
            return false;
        }
        addOutcomeFields(payload, eventRecord);
        return true;
    }

    private static Boolean addRunProfile(Map<String, Object> payload, RHCIntegrationEventDTO eventRecord) {
        if (eventRecord.eventType != 'RUN') {
            return false;
        }
        addRunFields(payload, eventRecord);
        return true;
    }

    private static Boolean addLogProfile(Map<String, Object> payload, RHCIntegrationEventDTO eventRecord) {
        if (eventRecord.eventType != 'LOG') {
            return false;
        }
        payload.put('code', eventRecord.code);
        return true;
    }

    private static Map<String, Object> commonFields(RHCIntegrationEventDTO eventRecord) {
        return new Map<String, Object>{
            'payloadProfileVersion' => PROFILE_VERSION,
            'eventContractVersion' => eventRecord.contractVersion,
            'frameworkVersion' => eventRecord.frameworkVersion,
            'eventType' => eventRecord.eventType,
            'eventId' => eventRecord.eventId,
            'runId' => eventRecord.runId,
            'occurredAt' => eventRecord.occurredAt,
            'source' => eventRecord.source
        };
    }

    private static void addOutcomeFields(Map<String, Object> payload, RHCIntegrationEventDTO eventRecord) {
        payload.put('checkSetQualifiedApiName', eventRecord.checkSetQualifiedApiName);
        payload.put('checkQualifiedApiName', eventRecord.checkQualifiedApiName);
        payload.put('status', eventRecord.status);
        payload.put('severity', eventRecord.severity);
        payload.put('reasonCode', eventRecord.reasonCode);
        payload.put('recordId', eventRecord.recordId);
    }

    private static void addRunFields(Map<String, Object> payload, RHCIntegrationEventDTO eventRecord) {
        payload.put('checkSetQualifiedApiName', eventRecord.checkSetQualifiedApiName);
        payload.put('status', eventRecord.status);
        payload.put('recordId', eventRecord.recordId);
        payload.put('eligibleCount', eventRecord.eligibleCount);
        payload.put('evaluatedCount', eventRecord.evaluatedCount);
        payload.put('passedCount', eventRecord.passedCount);
        payload.put('failedCount', eventRecord.failedCount);
        payload.put('skippedCount', eventRecord.skippedCount);
        payload.put('unableCount', eventRecord.unableCount);
        payload.put('systemErrorCount', eventRecord.systemErrorCount);
    }
}
