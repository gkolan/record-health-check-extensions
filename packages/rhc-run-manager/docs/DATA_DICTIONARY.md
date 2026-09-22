# Data dictionary

All objects below are owned by RHC Run Manager. Their sharing model is Private. Permission sets grant
persona-specific access; Apex uses user-mode queries and DML.

## Record Health Check Run Definition

API name: `Record_Health_Check_Run_Definition__c`

One reusable execution configuration.

| Field | Meaning |
| --- | --- |
| `Name` | Auto-number record identity (`RHC-DEF-...`) |
| `DisplayName__c` | Administrator-facing purpose-oriented name |
| `Active__c` | Whether execution is allowed |
| `SelectionType__c` | `CHECK_SET` or `CHECK` |
| `QualifiedApiName__c` | Exact core metadata identity chosen from the picker |
| `TargetObjectApiName__c` | Object derived from core metadata; never administrator-entered |
| `PopulationMode__c` | `ALL_ACCESSIBLE`, `GUIDED_FILTERED`, or `SUPPLIED_IDS` |
| `FilterJson__c` | Packaged structured filter; never SOQL |
| `BatchSize__c` | Target records per independently captured scope, 1–200 |
| `CaptureMode__c` | `PASS`, `FAIL`, or `BOTH` |
| `CoalesceDelayMinutes__c` | Supplied-ID consolidation window, clamped to 1–10 minutes |

Run Now and Schedule reject `SUPPLIED_IDS`. The packaged Flow action requires `SUPPLIED_IDS`.

## Record Health Check Schedule

API name: `Record_Health_Check_Schedule__c`

One human-friendly recurrence and its exact Run Manager-owned Salesforce job.

| Field | Meaning |
| --- | --- |
| `RunDefinition__c` | Definition to launch |
| `Active__c` | Whether the schedule may fire |
| `Frequency__c` | `DAILY`, `WEEKDAYS`, or `WEEKLY` |
| `PreferredStartTime__c` | Local `HH:mm` selected by scheduling user |
| `DayOfWeek__c` | `MON` through `SUN`; required for Weekly |
| `StartDate__c` | Optional first eligible date |
| `EndDate__c` | Optional last eligible date |
| `CronTriggerId__c` | Platform job owned and validated by this Schedule |
| `LastFiredAt__c` | Most recent successful delegation to shared execution |

## Record Health Check Run Request

API name: `Record_Health_Check_Run_Request__c`

Durable staging row for supplied IDs.

| Field | Meaning |
| --- | --- |
| `RunDefinition__c` | Supplied-ID definition receiving the target |
| `RequestKey__c` | Unique `definitionId|recordId` idempotency key |
| `RecordId__c` | Supplied target Salesforce ID stored as text |
| `Status__c` | `PENDING` or `SUBMITTED` |
| `RequestedAt__c` | Most recent staging time |

Upsert by Request Key prevents repeated Contact updates from creating duplicate pending rows for the
same Account and definition.

## Record Health Check Batch Run

API name: `Record_Health_Check_Batch_Run__c`

One owned Batch Apex job and the top-level monitoring envelope.

| Field | Meaning |
| --- | --- |
| `RunDefinition__c` | Saved definition used for this launch |
| `Schedule__c` | Schedule source when applicable |
| `AsyncApexJobId__c` | Exact Salesforce asynchronous job ID |
| `Source__c` | `RUN_NOW`, `SCHEDULED`, or `SUPPLIED_IDS` |
| `Status__c` | `QUEUED`, `PROCESSING`, `COMPLETED`, `PARTIAL_FAILURE`, `ERROR`, or `CANCELLED` |
| `SubmittedRecordCount__c` | Records delivered to scopes |
| `ProcessedRecordCount__c` | Records whose scopes completed evaluation |
| `FailedScopeCount__c` | Scopes that threw an exception |
| `StartedAt__c` | Launch timestamp |
| `CompletedAt__c` | Finish timestamp |
| `ErrorSummary__c` | Sanitized aggregate scope-error text |

## Record Health Check Run

API name: `Record_Health_Check_Run__c`

One independently captured Batch scope.

| Field | Meaning |
| --- | --- |
| `BatchRun__c` | Parent job envelope |
| `RunId__c` | Correlation ID passed to core (`rm-{batch}-{scope}`) |
| `ScopeNumber__c` | One-based scope sequence in the Batch instance |
| `Status__c` | `IN_PROGRESS`, `COMPLETED`, or `ERROR` |
| `SelectionType__c` | Snapshot of Check Set/Check selection type |
| `QualifiedApiName__c` | Snapshot of selected core identity |
| `CheckSetQualifiedApiName__c` | Owning Check Set, including individual-Check execution |
| `RecordCount__c` | Target records in this scope |
| `PassedCount__c` | Canonical core PASS total |
| `FailedCount__c` | Canonical core FAIL total |
| `SkippedCount__c` | Canonical core SKIPPED total |
| `UnableCount__c` | Canonical core UNABLE_TO_EVALUATE total |
| `SystemErrorCount__c` | Canonical core ERROR total |
| `OccurredAt__c` | Scope start timestamp |
| `CompletedAt__c` | Scope completion/error timestamp |
| `ErrorSummary__c` | Sanitized scope exception summary |

## Record Health Check Run Result

API name: `Record_Health_Check_Run_Result__c`

One retained canonical core evaluation detail.

| Field | Meaning |
| --- | --- |
| `Run__c` | Parent scope Run |
| `ResultKey__c` | SHA-256 idempotency key for run/record/check |
| `RecordId__c` | Evaluated target record ID |
| `CheckQualifiedApiName__c` | Canonical Check identity |
| `Status__c` | Retained canonical status |
| `Severity__c` | Core severity |
| `ReasonCode__c` | Core reason code |
| `ComparisonOperator__c` | Core comparison operator when applicable |
| `FoundValueJson__c` | JSON representation of actual/found value |
| `ExpectedValueJson__c` | JSON representation of expected value |
| `DiagnosticId__c` | Core diagnostic identity |
| `DiagnosticCategory__c` | Core diagnostic grouping |
| `DiagnosticSummary__c` | Human-readable diagnostic summary |
| `RecommendedAction__c` | Core recommended remediation |
| `OccurredAt__c` | Capture timestamp |

Detailed rows are capture-mode dependent. `SKIPPED` is summary-only.

## Record Health Check Run Setting

API name: `Record_Health_Check_Run_Setting__c`

Package-owned singleton for explicit manual-retention configuration.

| Field | Meaning |
| --- | --- |
| `SettingKey__c` | Unique singleton identity; validation requires `Default` |
| `RetentionDays__c` | Whole-day window from 1 through 3,650 |

The default 365-day recommendation exists only in the UI/service response. No settings row means
cleanup is not configured and cannot run.

## Relationship and deletion order

```text
Run Definition
├── Schedule
├── Run Request
└── Batch Run
    └── Run
        └── Run Result
```

The packaged retention service deletes children before parents and caps each request at 1,000
explicit rows. It never deletes definitions, schedules, active Runs, active Batch Runs, or pending
Requests. Never directly delete a Run Definition while an active Schedule or pending supplied-ID
workflow depends on it.
