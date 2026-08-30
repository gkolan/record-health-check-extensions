# Installation and access

This guide is for the Salesforce administrator who installs RHC Builder and grants authoring access.
Complete it in a sandbox before installing in production.

## What you need before installation

- A Salesforce user allowed to install packages and assign Permission Sets.
- The target org's My Domain URL and intended sandbox or production environment.
- Record Health Check core version `2.0.4-2`, subscriber package version
  `04tak000000cZBFAA2`.
- The RHC Builder installation URL and installation key from the release owner.
- RHC Builder beta `0.2.0.1`, subscriber package version `04tak000000ckt3AAA`, if validating the
  currently recorded beta.
- A list of approved Builder authors.

RHC Builder depends only on Record Health Check core. It must not require another extension.

## 1. Confirm the core package

1. Sign in to the target Salesforce org.
2. Select the gear icon in the upper-right corner.
3. Select **Setup**.
4. In the left **Quick Find** box, enter `Installed Packages`.
5. Select **Installed Packages**.
6. Find **Record Health Check**.
7. Confirm the installed version is the version required above.
8. If core is missing or has a different version, stop. Install or upgrade the supported core
   version before Builder.

Expected result: **Record Health Check** appears in Installed Packages. Core continues to work with
or without Builder.

## 2. Install RHC Builder

1. Open the Builder installation URL while signed in to the intended target org.
2. Confirm the page names **Record Health Check Builder** and the intended version.
3. Verify the browser address belongs to the correct Salesforce org. Do not continue in the wrong
   sandbox or production org.
4. Enter the installation key supplied through the approved secure channel.
5. Select **Install for Admins Only**.
6. Select **Install**.
7. If Salesforce displays an external-access approval, stop and have it reviewed. Builder itself
   does not call external systems, so an unexpected request should be investigated.
8. Wait for **Installation Complete**. Large-org installations may finish asynchronously and send
   an email.
9. Return to **Setup → Installed Packages**.
10. Confirm **Record Health Check Builder** appears with the expected version.

Expected result: both core and Builder appear as separate installed packages. Uninstalling Builder
later does not remove core runtime Custom Metadata already published by Builder.

## 3. Assign authoring access

1. In Setup **Quick Find**, enter `Permission Sets`.
2. Select **Permission Sets**.
3. Select **Record Health Check Builder Admin**.
4. Select **Manage Assignments**.
5. Select **Add Assignments**.
6. Select the checkbox beside each approved Builder author.
7. Select **Next**.
8. Select **Assign**.
9. Select **Done**.
10. Ask each author to refresh Salesforce or sign out and back in.

The Permission Set grants:

- the **RHC Builder Author** Custom Permission;
- visibility to the **Record Health Check Builder** tab;
- access to the Builder controller; and
- read-only visibility to Builder draft, version, Check snapshot, and deployment-ledger records.

Authors do not edit those records directly. Builder performs controlled writes through Apex after
checking the Custom Permission.

## 4. Verify the user experience

1. Sign in as an assigned author or use **Login As** according to your organization's policy.
2. Select the App Launcher grid.
3. Enter `Record Health Check Builder` in the search box.
4. Select **Record Health Check Builder**.
5. Confirm the page title is **RHC Builder**.
6. Confirm the path shows:
   1. **1. Design**
   2. **2. Validate and save**
   3. **3. Publish and monitor**
7. Confirm **Target Salesforce object** contains objects the user can read.
8. Do not create production configuration as an installation test. Continue with the sandbox
   walkthrough in the [click-by-click guide](CLICK_BY_CLICK_GUIDE.md).

## Installation troubleshooting

| What you see                 | Likely reason                                             | Exact next action                                                     |
| ---------------------------- | --------------------------------------------------------- | --------------------------------------------------------------------- |
| Core dependency error        | Required core is missing or incompatible                  | Return to Installed Packages and install the pinned core first        |
| Installation key rejected    | Wrong key or whitespace was included                      | Obtain the key again from the release owner and paste it exactly      |
| Authoring access is required | Permission Set is not effective                           | Recheck **Manage Assignments**, then refresh or sign in again         |
| Builder tab is not found     | Tab permission has not refreshed                          | Confirm the Permission Set, then use App Launcher search again        |
| No target objects appear     | The author lacks readable/queryable object access         | Review profile, Permission Sets, licenses, and object access          |
| Core package is incompatible | Installed schema does not match Builder's pinned contract | Install a supported core/Builder combination; do not bypass the error |

## Remove access or uninstall

To remove one author's access, open **Record Health Check Builder Admin → Manage Assignments**, select
the user, and select **Remove Assignments**.

Before uninstalling Builder:

1. Export or record any version and operation history required by your audit policy.
2. Confirm which core Custom Metadata is currently published.
3. Understand that uninstalling Builder removes Builder-owned draft/version history but does not
   remove published core configuration.
4. Test the uninstall in a sandbox.
5. Confirm core runtime behavior still works independently.
