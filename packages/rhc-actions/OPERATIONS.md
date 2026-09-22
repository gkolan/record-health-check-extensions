# RHC Actions operations

This short page preserves the original operations entry point. Use the comprehensive
[production operations guide](docs/OPERATIONS.md) for ownership, daily checks, incidents, capacity,
change procedures, and retention. For first-time installation and the manual-approval example,
follow the modular [administrator guide](ADMIN_GUIDE.md).

Configure the Platform Event subscriber with a dedicated identity and assign
`RHC_Actions_Runtime`. Its sharing, CRUD, FLS, Apex, Flow, and record permissions apply. Removing
`RHC_Actions_Automatic_Execution` makes new automatic matches fail closed to manual review and
causes already-queued automatic actions to fail authorization before Flow execution.

Salesforce uses Automated Process for a Platform Event Apex trigger unless a release administrator
deploys `PlatformEventSubscriberConfig` through Metadata API or Tooling API. This identity change is
not available as a complete click-only Setup procedure. Do not enable an automatic policy until the
installed `RHCActionResultSubscriber` is verified under the intended dedicated runtime user.

**Run Action** revalidates the active policy, execution mode, applicable custom permission, Flow,
and request; records the approver; and queues execution. Success records the interview ID.
Retryable starts wait at least one minute and cannot exceed policy limits. Recent success for the
same policy and record is suppressed for that policy's cooldown.

The health-check transaction has already committed. Corrective Flow execution is not atomic with
it, and committed downstream work cannot be assumed reversible.

## Triage

1. Inspect Pending Action and Action History.
2. Correlate Event ID and Run ID with core evidence.
3. Use Flow interview ID in Flow monitoring.
4. For `FLOW_CONTRACT_INVALID`, activate a compatible Flow or correct v1 mappings.
5. For start failures, verify runtime Flow, object, field, record, and Apex access plus fault paths.
6. For `ASYNC_EXECUTION_RETRYABLE`, inspect Apex Jobs and the one-minute recovery schedule.
7. For `ASYNC_EXECUTION_FAILED` or `ASYNC_RECOVERY_ENQUEUE_FAILED`, contain the policy and inspect
   Apex Jobs and async capacity before generating a new controlled event.
8. Never copy stack traces or raw payloads into Action records.

A rejected manual proposal remains on Pending Action with status `REJECTED`. Because no Flow
attempt occurred, rejection does not create an Action History record.

Retention is never scheduled. In **RHC Actions Review**, an Admin can save an approved 1–3,650-day
window and confirm a manual purge. Each request deletes at most 1,000 oldest eligible rows,
completed Action History first and then terminal Pending Actions. Do not run cleanup during an
incident or legal hold; `PENDING_REVIEW`, `QUEUED`, `RUNNING`, and `RETRY_WAIT` are never eligible.

Deactivate policies before uninstall. Removing Actions removes only owned metadata and data; core
and other extensions remain operational.
