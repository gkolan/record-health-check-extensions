# Installation and upgrade

## Release status

The unlocked 2GP package container is `0Hoak0000005M7xCAE`. As of 2026-08-25, the first `04t`
version is pending because the Dev Hub reached its daily package-version-create limit. Do not invent
or publish an installation URL until Package validation records a successful Subscriber Package
Version ID.

## Prerequisites

- Lightning Experience.
- Record Health Check core 2.0.4.2 (`04tak000000cZBFAA2`) or a later explicitly validated version.
- A Salesforce edition that supports the packaged Apex, Platform Events, Custom Report Types,
  reports, dashboards, custom objects, Custom Settings, and scheduled/Batch/Queueable Apex.
- Capacity for the chosen Platform Event publication and data retention.
- A release administrator who can install packages and assign Permission Sets.

No RHC Run Manager, RHC Actions, RHC Alerts, RHC Integrations, or Builder dependency is required.

## Pre-install assessment

1. Record the target org ID, environment type, and current core version.
2. Confirm the target is a sandbox for first installation.
3. Estimate daily Set Run and Result event volume.
4. Approve detailed and snapshot retention.
5. Select the reporting time zone.
6. Identify administrators and viewers.
7. Confirm report/dashboard folder-sharing expectations.
8. Confirm no unrelated extension is being treated as a prerequisite.

## Install with Salesforce CLI

After Package validation publishes the real `04t`:

```bash
sf package install --package <RHC_REPORTS_04T> \
  --target-org <subscriber-alias> \
  --security-type AdminsOnly \
  --upgrade-type DeprecateOnly \
  --wait 30 --publish-wait 10 --no-prompt
```

Then verify:

```bash
sf package installed list --target-org <subscriber-alias>
```

Expected dependency order is Record Health Check, then RHC Reports. Another extension appearing in
the org does not make it a dependency; check the RHC Reports package-version dependency metadata.

## Install through the browser

When the release owner supplies an approved installation URL:

1. Confirm the URL contains the documented RHC Reports `04t` ID.
2. Log into the intended sandbox, not production.
3. Confirm the organization name shown by Salesforce.
4. Review package name, publisher, version, API access, and components.
5. Select **Install for Admins Only**.
6. Click **Install**.
7. Wait for the completion page or installation email.
8. Open Setup → Installed Packages and verify both package names and versions.

Do not select Install for All Users. RHC Reports ships Admin and Viewer Permission Sets so access can
be assigned deliberately after installation.

## Post-install sequence

1. Assign RHC Reports Admin to the setup owner.
2. Assign Viewer only to the approved reporting audience.
3. Complete [Click-by-click setup](CLICK_BY_CLICK_SETUP.md).
4. Verify one publishing Check Set in a sandbox.
5. Run the [demo data and complete functional test](DEMO_TEST_DATA.md) in the sandbox.
6. Wait for a completed-day aggregation.
7. Validate report and dashboard visibility as a Viewer.
8. Record the package/core versions, schedule owner, time zone, retention, and publication choices.

## Upgrade procedure

1. Read release notes and supported core contract before changing either package.
2. Validate in a sandbox with representative retained facts.
3. Export analytical data when the upgrade changes objects, aggregation, or retention.
4. Install the new core version first when required by dependency metadata.
5. Install the RHC Reports version with the approved upgrade type.
6. Re-run Coverage, scheduled-job, report, dashboard, duplicate Event ID, and aggregation-idempotency
   acceptance checks.
7. Confirm the existing schedule owner and time zone remain correct.

Day 1 has no compatibility layers or migrations. A future incompatible contract requires a new
explicit package design and documentation, not an undocumented alias.

## Uninstall warning

Uninstalling a package can remove package-owned metadata and data. Before considering uninstall:

1. disable publication at callers only through approved change control;
2. turn off scheduled maintenance through the assistant;
3. export Run Facts, Result Facts, Daily Snapshots, and the org setting when retention is required;
4. record report/dashboard clones that depend on package report types; and
5. test uninstall impact in a sandbox.

Do not treat uninstall as a retention or troubleshooting tool.

## Official Salesforce references

- [Install a Managed Package](https://help.salesforce.com/s/articleView?id=sf.distribution_installing_packages.htm&language=en_US&type=5) — Salesforce Help page; the review/install flow is also useful background for approved package URLs.
- [Manage Permission Set Assignments](https://help.salesforce.com/s/articleView?id=perm_sets_assigning.htm&language=en_US&type=5) — Salesforce Help page.
