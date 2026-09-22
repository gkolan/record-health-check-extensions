# Installation and first-time setup

This guide is for a Salesforce administrator installing a released RHC Run Manager beta. Replace
`<RUN_MANAGER_04T_ID>` with the subscriber package version ID provided in the release notes.

## Before installation

1. Confirm you are installing in a sandbox or approved test org before production.
2. Confirm Record Health Check core `2.0.4-2` is installed.
3. Confirm you have **Download AppExchange Packages** or equivalent package-install authority.
4. Record which users will be Administrators, Viewers, and Flow Executors.
5. Confirm active core Check Sets/Checks exist for the objects you intend to evaluate.

Run Manager does not require Builder, Alerts, Reports, Actions, or Integrations.

## Install with Salesforce Setup

1. Sign in to the target Salesforce org.
2. Paste this pattern into the browser address bar after the Salesforce domain:

   ```text
   /packaging/installPackage.apexp?p0=<RUN_MANAGER_04T_ID>
   ```

3. Press **Enter**.
4. On **Install RHC Run Manager**, confirm the package name and version match the release notes.
5. Choose **Install for Admins Only**. Access will be granted with packaged permission sets.
6. Select **I acknowledge that I'm installing a Non-Salesforce Application** if Salesforce displays
   that acknowledgement.
7. Click **Install**.
8. Wait for **Installation Complete**. If Salesforce says installation is taking a long time, click
   **Done** and wait for the completion email.

## Install with Salesforce CLI

Release engineers can use:

```bash
sf package install \
  --package <RUN_MANAGER_04T_ID> \
  --target-org <subscriber-alias> \
  --wait 20 \
  --publish-wait 20 \
  --no-prompt \
  --security-type AdminsOnly \
  --json
```

## Confirm installed packages

1. Click **gear → Setup**.
2. Enter `Installed Packages` in **Quick Find**.
3. Click **Installed Packages**.
4. Confirm **Record Health Check** shows version `2.0.4.2`.
5. Confirm **RHC Run Manager** shows the beta version from the release notes.
6. For a clean-install test, confirm no other RHC extension is installed.

CLI equivalent:

```bash
sf package installed list --target-org <subscriber-alias> --json
```

## Assign permissions click by click

Repeat these steps for each persona:

1. In Setup, enter `Permission Sets` in **Quick Find**.
2. Click **Permission Sets**.
3. Click the permission-set label.
4. Click **Manage Assignments**.
5. Click **Add Assignments**.
6. Select the users.
7. Click **Next**.
8. Click **Assign**.
9. Click **Done**.

Assignments:

| User job | Run Manager permission | Typical core permission |
| --- | --- | --- |
| Configures definitions/schedules | RHC Run Manager Admin | Record Health Check Admin |
| Monitors without changing setup | RHC Run Manager Viewer | Core read/user access appropriate to role |
| Runs record-triggered supplied-ID Flow | RHC Run Manager Executor | Core evaluation/data access appropriate to automation user |

Do not assign Admin to every Flow user. Executor exists specifically to avoid that.

## Verify the app

Administrators should see the **Retention** tab because `RHC_Run_Manager_Admin` includes the
`RHC_Run_Manager_Manage_Retention` custom permission and settings/delete access. Viewer and Executor
users must not see retention controls and must not receive delete access.

1. Leave Setup.
2. Click the **App Launcher**.
3. Enter `RHC Run Manager`.
4. Click **RHC Run Manager**.
5. Confirm the page loads without an access error.
6. Confirm these tabs appear inside the card:
   **1. Run Definitions**, **2. Schedules**, and **3. Monitoring**. An Admin also sees
   **4. Retention**; Viewer and Executor users do not.
7. Open **1. Run Definitions**.
8. Choose **Check Set** and confirm active core Check Sets appear in the picker.
9. Select one and confirm **Target object: ...** appears.

If the app or picker is empty, see [Operations troubleshooting](OPERATIONS.md#installation-and-access).

## First controlled validation

Before creating a broad production definition:

1. Choose a Check Set for a familiar object.
2. Choose **Guided Filtered**.
3. Add a filter that selects one known test record.
4. Use Batch Size `1` and Capture Mode **Both**.
5. Save and choose **Run now**.
6. Open Monitoring and confirm Batch Run → scope Run → retained Results.
7. Deactivate or edit the definition after validation.

Then follow the full [Administrator Guide](../ADMIN_GUIDE.md).

## Upgrade and uninstall safety

Before an upgrade, export operational records required by your retention policy and pause broad
automation changes. Run Manager upgrades do not perform background data cleanup; the external-ID
keys on Runs, Results, and Requests preserve retry/idempotency behavior across compatible upgrades.

Before uninstall, export any Run Manager history that must be retained. The configured package
uninstall handler aborts only active jobs owned by `RHCRunManagerBatch`,
`RHCRunManagerCoalescerQueueable`, and scheduled jobs whose names begin `RHC Run Manager `. It does
not abort customer-owned schedules or asynchronous Apex. Package uninstall can remove packaged
metadata and data, so the export is the recovery boundary.
