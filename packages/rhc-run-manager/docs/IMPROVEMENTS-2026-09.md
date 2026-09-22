# RHC Run Manager — improvement specification (2026-09)

Baseline: 110 components deploy, 47 Apex tests pass, 12 Jest tests pass. Analyzer reports 170
severity-3 findings, all from rules the package disables in `code-analyzer.yml` (braces,
complexity, naming, boolean parameters). Source reviewed: execution service, batch, capture,
coalescer, schedule service and scheduled adapter, admin controller, `rhcRunManager` LWC.

## RM1 — Prevent overlapping runs of one definition

**Problem.** `RHCRunManagerExecutionService.start` launches a new Batch for a definition without
checking whether one is already `QUEUED` or `PROCESSING`. A schedule firing while a manual run is
still processing, or a double-click on Run Now, evaluates the same population twice, doubles
captured Results, and doubles core event publication for downstream extensions.

**Change.** Before inserting the Batch Run, query
`Record_Health_Check_Batch_Run__c WHERE RunDefinition__c = :definitionId AND Status__c IN
('QUEUED','PROCESSING') LIMIT 1` in user mode. If a row exists, throw
`ExecutionException('A Batch Run for this Run Definition is already in progress.')`.
`SUPPLIED_IDS` launches are exempt because the coalescer already serializes them per definition.
The scheduled adapter catches the exception and records `LastFiredAt__c` unchanged so the next
occurrence proceeds normally.

**Acceptance.**
- Run Now while a Batch Run is `PROCESSING` → exception, no new Batch Run.
- Run Now after the previous run reached `COMPLETED`/`PARTIAL_FAILURE`/`ERROR`/`CANCELLED` → new
  Batch Run.
- Scheduled fire during an active run → no exception escapes the Schedulable.

**Tests.** `RHCRunManagerExecutionTest`: `start_rejectsOverlappingRun`,
`start_allowsAfterTerminalStatus`; `RHCRunManagerAsyncTest` schedule overlap case.

## RM2 — Cancel a running Batch Run

**Problem.** An administrator who launches a run against the wrong population or filter has no
supported way to stop it. `AsyncApexJobId__c` is stored but only displayed.

**Change.**
- `Status__c` gains `CANCELLED` (generator `generate_metadata.mjs`, regenerated XML).
- `RHCRunManagerAdminController.cancelBatchRun(Id batchRunId)`: requires the Admin permission
  path used by `runNow`; loads the Batch Run in user mode; if status is `QUEUED` or
  `PROCESSING`, calls `System.abortJob(AsyncApexJobId__c)` inside a try/catch (the job may already
  have finished), then updates `Status__c = 'CANCELLED'`, `CompletedAt__c = now`, and
  `ErrorSummary__c = 'Cancelled by <user name>'`.
- `RHCRunManagerBatch.finish` leaves a `CANCELLED` row untouched (abort can race with finish).
- LWC: "Cancel" row action on Batch Runs, enabled only for `QUEUED`/`PROCESSING`.

**Acceptance.**
- Cancel on a `PROCESSING` row → status `CANCELLED`, abort requested.
- Cancel on a `COMPLETED` row → user error, no change.
- `metadata:check` passes after regeneration.

**Tests.** `RHCRunManagerAdminControllerTest`: `cancelBatchRun_marksCancelled`,
`cancelBatchRun_rejectsTerminal`; Jest: cancel action calls Apex and reloads.

**Docs.** `ADMIN_GUIDE.md` monitoring section; `docs/OPERATIONS.md` status table.

## RM3 — Cross-suite X1: stale definitions/schedules/batch runs after actions

**Problem.** `getDefinitions`, `getSchedules`, `getBatchRuns`, `getRuns`, `getResults` are
`cacheable=true` and `loadData()` re-reads them after save, run now, pause, and cancel.

**Change.** Remove `cacheable=true` from those five. Keep it on `getSelections`,
`resolveSelection`, and `getTargetFields` (core metadata describes).

**Acceptance.** Run Now → the new `QUEUED` Batch Run appears without reload.

## RM4 — Result totals on the Batch Run (added in the second pass)

`PassedCount__c`, `FailedCount__c`, `UnableCount__c`, `SystemErrorCount__c` on
`Record_Health_Check_Batch_Run__c` (generator), accumulated by the stateful Batch from each
completed scope's core summary and written in `finish`. Monitoring shows them as columns, so an
administrator sees the business outcome of a run without opening scopes. Skipped results are still
counted only per scope. Test: rollup assertion in `shouldPersistPartialFailure_WhenScopeThrows`.

## RM5 — Bounded operational-record retention

Implemented a package-owned settings singleton and Admin-only manual cleanup. A saved whole-day
window from 1 through 3,650 is required; the 365-day recommendation alone cannot authorize
deletion. Each separately confirmed request deletes at most 1,000 explicit rows in dependency order:
eligible Results, empty terminal scope Runs, empty terminal Batch Runs, then old submitted Requests.
Queued/processing Batch Runs, in-progress scope Runs, pending Requests, definitions, and schedules
are excluded. The service uses user mode and requires `RHC_Run_Manager_Manage_Retention`; the LWC
hides retention controls without that capability and invalidates confirmation after edits or use.

## RM6 — Capture-service complexity reduction

The stricter root analyzer policy found 17 moderate findings in
`RHCRunManagerCaptureService`: 14 missing-brace findings, cyclomatic and cognitive complexity in
`capture`, and the existing four-parameter capture contract. The service now isolates atomic
user-mode persistence from result selection, centralizes the Result-row mapping, and uses braces
for every touched conditional. At this stage, a focused root-policy scan reported only the
parameter-count heuristic; RM16 later replaced those positional values with a typed capture request
without changing security, limits, or behavior.

The full Run Manager scan under the root policy fell from 247 findings (179 moderate, 68 low) to
231 (163 moderate, 68 low), with no critical or high findings. The package policy remains clean
because its documented configuration excludes the remaining style, documentation, and design
rules. Broad mechanical reformatting remains lower priority than behavior and release validation.

## RM7 — Cancellation-service separation

Batch cancellation now delegates from the Aura controller to
`RHCRunManagerCancellationService`. The service owns active-status validation, the bounded query
for the stored still-active `AsyncApexJob`, abort, and the user-mode terminal update; the controller
only translates domain errors into sanitized Lightning errors. Dedicated tests cover active,
terminal, and null-ID behavior without changing the existing `cancelBatchRun(Id)` contract.

The new production and test classes have zero findings under the strict root analyzer policy. The
controller fell from 50 to 45 findings, removing its method-level cancellation complexity and brace
findings; the full Run Manager result fell again from 231 to 226 findings (158 moderate, 68 low),
still with no critical or high findings.

## RM8 — Schedule-service decomposition

`RHCRunManagerScheduleService.save` now coordinates focused helpers for date-window validation,
definition eligibility, schedule loading and persistence, platform-job creation, and exact owned-job
replacement. The public eight-argument contract, human recurrence model, user-mode reads/writes,
CRON ownership prefix, and create/update/pause behavior are unchanged.

The focused strict scan fell from 12 moderate findings to the two accepted public-signature
heuristics (`ExcessiveParameterList` and `AvoidBooleanMethodParameters`). The full Run Manager scan
fell from 226 to 216 findings (148 moderate, 68 low), with no critical or high findings.

## RM9 — Supplied-ID staging decomposition

`RHCRunManagerSubmitIdsAction` now keeps bulk Flow orchestration separate from request validation,
row construction, user-mode upsert, and per-definition coalescer enqueueing. A private validation
context carries the shared definition, describe, and staging maps without changing the invocable
request or response contract. The transaction savepoint still makes partial upsert failure atomic,
and duplicate definition/record pairs still converge through the same external key.

The focused strict scan fell from 16 findings (14 moderate and 2 low) to two moderate complexity
heuristics. Parameter-count, cognitive-complexity, brace, and ApexDoc findings were
removed. The full Run Manager scan fell from 216 to 202 findings (136 moderate, 66 low), with no
critical or high findings.

## RM10 — Coalescer execution decomposition and drain-bound correction

`RHCRunManagerCoalescerQueueable.execute` now coordinates focused request loading, ID conversion,
Batch launch, terminal request transition, and bounded continuation helpers. Its finalizer attachment,
user-mode locked query/update, partial-failure exception, retry policy, and continuation behavior are
unchanged. A regression test proves a malformed durable Record ID is consumed as `SUBMITTED` without
launching a Batch, so corrupt staging data cannot remain pending forever.

The architecture guide previously claimed a 50,000-row drain, contradicting the implemented 9,000-row
cap and Salesforce's 10,000-row transaction DML limit. It also incorrectly denied the existence of
the implemented bounded finalizer retry. The guide now documents the authoritative drain/headroom and
the unhandled-failure-only, two-retry finalizer contract. The production class and touched async test
have zero strict-policy findings. The full Run Manager scan fell from 202 to 179 findings (118
moderate, 61 low), with no critical or high findings.

## RM11 — Guided-filter boundary decomposition and negative coverage

`RHCRunManagerFilterService` now centralizes comparison tokens and field-type groups, isolates field
existence/accessibility/filterability checks from clause construction, and retains exact per-filter
bind naming through its returned query specification. At this stage, the four-argument `build`
contract remained unchanged; RM16 later replaced it with a typed request. The operator set,
user-mode execution handoff, and raw-SOQL rejection boundary remain unchanged.

The Apex test suite now separately covers unsupported operator syntax, text operators on non-text
fields, malformed numeric input, bind-free null clauses, and the ten-condition cap in addition to
the existing valid, injected-field, and supplied-ID paths. The focused strict scan fell from 16
findings across the service/test pair to two moderate service-level heuristics: the unchanged public
parameter count and aggregate class complexity. The full Run Manager scan fell from 179 to 165
findings (105 moderate, 60 low), with no critical or high findings.

## RM12 — Retention, scheduled-adapter, and Batch contract hardening

The retention service and its test now use explicit braced control flow, complete public ApexDoc,
and smaller test-data helpers without changing the saved singleton, permission boundary, child-first
purge order, or 1,000-row deletion cap. The scheduled adapter now documents both platform entry-point
parameters and braces its early-exit guards. These three files have zero strict-policy findings.

`RHCRunManagerBatch` now documents its complete Batchable contract and uses explicit braces around
failure hooks, empty-scope handling, scope ID collection, cancellation preservation, origin mapping,
and error fallback. Its focused strict scan contains only two accepted stateful-orchestration
heuristics: the immutable execution/counter field set and five-argument constructor. No execution,
capture, correlation, or monitoring behavior changed. The full Run Manager scan fell from 165 to 118
findings (69 moderate, 49 low), with no critical or high findings.

## RM13 — Public contract and test-harness analyzer signal

Every Admin controller Aura method now documents its parameters and return contract, and all of its
guards use explicit braces. The controller fell from 45 strict-policy findings to two aggregate class
complexity heuristics. Whole-number validation now uses a three-argument predicate, preserving the
same ranges and messages while removing an internal long-parameter warning.

Legacy underscore-separated Apex test names were normalized to the configured camel-case convention,
test-only loops and guards now use explicit braces, and the Account fixture removed an unused Boolean
option: every caller had requested an insert. Core gateway, execution-service, test-factory, and
uninstall-test contract documentation is complete. The root analyzer now excludes build-time
`generate_metadata.mjs` files because package drift checks verify them and LWC runtime ESLint rules
misclassify their Node.js imports and process flags. The full Run Manager scan fell from 118 to 13
moderate design heuristics, with no critical, high, low, or informational findings.

## RM14 — Run Definition service boundary

Run Definition validation, core metadata resolution, guided-filter validation, canonical target
derivation, and user-mode insert/update now live in `RHCRunManagerDefinitionService`. The Admin
controller retains the existing `saveDefinition(DefinitionInput)` Aura contract and maps that stable
DTO to a draft record; domain validation messages and the generic save failure remain unchanged.

Dedicated tests separately cover insert canonicalization, update persistence, null input, each
allowlisted mode, fractional Batch Size, and out-of-range coalesce delay. The new service/test pair
has zero strict-policy findings. The controller no longer has a cognitive-complexity finding and its
cyclomatic total fell from 64 to 50. The full Run Manager scan fell from 13 to 12 moderate design
heuristics, with no critical, high, low, or informational findings.

## RM15 — Cohesive schedule request contract

`RHCRunManagerScheduleService.save` now accepts one typed request containing the human recurrence
instead of eight positional arguments. The service also owns pause-time record loading and exact
owned-job replacement; the Admin controller retains its existing Aura `ScheduleInput` DTO and maps
it to the internal request. Administrators still cannot supply CRON, and the recurrence, date-window,
active-definition, supplied-ID exclusion, user-mode persistence, and job-ownership rules are unchanged.

The existing schedule tests now build explicit active or inactive daily requests, with an additional
negative test for a null service request. The touched controller/service/test focused scan contains
only the controller's pre-existing aggregate cyclomatic heuristic. The full Run Manager scan fell
from 12 to 10 moderate design heuristics, with no critical, high, low, or informational findings.

## RM16 — Typed execution, capture, and query boundaries

The supplied-ID action now delegates per-input definition and target-ID validation to a focused
private validator while retaining the exact invocable request/response DTOs, bulk response order,
user-mode staging, atomic rollback, and one-coalescer-per-definition behavior. The action's focused
strict scan is clean.

Filter query construction now accepts one `QueryRequest` instead of four positional values, and
scalar type conversion is isolated from object/field/operator validation. Execution launch and
result capture likewise accept typed requests rather than four positional values. Run Now,
schedules, the coalescer, and Batch still converge on the same execution and capture services; no
Aura or Flow entry-point contract changed. Null-request tests cover each new guard. Core metadata
resolution now maps Check Set and Check records through type-specific helpers instead of a generic
four-value mapper.

Focused strict scans of the supplied-ID action, filter service/test, core gateway/test, and
execution/capture surfaces report zero findings. The full Run Manager scan fell from 10 to three
moderate design heuristics: aggregate branching in the thin Aura facade plus the stateful Batch's
serialized field set and five-value constructor. There are no critical, high, low, or informational
findings. The Batch envelope remains unchanged pending current org-side compilation and async
execution evidence.

## RM17 — Typed stateful Batch envelope

`RHCRunManagerBatch` now accepts one `LaunchRequest` instead of five positional constructor values.
The constructor validates the request and maps it into one immutable execution plan, while scope
numbers, row counts, outcome totals, and bounded errors live in one progress object. This preserves
the same `Database.Stateful` behavior while making the values that cross scope transactions
explicit and preventing launch arguments from being reordered accidentally.

The execution service and focused Batch test now construct the named request, and a negative test
rejects an incomplete launch before asynchronous work can be queued. The full strict-policy scan
fell from three moderate findings to one: only the thin Aura facade's aggregate cyclomatic total
remains. There are no critical, high, low, or informational findings. Evidence:
`/tmp/rhc-run-manager-state-envelope-final3.json`. Sixteen Jest tests, generated-metadata drift,
Metadata API conversion, and the high-severity dependency audit pass. Current Apex compilation and
execution remain pending because no default org is authorized.

## RM18 — Focused administrator command boundary

`RHCRunManagerAdminController` retains every existing Aura-enabled method and DTO, while definition
save, Run Now, cancellation, schedule save, and schedule pause now delegate to
`RHCRunManagerAdminCommandService`. The command service owns input mapping and the existing safe
domain/generic error translations. Sharing, user-mode behavior in downstream services, validation
messages, return values, and the LWC contract are unchanged. The generated Admin permission set
grants access to the new class; Viewer and Executor access are unchanged.

This removes the final aggregate-complexity finding from the Aura facade. Both the focused strict
scan and the full Run Manager strict-policy scan contain zero findings. Evidence is retained at
`/tmp/rhc-run-manager-admin-command-strict-20260920-2222.json` and
`/tmp/rhc-run-manager-strict-clean-final-20260920-2230.json`. All 16 Jest tests pass with 92.2% statement,
80.32% branch, and 100% function/line coverage. Generated metadata, the zero-vulnerability audit,
and Metadata API conversion pass. The focused Apex run could not start because no default or target
org is configured.
