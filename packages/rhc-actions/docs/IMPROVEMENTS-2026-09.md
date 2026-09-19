# RHC Actions — improvement specification (2026-09)

Baseline: 86 components deploy, 44 Apex tests pass, 4 Jest tests pass, zero analyzer findings
above severity 4. Source reviewed: subscriber handler, capture service, execution service and
queueable/finalizer, policy service, review controller, `rhcActionReview` LWC.

## AC1 — Cross-suite X1: approved/rejected actions remain listed

**Problem.** `RHCActionReviewController.getPendingActions` is `cacheable=true`; `rhcActionReview`
calls it imperatively after `runAction` and `rejectAction`. The approved row stays in the queue
until the reviewer reloads, inviting a second click on a row the server now rejects as not
`PENDING_REVIEW`.

**Change.** Remove `cacheable=true` from `getPendingActions`. The method already runs in user mode
and is bounded to 200 rows.

**Acceptance.** Approve a Pending Action → after the toast the row is gone without reload.

## AC2 — Guard the review list against the same double-submit at the client

**Problem.** `runSelected` and `rejectSelected` disable buttons via `submitting`, but the
`lightning-datatable` row action remains active while a request is in flight, so a reviewer can
open a second record and submit while the first call is pending.

**Change.** Bind `submitting` to the datatable's `is-loading` attribute so row actions are
suppressed during a request. One attribute; no new state.

**Acceptance.** Jest: while `runAction` is pending the datatable exposes `isLoading = true`.

## AC3 — Bulk approve / reject (added in the second pass)

`runActions(List<Id>)` and `rejectActions(List<Id>)` (≤ 50 per decision) lock only rows still in
`PENDING_REVIEW`, update in one DML, and enqueue one execution job (the execution service
re-validates each policy's Flow contract at run time). Rows no longer pending are reported as `skipped`, not failed. The
single-row endpoints delegate to the bulk ones. The review table gains row selection with
**Approve selected** / **Reject selected**; the per-row dialog remains for reviewers who want to
inspect first. Tests: `shouldApproveSelectionInOneDecisionAndSkipNonPending`, Jest
"approves the selected rows in one decision and reloads".

## Backlog

- Pending Action / Action History retention (explicitly deferred in
  `docs/SECURITY_AND_AUTHORIZATION.md`).
