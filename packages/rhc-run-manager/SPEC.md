# RHC Run Manager specification

## Why this project exists

Core evaluates records and returns responses or optional Platform Events, but intentionally does not
persist operational history. Starting the packaged asynchronous helpers, choosing Batch scope,
scheduling recurring work, correlating Salesforce jobs, and saving selected results otherwise
requires Apex and custom objects.

RHC Run Manager gives administrators a no-code control plane for scheduled health-check runs. It
owns schedules, the Batch jobs it creates, durable operational envelopes, and selected results.

## User value

A junior administrator supplies only:

1. a meaningful Run Definition name;
2. Selection Type: **Check Set** or **Check**;
3. an active Check Set or Check chosen from a metadata-driven picker;
4. Batch Size from 1 through 200;
5. Capture mode: **Pass**, **Fail**, or **Both**; and
6. recurrence, optional start/end dates, and preferred start time.

Run Manager resolves both the opaque Qualified API Name and target object from core metadata. The
administrator never enters an Apex class, object API name, SOQL, CRON expression,
event-publication value, or namespace prefix.

## Dependency on core

Run Manager depends only on core for:

- Check Set and Check identity resolution;
- target-object ownership;
- `RecordHealthCheckRequest.forCheckSet(...)` and `forCheck(...)`;
- evaluation semantics and response contracts;
- canonical statuses and lifecycle events; and
- security and request limits enforced by the engine.

For each scope it invokes core, stores approved response fields, and requests canonical core event
publication so independently installed Alerts, Reports, Actions, and Integrations can react without
reading Run Manager objects.

## Owned data and behavior

| Object | Responsibility |
| --- | --- |
| `Record_Health_Check_Run_Definition__c` | Saved selection, population mode, guided filters, Batch size, and capture mode |
| `Record_Health_Check_Schedule__c` | Human schedule settings and exact `CronTrigger` identity |
| `Record_Health_Check_Batch_Run__c` | One firing or Run Now job and its `AsyncApexJob` identity |
| `Record_Health_Check_Run__c` | One framework scope/run envelope |
| `Record_Health_Check_Run_Result__c` | One retained Check result for one business record. The `Run_Result` API stem avoids Salesforce's cross-type collision with core `Record_Health_Check_Result__e`. |
| `Record_Health_Check_Run_Request__c` | Deduplicated supplied-ID staging for cross-transaction coalescing |

Every Run Definition stores `SelectionType__c` (`CHECK_SET` or `CHECK`), the opaque exact
`QualifiedApiName__c`, `PopulationMode__c`, `BatchSize__c`, and `CaptureMode__c`. It caches the
resolved target object for administrator visibility, but execution revalidates against core
metadata. A definition never stores an Apex class, namespace prefix, raw SOQL, CRON expression, or
event-publication choice.

## Record-population modes

1. **ALL_ACCESSIBLE** queries every target record visible to the execution user in user mode.
2. **GUIDED_FILTERED** applies structured field/operator/value predicates created by packaged UI.
   Fields must exist on the derived object, be accessible, and use an allowlisted operator. Values
   are bind variables. Administrator-authored SOQL is never accepted or stored.
3. **SUPPLIED_IDS** consumes target IDs staged by the packaged Flow action.
4. Related-record change handling uses the same supplied-ID path. A Flow can pass current and prior
   parent IDs; nulls and duplicates are removed before staging.

The Flow action accepts a Run Definition ID plus scalar current/prior IDs and an optional ID
collection. It upserts one staging row per definition/record pair. A delayed Queueable uses a
duplicate signature per definition, drains committed pending rows, and starts one Batch. This
coalesces IDs from many Contact-trigger transactions and avoids one evaluation job per Contact.

Schedules, Run Now, and supplied-ID requests all call the same execution service. Only source and
population input differ.

Capture and publication are derived:

| Capture | Detailed results retained | Core publication |
| --- | --- | --- |
| `PASS` | `PASS` | `ALL` |
| `FAIL` | `FAIL`, `UNABLE_TO_EVALUATE`, `ERROR` | `ACTIONABLE` |
| `BOTH` | Both groups | `ALL` |

`SKIPPED` is counted on envelopes but is not retained as a detailed pass/fail result. Run Manager
must suppress duplicate persistence when it observes events produced by its own direct executions.

## Example

Maya schedules `Opportunity_Close_Readiness` every weekday at 2:00 AM with Batch Size 50 and Capture
**Fail**.

1. Run Manager confirms the identity is a Check Set and resolves `Opportunity`.
2. At each firing it queries all Opportunities visible to the schedule owner using user-mode access.
3. It evaluates scopes of at most 50 and retains actionable results plus all run totals.
4. The morning view shows 4,800 submitted records, 4,750 processed records, two failed scopes, and
   the corresponding `AsyncApexJob`.
5. Maya drills into failures without opening Setup → Apex Jobs or writing a query.
6. Because the run requested `ACTIONABLE` core publication, RHC Alerts can independently notify
   Sales Operations if that package is installed.

For one exact Check, Maya chooses **Check** and enters `Opportunity_Amount_Is_Present`. Run Manager
finds its owning Check Set and derives `Opportunity`; there is no separate object input.

## Constraints it cannot escape

- Release 1 supports all accessible records, packaged guided filters, and supplied IDs; it accepts
  no arbitrary SOQL.
- Scheduled Apex and concurrent asynchronous execution are subject to Salesforce org limits.
- Salesforce treats the requested start time as preferred; platform load can delay execution.
- Batch scopes commit independently. Earlier results remain if a later scope fails.
- A completed Apex job means execution completed, not that records passed.
- Sharing, CRUD, FLS, metadata access, and later permission changes affect what a schedule can see.
- Event publication consumes platform-event allocations and is asynchronous.
- Platform events are delivered at least once; idempotency is mandatory.
- Run Manager cannot reconstruct runs completed before installation or runs started elsewhere with
  event publication disabled.
- It monitors only jobs it creates, not arbitrary customer Batch Apex classes.

## Boundaries

Run Manager does not author Checks, notify humans, own long-term reporting aggregates, execute
corrective Flows, or call external systems. Other extensions consume core events, not these objects.

## Monitoring reconciliation

The former core Monitor and result-history proposals are reconciled into this package with these
explicit dispositions:

- Run Manager retains the minimum operational envelope and administrator-selected result details;
  RHC Reports owns long-term analytical facts and trends.
- Coverage is truthful: Run Manager can prove only the records it submits and responses it captures.
  It cannot infer unpublished external runs or reconstruct history from before installation.
- Monitoring access rechecks sharing, object, and field permissions. Stored operational identity is
  never authority to reveal a source record or restricted evidence.
- The workspace drills from Batch Run to independently committed scope Run to retained Result and
  links the owned `AsyncApexJob`; it does not monitor arbitrary customer jobs.
- Run Manager records terminal and partial-failure state. Human transition notification belongs to
  RHC Alerts, which consumes canonical core events rather than Run Manager objects.
- Core does not expose a stable per-Check CPU/query/heap contract, so Run Manager does not promise
  per-Check resource accounting. It reports bounded job/scope failure evidence available from its
  own execution path.
- History cleanup is an explicit administrator-approved retention process. Release 1 never silently
  purges operational records.

## Acceptance criteria

1. It installs with core and without another extension.
2. Both Check Set and Check identities work, including namespaced identities.
3. Scope sizes outside 1-200 fail before schedule creation.
4. Capture modes retain exactly their documented statuses.
5. Save, reschedule, event delivery, and execution retry paths are idempotent.
6. Partial failures remain visible and correlated across Schedule, Batch Run, Run, and Result.
7. All-record and filtered discovery run in user mode and filter construction accepts no raw SOQL.
8. Supplied IDs are null-safe, deduplicated, idempotently staged, and coalesced across transactions.
9. Direct capture and canonical event publication cannot create duplicate Run Manager Results.
10. Schedule updates replace only their owned `CronTrigger`; start dates suppress early launches and
    schedules deactivate after their end date.
11. Tests cover user-mode access, capture modes, bulk Flow input, coalescing, partial failure,
    idempotency, platform bounds, and LWC loading/action/error states.
12. The packaged UI uses named definitions, a metadata-driven selection picker, managed schedule
    edit/pause actions, supplied-ID Flow guidance, and Batch Run → scope Run → Result drill-down.
13. Admin, Viewer, and Executor permission sets provide configuration, monitoring, and Flow/runtime
    personas without requiring unrelated extension packages.
14. Monitoring never claims coverage for a run or record the package did not submit and capture.
15. Viewer drill-down cannot elevate current business-record or restricted-field access.
16. Notification and analytical-trend requirements remain independently installable through Alerts
    and Reports rather than creating extension-to-extension dependencies.
