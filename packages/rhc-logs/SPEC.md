# RHC Logs authoritative specification

## Status and authority

This document is the authoritative Day 1 contract for RHC Logs. Implementation, documentation,
permissions, tests, packaging, and release evidence must agree with it. There are no migrations,
legacy aliases, deprecated APIs, dual writes, or compatibility shims.

## Product purpose

RHC Logs is an optional, lightweight Salesforce 2GP extension that retains restricted diagnostic
events published by Record Health Check core. It lets approved administrators search, investigate,
monitor, and expire those events without installing another RHC extension or sending the data out
of Salesforce.

RHC Logs depends only on Record Health Check core. It does not depend on or access RHC Run Manager,
Alerts, Reports, Actions, Integrations, or Builder.

## Required core contract

RHC Logs subscribes directly and only to the packaged
`rhc__Record_Health_Check_Log__e` high-volume Platform Event. It does not subscribe to Run or Result
events. The minimum compatible promoted core version is **Record Health Check 2.0.4.2**, package
version alias `Record Health Check@2.0.4-2`, subscriber package version
`04tak000000cZBFAA2`.

That release is the minimum because it promotes all of these required behaviors together:

- canonical Log event contract version `1.0`;
- required canonical Event ID suitable for durable idempotency;
- default-off `PublishErrorLogEvent__c` Check Set control; and
- separate **Record Health Check Error Log Publisher** permission.

Core publication is opt-in per Check Set. The running identity must also receive the core publisher
permission. If no event is published, RHC Logs has nothing to retain. Publication and delivery are
asynchronous, best effort, and at least once.

### Core gap analysis

| Proposed capability | Promoted core support | RHC Logs decision |
| --- | --- | --- |
| Direct diagnostic ingestion | `Record_Health_Check_Log__e` exists | Subscribe directly; do not invent another event contract. |
| Durable idempotency | Required `EventId__c` Text(80) | Retain in a unique external-ID field. Replay ID is not a durable key. |
| Time, severity, code, run correlation | Canonical fields exist | Retain exact values, bounded to destination limits. |
| Check Set and Check identity | Event exposes `CheckSetDeveloperName__c` and `CheckDeveloperName__c` | Preserve exact strings. Do not add, remove, infer, or rewrite namespace prefixes. Do not relabel them as Qualified API Names. |
| Execution source | No source field exists on Log contract 1.0 | Do not infer or store a source. UI explains that this filter is unavailable for this contract. |
| Publication readiness | Check Set CMDT exposes `PublishErrorLogEvent__c`; event describe exposes subscriber accessibility | Setup assistant performs read-only describe/configuration checks where authorized. Permission-set assignment gaps cannot be proven for every possible runtime identity and are reported as guided checks. |
| Stack trace investigation | `StackTrace__c` exists | Excluded on Day 1; message and structured details provide a smaller restricted surface. |
| Structured diagnostics | `DetailsJson__c` exists | Retain only a bounded opaque copy; never parse it into a new contract and never store raw event JSON. |

The promoted contract is sufficient. Core changes are not proposed.

## Package boundary

RHC Logs owns only:

- the retained diagnostic Log object;
- one small Settings object holding a singleton retention configuration and observable counters;
- Log-event ingestion and canonical Event ID duplicate suppression;
- bounded cleanup, manual cleanup invocation, and one managed schedule;
- administration, setup-assistant, monitoring, and log-review Lightning UI;
- Admin and least-privilege Viewer permission sets; and
- package-specific documentation and tests.

RHC Logs never evaluates records, runs or schedules health checks, retains ordinary health-check
results, reads Salesforce Debug Logs, sends notifications, executes corrective Flows, makes
callouts, stores credentials, or delivers data externally. Subscriber code never calls Record
Health Check from the Log-event trigger.

## Data model

### RHC Diagnostic Log (`Record_Health_Check_Diagnostic_Log__c`)

Private-sharing, package-owned operational record with an auto-number name. Only the fields below
are stored. Every copied text value is null-safe and truncated to the declared destination length.

| Destination field | Source | Classification | Maximum | Operational necessity |
| --- | --- | --- | --- | --- |
| Event ID | `EventId__c` | retained | 80 | Canonical unique external ID prevents duplicate delivery from creating duplicate records. |
| Run ID | `RunId__c` | retained | 120 | Correlates diagnostics from one core execution. |
| Occurred At | `OccurredAt__c` | retained | Date/Time | Preserves canonical event time for investigation and retention. |
| Contract Version | `ContractVersion__c` | retained | 10 | Makes unsupported or changed contracts visible. |
| Framework Version | `FrameworkVersion__c` | retained | 20 | Correlates incidents with the publishing core version. |
| Severity | `Level__c` | retained | 10 | Supports critical/review filtering while preserving the exact canonical value. |
| Code | `Code__c` | retained | 120 | Supports diagnostic classification and search; it is not a public business reason code. |
| Message | `Message__c` | retained with additional protection; bounded | 8,000 | Supplies the minimum human-readable investigation detail; Viewer lacks field access. |
| Structured Diagnostic Details | `DetailsJson__c` | retained with additional protection; bounded | 8,000 | Preserves bounded machine-readable context without defining a second contract; Viewer lacks field access. |
| Exception Type | `ExceptionType__c` | retained | 120 | Identifies the failure class without retaining a stack trace. |
| Record ID | `RecordId__c` | retained with additional protection | 18 | Correlates to the affected record when supplied; Viewer lacks field access. |
| Check Set Developer Name | `CheckSetDeveloperName__c` | retained exactly | 120 | Identifies the publishing Check Set exactly as provided by core. |
| Check Developer Name | `CheckDeveloperName__c` | retained exactly | 120 | Identifies the publishing Check exactly as provided by core. |
| Running User ID | `UserId__c` | retained with additional protection | 18 | Identifies the execution principal when supplied; Viewer lacks field access. |
| Ingested At | package generated | package operational metadata | Date/Time | Separates event occurrence from successful retention time. |

Deliberately excluded core fields:

- `StackTrace__c`: not essential for the initial package and materially increases restricted-data
  exposure.
- Replay ID and platform audit fields: Replay ID is not the durable idempotency key and audit fields
  are not part of the canonical event payload.
- raw event JSON: prohibited; only explicitly mapped fields are stored.

No authentication data, access tokens, headers, Salesforce Debug Logs, or unrelated exception data
is stored.

### RHC Logs Settings (`Record_Health_Check_Log_Settings__c`)

Private-sharing singleton keyed by the fixed unique Settings Key `Default` (with the same record
name). A package-owned object is required
because retention must be deliberately mutable by an administrator, scheduling state must be
observable, and protected Custom Metadata is not safely subscriber-editable.

Fields:

- Settings Key: required unique Text(40), fixed to `Default` by package services.
- Retention Days: integer, allowed range 1–365, blank until deliberately configured.
- Automated Cleanup Enabled: false by default.
- Cleanup Batch Size: integer, allowed range 1–9,998, default 2,000. The maximum reserves two
  transaction DML rows for lock acquisition and result persistence.
- Last Ingestion At, Last Ingestion Count, Last Duplicate Count, Last Ingestion Failure Count,
  Last Ingestion Status, and sanitized Last Ingestion Error Categories.
- Last Cleanup At, Last Cleanup Deleted Count, Last Cleanup Failure Count, Last Cleanup Status.
- Cleanup In Progress and Cleanup Run Token for overlap protection and retry-safe observation.

Counters are operational snapshots, not an audit ledger. Update failure must never cause retained Log
inserts to roll back.

## Ingestion contract

An `after insert` trigger on `rhc__Record_Health_Check_Log__e` delegates one bulk list to a handler.
The handler:

1. accepts only nonblank canonical Event IDs and required contract fields;
2. maps the allow-listed fields above, truncating text defensively;
3. preserves Check Set and Check strings byte-for-byte unless truncation is required by the same
   120-character limit as the source (therefore no truncation is expected for valid events);
4. uses the unique Event ID destination field and partial-success `Database.insert(..., false)`;
5. treats duplicate-value failures as successful duplicate suppression;
6. rolls back the complete delivery and throws `EventBus.RetryableException` for transient lock or
   unknown platform failures only while the delivery retry count is below three, allowing
   idempotent redelivery through the unique Event ID; after that bound, it records
   `RETRY_EXHAUSTED` as permanent operational evidence instead of risking subscriber suspension;
7. records bounded ingestion counts and sanitized permanent error categories without storing failed
   payloads; and
8. performs no query, DML, notification, health-check invocation, Flow execution, or callout per
   individual event.

Malformed optional fields become null. Unsupported contract versions are retained and visibly
flagged for investigation because discarding them would hide operational evidence; mapping remains
limited to known fields.

## Retention and cleanup

Cleanup is disabled until an administrator sets Retention Days and explicitly enables automation.
Manual preview and execution use the same policy. Eligibility is strictly:

`OccurredAt__c < System.now().addDays(-RetentionDays__c)`

Records exactly on the boundary are retained. Each invocation queries only
`Record_Health_Check_Diagnostic_Log__c`, orders oldest first, applies the configured bounded limit, and uses
partial-success delete. It never deletes another object. A singleton overlap token prevents two
cleanup runs from deleting concurrently; stale locks are recoverable after a documented timeout.
Every run records success, partial failure, skipped-overlap, or configuration-disabled status and
counts. Re-running is safe.

The scheduler creates at most one named daily job and delegates to the cleanup service. Disabling
automated cleanup aborts only the package-owned scheduled job. Manual cleanup remains explicit and
bounded.

## Administration and review experience

The **RHC Logs** Lightning app provides:

- **Setup Assistant**: confirms the core Log event is installed and accessible; explains default-off
  publication; lists visible Check Set CMDT records with their exact developer name and publication
  flag; explains the separate publisher permission and limits of assignment detection; configures
  bounded retention; and enables/disables the package-owned schedule.
- **Log Review**: a security-enforced, keyset-paginated list filtered by occurred date, severity, code, Run
  ID, Check Set developer name, Check developer name, and Record ID. Execution Source is shown as
  unavailable because contract `1.0` has no such field. Navigation opens the standard record page,
  where object, sharing, and field permissions apply.
- **Operations**: shows recent ingestion/duplicate/failure snapshots, cleanup status, retained record
  count, oldest/newest occurrence, approximate data-storage caveats, Platform Event/asynchronous
  Apex/scheduled Apex/query/DML limits, and safe disable/uninstall guidance.
- object list views for Recent Logs, Critical Logs, and Requires Investigation.

Controllers use `with sharing`, explicit CRUD/FLS checks, `WITH USER_MODE`, and user-mode DML for
administrator-owned policy changes. The fixed singleton key, ingestion snapshots, and cleanup lease
and outcome fields use narrowly scoped system-mode writes after those checks because those fields are
package-owned and not user-editable. UI errors are sanitized. No restricted value is returned when
field access is absent.

## Permission model

- **RHC Logs Admin**: configure only Retention Days, Cleanup Batch Size, and Automated Cleanup;
  schedule/disable cleanup; run bounded cleanup; view Logs; and read restricted diagnostic fields
  plus package-owned operational state. It cannot edit counters, status, singleton identity, or
  cleanup lease fields. It does not grant core Log publication permission.
- **RHC Logs Viewer**: read the Log object and nonrestricted correlation/classification fields only.
  It does not expose Message, Structured Diagnostic Details, Record ID, or Running User ID; it has
  no Settings mutation, cleanup, scheduling, event publication, or event-subscription permission.

The Platform Event trigger runs as Salesforce event automation; no dedicated runtime permission set
is introduced unless clean-subscriber validation proves one is required. Package objects use Private
sharing. Guest and public access are unsupported.

## Setup-assistant findings

Findings are read-only and evidence-based:

- core event absent or event field contract incomplete;
- core event inaccessible to the current administrator;
- current user lacks visibility of Check Set configuration;
- Check Sets with publication enabled/disabled, when visible;
- reminder that each actual running identity needs the separate core publisher permission;
- retention missing/out of range, cleanup disabled/enabled, schedule absent/present;
- unsupported retained contract versions; and
- recent ingestion, duplicate, failure, cleanup, and storage snapshots.

The assistant does not claim to inspect every possible Flow, Queueable, integration, or user that can
run core and therefore does not assert universal publisher-permission compliance.

## Security and lifecycle

Diagnostic Logs are restricted operational data. Organization-Wide Defaults remain Private. Admins
must narrowly assign permission sets, review sharing/report/export/backup access, and apply Platform
Encryption where organizational policy requires it. RHC Logs never includes restricted details in
notifications and provides no guest/public surface.

Safe disable order: disable automated cleanup, abort the package-owned schedule, clear core Log
publication on Check Sets that no longer need it, and remove RHC Logs permission assignments. Event
ingestion stops only when the trigger/package is uninstalled or core publication stops.

Uninstall permanently deletes package-owned Logs and Settings under Salesforce package-uninstall
behavior. Administrators must export only approved evidence before uninstall and treat exports as
restricted. Core and every other extension continue independently.

## Limits and observability

Administrators are explicitly told that Platform Event publication/delivery, daily event allocation,
event retention, automated-process execution, Apex CPU/heap/SOQL/DML, async Apex, scheduled-job,
custom-object storage, query selectivity, list-view/report export, and delete/recycle-bin behavior
apply. Counters are best-effort snapshots and must not be represented as a complete audit log.

## Acceptance and release gates

Before an installable release is claimed, evidence must show:

1. Apex tests cover CRUD/sharing/FLS, restricted-field visibility, 251-event ingestion, canonical
   Event ID idempotency and duplicate delivery, oversized bounding, malformed optional values,
   exact namespace-bearing identity preservation, retention boundary/scope, overlap/retry behavior,
   setup findings, and Admin versus Viewer access.
2. LWC Jest tests cover loading, filters, restricted-field omission, setup findings, cleanup controls,
   errors, empty states, keyset continuation, and the exact navigation request.
3. Salesforce Code Analyzer completes and findings are remediated or explicitly gated.
4. Source deploys against the minimum promoted core version.
5. A 2GP version is created with passing package code coverage.
6. Its `04t` installs into a clean subscriber org containing only required core, and administrator
   acceptance tests pass.
7. Disable, uninstall, and data-loss guidance is exercised.

A registered `0Ho` container is not installable. README and release documentation may claim an
installable artifact only after recording a validated subscriber package version ID beginning with
`04t`, actual test counts, coverage, validation results, and outstanding gates. Evidence is never
invented.

The standards-compliant object and field API names in this specification were normalized before any
RHC Logs package container or `04t` existed. If a package version is ever released, future schema
renames require an explicit managed-package upgrade/migration design and must not be treated as a
mechanical source edit.
