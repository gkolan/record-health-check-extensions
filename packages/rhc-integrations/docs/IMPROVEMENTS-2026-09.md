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
