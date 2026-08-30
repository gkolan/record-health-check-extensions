/**
 * Matches canonical event DTOs to active routes and builds bounded delivery-ledger rows.
 */
public with sharing class RHCIntegrationDeliveryFactory {
    private static final String SUPPORTED_CONTRACT = '1.0';

    /**
     * @param eventRecords Canonical event DTOs from one subscriber transaction.
     * @param routes Active package-owned routes.
     * @param maximumDeliveries Safe delivery-row limit for the transaction.
     * @return Delivery rows ready for idempotent insertion.
     */
    public static List<Record_Health_Check_Integration_Delivery__c> build(
        List<RHCIntegrationEventDTO> eventRecords,
        List<Record_Health_Check_Integration_Route__c> routes,
        Integer maximumDeliveries
    ) {
        List<Record_Health_Check_Integration_Delivery__c> deliveries =
            new List<Record_Health_Check_Integration_Delivery__c>();
        for (RHCIntegrationEventDTO eventRecord : eventRecords) {
            appendMatchingDeliveries(eventRecord, routes, deliveries, maximumDeliveries);
        }
        return deliveries;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void appendMatchingDeliveries(
        RHCIntegrationEventDTO eventRecord,
        List<Record_Health_Check_Integration_Route__c> routes,
        List<Record_Health_Check_Integration_Delivery__c> deliveries,
        Integer maximumDeliveries
    ) {
        if (String.isBlank(eventRecord.eventId)) {
            return;
        }
        for (Record_Health_Check_Integration_Route__c route : routes) {
            if (!matches(route, eventRecord)) {
                continue;
            }
            Record_Health_Check_Integration_Delivery__c delivery = buildDelivery(route, eventRecord);
            if (delivery != null) {
                addWithinFanoutLimit(delivery, deliveries, maximumDeliveries);
            }
        }
    }

    private static void addWithinFanoutLimit(
        Record_Health_Check_Integration_Delivery__c delivery,
        List<Record_Health_Check_Integration_Delivery__c> deliveries,
        Integer maximumDeliveries
    ) {
        if (deliveries.size() >= maximumDeliveries) {
            throw new RHCIntegrationEventHandler.FanoutLimitException(
                'RHC Integrations fan-out exceeded the safe per-transaction limit of '
                + maximumDeliveries
                + ' deliveries. Reduce the subscriber batch size or active matching routes.'
            );
        }
        deliveries.add(delivery);
    }

    private static Boolean matches(
        Record_Health_Check_Integration_Route__c route,
        RHCIntegrationEventDTO eventRecord
    ) {
        String selectedIdentity = route.SelectionType__c == 'CHECK'
            ? eventRecord.checkQualifiedApiName
            : eventRecord.checkSetQualifiedApiName;
        return containsValue(route.EventTypes__c, eventRecord.eventType)
            && route.QualifiedApiName__c == selectedIdentity
            && containsValue(route.Statuses__c, eventRecord.status)
            && meetsSeverity(route.MinimumSeverity__c, eventRecord.severity);
    }

    private static Boolean containsValue(String multiSelect, String expected) {
        return !String.isBlank(multiSelect)
            && !String.isBlank(expected)
            && new Set<String>(multiSelect.split(';')).contains(expected);
    }

    private static Boolean meetsSeverity(String minimumSeverity, String eventSeverity) {
        if (String.isBlank(minimumSeverity)) {
            return true;
        }
        if (String.isBlank(eventSeverity)) {
            return false;
        }
        Map<String, Integer> ranks = new Map<String, Integer>{
            'INFO' => 1, 'WARNING' => 2, 'CRITICAL' => 3
        };
        return ranks.containsKey(eventSeverity)
            && ranks.get(eventSeverity) >= ranks.get(minimumSeverity);
    }

    private static Record_Health_Check_Integration_Delivery__c buildDelivery(
        Record_Health_Check_Integration_Route__c route,
        RHCIntegrationEventDTO eventRecord
    ) {
        String payload = RHCIntegrationPayloadBuilder.build(route.PayloadProfile__c, eventRecord);
        if (payload == null) {
            return null;
        }
        Boolean supportedContract = eventRecord.contractVersion == SUPPORTED_CONTRACT;
        return new Record_Health_Check_Integration_Delivery__c(
            Route__c = route.Id,
            EventId__c = eventRecord.eventId,
            RouteEventKey__c = String.valueOf(route.Id) + ':' + eventRecord.eventId,
            EventType__c = eventRecord.eventType,
            ContractVersion__c = eventRecord.contractVersion,
            PayloadProfile__c = route.PayloadProfile__c,
            PayloadProfileVersion__c = RHCIntegrationPayloadBuilder.PROFILE_VERSION,
            Payload__c = payload,
            Status__c = supportedContract ? 'PENDING' : 'DEAD_LETTER',
            ErrorCode__c = supportedContract ? null : 'UNSUPPORTED_EVENT_CONTRACT',
            ErrorDetail__c = supportedContract ? null : 'The event contract is not allow-listed by this package version.',
            CompletedAt__c = supportedContract ? null : System.now()
        );
    }
}
