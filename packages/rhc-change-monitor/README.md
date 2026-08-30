# RHC Change Monitor

> **Re-evaluate Record Health Check after selected Salesforce record changes.**

> [!WARNING]
> **Development preview:** this directory now contains the first Salesforce DX implementation
> slice, but it has no package container or installable version and has not passed the CDC replay,
> adapter-packaging, effective-principal, or load gates. Do not deploy it to production or present it
> as an available extension. See [release evidence](RELEASE_EVIDENCE.md) for the open gates.

RHC Change Monitor is a proposed optional extension for organizations that want selected Record
Health Check Checks or Check Sets to run after Salesforce Change Data Capture (CDC) reports a source
record change. It reacts to a change notification by reloading the current source record through
Record Health Check core. It does not evaluate the transient CDC payload as though it were a durable
business record.

## Intended outcome

An administrator can define a policy such as:

- watch Account changes;
- rerun `Account_Data_Quality` after CREATE, UPDATE, or UNDELETE;
- on UPDATE, run only when one of `OwnerId`, `Industry`, or `AnnualRevenue` changed;
- publish only actionable Record Health Check results; and
- retain bounded operational evidence showing whether the change was accepted, ignored,
  deduplicated, evaluated, or failed.

The extension must never change the checked record, infer a result from the event payload, or hide
the running principal used by core's user-mode evaluation.

## Proposed package boundary

RHC Change Monitor depends only on Record Health Check core. It owns CDC intake, policy matching,
deduplication, bounded dispatch, and an operational ledger. Core continues to own record loading,
access enforcement, Check selection, evaluation semantics, and canonical result events.

It does not send human notifications. Install RHC Alerts for Salesforce bell notifications or
email. It does not retain analytical result history, schedule portfolio scans, or deliver webhooks.

## Start here

| Need | Document |
| --- | --- |
| Product scope, contracts, and acceptance criteria | [Specification](SPEC.md) |
| Required feasibility decisions before implementation | [Gap analysis](GAP_ANALYSIS.md) |
| Administrator setup and operational workflow | [Administrator guide](ADMIN_GUIDE.md) |
| Trust boundaries, abuse cases, and controls | [Threat model](THREAT_MODEL.md) |
| Subscriber-owned trigger requirements | [Adapter contract](docs/ADAPTER_CONTRACT.md) |
| Source layout and contributor workflow | [Development guide](docs/DEVELOPMENT.md) |
| Implemented objects and data minimization | [Data model](docs/DATA_MODEL.md) |
| Runtime monitoring and recovery | [Operations guide](docs/OPERATIONS.md) |
| Security implementation notes | [Security guide](docs/SECURITY.md) |
| Canonical shared no-namespace test org | [Shared no-namespace validation org](docs/SHARED_NO_NAMESPACE_ORG.md) |
| Gate-by-gate build evidence | [Release evidence](RELEASE_EVIDENCE.md) |

## Current state

State: **implementation preview, blocked on feasibility evidence**. The project contains the policy
and ledger schema, disclosure-safe event envelope, versioned claim keys, closed routing, bulk claim
intake, bounded dispatch, permission sets, and contract tests. It deliberately ships no
object-specific CDC trigger or CDC channel membership. A package container, release language, and
production use remain blocked until the named feasibility gates pass.
