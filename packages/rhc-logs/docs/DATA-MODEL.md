# RHC Logs data model

Record_Health_Check_Diagnostic_Log__c uses Private sharing and an auto-number display name. EventId__c is the unique
external-ID idempotency key. Run ID, occurrence, contract/framework version, severity, code,
exception type, Check Set developer name, Check developer name, and ingestion time support approved
correlation and classification.

Message and Structured Diagnostic Details are bounded to 8,000 characters and Admin-only. Record ID
and Running User ID are Admin-only. Stack Trace is deliberately excluded on Day 1. Raw event JSON,
Replay ID, auth material, headers, debug logs, source inference, and ordinary health-check results
are never stored.

Record_Health_Check_Log_Settings__c uses Public Read/Write sharing and unique Settings Key Default.
Approved admins share the singleton regardless of its owner, subject to object and field permissions.
It stores the bounded
retention policy, schedule enablement, last-run snapshots, sanitized ingestion error categories, and
a stale-recoverable overlap token. Admin can edit only Retention Days, Cleanup Batch Size, and
Automated Cleanup; singleton identity, counters, outcomes, and lease state are package-owned and
read-only. It contains no diagnostic payload. See [the specification](../SPEC.md#data-model).
