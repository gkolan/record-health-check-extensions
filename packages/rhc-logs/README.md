# RHC Logs

> **Retain and investigate restricted Record Health Check diagnostic events inside Salesforce.**

RHC Logs is an optional, lightweight Salesforce extension for administrators who need searchable,
time-bounded operational evidence when Record Health Check encounters a technical error. It retains
only an allow-listed, bounded subset of the canonical core Log Platform Event and requires no other
extension.

## Before you install

- Install promoted **Record Health Check 2.0.4.2** (04tak000000cZBFAA2) or later first.
- Core Log publication is off by default on every Check Set.
- Each actual running identity needs the separate core **Record Health Check Error Log Publisher**
  permission before an enabled Check Set can publish.
- Diagnostic messages, structured details, Record IDs, and User IDs are restricted operational data.
- RHC Logs does not capture Salesforce Debug Logs.

## What installation adds

- private RHC Diagnostic Log and RHC Logs Settings objects;
- direct canonical Log-event ingestion with unique Event ID duplicate suppression and transient retry;
- deliberately configured, bounded retention cleanup and one optional daily schedule;
- the RHC Logs Setup Assistant, Log Review UI, operations snapshot, and three list views;
- Admin and least-privilege Viewer permission sets; and
- Apex and LWC tests plus security, operations, troubleshooting, and development guidance.

It does not evaluate records, run or schedule health checks, retain ordinary results, notify people,
execute corrective Flows, make callouts, or access another extension.

## Get started

1. Install core and then an approved RHC Logs 04t in a sandbox.
2. Assign **RHC Logs Admin** narrowly. Assign **RHC Logs Viewer** only to approved support readers.
3. Open **RHC Logs → RHC Logs Setup**.
4. Confirm the canonical event contract is available and review which visible Check Sets publish.
5. Assign core **Record Health Check Error Log Publisher** to every approved running identity.
6. Configure Retention Days (1–365) and Cleanup Batch Size (1–9,998). A full batch continues in
   up to five bounded follow-up jobs so backlogs drain within one schedule.
7. Save with automated cleanup still disabled, publish one synthetic test error, and review it.
8. Enable the daily cleanup only after validating the boundary and permissions.
9. Follow the [administrator guide](docs/ADMINISTRATION.md) before production use.

No published Log event means there is nothing for this package to retain.

## Security model

Both objects use Private sharing. Viewer can read correlation and classification fields but cannot
read Message, Structured Diagnostic Details, Record ID, or Running User ID. Admin can review those
restricted fields and manage the three retention-policy fields. Package-owned counters, status,
singleton identity, and cleanup lease fields are read-only to Admin. Neither permission set grants
core event publication.
There is no guest/public surface, notification delivery, raw event JSON, stack trace, credential, or
Salesforce Debug Log retention.

See [Security](docs/SECURITY.md) and [Data model](docs/DATA-MODEL.md).

## Current availability

The source project exists, but no RHC Logs package container or installable subscriber package
version has been recorded yet. There is no approved RHC Logs 04t at this time. Do not describe a
future 0Ho container as installable.

Release evidence and outstanding gates are tracked in
[Development and release](docs/DEVELOPMENT.md). Package-candidate creation remains locked by the
[release gate ledger](docs/RELEASE-GATES.md); no-namespace runtime verification is still pending.

## Documentation

| Need | Start here |
| --- | --- |
| Configure and accept the package | [Administrator guide](docs/ADMINISTRATION.md) |
| Handle restricted data | [Security](docs/SECURITY.md) |
| Monitor ingestion, cleanup, storage, and limits | [Operations](docs/OPERATIONS.md) |
| Diagnose missing or duplicate logs | [Troubleshooting](docs/TROUBLESHOOTING.md) |
| Understand stored and excluded fields | [Data model](docs/DATA-MODEL.md) |
| Build, test, analyze, package, install, and uninstall | [Development](docs/DEVELOPMENT.md) |
| Decide whether candidate creation is unlocked | [Release gate ledger](docs/RELEASE-GATES.md) |
| Record machine-verifiable pre-package evidence | [Pre-package evidence](docs/PREPACKAGE-EVIDENCE.md) |
| Review static-analysis exceptions | [Code Analyzer suppressions](docs/CODE-ANALYZER-SUPPRESSIONS.md) |
| Review core-contract sufficiency | [Core event gap analysis](docs/CORE-EVENT-GAP-ANALYSIS.md) |
| Review authoritative scope | [Specification](SPEC.md) |
