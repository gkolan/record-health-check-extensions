# RHC Change Monitor

> **Re-evaluate Record Health Check after selected Salesforce record changes.**

> [!WARNING]
> **Development preview:** this directory now contains the first Salesforce DX implementation
> slice, but it has no package container or installable version. The effective-principal gate passed;
> replay/redelivery, adapter packaging, measured-load, and package-lifecycle gates remain open. Do
> not deploy it to production or present it as an available extension. See
> [release evidence](RELEASE_EVIDENCE.md) for the current gate ledger.

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
| Generate a subscriber-owned trigger and CDC channel member | `npm run adapter:generate -- --help` |
| Source layout and contributor workflow | [Development guide](docs/DEVELOPMENT.md) |
| Implemented objects and data minimization | [Data model](docs/DATA_MODEL.md) |
| Runtime monitoring and recovery | [Operations guide](docs/OPERATIONS.md) |
| Security implementation notes | [Security guide](docs/SECURITY.md) |
| Canonical shared no-namespace test org | [Shared no-namespace validation org](docs/SHARED_NO_NAMESPACE_ORG.md) |
| Gate-by-gate build evidence | [Release evidence](RELEASE_EVIDENCE.md) |

## First run

Change Monitor is not publicly installable. In an approved disposable development org only:

1. Install the compatible Record Health Check core version and deploy this preview from its
   namespaced packaging environment.
2. Assign Admin, Runtime, and Viewer access only to their documented principals.
3. Generate the subscriber-owned adapter for one supported object and deploy the generated trigger
   and CDC channel member after review.
4. Create one inactive policy, validate its Check or Check Set identity, then activate it.
5. Change one controlled record and confirm one eligible claim reaches its documented dispatch
   outcome; also verify an ineligible and a duplicate change are ignored with bounded evidence.
6. Remove the adapter before removing the preview metadata, then confirm core still evaluates the
   record normally.

Follow the [Administrator guide](ADMIN_GUIDE.md), [adapter contract](docs/ADAPTER_CONTRACT.md), and
suite [install, first-run, and uninstall checklist](../../docs/FIRST_RUN.md). Passing this preview
exercise does not unlock production use or a public package release.

## Current state

State: **implementation preview; Gate 3 (execution principal) passed on 2026-09-18**. The project
contains the policy and ledger schema, disclosure-safe event envelope, versioned claim keys, closed
routing, bulk claim intake, a package-owned dispatch event whose trigger runs as a
subscriber-configured runtime user, bounded dispatch, an operations console (outcome summary,
bounded retry of runtime failures, persisted retention settings, and an explicitly confirmed
1,000-row purge that excludes pending claims), atomic handling of immediately rejected dispatch
signals, permission sets, and contract tests. See
`docs/IMPROVEMENTS-2026-09.md` for the evidence. It deliberately packages no
object-specific CDC trigger or CDC channel membership; the adapter generator creates those as
subscriber-owned source for a named object. A package container, release language, and production
use remain blocked until the remaining feasibility gates pass.
