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

## AC4 — Governed Pending Action / Action History retention (2026-09-20)

Actions now owns a validated `RHC_Action_Setting__c` singleton and an Admin-only manual cleanup
path. The unsaved 365-day recommendation cannot authorize deletion. Each confirmed request deletes
at most 1,000 combined rows, oldest completed Action History first and then old terminal Pending
Actions in `SUCCEEDED`, `FAILED`, `SUPPRESSED`, or `REJECTED`. It never selects
`PENDING_REVIEW`, `QUEUED`, `RUNNING`, or `RETRY_WAIT`.

The Admin Permission Set receives `RHC_Actions_Manage_Retention` and settings CRUD, but no packaged
role receives direct delete CRUD on Pending Action or Action History. The deletion boundary is a
permission-gated service using system mode only after authorization; no scheduler is included.

Local evidence: 11 Jest tests, source least-privilege validation, and XML parsing pass. Apex
deployment/tests and clean-subscriber lifecycle validation remain release gates.

## AC5 — Explicit test principals and complete Apex contracts (2026-09-21)

All Actions test scenarios now execute inside an explicit `System.runAs` boundary, including the
pure policy, capacity, subscriber, finalizer, and Queueable cases that previously inherited the
test-running user implicitly. Public and virtual Apex methods now have complete descriptions,
parameters, and return contracts.

The one retained production debug statement is narrowly suppressed and documented: it emits only a
fixed, sanitized message if a best-effort capture-failure audit row is itself rejected. Throwing in
that path would roll back already captured pending actions and make a permanent audit-row defect
poison event redelivery.

The current package-source Recommended scan reports zero findings
(`/tmp/rhc-actions-recommended-20260921-0220.json`). Eleven Jest tests pass with 91.58% statement,
70.83% branch, 92.3% function, and 92.85% line coverage; source, minimum-core, XML,
zero-vulnerability dependency-audit, and Metadata API conversion gates pass. The five-class Apex
run could not start because no default or target org is configured.
