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

## Large data loads

Pause policies before unintended bulk loads. Review CDC delivery, Queueable, Platform Event, and
storage allocations before reactivation. `ALL` publication can amplify one changed record into many
core result events; `ACTIONABLE` is the default.

## Disable and uninstall

Deactivate policies, drain or deliberately reconcile pending work, preserve required incident
evidence, remove subscriber-owned adapters, and only then uninstall. Never disable a CDC entity
until every subscriber owner confirms it is no longer needed.
