# RHC Change Monitor feasibility and gap analysis

## Decision summary

The capability belongs outside core, but an on-platform package is not yet proven feasible. Core's
public record-ID API is sufficient for evaluation. A local, non-release SFDX implementation now
exists to make the adapter, replay-identity, principal, and limit hypotheses executable. It is
feasibility source, not evidence that the hypotheses passed.

Do not create a 2GP package container, package version, or production release until Gates 1–4, the
no-namespace validation matrix, all other pre-registration checks, and an explicit
release-worthiness review pass. Source compilation alone is not approval.

## What core already provides

| Need | Existing core contract | Decision |
| --- | --- | --- |
| Evaluate current records | `RecordHealthCheckRequest.forCheck/forCheckSet` with up to 200 IDs | Reuse; do not add CDC payload evaluation |
| Enforce run authorization | Record Health Check Run custom permission | Preserve without bypass |
| Enforce source access | Core record loading and query evaluation in user mode | Effective CDC principal must be explicit |
| Publish outcomes | `NONE`, `ACTIONABLE`, `ALL` | Policy selects explicitly; default `ACTIONABLE` |
| Correlate a caller run | `withRunId(...)` | Use a safe versioned claim-derived run correlation |
| Report results | Canonical response and optional Platform Events | Store counts only; other extensions consume events independently |

No core edit is proposed. If feasibility reveals a generally useful asynchronous public API gap,
that change needs its own core proposal and security review; Change Monitor cannot call a core
internal class.

## Gate 1: change-event adapter packaging

Prove in scratch and subscriber-style orgs:

1. whether a trigger referencing a standard `*ChangeEvent` installs when that entity is not selected
   for CDC;
2. whether a namespaced 2GP package can safely ship any fixed change-event trigger;
3. whether custom-object CDC necessarily requires subscriber-owned source; and
4. which metadata or Tooling APIs can inspect selected entities without granting source mutation.

Expected decision: ship a narrow global handler plus subscriber-owned, reviewed trigger templates.
Do not dynamically generate Apex.

## Gate 2: stable replay identity

Capture the exact Apex representation of a real CREATE, UPDATE, UNDELETE, DELETE, duplicate replay,
and bulk transaction. Prove which of these remain stable across redelivery:

- entity name;
- transaction key;
- sequence number;
- source record IDs;
- commit timestamp;
- event UUID when exposed; and
- Replay ID when exposed.

Define and collision-test the canonical claim encoding. If replayed delivery cannot produce the same
claim key, the package cannot promise idempotent evaluation and does not proceed.

## Gate 3: execution principal

In a clean subscriber-style org, record the effective user and permission behavior for:

- the change-event trigger;
- directly invoked handler Apex;
- one Queueable hop; and
- core `RecordHealthCheck.evaluate(...)`.

Prove a supported way to grant the effective principal core Apex access and the Record Health Check
Run custom permission. Then prove positive and negative record/FLS cases. Do not infer this from
ordinary Apex triggers or Platform Event subscribers.

If the supported principal is excessively privileged, invisible to administrators, or cannot be
permissioned reliably, reject the on-platform runtime. Consider a separately specified Pub/Sub
worker operating as a named integration user.

### No-namespace finding — 2026-08-30

The Account change-event trigger and its Queueable ran as the `AutomatedProcess` user
`autoproc@00drl00000ukhko2at`. Real CREATE, matching UPDATE, and UNDELETE deliveries reached the
dispatcher but failed closed with `RUNTIME_PERMISSION_MISSING`. A valid
`PlatformEventSubscriberConfig` naming the scratch administrator deployed successfully, but the
next real delivery still ran as Automated Process. Therefore that platform-event subscriber
control is not a principal solution for this CDC trigger.

Gate 3 is blocked. Do not remove the custom-permission check and do not assign an administrator
permission set to Automated Process as a shortcut. The next design review must either prove a
least-privilege permission model for Automated Process or select the separately authenticated
Pub/Sub worker boundary described above.

The source now includes `RHC_Change_Monitor_Runtime`, which grants only policy reads, evaluation
create/read/edit, and runtime Apex access. It validated and deployed unassigned in the shared org.
The narrowest remaining on-platform experiment is pairing it with core's
`Record_Health_Check_User` permission set on Automated Process. That is still a persistent security
change and is not authorized merely by deploying the source.

## Gate 4: transaction and limit behavior

Prove:

- maximum CDC trigger batch shape and header `recordIds` behavior;
- bulk policy selection without per-event SOQL;
- claim DML with duplicate partial success;
- Queueable capacity and chaining under event bursts;
- safe splitting into core's 200-record maximum;
- gap and overflow visibility; and
- amplification when one source object has ten policies and core publication is `ACTIONABLE` or
  `ALL`.

Document measured limits and deliberately choose lower package caps.

## Gate 5: pre-registration release-worthiness review

After the earlier gates pass, but before any package is created:

1. choose the final product/package name;
2. pass the complete namespaced and no-namespace source deployment and test matrix;
3. confirm the local SFDX project remains pinned to the same promoted core and API version as the suite;
4. implement the smallest adapter model proven by Gate 1;
5. close or explicitly disposition every security, analyzer, operations, and limits finding;
6. complete security, operations, data-model, development, and release-evidence documentation;
7. record an explicit release-worthiness decision; and
8. update repository validation from seven to eight package projects only when the real SFDX
   project exists.

The current maintainer decision does not authorize registration of a 2GP container or creation of
a package version after this review. A later explicit exception would be required to create a
release candidate for the otherwise impossible clean install, upgrade, and uninstall lifecycle
tests. Such a candidate would not itself be release approval.

## Explicitly rejected shortcuts

- Treating `*ChangeEvent` records as core records.
- Calling core with a CDC event Replay ID.
- Running core directly inside each trigger-event loop.
- Shipping triggers for arbitrary subscriber custom objects.
- Generating Apex through Metadata API during setup.
- Disabling custom-permission or user-mode enforcement.
- Falling back to an unnamed system context.
- Retrying every exception.
- Calling DELETE an `UNABLE_TO_EVALUATE` health result.
- Depending on RHC Run Manager merely to obtain a runtime principal.
