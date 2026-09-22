# RHC Logs — improvement specification (2026-09)

Baseline: 56 components deploy, 32 Apex tests pass, 16 Jest tests pass, zero analyzer findings.
Source reviewed: `RHCLogsIngestionService`, `RHCLogsCleanupService`, `RHCLogsCleanupScheduler`,
`RHCLogsAdminController`, `RHCLogsReviewController`, both LWCs.

## L1 — Bound Platform Event retries in ingestion

**Problem.** `RHCLogsIngestionService.ingest` throws `EventBus.RetryableException` whenever any row
fails with `UNABLE_TO_LOCK_ROW` or `UNKNOWN_EXCEPTION`. Salesforce retries the batch up to nine
times and then suspends the trigger. A persistently locked settings row or one poisoned event
therefore takes the whole subscriber offline. RHC Actions and RHC Integrations already cap this at
three retries; Logs does not.

**Change.** Read `EventBus.TriggerContext.currentContext().retries`. If it is below
`MAX_RETRIES = 3`, keep the current behavior. Otherwise stop retrying: count the retryable rows as
failed, add `RETRY_EXHAUSTED` to the permanent error codes, and let the operational snapshot record
`PARTIAL_FAILURE`. Successful rows in that delivery are kept because inserts already use
`allOrNone = false` and `EventId__c` uniqueness keeps a later replay idempotent.

**Acceptance.**
- Retry attempt 0–2 with a retryable error still throws `EventBus.RetryableException`.
- Retry attempt 3 with a retryable error does not throw; the snapshot shows `PARTIAL_FAILURE` and
  `LastIngestionErrorCodes__c` contains `RETRY_EXHAUSTED`.
- Existing duplicate, malformed, and success paths are unchanged.

**Tests.** `RHCLogsIngestionServiceTest`: `retriesAreExhausted_recordsPermanentFailure` using the
`@TestVisible` retry-count override (trigger context is not available in a unit test).

**Docs.** `docs/OPERATIONS.md` troubleshooting table gains the `RETRY_EXHAUSTED` code.

## L2 — Let cleanup catch up on a backlog

**Problem.** One cleanup run deletes at most `CleanupBatchSize__c` rows (≤ 9,998) and the schedule
runs once a day. An org that ingests more expired rows per day than that never converges, and an
administrator who lowers `RetentionDays__c` waits days for the backlog to drain.

**Change.** After a run deletes a full batch (`deletedCount == CleanupBatchSize__c`), enqueue
`RHCLogsCleanupContinuation` (Queueable) which calls `RHCLogsCleanupService.run(AUTOMATED)` again.
Continuations are bounded to `MAX_CONTINUATIONS = 5` per trigger, so one schedule fires at most six
bounded transactions. Manual cleanup from the setup page uses the same continuation. The lease and
overlap protection already in `run` make each hop independently safe.

**Acceptance.**
- A run that deletes fewer rows than the batch size enqueues nothing.
- A run that deletes exactly the batch size enqueues one continuation with hop 1.
- Hop 5 never enqueues hop 6.
- `Test.isRunningTest()` is not used to skip enqueueing; tests assert `Limits.getQueueableJobs()`.

**Tests.** `RHCLogsCleanupServiceTest`: `fullBatch_enqueuesContinuation`,
`partialBatch_doesNotEnqueue`; `RHCLogsCleanupContinuationTest`: `lastHop_stops`.

**Docs.** README "How it works" and `docs/OPERATIONS.md` describe the bounded continuation.

## L3 — Cross-suite X1: stale status after save/cleanup

**Problem.** `RHCLogsAdminController.getStatus` is `cacheable=true` and `rhcLogsSetup` calls it
imperatively after `saveSettings` and `runCleanup`; the refreshed panel can show the previous
retention values and cleanup counts.

**Change.** Remove `cacheable=true` from `getStatus`. `RHCLogsReviewController.search` stays
cacheable because its arguments change with every filter/cursor and no write precedes a re-read.

**Acceptance.** Saving settings then reading the panel shows the saved values without a page reload.

## L4 — Inline log details (added in the second pass)

The review table gains a **Show details** row action that opens the selected log's Event ID,
exception type, running user, ingestion time, Message, and Structured Details in a panel under the
table, so an investigator scans several rows without leaving the filtered, paginated list. Only
fields the controller already returned (that is, fields the user can read) are shown; the record
link remains for full-page review. Test: Jest "shows message and structured details inline".

## L5 — Cleanup control flow and Queueable recovery evidence

The cleanup entry point now delegates mode/access/settings initialization and pre-cleanup stop
conditions to focused helpers. This removes the production cyclomatic-complexity finding without
changing lease, overlap, DML-budget, deletion, or continuation behavior.

The continuation intentionally does not attach a Finalizer. A failed hop rolls back its entire
transaction, including its lease, after the previous successful hop has already committed and
released its own lease; the next schedule or manual run therefore resumes safely. The narrow
`QueueableWithoutFinalizer` suppression and this recovery model are recorded in
`CODE-ANALYZER-SUPPRESSIONS.md` and enforced by the source validator.

Local verification on September 21 passed 17/17 Jest tests, with 100% statement/function/line and
96.42% branch coverage, source validation, minimum-core validation, XML parsing, dependency audit,
Metadata API conversion, and a full-package Recommended scan with zero findings. The focused Apex
run could not start because no default or explicitly authorized target org is configured.

## Not changed

- Review page filters and keyset pagination: correct and secure as reviewed.
- Retention ceiling (365 days) and batch ceiling (9,998): unchanged contracts.
