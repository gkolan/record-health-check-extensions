# RHC Change Monitor specification

## Why this project exists

Record Health Check can evaluate a known set of record IDs from Apex, Flow, Queueable, Batch, or
Scheduled Apex. Core deliberately does not subscribe to arbitrary business-record changes. An
organization that wants a Check rerun after a record change otherwise has to build object-specific
CDC enablement, change-event triggers, policy routing, permission handling, duplicate protection,
bulk dispatch, and operations evidence.

RHC Change Monitor provides that optional orchestration without changing core's read-only,
object-neutral evaluation contract.

## Product promise

For an explicitly supported and enabled source entity, the extension accepts a Salesforce CDC
change event, determines whether an active policy matches the entity, change type, and changed-field
filter, and asks Record Health Check core to evaluate the current durable source record under a
documented principal. It records bounded operational evidence for every accepted unit of work.

The product promise is **at-least-once intake with idempotent evaluation claims**, not synchronous
evaluation, exactly-once event delivery, or guaranteed human notification.

## Dependency and ownership

RHC Change Monitor depends only on a promoted Record Health Check core version that exposes:

- `rhc.RecordHealthCheckRequest.forCheck(...)` and `forCheckSet(...)`;
- `rhc.RecordHealthCheck.evaluate(...)` or a promoted asynchronous public equivalent;
- `rhc.RecordHealthCheckEventPublication.NONE`, `ACTIONABLE`, and `ALL`;
- exact Check and Check Set Qualified API Names; and
- the Record Health Check Run custom permission.

Core owns authorization, current-record loading, `WITH USER_MODE` behavior, Check execution, status
semantics, result shaping, and canonical Platform Event publication. Change Monitor must not copy,
fork, bypass, or weaken those responsibilities.

Change Monitor owns:

- CDC intake adapters for explicitly supported entities;
- Change Policy configuration;
- change-type and changed-field routing;
- stable intake and policy idempotency keys;
- bounded asynchronous dispatch and retry classification;
- a minimal Change Evaluation ledger; and
- package-owned retention settings with bounded, explicitly confirmed manual cleanup; and
- setup diagnostics and operational visibility.

## Non-goals

Release 1 does not:

- evaluate `AccountChangeEvent` or another change-event payload as a core record;
- compare old and new values or expose change payload values to Checks;
- dynamically create Apex triggers from administrator input;
- accept arbitrary Apex class names, SOQL, formulas, or field-value expressions;
- process deleted records through core;
- guarantee event order, exactly-once delivery, or immediate evaluation;
- retain general health-check result history;
- send Salesforce Custom Notifications, email, or webhooks;
- depend on RHC Alerts, Run Manager, Reports, Actions, Integrations, Builder, or Logs; or
- enable CDC for an organization without an explicit administrator action and capacity review.

## Administrator-facing policy

One `Record_Health_Check_Change_Policy__c` record represents one approved route from a source
entity to one exact core selection.

| Field | Proposed type | Contract |
| --- | --- | --- |
| `Name` | Auto Number | Operational identity such as `RHC-CP-{000000}` |
| `DisplayName__c` | Text(80) | Human policy name |
| `Active__c` | Checkbox | Inactive policies cannot claim or dispatch new work |
| `SourceObjectApiName__c` | Text(120) | Exact source entity API name, not the `*ChangeEvent` name |
| `SelectionType__c` | Restricted Picklist | `CHECK_SET` or `CHECK` |
| `QualifiedApiName__c` | Text(120) | Exact opaque core Qualified API Name |
| `ChangeTypes__c` | Text(255) | Closed set containing `CREATE`, `UPDATE`, and/or `UNDELETE` |
| `ChangedFields__c` | Long Text Area | Optional newline-delimited exact field API names used only for UPDATE routing |
| `EventPublication__c` | Restricted Picklist | `NONE`, `ACTIONABLE`, or `ALL`; default `ACTIONABLE` |
| `ActiveAfter__c` | DateTime | Optional activation boundary preventing replayed older events from becoming new work |

The administration service must validate that:

1. the source object is supported by Salesforce CDC and by an installed intake adapter;
2. CDC is enabled for the source entity;
3. the selected Check or Check Set exists and targets the same source object;
4. each changed-field name resolves exactly on that source object;
5. UPDATE is selected when a changed-field filter is present;
6. the requested publication mode is explicit; and
7. the runtime principal and core Run permission feasibility checks pass.

Qualified API Names remain case-sensitive opaque identities. Code never adds or strips `rhc__`.

## Change-type behavior

| CDC condition | Release-1 behavior | Reason |
| --- | --- | --- |
| `CREATE` | Evaluate the durable record after commit | The record is queryable after CDC delivery |
| `UPDATE` | Evaluate when the field filter is empty or intersects the canonical changed-field set | Avoid unnecessary runs without interpreting payload values |
| `UNDELETE` | Evaluate the restored durable record | The record is queryable again |
| `DELETE` | Record `IGNORED / RECORD_DELETED`; do not call core | Core requires a queryable durable record |
| Gap or overflow signal | Record a high-priority operational incident and stop affected automatic dispatch | Missing changes cannot be reconstructed safely from the gap event |
| Unknown future value | Fail closed as `IGNORED / UNSUPPORTED_CHANGE_TYPE` and surface setup/operations guidance | Additive Salesforce values must not silently acquire semantics |

CREATE and UNDELETE do not apply `ChangedFields__c`; the complete current record is the evaluation
subject. UPDATE filtering uses only field identity. A filter match never proves that the new value is
meaningful or that a Check outcome changed.

## Intake adapter boundary

Salesforce change-event triggers are bound to change-event sObject types at compile time. A package
configuration record cannot dynamically attach an Apex trigger to an arbitrary standard or custom
object. Therefore Release 1 must choose one of these reviewed models after the feasibility spike:

1. **Subscriber-owned adapter, preferred initial design.** The package exposes one narrow global
   handler. A reviewed subscriber trigger for each selected `*ChangeEvent` type passes `Trigger.new`
   to that handler. Templates and contract tests are shipped as documentation, not silently deployed
   Apex.
2. **Explicit packaged adapters.** A separately reviewed package variant ships a small documented
   allow-list of standard change-event triggers. Installation prerequisites must prove those event
   types compile and install consistently when CDC selection differs by org.
3. **External Pub/Sub worker.** An integration user subscribes to CDC through Pub/Sub API and invokes
   a supported Salesforce API. This is a different operational product and must not be smuggled into
   the on-platform package without a new threat model and deployment contract.

Dynamic Apex generation, Metadata API trigger creation at runtime, and broad triggers on subscriber
custom objects are prohibited.

## Runtime sequence

```text
Salesforce record commit
        |
        v
CDC change event (asynchronous, replayable)
        |
        v
Object-specific intake adapter
        |
        +--> validate supported header and source identity
        +--> split header record IDs into one record-level claim each
        +--> match active policies once per event batch
        +--> insert unique Event + Policy + Record claims
        |
        v
Bounded dispatcher (maximum 200 same-object IDs per core request)
        |
        +--> re-check policy active state and activation boundary
        +--> invoke core with exact selection and explicit publication mode
        +--> store terminal status/counts or bounded failure classification
        |
        v
Optional canonical core Result and Set Run Platform Events
```

The CDC trigger must not execute unbounded core evaluations inside the trigger loop. Header parsing,
policy selection, and claims are bulk operations. Evaluation happens in bounded asynchronous work.

## Identity and idempotency

CDC delivery is replayable and can be received more than once. The feasibility spike must identify
a stable, subscriber-visible event identity available in Apex for the supported API version. The
preferred claim input is the immutable combination of entity identity, transaction key, sequence
number, change type, and source record ID. Replay ID may be retained as stream-position evidence but
must not be treated as a business-record ID or assumed contiguous.

`ClaimKey__c` is a unique SHA-256 digest of:

```text
CDC stable event identity | Policy Id | Source Record Id
```

One duplicate claim produces no second core evaluation. Hash inputs use a versioned canonical
encoding so delimiter ambiguity, null normalization, or a later format change cannot collide
silently. If the platform does not expose enough stable identity to prove replay idempotency in Apex,
the on-platform design does not pass its feasibility gate.

## Operational ledger

`Record_Health_Check_Change_Evaluation__c` is a bounded orchestration ledger, not result history.

| Field | Proposed type | Contract |
| --- | --- | --- |
| `Name` | Auto Number | `RHC-CE-{000000}` |
| `Policy__c` | Lookup | Policy evaluated; deletion uses Set Null |
| `ClaimKey__c` | Unique External ID Text(64) | Versioned event-policy-record digest |
| `SourceObjectApiName__c` | Text(120) | Exact source object identity |
| `RecordId__c` | Text(18) | Source record correlation, never a relationship |
| `ChangeType__c` | Restricted Picklist | Observed supported or normalized unsupported category |
| `TransactionKey__c` | Text(80) | Bounded CDC transaction correlation when available |
| `SequenceNumber__c` | Number | CDC order evidence within a transaction when available |
| `ReplayId__c` | Text(80) | Opaque stream-position evidence when available |
| `RunId__c` | Text(120) | Core run correlation after dispatch |
| `OccurredAt__c` | DateTime | CDC commit/event time |
| `AcceptedAt__c` | DateTime | Claim time |
| `CompletedAt__c` | DateTime | Terminal orchestration time |
| `Outcome__c` | Restricted Picklist | `PENDING`, `EVALUATED`, `IGNORED`, `FAILED`, or `DUPLICATE` |
| `ReasonCode__c` | Restricted Picklist | Package-owned bounded routing/failure reason |
| `AttemptCount__c` | Number(2,0) | Bounded dispatch attempts |
| `ResultCount__c` | Number | Count only; no copied result payload |
| `ActionableCount__c` | Number | `FAIL + UNABLE_TO_EVALUATE + ERROR` count |

Do not store changed values, old values, raw event payloads, found/expected values, display messages,
stack traces, unrestricted exception text, user session data, or notification bodies.

### Retention contract

One `Record_Health_Check_Change_Setting__c` singleton stores the administrator-approved retention
window. The supported identity is `Default`, and `RetentionDays__c` is a whole number from 1 through
3,650. An unsaved 90-day recommendation is non-authorizing. One manually confirmed purge deletes at
most 1,000 oldest terminal evaluations outside the saved window, ordered by acceptance time;
`PENDING` is never eligible. Release 1 includes no scheduled or automatic deletion.

## Execution principal and authorization

This is a release-blocking contract, not an implementation detail.

Core requires the Record Health Check Run custom permission and evaluates source data in user mode.
CDC processing is asynchronous and does not automatically preserve the human user who committed the
record as the core evaluation principal. Change Monitor must publish one documented answer to all of
these questions before source implementation:

1. Which Salesforce user is the effective principal in the change-event trigger and dispatcher?
2. How is the core Run custom permission granted through supported Salesforce configuration?
3. Which sharing, object, and field access determines the result?
4. Can an administrator inspect and test that principal before policy activation?
5. What happens when permission or data access is later removed?

The package must not use `without sharing`, privileged internal core APIs, synthetic `runAs`, or a
custom-permission bypass to make a failing design appear functional. If a supported least-privilege
principal cannot be established, the on-platform package remains unimplemented and the external
integration-user model requires separate approval.

## Loop and amplification controls

- Core and conforming Checks are read-only, so evaluation must not create another source change.
- Package-owned Change Policy, Change Evaluation, and Change Setting objects are never eligible
  source entities.
- Intake and administrator retry must inspect immediate dispatch-event publication results and
  roll back the associated claim transition when Salesforce rejects the wake-up signal.
- An authorized administrator can request one additional data-free dispatch signal for existing
  pending claims when no dispatcher is active; this recovery does not mutate or duplicate claims.
- One source object can have a documented maximum number of active policies; the initial proposed
  cap is 10 and must be load-tested before release.
- One change-event batch queries policies once and inserts claims with partial-success DML.
- One core request contains at most 200 same-object record IDs and one exact selection.
- Queueable chaining is bounded; failures do not spin indefinitely.
- `ACTIONABLE` is the default publication mode to avoid producing every passing result event after
  high-volume data loads.
- Setup displays estimated CDC and core Platform Event amplification before activation.

## Retry and failure policy

Retry only failures explicitly proven transient, such as a row-lock conflict. Authorization,
invalid policy identity, missing CDC setup, unsupported headers, deleted records, inaccessible
records, and core configuration results are not blind-retry candidates. Core `FAIL`, `SKIPPED`,
`UNABLE_TO_EVALUATE`, and contained `ERROR` are evaluation outputs, not dispatcher exceptions.

The initial retry cap is three attempts. Each attempt increments the ledger before work begins.
Exhausted work becomes terminal `FAILED` with a bounded package reason code. There is no automatic
infinite replay and no administrator action that bypasses policy revalidation.

## Setup diagnostics

The administration experience must show, before activation:

- source entity CDC eligibility and current selected-entity state;
- installed adapter availability;
- exact core selection and source-object compatibility;
- changed-field validity;
- effective runtime principal and Run custom-permission result;
- source record and field access probe using controlled sandbox data;
- event publication mode and estimated event amplification;
- current CDC, Platform Event, Queueable, and storage limit posture where Salesforce exposes it; and
- the package's unsupported DELETE and gap behavior.

A green setup result proves configuration at one point in time. It does not guarantee future event
delivery, available allocations, record access, or downstream subscriber success.

## Acceptance criteria

Implementation is acceptable only when all of the following are proven in a clean namespaced
subscriber-style org:

1. The package installs with core and without another extension.
2. CREATE, matching UPDATE, nonmatching UPDATE, UNDELETE, DELETE, duplicate delivery, and an unknown
   future change type each follow the specified path.
3. One stable event-policy-record claim creates at most one core evaluation.
4. A bulk event with more than 200 record IDs is split without loss, cross-object mixing, or limit
   failure.
5. Exact Check and Check Set Qualified API Names work with packaged and subscriber-owned metadata.
6. Source-object and changed-field mismatch prevents activation.
7. The effective principal, custom permission, sharing, CRUD, and FLS behavior are documented and
   verified with positive and negative users.
8. DELETE never calls core and never masquerades as a health-check failure.
9. A gap/overflow signal becomes visible high-priority operational evidence.
10. No changed value, raw payload, unrestricted exception, or core display detail is persisted.
11. Manual cleanup requires saved settings and explicit confirmation, deletes no `PENDING` claims,
    and never exceeds 1,000 rows in one run.
12. Removing Change Monitor does not change core evaluation or another extension.
13. Salesforce source validation, Apex tests, Code Analyzer, package creation, clean installation,
    upgrade, and uninstall tests all pass before release language is used.

## Official Salesforce references

- [Set up CDC selected entities](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/qs-set-up-events.html)
  — developer documentation describing explicit Change Data Capture entity selection.
- [Event deserialization considerations](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/event-deserialization-considerations.html)
  — developer documentation describing changed, nulled, and diff field semantics across delivery
  APIs.
- [Event message durability](https://developer.salesforce.com/docs/platform/pub-sub-api/guide/event-message-durability.html)
  — developer documentation describing retention and opaque Replay IDs.
- [Change event Apex trigger example](https://developer.salesforce.com/blogs/2019/06/get-buildspiration-with-asynchronous-apex-triggers-in-summer-19)
  — official Salesforce Developers article showing object-specific asynchronous after-insert
  triggers such as `OpportunityChangeEvent`.

These sources ground platform behavior; the package must still verify exact Apex fields, limits,
execution identity, packaging behavior, and supported API-version semantics in its feasibility org.
