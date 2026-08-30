# Architecture and security

## Purpose and ownership boundary

RHC Run Manager is a second-generation unlocked Salesforce package that depends only on Record
Health Check core. It owns orchestration around the core evaluator; it does not replace the core
evaluation model.

Run Manager owns:

- saved execution definitions;
- administrator-guided record populations;
- supplied-ID staging and cross-transaction consolidation;
- Batch Apex construction and scope size;
- schedule creation and owned CronTrigger replacement;
- security context and user-mode data access;
- per-job and per-scope correlation;
- selected detailed-result retention;
- operational status and error summaries.

Record Health Check core owns:

- Check Set and Check metadata;
- canonical request, response, result, status, and publication types;
- evaluation behavior;
- canonical platform-event publication.

Run Manager never accepts a customer Batch class, raw SOQL, a CRON expression, a target object, or
an event-publication override.

## Component map

| Component | Responsibility |
| --- | --- |
| `rhcRunManager` LWC | Three-step administration UI: definitions, schedules, monitoring |
| `RHCRunManagerAdminController` | LWC facade, input validation, metadata pickers, monitoring reads |
| `RHCRunManagerCoreMetadataGateway` | Resolves Check Set/Check identities and derives target object |
| `RHCRunManagerFilterService` | Validates structured filters and produces bound queries |
| `RHCRunManagerSubmitIdsAction` | Bulk Flow action; removes nulls/duplicates and stages requests |
| `RHCRunManagerCoalescerQueueable` | Delayed, duplicate-signature drain per definition |
| `RHCRunManagerExecutionService` | Shared validated launch path for every execution source |
| `RHCRunManagerBatch` | Population, scoped core calls, capture, correlation, partial-failure isolation |
| `RHCRunManagerCaptureService` | Capture-mode filtering and idempotent Result upsert |
| `RHCRunManagerScheduleService` | Human recurrence to owned Salesforce scheduled job |
| `RHCRunManagerScheduled` | Date-window guard and shared execution delegation |

## Execution lifecycle

### Run Now

1. Administrator chooses **Run now** on an active definition.
2. `RHCRunManagerAdminController.runNow` calls `RHCRunManagerExecutionService.runNow`.
3. The execution service reads the definition in user mode, validates the source/population pairing,
   resolves core metadata, validates filters, and inserts a queued Batch Run.
4. Run Manager starts `RHCRunManagerBatch` with the saved Batch Size.
5. Batch `start` builds a bound user-mode population query.
6. Every `execute` scope creates one Run record and one correlation ID.
7. The scope constructs a canonical core `RecordHealthCheckRequest` and calls
   `RecordHealthCheck.evaluate`.
8. Capture retains only the configured result group; the Run stores all summary counts.
9. Batch `finish` marks the Batch Run `COMPLETED` or `PARTIAL_FAILURE`.

### Scheduled

1. Administrator saves a human recurrence: Daily, Weekdays, or Weekly; start time; optional dates.
2. `RHCRunManagerScheduleService` creates the CRON expression internally and schedules only
   `RHCRunManagerScheduled`.
3. On fire, the adapter confirms the Schedule is active and inside its date window.
4. The adapter calls the same execution service with source `SCHEDULED`.
5. The Schedule records `LastFiredAt__c`.

### Supplied IDs

1. A Flow interview invokes **Submit Record IDs to RHC Run Manager**.
2. The action combines current ID, prior ID, and optional ID collection; nulls and duplicates are
   removed per Flow input.
3. One request row is upserted by `definitionId|recordId`. Retried inputs therefore converge on the
   same durable row.
4. A delayed Queueable is submitted with a duplicate signature containing the definition ID.
5. Additional committed transactions can add rows during the 1–10 minute consolidation window,
   while duplicate Queueable submissions are suppressed by Salesforce.
6. The Queueable drains up to 50,000 pending rows, starts one supplied-ID Batch, then marks drained
   requests submitted.
7. The Batch follows the same scoped core evaluation and capture path as every other source.

## Correlation model

The records form this hierarchy:

```text
Run Definition
├── Schedule (optional source configuration)
├── Run Request (durable supplied-ID staging)
└── Batch Run (one asynchronous job)
    └── Run (one independently committed Batch scope)
        └── Run Result (one retained record/check evaluation)
```

Each scope correlation ID uses `rm-{BatchRunId}-{scopeNumber}`. It becomes the core request Run ID
and the packaged Run's `RunId__c`. This makes the Batch Run, scope Run, retained Results, core
response, and canonical events traceable without relying on log text.

## Security model

All customer-record and Run Manager operational-data queries/DML use Salesforce user mode:

- `WITH USER_MODE` for static SOQL;
- `Database.getQueryLocatorWithBinds(..., AccessLevel.USER_MODE)` for population queries;
- `AccessLevel.USER_MODE` for insert, update, and upsert.

Consequences:

- object permissions, field permissions, sharing, and record access apply;
- **All Accessible** means accessible to the user who launches or owns the asynchronous work, not all
  records in the org;
- guided filters can use only described, accessible fields;
- a schedule runs under its scheduling user;
- automation users require the Executor permission set plus appropriate core and target-data access.

The permission personas are intentionally separate:

| Persona | Configuration | Execution/staging | Monitoring | Delete |
| --- | --- | --- | --- | --- |
| Admin | Yes | Yes | Yes | Packaged operational/configuration records |
| Viewer | No | No | Read only | No |
| Executor | No | Flow supplied-ID path | Minimum operational access needed for owned async processing | No |

## Filter safety

Guided filters are stored as JSON objects with `field`, `operator`, and `value`. The service:

1. derives the target object from core metadata;
2. describes that object and validates field existence/accessibility;
3. allows only packaged operators;
4. converts values to the described Salesforce type;
5. constructs clauses with bind variables;
6. executes through `Database.getQueryLocatorWithBinds` in user mode.

Administrator-entered SOQL is never accepted or concatenated.

## Capture and publication

| Capture mode | Retained detail | Core publication |
| --- | --- | --- |
| `PASS` | `PASS` | `ALL` |
| `FAIL` | `FAIL`, `UNABLE_TO_EVALUATE`, `ERROR` | `ACTIONABLE` |
| `BOTH` | PASS and actionable groups | `ALL` |

`SKIPPED` contributes to the Run summary but is never stored as detailed history. Publication is
derived from Capture Mode; administrators cannot create a mismatch.

## Idempotency

- Run Request external key: `{RunDefinitionId}|{RecordId}`.
- Run Result external key: SHA-256 of `{RunCorrelationId}|{RecordId}|{CheckQualifiedApiName}`.
- Queueable duplicate signature: fixed product marker plus Run Definition ID.

These mechanisms protect different boundaries: input retries, result retries/event-equivalent
duplicates, and one coalescer per definition.

## Partial failure behavior

Each Batch scope creates and updates its own Run envelope. A caught scope exception:

- marks that scope Run `ERROR`;
- stores a sanitized error summary;
- increments `FailedScopeCount__c`;
- does not roll back earlier committed scopes;
- allows later scopes to continue when Salesforce permits;
- results in Batch Run status `PARTIAL_FAILURE`.

A health-check `FAIL` result is business output, not a Batch failure.

## Platform-limit behavior

- Batch Size is restricted to 1–200.
- Supplied-ID drain is capped at 50,000 pending rows per coalescer execution.
- Consolidation delay is clamped to 1–10 minutes.
- Filter clauses use binds instead of growing literal query text.
- The Flow action is bulkified across the complete invocable input list.
- Result upsert uses partial success so one invalid detail does not discard all valid details.
- Scope error text is normalized and capped at 1,000 characters.

Pending supplied-ID rows are the durable retry boundary. Run Manager intentionally does not add a
Queueable finalizer that could create a second asynchronous job for the same definition.

