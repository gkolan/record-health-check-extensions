# Install and verify RHC Actions

## Audience and outcome

Use this runbook as the package installer or Salesforce administrator. At the end, core and Actions
are installed in the correct order and the RHC Actions application is visible to an administrator.

## Information to obtain before opening Salesforce

Ask the release owner for:

- target org name and whether it is a sandbox or production;
- approved Record Health Check install link and version;
- approved RHC Actions install link and version;
- installation keys, delivered separately through an approved secret channel;
- release notes and known issues; and
- change or ticket number authorizing installation.

The minimum compatible core version is Record Health Check `2.0.4.2`, subscriber package version
`04tak000000cZBFAA2`.

> [!IMPORTANT]
> The RHC Actions package container `0Hoak0000005M6LCAU` is not installable. An installable version
> must have an ID beginning `04t`. The first Actions `04t` had not been created when this source was
> documented because the Dev Hub daily version quota was exhausted.

**Stop if:** the release owner gives you only the `0Ho` container ID, cannot provide an Actions
`04t`, or cannot identify the required core version.

## Step 1: Confirm the target org

1. Sign in to Salesforce using the approved installer account.
2. Click the gear icon in the upper-right corner.
3. Click **Setup**.
4. In **Quick Find**, enter `Company Information`.
5. Click **Company Information**.
6. Record the **Salesforce.com Organization ID**, org name, and instance in the change ticket.
7. Confirm the Organization ID matches the approved target.

**What you should see:** the expected sandbox or production organization.

**Stop if:** the Organization ID does not match the change ticket. Close the install link without
continuing.

## Step 2: Check whether core is already installed

1. Stay in **Setup**.
2. In **Quick Find**, enter `Installed Packages`.
3. Click **Installed Packages**.
4. Find **Record Health Check**.
5. Record its installed version number.

**What you should see:** Record Health Check `2.0.4.2` or a later version explicitly supported by
the Actions release notes.

**Stop if:** core is missing, older than the supported minimum, or newer without an explicit
compatibility statement.

## Step 3: Install or confirm core

Skip this step only when Step 2 confirmed a supported core.

1. Open the approved core installation link in the same browser session.
2. Confirm the page names **Record Health Check** and the expected version.
3. If prompted, enter the core installation key from the approved secret channel.
4. Select **Install for Admins Only**.
5. Click **Install**.
6. If Salesforce says the installation is taking a long time, click **Done** and wait for the
   completion email.
7. Return to **Setup → Installed Packages**.
8. Confirm the core version is present.

**Why:** installing for administrators only avoids accidentally granting package metadata access to
every profile. Packaged Permission Sets grant intended access later.

## Step 4: Install RHC Actions

1. Open the approved RHC Actions installation link.
2. Confirm the page names **RHC Actions** and the approved version.
3. If prompted, enter the Actions installation key supplied separately.
4. Select **Install for Admins Only**.
5. Click **Install**.
6. Do not approve third-party access unless the release notes explicitly describe and the security
   team approves it. RHC Actions itself performs no external callouts.
7. Wait for the success page or completion email.
8. Return to **Setup → Installed Packages**.
9. Confirm **RHC Actions** appears.
10. Record the installed version in the change ticket.

**What you should see:** both packages listed, with core installed independently of Actions.

**Stop if:** Salesforce reports a dependency, component, namespace, Apex compilation, or permission
error. Save the exact installation error for the release owner; do not install another RHC
extension as a workaround.

## Step 5: Confirm the installed package contents

1. In **Setup Quick Find**, enter `Permission Sets`.
2. Click **Permission Sets**.
3. Search the list for:
   - **RHC Actions Admin**
   - **RHC Actions Approver**
   - **RHC Actions Runtime**
   - **RHC Actions Viewer**
4. In **Quick Find**, enter `Custom Permissions`.
5. Click **Custom Permissions**.
6. Confirm these entries exist:
   - **RHC Actions Approve**
   - **RHC Actions Automatic Execution**
   - **Manage RHC Actions Retention**
7. In **Quick Find**, enter `Flows`.
8. Click **Flows**.
9. Confirm installing Actions did not create a customer corrective Flow. The package deliberately
   does not ship `Create_Data_Steward_Task` because the org owns corrective business behavior.

**What you should see:** four packaged Permission Sets, three Custom Permissions, and no package-owned
business correction Flow.

## Step 6: Assign temporary setup access to the installer

If the installer is also the package administrator:

1. Open **Setup → Permission Sets**.
2. Click **RHC Actions Admin**.
3. Click **Manage Assignments**.
4. Click **Add Assignments**.
5. Select the installer user.
6. Click **Next**.
7. Click **Assign**.
8. Click **Done**.
9. Refresh the browser or sign out and in.

If duties are separated, have the access administrator perform this step for the approved package
administrator.

## Step 7: Open the application

1. Click the App Launcher nine-dot grid.
2. Click **View All** if needed.
3. Enter `RHC Actions` in **Search apps and items**.
4. Click **RHC Actions**.
5. Confirm the navigation contains:
   - **RHC Actions Review**
   - **Corrective Action Policies**
   - **Pending Actions**
   - **Action History**
6. Click each tab once and confirm it opens without an access error.

**What you should see:** an empty review queue and object tabs. An empty queue is correct before a
policy and matching future event exist.

**Stop if:** the app is missing or any tab reports insufficient access. Complete the permission
runbook before creating configuration.

## Installation acceptance checklist

- [ ] Target Organization ID matched the approved org.
- [ ] Record Health Check is at a supported version.
- [ ] RHC Actions appears under Installed Packages.
- [ ] Four packaged Permission Sets exist.
- [ ] Three packaged Custom Permissions exist.
- [ ] The RHC Actions app and four navigation items open.
- [ ] No sibling RHC extension was installed to satisfy Actions.
- [ ] Package versions and installation result are recorded in the change ticket.

Next: [Assign permissions](ASSIGN_PERMISSIONS.md).
