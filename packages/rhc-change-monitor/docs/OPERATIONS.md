# RHC Change Monitor operations

## Daily review

Monitor pending age, terminal failures, gap incidents, ignored deletes, retry exhaustion, and the
ratio of accepted changes to evaluated records. A gap is not retry work: pause the affected policy,
reconcile current state through an approved portfolio run, and reactivate only after the operations
owner accepts the recovery evidence.

## Retry behavior

Only errors classified as row-lock conflicts are retried automatically. Each durable claim permits
at most three attempts. Queueable chaining is capped at ten jobs, each selecting at most 200 claims.
Authorization and configuration failures are terminal and retain only a bounded reason code.

If **Pending claims** is greater than zero while **Dispatcher queued** is false, select
**Dispatch pending claims**. The action does not edit or duplicate claims; it publishes one
data-free wake-up signal, and the subscriber-side coordinator still prevents parallel dispatcher
fan-out. Do not use it for a CDC gap—gaps require reconciliation, not replay of the visible queue.

## Large data loads

Pause policies before unintended bulk loads. Review CDC delivery, Queueable, Platform Event, and
storage allocations before reactivation. `ALL` publication can amplify one changed record into many
core result events; `ACTIONABLE` is the default.

## Retention and manual purge

The package stores one administrator-approved retention window in
`Record_Health_Check_Change_Setting__c`. The initial 90-day value shown in the console is a
recommendation only; an administrator must save a whole number from 1 through 3,650 before any
deletion is allowed.

Before each cleanup, reconcile active incidents and export evidence required by the organization's
records policy. In the **RHC Change Monitor** console, review the saved window, acknowledge that the
operation permanently deletes eligible records, and select **Purge eligible Change Evaluations**.
One run deletes at most 1,000 oldest terminal evaluations whose `AcceptedAt__c` is outside the
window. `PENDING` evaluations are never eligible. The acknowledgment clears after each attempt, and
changing the displayed window disables purge until the new value is saved.

No scheduled or automatic deletion is included. Repeated manual runs require a fresh acknowledgment;
automation requires measured volume, an approved records policy, monitoring, and separate design
review.

## Disable and uninstall

Deactivate policies, drain or deliberately reconcile pending work, preserve required incident
evidence, remove subscriber-owned adapters, and only then uninstall. Never disable a CDC entity
until every subscriber owner confirms it is no longer needed.
