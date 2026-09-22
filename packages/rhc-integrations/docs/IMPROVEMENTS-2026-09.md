# RHC Integrations — improvement specification (2026-09)

Baseline: 61 components deploy, 23 Apex tests pass, 8 Jest tests pass, zero analyzer findings
above severity 4. Source reviewed: subscriber coordinator, event handler, ingestion service,
delivery factory/policy/queueable, dead-letter controller and LWC.

## I1 — Deliver several rows per Queueable hop

**Problem.** `RHCIntegrationDeliveryQueueable.execute` locks one ledger row, performs one callout,
updates it, and chains a new Queueable for the next row. A burst of 1,000 actionable results
becomes 1,000 serial async jobs (each with its own dispatch latency, typically seconds), and
consumes 1,000 of the daily async executions for what the platform allows in ten transactions
(100 callouts per transaction). Throughput to the external system is therefore bounded by
Queueable scheduling, not by the endpoint.

**Change.** Process up to `DELIVERIES_PER_HOP = 10` rows per execution:

1. Lock the head slice with one `SELECT … FOR UPDATE` (rows keep their queue order).
2. For each locked row: skip rows that are no longer deliverable; defer rows whose
   `NextAttemptAt__c` is in the future to the tail; otherwise perform the callout and classify
   the result **in memory** (`RHCIntegrationDeliveryPolicy.process` no longer issues DML).
3. After the last callout, issue **one** `Database.update` for every processed row. Callouts
   precede DML, which satisfies the platform rule that no callout may follow uncommitted DML.
4. Rows classified `RETRY_WAIT` return to the tail. Chain with a delay only when every remaining
   row is waiting; otherwise chain immediately.

Idempotency is preserved: the request already sends `Idempotency-Key: <EventId>`, so if the
transaction fails after some callouts and before the single update, the finalizer marks the
in-flight rows `QUEUEABLE_UNHANDLED` and replay resends with the same key. That trade-off is
documented in `docs/DELIVERY-LIFECYCLE.md`.

`currentDeliveryId` becomes `currentDeliveryIds` (the locked slice) and the finalizer recovers
every row of the slice that is still deliverable.

**Acceptance.**
- One hop with 10 pending rows and a 200 mock issues 10 callouts and 1 DML statement, and all
  rows are `SUCCEEDED`.
- A slice mixing due and not-yet-due retry rows delivers the due rows and re-queues the others.
- Unhandled failure marks every still-pending row of the slice `DEAD_LETTER / QUEUEABLE_UNHANDLED`.
- Existing single-row tests continue to pass.

**Tests.** `RHCIntegrationDeliveryQueueableTest`: `hop_deliversSliceWithSingleDml`,
`hop_defersFutureRetries`, `finalizer_recoversWholeSlice`.

**Docs.** `docs/DELIVERY-LIFECYCLE.md` and `docs/ARCHITECTURE.md` describe the slice, the ordering
rule (callouts first, one update), and the replay behavior after an unhandled failure.

## I2 — Cross-suite X1: replayed dead letters remain listed

**Problem.** `RHCIntegrationDeadLetterController.getDeadLetters` is `cacheable=true` and the LWC
re-reads it after `replay`; replayed rows still appear as dead letters.

**Change.** Remove `cacheable=true` from `getDeadLetters`.

**Acceptance.** Replay a row → it leaves the dead-letter table without reload.

## I3 — Bulk replay of dead letters (added in the second pass)

`replayAll(List<Id>)` (≤ 50) locks the selected rows that are still `DEAD_LETTER`, rejects the
whole request if any route in the selection is inactive (nothing is half-replayed against an
unfixed endpoint), resets them for replay in one user-mode DML, and starts **one** delivery chain
so the sliced Queueable sends them together. `replay(Id)` delegates to it. The dead-letter table
gains row selection and **Replay selected** for users with `RHC_Integration_Replay`; viewers keep
the read-only table. Tests: `shouldReplaySelectionInOneChainAndSkipNonDeadLetters`, Jest
"replays the selected rows in one request".

## I4 — Package-owned, bounded delivery retention (2026-09-20 follow-up)

The package now owns a validated singleton retention setting and exposes it in the Dead Letters
tab only to users with setting create/read/edit plus Delivery delete access. The initial 90-day
value is an unsaved recommendation. Saving a 1–3,650 day window never schedules deletion.

Each separately acknowledged purge uses user-mode query/delete, processes at most 1,000 oldest
completed `SUCCEEDED` or `DEAD_LETTER` rows, and excludes `PENDING` and `RETRY_WAIT` regardless of
age. Admin receives setting create/read/edit without delete; Operator, Viewer, and Runtime receive
no setting access. Apex and Jest tests cover recommendation/save/update/range validation, saved-policy
precondition, terminal-only deletion, confirmation, and hidden controls.

## I5 — Revalidate replay security-flow evidence

Code Analyzer 5.15.0 / SFGE 0.24.0 repeatedly stops with an internal vertex-loading error on both
public replay entry points at the same replay DML sink, even after replay fields are passed through
`Security.stripInaccessible`. The sink is protected independently by the replay Custom Permission,
a locked `WITH USER_MODE` query, fail-closed rejection when any replay-state field is removed, and
`update as user`.

The current follow-up reproduced 30/32 analyzed entry points with zero reported violations. Both
documented next-line and stack directive placements were tested with the engine's display and
internal rule names; SFGE ignored them and remained incomplete, so no ineffective suppression was
retained. The dedicated security scan must identify and analyze every entry point with zero
violations, and the strict log verifier continues to reject internal engine errors or incomplete
entry-point counts.

## I6 — Explicit test principals and current local evidence

All Integrations test annotations now use canonical `@IsTest` casing. Payload, direct-event
subscriber, Queueable, and handler tests execute as an explicit least-privilege Standard User
supplied by the shared test factory. Controller authorization tests retain their explicit Admin and
Viewer principals. The current full-package Recommended scan reports zero findings without adding
an analyzer suppression.

Local verification on September 21 passed 15/15 Jest tests with 100% statement, branch, function,
and line coverage, source validation, the minimum-core contract, XML parsing, dependency audit, and
Metadata API conversion. The focused Apex run could not start because no default or explicitly
authorized target org is configured.
