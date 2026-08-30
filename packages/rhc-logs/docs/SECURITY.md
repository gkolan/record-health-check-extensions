# RHC Logs security

RHC diagnostic Logs are restricted operational data. They can identify users and records and can
contain implementation details or data fragments in messages and structured diagnostics.

## Controls

- Private organization-wide defaults on both package objects.
- Viewer has package-object View All Records only to overcome Automated Process ownership, but lacks
  restricted field access.
- Admin has package-object Modify All Records for bounded deletion and approved investigation.
- Review queries run with sharing and user-mode field/object enforcement.
- Administration uses user-mode reads and policy DML plus explicit CRUD/FLS checks. Only the fixed
  singleton key and package-owned ingestion/cleanup state use narrowly scoped system-mode writes.
- Admin field permissions make every counter, outcome, singleton-key, and cleanup-lease field
  read-only; only the three retention-policy fields are editable.
- Event ingestion is reachable only from the package Platform Event trigger and writes only package
  objects. Cleanup system-mode writes are restricted to the package settings singleton; log queries
  and deletes retain user-mode enforcement.
- No raw event JSON, stack trace, auth data, tokens, headers, debug logs, guest access, callouts, or
  notifications.
- All copied text is bounded. Event ID is unique and external-ID indexed.
- UI errors are sanitized and never echo a diagnostic payload.

## Restricted fields

Message and Structured Diagnostic Details may contain data or implementation context. Record ID and
Running User ID identify Salesforce records and principals. Only Admin receives these fields.
Organizations should evaluate Shield Platform Encryption, report/export permissions, backups,
sandboxes, support access, and data residency under their own policy.

At-least-once delivery is mitigated with canonical Event ID uniqueness. Contract drift remains
visible through Contract Version. Namespace-bearing identities are opaque and never rewritten.
Cleanup uses a fixed object and cannot accept an object name from UI input. Do not assign either
permission set to guest, unauthenticated, broad employee, or public integration personas.
