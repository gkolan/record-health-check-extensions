/**
 * Security-enforced, paginated review API for retained diagnostic Logs.
 */
public with sharing class RHCLogsReviewController {
    private static final Integer DEFAULT_LIMIT = 100;
    private static final Integer MAX_LIMIT = 200;

    /** Approved filters for retained logs. */
    public class LogFilter {
        @AuraEnabled public Datetime occurredFrom;
        @AuraEnabled public Datetime occurredTo;
        @AuraEnabled public String severity;
        @AuraEnabled public String code;
        @AuraEnabled public String runId;
        @AuraEnabled public String checkSetDeveloperName;
        @AuraEnabled public String checkDeveloperName;
        @AuraEnabled public String recordId;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Datetime cursorOccurredAt;
        @AuraEnabled public Id cursorId;
    }

    /** One stable keyset page ordered by occurrence time and record ID. */
    public class LogPage {
        @AuraEnabled public List<Record_Health_Check_Diagnostic_Log__c> rows;
        @AuraEnabled public Boolean hasMore;
        @AuraEnabled public Datetime nextOccurredAt;
        @AuraEnabled public Id nextId;
    }

    private class QueryContext {
        private List<String> conditions = new List<String>();
        private Map<String, Object> binds = new Map<String, Object>();

        private void addText(String clause, String key, String value) {
            if (!String.isBlank(value)) {
                conditions.add(clause);
                binds.put(key, value);
            }
        }

        private void addDate(String clause, String key, Datetime value) {
            if (value != null) {
                conditions.add(clause);
                binds.put(key, value);
            }
        }
    }

    /**
     * Returns only fields readable by the current user.
     * @param filter approved equality/date filters
     * @return newest matching retained Logs plus an opaque continuation key
     */
    @AuraEnabled(cacheable=true)
    public static LogPage search(LogFilter filter) {
        if (!Schema.SObjectType.Record_Health_Check_Diagnostic_Log__c.isAccessible()) {
            throw sanitized('You do not have access to RHC Diagnostic Logs.');
        }

        LogFilter safeFilter = filter == null ? new LogFilter() : filter;
        Integer rowLimit = normalizedRowLimit(safeFilter.pageSize);
        assertCompleteCursor(safeFilter);
        assertFilterAccess(safeFilter);
        QueryContext context = buildQueryContext(safeFilter, rowLimit);
        List<String> selectedFields = readableFieldNames();
        String query = 'SELECT ' + String.join(selectedFields, ',')
            + ' FROM Record_Health_Check_Diagnostic_Log__c'
            + (context.conditions.isEmpty()
                ? ''
                : ' WHERE ' + String.join(context.conditions, ' AND '))
            + ' ORDER BY OccurredAt__c DESC, Id DESC LIMIT :queryLimit';
        List<Record_Health_Check_Diagnostic_Log__c> rows =
            (List<Record_Health_Check_Diagnostic_Log__c>) Database.queryWithBinds(
            query,
            context.binds,
            AccessLevel.USER_MODE
        );
        return buildPage(rows, rowLimit);
    }

    private static Integer normalizedRowLimit(Integer requestedLimit) {
        return requestedLimit == null
            ? DEFAULT_LIMIT
            : Math.max(1, Math.min(MAX_LIMIT, requestedLimit));
    }

    private static void assertCompleteCursor(LogFilter filter) {
        if ((filter.cursorOccurredAt == null) != (filter.cursorId == null)) {
            throw sanitized('The log page cursor is incomplete. Apply the filters again.');
        }
    }

    private static void assertFilterAccess(LogFilter filter) {
        Map<String, Schema.SObjectField> fields =
            Record_Health_Check_Diagnostic_Log__c.SObjectType
                .getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        Map<String, Object> valuesByField = new Map<String, Object>{
            'OccurredAt__c' => filter.occurredFrom ?? filter.occurredTo,
            'Severity__c' => filter.severity,
            'Code__c' => filter.code,
            'RunId__c' => filter.runId,
            'CheckSetDeveloperName__c' => filter.checkSetDeveloperName,
            'CheckDeveloperName__c' => filter.checkDeveloperName,
            'RecordId__c' => filter.recordId
        };
        for (String fieldName : valuesByField.keySet()) {
            Object requestedValue = valuesByField.get(fieldName);
            if (requestedValue != null
                && String.isNotBlank(String.valueOf(requestedValue))
                && !fields.get(fieldName).getDescribe().isAccessible()) {
                throw sanitized('You do not have access to one or more requested log filters.');
            }
        }
    }

    private static QueryContext buildQueryContext(LogFilter filter, Integer rowLimit) {
        QueryContext context = new QueryContext();
        context.binds.put('queryLimit', rowLimit + 1);
        context.addDate('OccurredAt__c >= :occurredFrom', 'occurredFrom', filter.occurredFrom);
        context.addDate('OccurredAt__c <= :occurredTo', 'occurredTo', filter.occurredTo);
        context.addText('Severity__c = :severity', 'severity', filter.severity);
        context.addText('Code__c = :code', 'code', filter.code);
        context.addText('RunId__c = :runId', 'runId', filter.runId);
        context.addText(
            'CheckSetDeveloperName__c = :checkSet',
            'checkSet',
            filter.checkSetDeveloperName
        );
        context.addText(
            'CheckDeveloperName__c = :checkName',
            'checkName',
            filter.checkDeveloperName
        );
        context.addText('RecordId__c = :recordId', 'recordId', filter.recordId);
        if (filter.cursorOccurredAt != null) {
            context.conditions.add(
                '(OccurredAt__c < :cursorOccurredAt OR '
                + '(OccurredAt__c = :cursorOccurredAt AND Id < :cursorId))'
            );
            context.binds.put('cursorOccurredAt', filter.cursorOccurredAt);
            context.binds.put('cursorId', filter.cursorId);
        }
        return context;
    }

    private static LogPage buildPage(
        List<Record_Health_Check_Diagnostic_Log__c> rows,
        Integer rowLimit
    ) {
        LogPage page = new LogPage();
        page.hasMore = rows.size() > rowLimit;
        if (page.hasMore) {
            rows.remove(rows.size() - 1);
        }
        page.rows = rows;
        if (page.hasMore && !rows.isEmpty()) {
            Record_Health_Check_Diagnostic_Log__c lastRow = rows[rows.size() - 1];
            page.nextOccurredAt = lastRow.OccurredAt__c;
            page.nextId = lastRow.Id;
        }
        return page;
    }

    private static List<String> readableFieldNames() {
        List<String> candidates = new List<String>{
            'Id', 'Name', 'EventId__c', 'RunId__c', 'OccurredAt__c',
            'ContractVersion__c', 'FrameworkVersion__c', 'Severity__c', 'Code__c',
            'ExceptionType__c', 'CheckSetDeveloperName__c', 'CheckDeveloperName__c',
            'IngestedAt__c', 'Message__c', 'StructuredDetails__c', 'RecordId__c',
            'RunningUserId__c'
        };
        Map<String, Schema.SObjectField> fields =
            Record_Health_Check_Diagnostic_Log__c.SObjectType
                .getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        List<String> readable = new List<String>();
        for (String candidate : candidates) {
            if (candidate == 'Id' || candidate == 'Name' || fields.get(candidate).getDescribe().isAccessible()) {
                readable.add(candidate);
            }
        }
        return readable;
    }

    private static AuraHandledException sanitized(String message) {
        AuraHandledException exceptionRecord = new AuraHandledException(message);
        exceptionRecord.setMessage(message);
        return exceptionRecord;
    }
}
