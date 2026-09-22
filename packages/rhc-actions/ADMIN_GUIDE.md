# RHC Actions administrator guide

This page is the stable entry point for Salesforce administrators. The detailed instructions are
split into focused runbooks so an administrator can stop, verify, and resume without searching one
very long page.

Last verified against source: **September 20, 2026**, RHC Actions `0.1.0.NEXT`.

## Complete first-time setup

Follow every guide in order:

1. [Install and verify the packages](docs/admin/INSTALL_AND_VERIFY.md)
2. [Assign Admin, Approver, Runtime, and Viewer access](docs/admin/ASSIGN_PERMISSIONS.md)
3. [Build and debug `Create_Data_Steward_Task`](docs/admin/BUILD_CORRECTIVE_FLOW.md)
4. [Create `Account_Has_Primary_Contact` manual policy](docs/admin/CREATE_MANUAL_POLICY.md)
5. [Run Maya's end-to-end manual approval test](docs/admin/TEST_MANUAL_APPROVAL.md)
6. [Monitor the queue and troubleshoot failures](docs/admin/MONITOR_AND_TROUBLESHOOT.md)

That monitoring guide also covers the Admin-only, explicitly confirmed retention cleanup. Agree
the retention period with legal, audit, security, and storage owners before saving it or purging.

Then run the complete sandbox demonstration:

7. [Create marked demo data and test every control](docs/admin/DEMO_DATA_AND_FULL_TEST.md)

Only after manual acceptance passes:

8. [Enable automatic execution through the security and release handoff](docs/admin/ENABLE_AUTOMATIC_EXECUTION.md)

For pausing or removal:

9. [Disable policies and uninstall safely](docs/admin/DISABLE_AND_UNINSTALL.md)

The [administrator documentation index](docs/admin/README.md) includes the expected time,
completion condition, example values, and audience for each guide.

## Example outcome

- Check: `Account_Has_Primary_Contact`
- Status: `FAIL`
- Flow: `Create_Data_Steward_Task`
- Mode: `MANUAL_APPROVAL`
- Approver: Maya

One future matching event creates one Pending Action. Maya reviews the actual Account and selects
**Run Action** once. RHC Actions validates the active Flow, queues it asynchronously, creates one
attempt record, and retains the Flow interview GUID. The example Flow creates one stewardship Task;
it does not invent a Contact or silently edit the Account.

## Non-negotiable safety facts

- Publication `NONE` produces no action.
- The health check, Platform Event delivery, approval, and Flow execution are separate transactions.
- Manual approval is the default.
- Automatic execution needs three independent controls and a release-engineer metadata handoff.
- The execution user's sharing, CRUD, FLS, Flow, Apex, queue, and record access apply.
- RHC Actions can validate Flow variables but cannot prove the Flow's internal side effects.
- Duplicate Event ID, retry, and cooldown protections must remain enabled.
- The package sends no human alerts and performs no external callouts.
- Retention cleanup is manual, terminal-only, capped at 1,000 combined rows, and never scheduled.

For the package's internal design, use the [maintainer documentation](docs/README.md).
