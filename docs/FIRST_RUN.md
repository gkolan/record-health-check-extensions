# Install, first run, and uninstall

Use this checklist for every Record Health Check extension. The extension projects are independently
installable after core; they do not depend on one another.

> [!IMPORTANT]
> A package container ID (`0Ho...`) is not installable. Install only a documented subscriber
> package version (`04t...`). Except for a password-protected Builder beta, this repository does not
> currently publish extension `04t` versions. The source lifecycle was verified one package at a
> time in a namespaced scratch org on 2026-09-21, but that is maintainer evidence—not a public
> installation path. Do not deploy namespaced package source directly to a subscriber org.

## Before installing

1. Use a sandbox or disposable test org.
2. Install promoted Record Health Check core `2.0.4.2` (`04tak000000cZBFAA2`) or a later compatible
   version.
3. Confirm the selected extension README documents an approved `04t`. Stop if it does not.
4. Review that extension's security, operations, data-retention, and uninstall guidance.
5. Export or record any configuration that must be recreated after uninstall.

Install an approved version with Salesforce Setup or:

```bash
sf package install --package <extension-04t> --target-org <sandbox-alias> --wait 30
sf package installed list --target-org <sandbox-alias>
```

## First-run acceptance by application

| Application | Access to assign | First controlled run | Evidence of success |
| --- | --- | --- | --- |
| [Actions](../packages/rhc-actions/README.md#first-run) | `RHC_Actions_Admin`; add Approver, Runtime, and Viewer only where required | Create a contract-compliant autolaunched Flow and a manual-approval policy, publish one matching Result, then approve it | One Pending Action reaches its expected outcome and Action History identifies the actor and Flow result |
| [Agent Actions](../packages/rhc-agent-actions/README.md#first-run) | `RHC_Agent_Actions_User` plus core `Record Health Check User` | Add both actions to a test agent topic and ask it to list applicable Check Sets and explain one test record | The agent returns the applicable qualified API name and a bounded, permission-safe explanation without changing the record |
| [Alerts](../packages/rhc-alerts/README.md#first-run) | `RHC_Alerts_Admin`; Viewer Runtime for investigators | Create an inactive policy, analyze publication coverage, send the built-in test alert, then activate and publish one matching event | The intended recipient receives one message and Delivery History shows the bounded outcome without duplicate delivery |
| [Builder](../packages/rhc-builder/README.md#first-run) | `RHC_Builder_Admin` | Create a sample draft, validate and save a complete version, publish it, and verify the resulting core metadata | Publication succeeds and core evaluates a controlled record with the published Check Set |
| [Change Monitor](../packages/rhc-change-monitor/README.md#first-run) | `RHC_Change_Monitor_Admin`, Runtime, and Viewer as documented | Development preview only: generate the subscriber-owned adapter for a supported object, deploy it in a disposable org, change one controlled record, and monitor the claim | One eligible change creates a bounded claim and dispatch outcome; ineligible or duplicate changes are ignored for the documented reason |
| [Integrations](../packages/rhc-integrations/README.md#first-run) | Admin, Operator, Runtime, and Viewer by responsibility | Test the Named Credential, create an inactive allow-listed route, activate it, and publish one controlled matching event | Delivery reaches `SUCCEEDED`; retry, dead-letter, and permission-gated replay behave as documented |
| [Logs](../packages/rhc-logs/README.md#first-run) | `RHC_Logs_Admin`; Viewer only for approved support readers; core Error Log Publisher for each publishing identity | Keep cleanup disabled, enable core Log publication for one test Check Set, publish one synthetic error, and review it | Setup reports the canonical contract, one sanitized log is searchable, and Viewer cannot read restricted fields |
| [Reports](../packages/rhc-reports/README.md#first-run) | `RHC_Reports_Admin`; Viewer for report consumers | Complete Setup, publish controlled Set Run and Result events, create a daily snapshot, and open packaged reports | Facts and snapshot are deduplicated and the reports/dashboard show the controlled result |
| [Run Manager](../packages/rhc-run-manager/README.md#first-run) | Admin, Viewer, and Executor by responsibility | Create a Run Definition for a small controlled population and select **Run Now** | The monitored run completes with expected counts and only the selected result categories are retained |

Do not proceed to production merely because the first run succeeds. Complete the selected package's
full acceptance guide, including negative permissions, limits, retry, retention, and monitoring.

## Uninstall verification

1. Disable schedules, policies, routes, subscribers, or agent-topic references owned by the
   extension.
2. Export extension-owned configuration and records that must be retained. Package uninstall can
   remove package-owned data.
3. Remove permission-set assignments and subscriber-owned dependencies called out by the package.
4. Uninstall from **Setup → Installed Packages**, or use the approved `04t`:

   ```bash
   sf package uninstall --package <extension-04t> --target-org <sandbox-alias> --wait 30
   ```

5. Confirm the extension no longer appears in `sf package installed list`, its app and permission
   sets are gone, and Record Health Check core is still installed.
6. Run one core-only health check. Do not uninstall core while another installed extension depends
   on it.

The 2026-09-21 maintainer audit performed this lifecycle one extension at a time using source deploy
and validated destructive removal because public extension `04t` versions are not yet available.
All nine source projects returned to a core-only baseline after their repaired tests passed.
