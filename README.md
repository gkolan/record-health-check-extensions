# Record Health Check Extensions

> **Take Record Health Check beyond the record page.**

> [!WARNING]
> **Active development:** These extensions are pre-release and may change in breaking ways without
> notice. Package contents, APIs, configuration, data models, and upgrade behavior are not yet
> stable. Use them only in development or sandbox environments, expect that updates may require
> reconfiguration or reinstallation, and do not rely on them for production workloads yet.

Record Health Check tells Salesforce users what looks good, what needs attention, and why. This
repository contains optional extensions that help administrators manage those health checks at
scale: retain diagnostic errors, run checks on a schedule, build them through a guided experience,
notify people, retain trends, start approved corrective Flows, and send outcomes to external systems.

The extensions build on the
[`record-health-check`](https://github.com/gkolan/record-health-check) core framework. Install the core package first,
then choose only the extensions your organization needs.

Each implemented extension is its own Salesforce second-generation package. An extension depends
on Record Health Check core, not on the other extensions, so adopting reporting does not require
adopting alerts, actions, integrations, or any other package. Documentation-only proposals are not
packages until their feasibility and release gates are complete.

## Choose the capability you need

| Extension | What it adds | How it can help your organization |
| --- | --- | --- |
| [RHC Logs](packages/rhc-logs/README.md) | Restricted diagnostic-event retention, investigation, and bounded cleanup | Gives approved administrators searchable technical-error evidence inside Salesforce |
| [RHC Run Manager](packages/rhc-run-manager/README.md) | No-code batch execution, scheduling, record selection, result history, and monitoring | Runs health checks across many records on demand, on a schedule, or from Flow |
| [RHC Builder](packages/rhc-builder/README.md) | Guided design, validation, versioning, publication, and rollback | Helps administrators create reliable health checks without editing individual Custom Metadata records by hand |
| [RHC Alerts](packages/rhc-alerts/README.md) | Configurable Salesforce bell notifications and email alerts for finalized outcomes | Brings important failures and operational issues to the people who need to respond |
| [RHC Change Monitor](packages/rhc-change-monitor/README.md) | CDC-driven reruns after selected record changes | Keeps selected checks current without putting CDC concerns into core; development preview |
| [RHC Reports](packages/rhc-reports/README.md) | Durable facts, daily snapshots, Salesforce reports, and a trend dashboard | Shows whether data quality and business readiness are improving over time |
| [RHC Actions](packages/rhc-actions/README.md) | Governed mapping from actionable outcomes to approved autolaunched Flows | Turns selected findings into controlled follow-up work, with manual approval by default |
| [RHC Integrations](packages/rhc-integrations/README.md) | Allow-listed outbound delivery through Named Credentials | Sends approved outcomes to external automation, monitoring, or data platforms |
| [RHC Agent Actions](packages/rhc-agent-actions/README.md) | Agentforce actions that explain findings and discover applicable Check Sets | Lets an agent tell a user which checks failed and how to fix them; source only |

## How the suite works

Record Health Check core remains the evaluation engine. It reads the Check Sets and Checks your
organization defines, evaluates Salesforce records, explains the outcome, and can publish canonical
Platform Events.

The extensions add focused capabilities around that engine:

1. **Logs** gives approved administrators durable diagnostic evidence when core encounters errors.
2. **Run Manager** evaluates rules across the records and schedule the organization chooses.
3. **Builder** helps an administrator create and safely publish rules.
4. **Alerts**, **Reports**, **Actions**, and **Integrations** can react independently to outcomes
   published by core.
5. **Change Monitor** is a CDC intake extension under feasibility development that initiates a new core evaluation
   for the durable source record after selected changes.

You can use one extension by itself or combine several. They do not read one another's data and do
not form a required installation chain.

For example, an organization could use Run Manager to check active Accounts every night, Alerts to
email the account owner when a critical issue is found, Reports to show the monthly trend, and
Actions to offer an approved remediation Flow. Another organization might install only Builder to
make Check Set authoring easier.

## What installation changes

Installing an extension adds its own Salesforce metadata, permissions, and user experience to your
org. Depending on the extension, that can include a Lightning app, setup assistant, custom objects,
permission sets, Platform Event subscribers, reports, dashboards, or administrator configuration.

Installing an extension does not replace Record Health Check core. Core continues to own record
evaluation and its public contracts. Removing one extension does not require removing the others.

Important behavior remains deliberate:

- Record Health Check core provides guidance and does not change the record being checked.
- RHC Logs retains only canonical diagnostic events that core is explicitly configured and
  permitted to publish.
- RHC Actions runs a Flow only when an administrator has configured an approved policy; manual
  approval is the default.
- RHC Integrations sends data only through routes and Named Credentials configured by an
  administrator.
- Reporting and alert coverage depends on the outcomes that core is configured to publish.

## Get started

1. [Install and configure Record Health Check core](https://github.com/gkolan/record-health-check/blob/main/docs/installation/install-and-verify.md).
2. Choose the extension that matches the outcome you need from the table above.
3. Open that extension's README to review its benefits, prerequisites, permissions, setup,
   security model, and release status.
4. Install the extension's released subscriber package version in a sandbox first.
5. Assign the packaged permission sets, complete setup, and run the documented acceptance scenario
   before using it with production data.

### Current availability

This repository includes complete package projects and documentation, but it is also the active
development home for the extension suite. A registered 2GP package container is not, by itself, an
installable release.

- **RHC Logs** has source and local validation evidence, but its first package container and
  installable package version are still pending.
- The first installable **RHC Run Manager** package version is still pending.
- **RHC Builder** has a validated beta package version for testing, but it has not been promoted or
  released.
- The first installable package versions for **Alerts, Reports, Actions, and Integrations** are
  still pending.
- **RHC Change Monitor** has a local implementation preview. Its CDC adapter, replay identity,
  execution principal, and limit gates must pass before a package container or version is created.

Do not construct an installation URL from a package-container ID. Use only an installable `04t`
subscriber package version documented by the selected extension, and confirm its current release
status before installation.

## Common ways to use the extensions

### Retain and investigate technical errors

Use **RHC Logs** to keep restricted diagnostic events searchable inside Salesforce, suppress
duplicate deliveries, monitor ingestion, and expire records with a bounded retention policy.

### Check records without opening them one at a time

Use **RHC Run Manager** for scheduled portfolio checks, bulk evaluation, monitored batch runs, or
Flow-supplied record IDs.

### Make health-check authoring easier

Use **RHC Builder** to create complete Check Sets, validate them as a unit, preserve versions,
publish deliberately, and return to an earlier validated version.

### Bring urgent findings to people

Use **RHC Alerts** when a health-check result should become a Salesforce Custom Notification under
the global bell or a plain-text email. Admins control which event types, statuses, severities, and
recipients qualify.

### Rerun checks after selected record changes

Use **RHC Change Monitor** when CDC should trigger a fresh core evaluation of the durable source
record. It is not available yet; its source exists to prove feasibility and contracts, not as an
installable or production-supported package.

### Understand change over time

Use **RHC Reports** to retain minimal reporting facts and daily snapshots, then explore trends with
native Salesforce reports and dashboards.

### Connect findings to governed remediation

Use **RHC Actions** when selected outcomes should create reviewable follow-up work or invoke a known
autolaunched Flow under explicit policies and permissions.

### Deliver approved outcomes outside Salesforce

Use **RHC Integrations** when downstream systems need health-check outcomes. Admins define
allow-listed routes and use Salesforce Named Credentials for authentication.

## Documentation

| Need | Start here |
| --- | --- |
| Compare all extension projects | [Package index](packages/README.md) |
| Install or configure one extension | The selected [package README](packages/README.md) |
| Understand package boundaries | [Package standards](docs/architecture/package-standards.md) |
| Review how the projects evolved | [Architecture stocktake](docs/architecture/stocktake.md) |
| Contribute or prepare a release | [Contributing guide](CONTRIBUTING.md) and [release gates](docs/RELEASING.md) |
| Report a security issue | [Security policy](SECURITY.md) |

The `packages/` directory contains the current independent package projects and their authoritative
documentation.

<details>
<summary><strong>For contributors and release maintainers</strong></summary>

<br />

There is intentionally no root `package.json`. Work from the package directory you are changing;
each package owns its package manifest, lockfile, Salesforce DX project, source, tests, and release
lifecycle.

```bash
git clone <repository-url>
cd record-health-check-extensions/packages/<extension>
npm ci
npm run
```

Run the validation steps documented by that package. Commit lockfiles and Salesforce metadata, but
do not commit local org state, credentials, dependencies, coverage, logs, generated analyzer output,
or temporary artifacts.

If you received the source without Git history, initialize it once from the repository root:

```bash
git init -b main
git add .
git commit -m "Initial commit"
```

</details>

## Security

Review the selected extension's security and operations documentation before installation. Never
commit or distribute Salesforce access tokens, private keys, installation keys, Named Credential
secrets, or populated environment files.

## License

Licensed under the [Apache License, Version 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
