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
