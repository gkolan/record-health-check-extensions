# RHC Reports — improvement specification (2026-09)

Baseline: 100 components deploy, 25 Apex tests pass, 5 Jest tests pass, 58 analyzer findings at
severity 3 (all in tests or style). Source reviewed: ingestion service and triggers, aggregation
service, daily aggregation queueable, maintenance scheduler, retention batch, setup and coverage
controllers, LWCs.

## R1 — Keep the subscriber alive on permanent row failures; bound retries

**Problem.** `RHCReportsIngestionService.assertSuccessful` throws `RHCReportsIngestionException`
when any upsert fails with a non-retryable status code. An unhandled non-retryable exception in a
Platform Event trigger moves the subscription to the error state; every later Result and Set Run
event is then lost until an administrator resumes the trigger in Setup. One malformed event
(for example a Qualified API Name longer than the fact field) therefore stops trend reporting for
the whole org. Retryable failures throw `EventBus.RetryableException` without a cap, so a stuck
lock also ends in suspension after nine retries.

**Change.**
1. Cap retries: if `EventBus.TriggerContext.currentContext().retries >= MAX_RETRIES (3)`,
   treat retryable failures as permanent for that delivery.
2. Never throw for permanent failures. Count them, keep the successful rows (upserts are already
   `allOrNone = false` and keyed by `EventId__c`), and record evidence on the hierarchy custom
   setting: new fields `LastIngestionFailureAt__c` (DateTime) and
   `LastIngestionErrorCodes__c` (Text 255, sorted status codes). The setup page shows both.
3. ~~Set a resume checkpoint after each successful upsert.~~ Dropped during implementation: the
   service performs one bulk upsert per delivery, so there is no intermediate point to checkpoint;
   Event ID keys already make a replay idempotent.

**Acceptance.**
- Permanent failure on one of three rows: two facts persisted, no exception, custom setting shows
  the code and timestamp.
- Retryable failure at retry count 0: `EventBus.RetryableException` as today.
- Retryable failure at retry count 3: no exception; evidence recorded with `RETRY_EXHAUSTED`.

**Tests.** `RHCReportsIngestionServiceTest`: `permanentFailure_recordsEvidenceAndContinues`,
`retryExhausted_recordsEvidence`; existing retryable test adjusted for the cap.

**Docs.** `docs/OPERATIONS_AND_SECURITY.md` "Ingestion evidence" section; README feature list.

## R2 — Remove the severity-3 analyzer debt in tests

**Problem.** Ten `AvoidHardcodingId` findings come from literal IDs such as `'001000000000001'`
in test factories, and two `@lwc/lwc/no-async-operation` findings come from `setTimeout` used to
flush promises in Jest.

**Change.** Add `RHCReportsTestDataFactory.fakeId(Schema.SObjectType, Integer)` that builds an ID
from the key prefix and a zero-padded counter; replace the literals. In Jest, replace
`setTimeout` flushes with `await Promise.resolve()` (twice where a nested microtask is awaited).

**Acceptance.** Re-scan of `packages/rhc-reports/force-app/**` reports zero `AvoidHardcodingId`
and zero `no-async-operation` findings; all tests still pass. The 2026-09-20 follow-up also
normalized all 25 test-method names and all 33 `@IsTest` annotations, removing both naming-rule
categories without changing behavior. The remaining findings include explicit-principal test
guidance and production design heuristics; they remain recorded for focused follow-up.

## R3 — Cross-suite X1: stale settings after save

**Problem.** `getSettings` is `cacheable=true`; `saveSettings` returns the new settings so the
first save renders correctly, but a subsequent `load()` (page re-entry within the session) shows
the cached pre-save values.

**Change.** Remove `cacheable=true` from `RHCReportsSetupController.getSettings`. `getCoverage`
stays cacheable (pure metadata read).

**Acceptance.** Save → navigate away → return: the saved values are shown.

## R4 — Run aggregation on demand (added in the second pass)

`RHCReportsSetupController.runAggregationNow()` (manager permission) queues the same
`RHCReportsDailyAggregationQueueable` the scheduler uses, for the most recently completed local
day with bounded catch-up, so an administrator who has just enabled publication or fixed a Check
Set does not wait for 02:15. The setup page gains **Run aggregation now**; the outcome appears in
"Latest aggregation outcome" after refresh. Tests: `shouldQueueLatestCompletedDayWhenAdminRunsAggregationNow`,
Jest "queues aggregation on demand and reloads the outcome".

## R5 — Coverage-controller decomposition and analyzer cleanup

`RHCReportsCoverageController.getCoverage()` now delegates configuration discovery, configured
Check counts, observed Run aggregates, observed Result aggregates, and final classification to
focused helpers. Coverage classification uses named predicates and one state-assignment boundary,
while the existing Aura response fields and state values remain unchanged. The response fields now
carry concise contract documentation.

The focused controller result fell from 27 findings to four accepted contract/query heuristics:
two generated Boolean-setter findings on the public Aura DTO and two unrestricted-query warnings on
the intentionally complete aggregate coverage queries. Across the package, controller cleanup plus
the test naming/annotation normalization reduced Recommended findings from 132 to 51: 0 critical,
0 high, 19 moderate, and 32 low. Evidence is retained at
`/tmp/rhc-reports-recommended-20260920-205626.json`. Six Jest tests, source validation, the minimum
core-contract validator, XML parsing, and Metadata API conversion pass. The focused Apex test could
not be submitted because no authorized default org is available.

## R6 — Typed daily-aggregation boundaries

`RHCReportsAggregationService` now carries reporting-day boundaries, Result-key collections, and
snapshot dimensions in focused internal types. Run and Result selection, accumulation, snapshot
record conversion, and partition replacement are separate operations. The public
`aggregateDate(Date, String)` API, time-zone behavior, safety limits, replacement transaction,
snapshot-key input order, and recurring-failure/recovery semantics remain unchanged.

The service fell from nine findings to one package-level aggregate complexity heuristic; all four
positional-parameter findings, the oversized-method findings, the accumulator field-count finding,
and its missing exception contract were removed. Completing the remaining package ApexDoc reduced
the full Reports Recommended result from 51 to 36 findings: 0 critical, 0 high, 12 moderate, and 24
low. Evidence is retained at `/tmp/rhc-reports-recommended-20260920-210324.json`.

## R7 — Typed catch-up Queueable state and finalizer decomposition

`RHCReportsDailyAggregationQueueable` now stores one serializable request instead of four parallel
fields, uses `CatchUpMode` rather than a Boolean catch-up argument, and delegates setting load,
outcome recording, watermark advancement, catch-up continuation, and retention handoff to focused
methods. Both setup and scheduled-maintenance callers use the enum contract. The two-argument
manual-recompute constructor, five-hop catch-up bound, success/failure evidence, monotonic
watermark, and retention-after-catch-up behavior remain unchanged.

The Queueable now has zero Recommended findings. The full Reports result fell from 36 to 33
findings: 0 critical, 0 high, 9 moderate, and 24 low. Evidence is retained at
`/tmp/rhc-reports-recommended-20260920-210558.json`. Existing Jest tests, source validation, the
minimum core-contract validator, XML parsing, and Metadata API conversion pass; the focused Apex
test remains unsubmitted because no authorized default org is available.

## R8 — Explicit test-only retention and Result-fact contracts

The retention Batch again exposes only its normal three-value production constructor. Focused Batch
tests use a named `withoutContinuation` factory rather than a fourth constructor argument, so
production chaining remains the default and the test exception is explicit. The test-data factory
now accepts a typed `ResultFactRequest` instead of five positional values; all callers use the
request and the shared Check identity remains unchanged.

Both touched surfaces have zero Recommended findings. The full Reports result fell from 33 to 31
findings: 0 critical, 0 high, 7 moderate, and 24 low. Evidence is retained at
`/tmp/rhc-reports-recommended-20260920-210838.json`.

## R9 — Typed setup-settings save request

`RHCReportsSetupController.saveSettings` now accepts one `SaveSettingsInput` instead of six
positional Aura parameters. The LWC sends the same retention, aggregation, time-zone, and scheduling
values under the named `input` boundary, and direct Apex callers use the same type. A null request
fails with a bounded user-facing error before settings are read or mutated.

This removes the controller's excessive-parameter finding and all three Boolean-parameter findings.
The focused controller/test/LWC result is clean, and the full Reports Recommended result fell from
31 to 27 findings: 0 critical, 0 high, 3 moderate, and 24 low. Evidence is retained at
`/tmp/rhc-reports-recommended-20260920-213038.json`. Six Jest tests, coverage, source validation,
the minimum-core contract, XML parsing, dependency audit, and Metadata API conversion pass locally.
Current Apex compilation and execution remain pending because no default org is authorized.

## R10 — Dedicated aggregation data boundary

`RHCReportsAggregationRepository` now owns the bounded Run, Result, and prior-status reads plus the
atomic replacement of one date/time-zone snapshot partition. `RHCReportsAggregationService` retains
the reporting window, grouping, recurrence/recovery, and deterministic snapshot construction rules.
The public `aggregateDate(Date, String)` contract, system-mode access, safety limits, error messages,
transaction boundary, and snapshot identity are unchanged. The existing aggregation test continues
to exercise the repository through the service and directly verifies the query-completeness guard.

This removes the service's remaining class-total complexity finding. A focused service/repository/test
scan contains only five pre-existing low-severity `runAs` recommendations, and the full Reports
Recommended result fell from 27 to 26 findings: 0 critical, 0 high, 2 moderate, and 24 low. The two
moderate findings are generated Boolean-setter heuristics on the coverage DTO. Evidence is retained
at `/tmp/rhc-reports-aggregation-repository-20260920-213452.json` and
`/tmp/rhc-reports-recommended-20260920-2205.json`. Six Jest tests, coverage, source validation, the
minimum-core contract, XML parsing, zero-vulnerability dependency audit, and Metadata API conversion
pass locally. The focused Apex run could not start because no default or target org is configured.

## R11 — Explicit service-test principals

The aggregation, ingestion, maintenance, and retention test suites now execute each scenario inside
`System.runAs` with a Standard User created by `RHCReportsTestDataFactory`. This makes the inherited-
sharing context deliberate across all 22 service-test methods instead of relying on the implicit
test-running user. Controller tests continue to use their separate Admin and Viewer permission-set
personas.

The focused factory/test scan is clean, and the full Reports Recommended result fell from 26 to
four findings at that stage: 0 critical, 0 high, 2 moderate, and 2 low. Those findings were two
generated Boolean-setter heuristics on the public coverage DTO and two intentionally complete
aggregate coverage queries. Evidence is retained at
`/tmp/rhc-reports-explicit-principals-20260920-2245.json` and
`/tmp/rhc-reports-recommended-principals-20260920-2248.json`. Six Jest tests, coverage, source and
minimum-core validation, XML parsing, zero-vulnerability dependency audit, and Metadata API
conversion pass locally. The four-class Apex run could not start because no default or target org
is configured.

## R12 — Reviewed coverage-controller analyzer exceptions

The two generated Aura Boolean-property setters and the two intentionally complete grouped
fact-table aggregate queries now carry narrow rule suppressions. Their public response types and
whole-retention-window coverage semantics are unchanged. The rationales and exact allowed
annotations are documented in `CODE-ANALYZER-SUPPRESSIONS.md` and enforced by the source validator;
the full package Recommended scan now reports zero findings
(`/tmp/rhc-reports-recommended-20260921-0240.json`). Six Jest tests pass with 90.56% statement,
53.33% branch, 93.75% function, and 88.88% line coverage; source, minimum-core, XML,
zero-vulnerability dependency-audit, and Metadata API conversion gates pass. The focused Apex run
could not start because no default or target org is configured.
