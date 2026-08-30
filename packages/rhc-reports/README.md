# RHC Reports

> **See how Record Health Check outcomes change over time.**

RHC Reports is an optional Salesforce extension that turns canonical Set Run and Result events into
minimal durable facts, daily snapshots, native reports, and the **Data Quality Trend** dashboard. It
adds historical and portfolio-level insight to the current guidance users see on a record page.

Reports is independently installable after Record Health Check core. It does not require Run Manager
or any other RHC extension.

## How Reports helps

Use Reports when your organization needs to answer questions such as:

- Is the failure rate improving week over week?
- Which Checks repeatedly fail?
- Where are errors or unable-to-evaluate outcomes concentrated?
- How often do records recover after a previous failure?
- Which execution sources produce the most health-check activity?
- Is core publishing enough information for the reporting coverage we expect?

The package provides report-ready facts and snapshots while deliberately excluding verbose result
details such as raw payloads, messages, found and expected values, remediation text, and stack
traces.

## How it works

1. Record Health Check core publishes canonical Set Run and Result Platform Events.
2. Reports subscribes directly to those events and deduplicates them by canonical Event ID.
3. Minimal Run and Result facts provide native reporting detail.
4. A retry-safe process creates daily snapshots using an explicit Salesforce time zone.
5. Retention settings and bounded cleanup help administrators manage storage.

Historical or unpublished outcomes cannot be reconstructed. Event delivery is asynchronous and at
least once, so run summaries and result details may arrive at different times.

## What installation adds

- the **RHC Reports** Lightning app;
- a Setup Assistant and Reporting Coverage experience;
- Run Fact, Result Fact, Daily Snapshot, and Settings objects;
- three Custom Report Types;
- six packaged Salesforce reports;
- the five-widget **Data Quality Trend** dashboard;
- Admin and Viewer permission sets; and
- event ingestion, snapshot, recovery, and retention services.

The package does not evaluate records, schedule health checks, notify users, run corrective Flows,
or call external systems.

## Publication determines coverage

| Core publication choice | What Reports can retain |
| --- | --- |
| `NONE` | Nothing; there is no reporting coverage |
| `ACTIONABLE` | Set Run summaries and failed, unable-to-evaluate, and error Result details |
| `ALL` | Set Run summaries and all Result details, including pass and skipped outcomes |

Choose publication deliberately. Broader reporting coverage creates more Platform Event traffic and
stored facts.

## Get started

1. Install the required Record Health Check core version.
2. Install an approved RHC Reports subscriber package version in a sandbox.
3. Assign `RHC_Reports_Admin` to setup owners and `RHC_Reports_Viewer` to report consumers.
4. Open the **RHC Reports** app and complete the Setup Assistant.
5. Review reporting coverage and adjust core publication where appropriate.
6. Produce controlled events, create a snapshot, and verify the packaged reports and dashboard.
7. Set retention only after reviewing storage, backup, and deletion requirements.

Follow the [click-by-click setup](docs/CLICK_BY_CLICK_SETUP.md) or the
[demo data and functional test](docs/DEMO_TEST_DATA.md).

### Current availability

The package project and registered 2GP container exist, but the first installable subscriber package
version is still pending. There is currently no documented RHC Reports `04t`. Do not construct an
installation URL from container `0Hoak0000005M7xCAE`.

See [package validation](docs/PACKAGE_VALIDATION.md) for authoritative evidence and remaining gates.

## Security and boundaries

- Reports stores the minimum fields needed for analytics rather than general result history.
- Package-owned reporting objects are governed by Admin and Viewer permission sets.
- Retention cleanup is configurable, bounded, and off until deliberately enabled.
- The package consumes canonical core events and does not read another extension's objects.
- Deleted source records may leave their former Salesforce Record ID in historical facts.
- Platform Event, storage, reporting, sharing, and retention limits still apply.

## Documentation

| Need | Start here |
| --- | --- |
| Follow exact first-time setup | [Click-by-click setup](docs/CLICK_BY_CLICK_SETUP.md) |
| Load demo data and test the package | [Demo data and functional test](docs/DEMO_TEST_DATA.md) |
| Perform routine administration | [Administrator guide](docs/ADMIN_GUIDE.md) |
| Plan installation, upgrade, or uninstall | [Installation and upgrade](docs/INSTALLATION.md) |
| Understand components and records | [Architecture and data model](docs/ARCHITECTURE_AND_DATA_MODEL.md) |
| Understand event coverage | [Event ingestion](docs/EVENT_INGESTION.md) |
| Use the reports and dashboard | [Reporting reference](docs/REPORTING_REFERENCE.md) |
| Review retention, limits, and access | [Operations and security](docs/OPERATIONS_AND_SECURITY.md) |
| Diagnose missing or incorrect data | [Troubleshooting](docs/TROUBLESHOOTING.md) |
| Review the authoritative scope | [Product specification](SPEC.md) |
| Review release readiness | [Package validation](docs/PACKAGE_VALIDATION.md) |

<details>
<summary><strong>For contributors and release maintainers</strong></summary>

<br />

This project currently has no Node package manifest. Validate Salesforce metadata, Apex, event
ingestion, reports, dashboards, security, Code Analyzer results, and clean-subscriber behavior from
this directory as documented in the [contributor guide](docs/CONTRIBUTING.md).

Package identity:

- Package: RHC Reports
- Container: `0Hoak0000005M7xCAE`
- Namespace: `rhc`
- Source line: `0.1.0.NEXT`
- Pinned core dependency: `Record Health Check@2.0.4-2`

</details>
