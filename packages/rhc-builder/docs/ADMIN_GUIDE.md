# Use RHC Builder

This document explains concepts, governance, and safe operating practices. For literal UI actions
and sample values, use the [click-by-click administrator guide](CLICK_BY_CLICK_GUIDE.md). For package
setup, use [Installation and access](INSTALLATION.md).

> [!IMPORTANT]
> RHC Builder is an optional extension package. It is not part of the Record Health Check core
> package. Install a Builder release that lists your installed core package as a supported
> dependency before using this guide.

RHC Builder helps a Salesforce administrator prepare, validate, version, and publish a complete
Check Set without managing each Custom Metadata record separately. Builder never runs
Checks against business records and never changes a business record.

## Before you start

You need:

- the Record Health Check core package version required by the Builder release;
- the RHC Builder extension package;
- the **Record Health Check Builder Admin** Permission Set; and
- read access to the Salesforce objects and fields used by the Check Set.

The permission set grants the **RHC Builder Author** Custom Permission, access to the Builder tab,
and read access to Builder's private draft, version, and publication records. Administrators do not
edit those records directly. Builder performs approved saves through its Apex controller.

Open **App Launcher**, search for **RHC Builder**, and open the tab. If you see an authoring-access
message, ask a Salesforce administrator to verify the Builder Permission Set assignment. If the
page reports that the installed core package is incompatible, install a supported core and Builder
combination before continuing.

## Install and give access

An administrator with package-install permissions performs these steps. Skip this section if the
release owner has already installed Builder and assigned your access.

### Install the package

1. Confirm that the required **Record Health Check** core package is already installed:
   1. Select the gear icon, then **Setup**.
   2. In **Quick Find**, enter `Installed Packages`.
   3. Select **Installed Packages**.
   4. Find **Record Health Check** and confirm its version matches the Builder release notes.
2. Open the Builder installation link supplied by the release owner while signed in to the target
   Salesforce org.
3. If Salesforce asks for an installation key, enter the key supplied separately by the release
   owner. Do not put the key in documentation, email distribution lists, or source control.
4. Select **Install for Admins Only**. Builder authoring access is granted separately with a
   Permission Set.
5. Select **Install**.
6. Approve third-party access only if Salesforce displays a package-specific request that your
   security team has reviewed. RHC Builder itself does not call external systems.
7. Wait for the installation-complete page or Salesforce confirmation email.
8. Return to **Setup → Installed Packages** and confirm **Record Health Check Builder** appears.

### Assign the Builder Permission Set

1. In **Setup**, enter `Permission Sets` in **Quick Find**.
2. Select **Permission Sets**.
3. Select **Record Health Check Builder Admin**.
4. Select **Manage Assignments**.
5. Select **Add Assignments**.
6. Select only the approved Builder authors.
7. Select **Next**, then **Assign**.
8. Ask the author to refresh Salesforce or sign out and back in.
9. From the App Launcher, search for and select **Record Health Check Builder**.
10. Confirm the page shows the three steps **1. Design**, **2. Validate and save**, and
    **3. Publish and monitor**. If it instead says authoring access is required, recheck the
    Permission Set assignment.

## Ten-minute first Check Set

This example creates an inactive Account Check Set with one Formula Check. Use a sandbox and replace
the example wording with your approved business requirement.

### Step 1: Design

1. Open **App Launcher**.
2. Search for **Record Health Check Builder** and select it.
3. Stay on **1. Design**.
4. In **Check Set name**, enter `Account Data Quality`.
5. Confirm **Qualified API Name** becomes `Account_Data_Quality`.
   - Leave the generated name unchanged for a new Check Set.
   - If you are intentionally updating existing metadata, paste its exact Qualified API Name,
     including its namespace when present.
6. In **Target Salesforce object**, select **Account**.
7. In **When the Check Set runs**, select the option approved for your implementation. If you are
   unsure, stop and ask the Record Health Check owner; this setting controls runtime behavior.
8. In **Short explanation**, enter `Checks the minimum Account data required by our process.`
9. Select **Add Check**. A panel named **Check 1** appears and the target object becomes locked.
10. In **What should be true?**, enter `Account name is present`.
11. Confirm the Check **Qualified API Name** becomes `Account_name_is_present`.
12. In **Evaluation type**, select **Formula**.
13. In **Failure severity**, select the severity approved by your business owner.
14. In **Field**, select **Account Name** (the label may be **Name** in your org).
15. Under **Pass when the field**, select **has a value**.
16. In **Failure message**, enter `Enter an Account Name.`
17. In **How to fix it**, enter `Edit the Account and complete the Account Name field.`
18. Leave **Advanced formula** closed. Builder generates the formula for this common case.
19. Select **Continue to validation**.

What you should see: the path moves to **2. Validate and save**, and the page says validation covers
the complete Check Set Version.

### Step 2: Validate and save

1. Select **Validate complete version**.
2. Wait until the button becomes available again.
3. If a red list appears, read each field path and message, select **Back to design**, correct every
   item, and select **Continue to validation** again.
4. Repeat **Validate complete version** until the green message says Builder validation passed.
5. Leave **Advanced: exact complete-version metadata JSON** closed unless a technical reviewer asks
   for it.
6. Select **Save validated version** once.
7. Wait for the save to finish. Builder automatically opens **3. Publish and monitor**.

What you should see: **Account Data Quality — Version 1** appears in the saved-version list with one
Check. Saving does not publish or activate anything.

### Step 3: Publish inactive and monitor

1. In the row for the version you just saved, select **Review**.
2. Confirm the version number, status, Qualified API Name, Check count, and displayed fingerprint.
3. Select **Publish inactive**.
4. In **Confirm complete-version publication**, read the message and select the confirmation button.
   Cancel if you selected the wrong version.
5. Wait for Salesforce to accept the request.
6. In **Recent operations**, locate the **Publish** operation.
7. Select **Refresh status** until its status is terminal rather than queued or in progress.
8. Treat the publication as successful only when the operation reports success. An accepted request
   is not yet a completed metadata deployment.
9. Test the published inactive metadata according to your sandbox test plan.

Do not select **Activate** during this first walkthrough. Activation makes the complete Check Set and
all of its Checks active together.

> [!NOTE]
> In validated beta `0.2.0.1`, **Refresh status** is on **2. Validate and save**. Select that step,
> refresh, and return to **3. Publish and monitor** to read **Recent operations**. Current source and
> later packages place **Refresh status** directly on **3. Publish and monitor**.

## Create other common Checks

### Check that at least one related record exists

1. On **1. Design**, select **Add Check**.
2. Enter the business question, for example `Account has a Contact`.
3. In **Evaluation type**, select **Query**.
4. In **Related records**, select **Contacts**.
5. Complete **Failure severity**, **Failure message**, and **How to fix it**.
6. Leave **Advanced query settings** closed. Builder generates a bounded query that checks for one
   related record and limits the query to one row.

### Compare two queries or use Apex

These are advanced authoring paths. Obtain reviewed SOQL, field names, comparison behavior, or the
core-compatible Apex plugin name from a developer. Builder validates and versions these values but
does not prove the SOQL business logic or author Apex code.

## Follow the three steps

1. **Design** — name the Check Set, select its object, and add guided Checks. Builder generates a
   Qualified API Name from each label; edit it only when an exact existing or namespaced identity is
   required. For the common Formula path, select a readable field and whether it should contain a
   value. For the common Query path, select readable related records and Builder generates a bounded
   existence query. Raw Formula and SOQL inputs are kept under **Advanced** for expert use.
2. **Validate and save** — resolve location-specific errors, optionally inspect the exact JSON, and
   save one immutable version containing the Check Set and every Check.
3. **Publish and monitor** — review or copy a saved version, publish it inactive for testing, activate
   it deliberately, or roll back by republishing a complete older version. Confirmations explain the
   impact before Salesforce accepts the asynchronous deployment. Use **Refresh status** to retrieve
   the latest result.

Switching a Check's evaluation type does not erase answers. Only fields belonging to the selected
type are included in the complete version, so you can safely compare authoring paths.
The target object is locked after the first Check is added because generated fields and relationships
belong to that object; remove the Checks before changing it.

## Understand the complete-version model

Builder treats one Check Set and all of its Checks as a single version.

- A Check is never saved, validated, published, activated, or rolled back by itself.
- Saving creates a complete Check Set Version that cannot be changed and stores a copy of each
  Check in its selected order.
- Publishing writes the selected complete version to core Custom Metadata.
- Rolling back republishes a previously validated complete version.
- Removing Builder does not remove core Custom Metadata that was already published.

This boundary prevents a partially updated Check Set from reaching the runtime package.

## Create and validate a version

1. Enter a clear **Check Set name**.
2. Enter the exact **Qualified API Name**. Preserve a namespace when one is present; Builder does
   not add, remove, or guess namespace prefixes.
3. Select the target Salesforce object.
4. Choose when the Check Set runs and add a short explanation.
5. Add each Check in the order it should run.
6. Give each Check a business question, exact Qualified API Name, evaluation type, severity, and
   failure message.
7. Complete the fields required for Formula, Query, Compare Two Queries, or Apex.
8. Select **Validate complete version**.
9. Correct every reported error. Validation covers the entire Check Set Version.
10. Expand **Advanced: exact complete-version metadata JSON** only when a release reviewer needs to inspect
    the exact values that Builder will submit. JSON is the technical text format shown in that
    section; most administrators do not need to edit or copy it.
11. Select **Save validated version** only after validation succeeds.

For an Apex Check, Builder configures an existing Record Health Check plugin class. It does not
write, test, or approve Apex code.

## Review a saved version

The saved-version list on **3. Publish and monitor** shows the Check Set name, version number,
Qualified API Name, status, and Check count. A saved version cannot be changed. Make another
complete version when the configuration must change.

Before publication, review:

- the target object and exact Qualified API Names;
- every Check's order and evaluation type;
- formulas and queries;
- expected-value and comparison settings;
- failure severity, user message, and correction guidance; and
- any referenced Apex plugin and its parameters.

Builder validation proves that the version follows the core configuration contract. It does not
prove that the business requirement is correct. Test representative passing, failing, skipped,
unable, and error scenarios in a sandbox.

## Publish or activate

Use the action that matches the approved release step:

| Action                        | What it does                                                                 | When to use it                                                              |
| ----------------------------- | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| **Publish inactive**          | Publishes the complete version to core Custom Metadata without turning it on | Use for review and sandbox testing before activation                        |
| **Activate**                  | Publishes the complete version with its activation choice                    | Use only after review and testing are complete                              |
| **Roll back to this version** | Republishes a previously validated complete version                          | Use when an approved earlier version must replace the current configuration |

Metadata publication runs in the background. An accepted request is not the same as a completed
deployment. Review the recent operation and Salesforce Deployment Status before treating a version
as published.

### Activate an approved version

1. Open **3. Publish and monitor**.
2. Find the exact approved version and select **Review**.
3. Match its version number and fingerprint to the release approval.
4. Select **Activate**.
5. Read the confirmation and confirm only if the Check Set and every Check are ready to run.
6. In **Recent operations**, select **Refresh status** until activation reports success or failure.
7. Execute the approved runtime smoke test against representative records.

### Roll back to an earlier version

1. Open **3. Publish and monitor**.
2. Find the approved earlier version and select **Review**.
3. Verify its version number, contents, and fingerprint.
4. Select **Roll back to this version**.
5. Read the warning. Rollback republishes the whole earlier snapshot; it is not a database undo.
6. Confirm the action.
7. Select **Refresh status** until the rollback operation reports success or failure.
8. Run the rollback smoke test. Do not assume the earlier configuration is active merely because
   Salesforce accepted the request.

### Revise a saved version

A saved Check Set Version is immutable and cannot be edited in place.

1. On **3. Publish and monitor**, find the version closest to the desired configuration.
2. Select **Copy as new draft**.
3. Confirm the green message says the version was copied into a new unsaved draft.
4. Make changes on **1. Design**.
5. Select **Continue to validation**, validate the whole version, and save it.
6. Review and publish the newly numbered version through the normal release process.

## Recover from common problems

| Message or symptom                   | Meaning                                                              | What to do                                                                                       |
| ------------------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Builder authoring access is required | The user does not have the Builder Custom Permission                 | Assign **Record Health Check Builder Admin** to an approved administrator                        |
| Core package is incompatible         | The installed core metadata does not match this Builder release      | Install a supported core and Builder version combination                                         |
| Local validation errors              | Required Builder answers are missing or inconsistent                 | Correct the named fields and validate again                                                      |
| Builder validation errors            | The complete version violates a Builder authoring rule               | Follow each reported correction; do not publish around the error                                 |
| Publication remains in progress      | Salesforce accepted the Metadata request but has not completed it    | Wait, refresh the operation, and review Deployment Status                                        |
| Publication failed                   | Salesforce did not publish the complete version                      | Review the safe summary and Deployment Status, correct the cause, and retry with a new operation |
| A newer version is unsuitable        | The published configuration passed validation but should be replaced | Select an approved earlier version and use **Roll back to this version**                         |

Do not edit Builder's private records to force a status, and do not interpret an accepted
publication request as success.

## Package boundaries

- Core owns runtime Custom Metadata, evaluation, and results.
- RHC Builder owns drafts, complete saved versions, the Checks stored with each version, publication
  history, and the Builder user interface.
- RHC Builder does not schedule runs, retain runtime results, send alerts, execute corrective Flows,
  or call external systems.

## Related

- [Documentation index](README.md)
- [Click-by-click administrator guide](CLICK_BY_CLICK_GUIDE.md)
- [Installation and access](INSTALLATION.md)
- [Operations and troubleshooting](OPERATIONS.md)
- [Sandbox demo kit](../demo/README.md)
- [End-to-end demo test plan](../demo/DEMO_TEST_PLAN.md)
- [RHC Builder overview](../README.md)
- [RHC Builder specification](../SPEC.md)
- [Builder contract](BUILDER_CONTRACT.md)
- [Field mapping](FIELD_MAPPING.md)
- [Verification record](VERIFICATION.md)
