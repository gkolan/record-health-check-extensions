# RHC Logs administrator guide

## Responsibilities

RHC Logs Admin configures retention, schedules cleanup, deletes expired package Logs, and sees
restricted fields. RHC Logs Viewer cannot configure or see Message, Structured Details, Record ID,
or Running User ID. Neither permission grants the core Error Log Publisher permission.

## Setup assistant

1. Open **RHC Logs → RHC Logs Setup**.
2. Confirm **Core Log event installed** and **Canonical field contract compatible**.
3. Review every visible Check Set. Publication is disabled by default.
4. For each enabled Set, identify every user, Flow runtime identity, Queueable, or integration that
   can run it. Assign core **Record Health Check Error Log Publisher** only after approval.
5. A current-user publication finding does not prove every runtime identity is covered.
6. Set Retention Days from 1 through 365 and Cleanup Batch Size from 1 through 9,998.
7. Leave automated cleanup disabled for initial acceptance. Save, ingest synthetic data, and run one
   bounded cleanup manually.
8. Enable the daily 2:00 AM job only after acceptance.

## Log review

Filter on occurrence date, severity, code, Run ID, exact Check Set developer name, exact Check
developer name, or Record ID. Core Log contract 1.0 has no Execution Source field; RHC Logs does not
infer one. Open a row through standard record navigation. Sharing, object permission, and field
access remain authoritative. Use **Load More Logs** to continue through stable keyset pages.

The Setup operations snapshot includes unsupported contract rows, ingestion outcome/error
categories, duplicate and failure counts, cleanup outcome/counts, and cleanup lease state. These
fields are package-owned and intentionally read-only even for RHC Logs Admin.

Use **Recent Logs**, **Critical Logs**, and **Requires Investigation** list views for common triage.
All current core Log events have level ERROR; the Critical view intentionally shows those errors.

## Acceptance scenario

Publish synthetic values with no production information. Verify one retained record, exact identity
preservation, duplicate suppression for the same Event ID, Viewer field restrictions, Admin
restricted-field visibility, manual cleanup below—not on—the boundary, and schedule enable/disable.

## Disable and uninstall

Disable automated cleanup and confirm the package job is absent. Clear core publication on Check Sets
that no longer require it and remove publisher/Admin/Viewer assignments. Export only approved
evidence if retention is required. Uninstall permanently removes package Logs and Settings; treat
exports as restricted. Core and other extensions remain independent.
