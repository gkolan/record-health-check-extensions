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
and zero `no-async-operation` findings; all tests still pass. The remaining findings
(`AnnotationsNamingConventions`, `MethodNamingConventions`, `ApexUnitTestClassShouldHaveRunAs`,
boolean parameters) are severity 3–4 style rules that the sibling packages also accept; they are
recorded, not fixed.

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
"Latest aggregation outcome" after refresh. Tests: `shouldQueueLatestCompletedDay_WhenAdminRunsAggregationNow`,
Jest "queues aggregation on demand and reloads the outcome".
