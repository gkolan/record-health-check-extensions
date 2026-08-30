# RHC Run Manager

> **Run Record Health Check across the records and schedule your organization chooses.**

RHC Run Manager is an optional Salesforce extension for no-code batch execution, scheduling,
selected result history, and operational monitoring. It moves health checks beyond one record page
by helping administrators evaluate a portfolio of records on demand, on a human-readable schedule,
or from Flow.

Run Manager is independently installable after Record Health Check core. It does not require
Builder, Alerts, Reports, Actions, Integrations, or any other extension.

## How Run Manager helps

Use Run Manager when your organization needs to:

- evaluate all accessible records for a selected Check Set or Check;
- select records with a guided filter instead of writing raw SOQL;
- accept record IDs from a Flow and combine related requests efficiently;
- run checks now or on a schedule with optional start and end dates;
- monitor batch jobs, independently committed scope runs, counts, and failures; or
- retain the result statuses selected by the administrator.

A common example is checking all active Accounts each night, or submitting an Account ID whenever a
related Contact changes.

## How it works

All three launch sources use the same validated execution service:

```text
Run Now ───────────────┐
Human Schedule ────────┼─> execution service ─> owned Batch ─> core evaluation
Flow-supplied IDs ─────┘                         └─> monitoring and selected history
```

Administrators select active core metadata through a picker. Run Manager resolves the target object
from that metadata and controls population, batch size, schedule, and capture mode. They do not enter
an object API name, raw SOQL, CRON expression, namespace, or Apex Batch class.

Record Health Check core still performs every evaluation. Run Manager owns orchestration and the
operational records used to monitor its work.

## What installation adds

- the **RHC Run Manager** Lightning app and guided workspace;
- Run Definition, Schedule, Batch Run, scope Run, Result, and Flow Request objects;
- Admin, Viewer, and Executor permission sets;
- batch, scheduling, coalescing, and monitoring services; and
- the packaged Flow action for submitting target record IDs.

## Get started

1. Install the required Record Health Check core version.
2. Install an approved RHC Run Manager subscriber package version in a sandbox.
3. Assign `RHC_Run_Manager_Admin` to administrators, `RHC_Run_Manager_Viewer` to read-only
   operators, and `RHC_Run_Manager_Executor` to users whose Flows submit IDs.
4. Open the **RHC Run Manager** Lightning app.
5. Create a Run Definition, choose its population and capture mode, then use **Run Now**.
6. Add a schedule or Flow entry point after the first monitored run succeeds.

Experienced administrators can use [installation and first-time setup](docs/INSTALLATION.md).
For a complete guided exercise, follow the [Administrator Guide](ADMIN_GUIDE.md) and
[demo guide](docs/DEMO_GUIDE.md).

### Current availability

The package project and registered 2GP container exist, but the first beta subscriber package
version is still pending. There is currently no documented installable `04t` version. Do not treat
the container ID as an installation ID.

See [release evidence](RELEASE_EVIDENCE.md) for the authoritative status.

## Population and result choices

- **All accessible** evaluates target records visible to the running user.
- **Guided filtered** stores validated field, operator, and value choices and uses bind variables.
- **Supplied IDs** accepts Flow inputs and combines committed requests before launching a Batch.
- **Pass** retains passing details.
- **Fail** retains failed, unable-to-evaluate, and error details.
- **Both** retains both groups. Skipped results are counted but are not retained in detail.

## Security and boundaries

- Target-record and operational-data access is enforced in Salesforce user mode.
- Guided filters expose only accessible described fields and supported operators.
- Flow-supplied IDs are validated, deduplicated, and durably staged.
- Run Manager does not accept customer-owned Batch classes or arbitrary SOQL.
- It depends only on Record Health Check core and does not read another extension's objects.
- Other independently installed extensions react to canonical events from core, not to Run Manager
  internals.

## Documentation

| Need | Start here |
| --- | --- |
| Install and assign access | [Installation and first-time setup](docs/INSTALLATION.md) |
| Configure the app step by step | [Administrator Guide](ADMIN_GUIDE.md) |
| Build a related-record Flow | [Flow guide](docs/FLOW_GUIDE.md) |
| Load demo data and test each mode | [Demo guide](docs/DEMO_GUIDE.md) |
| Monitor jobs and handle failures | [Operations runbook](docs/OPERATIONS.md) |
| Understand objects and fields | [Data dictionary](docs/DATA_DICTIONARY.md) |
| Understand execution and security | [Architecture](docs/ARCHITECTURE.md) |
| Review the authoritative scope | [Product specification](SPEC.md) |
| Review package readiness | [Release evidence](RELEASE_EVIDENCE.md) |

<details>
<summary><strong>For contributors and release maintainers</strong></summary>

<br />

```bash
npm ci
npm test
npx @salesforce-ux/slds-linter@latest lint force-app/main/default/lwc/rhcRunManager
sf code-analyzer run --rule-selector Recommended --target force-app/main/default
```

Follow the [development guide](docs/DEVELOPMENT.md) for Apex validation, package creation, and
clean-subscriber acceptance.

Package identity:

- Package: RHC Run Manager
- Container: `0Hoak0000005FhZCAU`
- Namespace: `rhc`
- Source line: `0.1.0.NEXT`
- Pinned core dependency: `Record Health Check@2.0.4-2`

</details>
