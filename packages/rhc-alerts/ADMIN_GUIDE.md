# RHC Alerts junior administrator guide

Last verified: **August 25, 2026**, against RHC Alerts `0.1.0` in Salesforce Lightning Experience.

This is a click-by-click guide for an administrator who uses Salesforce Setup but does not write
code. Complete the first configuration in a sandbox. Every procedure includes a **screen checkpoint**
so you know what should be visible before continuing.

## What this guide builds

The worked example creates this policy:

| Setting              | Example                                                                                                                      |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Policy name          | `Opportunity next-step alerts — Sales Operations`                                                                            |
| Selection type       | Check                                                                                                                        |
| Qualified API Name   | Select the installed core example **Example: Deal Readiness - Next Step**; typically `rhc__Example_Opportunity_DR_Next_Step` |
| Matching statuses    | FAIL, UNABLE TO EVALUATE, ERROR                                                                                              |
| Minimum severity     | WARNING                                                                                                                      |
| Recipient type       | Public Group                                                                                                                 |
| Recipient            | Sales Operations                                                                                                             |
| Notification channel | Salesforce notification (bell)                                                                                               |
| Cooldown             | 1,440 minutes (24 hours)                                                                                                     |
| Active               | On after review                                                                                                              |

When core publishes a matching Result event, direct active User members of the Sales Operations
public group receive one notification. Re-delivery of the same Event ID does not notify them again.
A later matching event for the same Opportunity inside 24 hours is recorded as suppressed.

RHC Alerts does not run the Check, change the Opportunity, retain the result payload, or send a
webhook.

## Roles in this guide

| Role                     | Example person           | Responsibility                                                                        |
| ------------------------ | ------------------------ | ------------------------------------------------------------------------------------- |
| Release administrator    | Alex                     | Installs promoted package versions and confirms dependency/version status             |
| RHC Alerts administrator | Maya                     | Enables publication, creates policies, runs setup analysis, and investigates delivery |
| Read-only viewer         | Jordan                   | Reviews delivery outcomes but cannot change policies or ledger rows                   |
| Recipient                | Sales Operations members | Receives the human notification using existing Salesforce access                      |
| Automation owner         | Flow/Apex owner          | Ensures programmatic health-check callers request `ACTIONABLE` or `ALL` publication   |

One person can hold more than one role, but keep permission assignments aligned to job
responsibilities.

## Terms you will see

- **Check**: one Record Health Check definition, such as the installed example
  `rhc__Example_Opportunity_DR_Next_Step`.
- **Check Set**: an ordered group of Checks.
- **Qualified API Name**: the exact core identity. A managed Check can look like
  `partnerpkg__Opportunity_Has_Primary_Contact`. The namespace is part of the identity.
- **Result event**: the canonical finalized Check outcome that carries status and severity.
- **Set Run event**: a completion summary. Contract `1.0` does not carry canonical aggregate
  severity, so it cannot directly produce a human alert.
- **Policy**: the administrator-approved matching, recipient, channel, and cooldown configuration.
- **Delivery**: one operational claim or duplicate-evidence row for one Event ID and policy.
- **Cooldown**: the quiet period after a successful delivery for the same policy and checked record.

## Before you start

Ask Alex to confirm these prerequisites:

- Record Health Check core `2.0.4-2` or a documented compatible later version is installed.
- An installable RHC Alerts version is installed after core.
- No RHC Run Manager, Reports, Actions, Integrations, or Builder package is required.
- You are in a sandbox for the first test.
- You have **Customize Application** and permission-set assignment authority, or another admin is
  available to perform those Setup steps.
- You know a safe test record and can intentionally produce a matching result.
- Email deliverability is understood if you plan to test Email.

### Confirm the installed packages

1. Sign in to the sandbox.
2. Click the **gear** icon in the upper-right corner.
3. Click **Setup**.
4. In the left **Quick Find** box, enter `Installed Packages`.
5. Click **Installed Packages**.
6. Find **Record Health Check**.
7. Confirm its installed version is the approved core baseline.
8. Find **RHC Alerts**.
9. If either package is missing, stop. Ask Alex for the approved installation link.

**Screen checkpoint:** The Installed Packages list contains Record Health Check and RHC Alerts.
Nothing in this guide requires another RHC extension.

> Development status: the RHC Alerts package container exists, but as of the verification date a
> final `04t` subscriber version is still pending the Dev Hub daily version-create allowance. Do not
> install unpackaged source into production as a substitute.

## Optional: ask the release administrator to load the sandbox demo

If you do not already have a safe Check, record, recipients, and policy, use the packaged repository
demo instead of inventing test data. The demo creates an Account and Opportunity whose names begin
`[RHC Alerts Demo]`, two public groups, and four clearly labeled policies. Email remains off until a
separate opt-in step.

Give the release administrator this guide:

- [Sandbox demo and acceptance guide](demo/README.md)
- [Complete capability test matrix](demo/TEST_MATRIX.md)

After the release administrator runs demo scripts 01 and 02, return to this guide. You can perform
all Salesforce screen checks yourself. The demo guide then tells the release administrator exactly
which event script to run before each screen check and tells you the exact delivery rows to expect.
It covers success, duplicate Event IDs, cooldown, empty-recipient failure, non-matching identity,
status and severity, optional Email, the Set Run contract limitation, publication NONE, viewer
access, safe message content, and limits.

**Do not run the demo in production.** It creates records and scripts 03 through 07 invoke the real
asynchronous delivery path. Script 06 can send a real email.

## Step 1: Assign RHC Alerts access

RHC Alerts includes two permission sets.

| Permission set label          | Assign to                             | What it permits                                                                                                                                          |
| ----------------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **RHC Alerts Admin**          | Maya and package configuration owners | Open the app, create/change policies, run setup analysis, and read all package delivery rows                                                             |
| **RHC Alerts Viewer Runtime** | Jordan, auditors, and support viewers | Open only bounded Delivery History; policy display name and reviewed delivery fields are read-only, with no recipient-directory or generic object access |

Neither permission set grants access to Opportunity, Account, Case, or any other checked business
record. Existing sharing, profile, and permission-set access still applies.

### Assign RHC Alerts Admin to Maya

1. From **Setup**, enter `Permission Sets` in **Quick Find**.
2. Click **Permission Sets**.
3. In the permission-set list, click **RHC Alerts Admin**.
4. Click **Manage Assignments**.
5. Click **Add Assignments**.
6. Select the checkbox beside Maya's name.
7. Click **Next**.
8. Select **No expiration date** unless your access policy requires an expiration.
9. Click **Assign**.
10. Click **Done**.

**Screen checkpoint:** Maya appears on the Current Assignments page for RHC Alerts Admin.

### Assign the read-only permission set to Jordan

1. Return to **Setup → Permission Sets**.
2. Click **RHC Alerts Viewer Runtime**.
3. Click **Manage Assignments**.
4. Click **Add Assignments**.
5. Select Jordan.
6. Click **Next**.
7. Choose the approved expiration option.
8. Click **Assign**, then **Done**.

**Screen checkpoint:** Jordan appears under Current Assignments. Jordan does not need RHC Alerts
Admin; Admin already includes history access and should not be assigned merely for viewing.

If a newly assigned user cannot find the app, ask them to refresh the browser. If necessary, sign
out and back in so Lightning navigation permissions refresh.

## Step 2: Create or verify the recipient public group

Skip this step if the policy sends to one User. The example uses the Sales Operations public group.

1. In **Setup**, enter `Public Groups` in **Quick Find**.
2. Click **Public Groups**.
3. Look for **Sales Operations**.
4. If it exists, click the group label and review its members.
5. If it does not exist, return to the Public Groups list and click **New**.
6. For **Label**, enter `Sales Operations`.
7. Keep the automatically generated Group Name unless your naming standard requires another value.
8. In the member search controls, choose **Users**.
9. Select the intended active human Users.
10. Click **Add** so they appear in **Selected Members**.
11. Click **Save**.

**Screen checkpoint:** Sales Operations is a regular public group and its Selected Members include
the intended Users.

Important group behavior:

- RHC Alerts sends only to direct active User members.
- Nested public groups are not expanded.
- Roles, Roles and Subordinates, queues, portal groups, and inactive Users are not recipients.
- A group with no direct active Users produces `FAILED / CONFIGURATION /
NO_DIRECT_ACTIVE_USERS`.
- Custom Notification allows at most 500 resolved recipients per attempt; Email allows 10.

## Step 3: Enable core Result event publication

This step determines whether RHC Alerts can observe a health-check outcome. If core publishes no
Result event, Alerts creates no delivery row and sends no message.

### Interactive runs: a person clicks Run or Rerun

1. In **Setup**, enter `Custom Metadata Types` in **Quick Find**.
2. Click **Custom Metadata Types**.
3. Find the core type labeled **Record Health Check**.
4. Click **Manage Records** beside Record Health Check.
5. Find the Check used by the policy. For the example, find the record labeled
   **Example: Deal Readiness - Next Step**. In an installed namespaced org its Qualified API Name is
   typically `rhc__Example_Opportunity_DR_Next_Step`.
6. Click **Edit** beside that Check.
7. Find **Publish User Result Event**.
8. Select **Publish User Result Event**.
9. Confirm the Check and its parent Check Set are active according to your core configuration.
10. Click **Save**.

**Screen checkpoint:** The Check record displays **Publish User Result Event** as selected.

### Check Set policies need publication on every active Check

If your policy uses Selection type **Check Set**:

1. List every active Check in that Check Set.
2. Open the first Check from **Custom Metadata Types → Record Health Check → Manage Records**.
3. Select **Publish User Result Event** and save.
4. Repeat for every active Check in that set.

Selecting **Publish User Run Event** on the Check Set alone is not sufficient. That setting publishes
the Set Run summary, but contract `1.0` has no canonical severity. Alerts uses each Result event for
Check Set status and severity matching.

### Programmatic runs: Flow, Apex, Batch, Queueable, or Scheduled

There is no Setup checkbox that can force every programmatic caller to publish. Give this exact
request to the automation owner:

> Confirm this Record Health Check request uses publication mode `ACTIONABLE` or `ALL`. Do not use
> `NONE` for a run expected to produce RHC Alerts.

- `NONE`: no Result event, no delivery row, no alert.
- `ACTIONABLE`: core publishes outcomes defined as actionable by its contract.
- `ALL`: core publishes all eligible finalized outcomes.

Record the chosen mode in the automation's design documentation. The Alerts setup assistant can warn
about this choice but cannot inspect a runtime request after the fact.

## Step 4: Open and tour the RHC Alerts app

1. Leave Setup and return to Lightning Experience.
2. Click the **App Launcher** (the nine-dot grid).
3. Click **View All** if needed.
4. Enter `RHC Alerts` in **Search apps and items**.
5. Click **RHC Alerts**.
6. Click the **RHC Alerts Administration** navigation tab.

**Screen checkpoint:** A card titled **RHC Alerts administration** appears. It contains:

1. Introductory text explaining that Alerts is human-only and does not change checked records.
2. A yellow limits banner.
3. The policy form.
4. **Save policy** and **Analyze publication coverage** buttons.
5. **Existing policies** after at least one policy exists. Each row's menu offers **Send test
   alert to me**, which sends one synthetic alert through the policy's channel to you only; it is
   not recorded in Delivery History and does not contact the policy's recipients.
6. **Setup assistant** findings after analysis finds one or more items.

The yellow banner should show:

- Custom Notifications: 500 recipients per send.
- Email: 10 recipients per attempt.
- Retries: 3.
- Instructions to review **Setup → Company Information** and **Setup → Deliverability** for live org
  allocations.

If the page shows **RHC Alerts could not load**:

1. Confirm Maya has RHC Alerts Admin.
2. Refresh the page.
3. Confirm core and Alerts versions are installed.
4. Confirm the packaged permission metadata deployed successfully.
5. Ask Alex to review browser console/Apex failures only after the permission checks.

## Step 5: Create the worked example policy

Complete the form from top to bottom. Do not use the browser Back button while the spinner is visible.

### 5A. Policy name

1. Click **Policy name**.
2. Enter `Opportunity next-step alerts — Sales Operations`.

Use a name that answers three questions: what condition, what record/process, and who receives it.
Avoid names such as `Test`, `Alert 1`, or `Critical` that become ambiguous in delivery history.

### 5B. Active

1. In a sandbox, leave **Active** on for this controlled example.
2. In production, keep Active off until the approved change window if live matching events could
   arrive during setup.

An inactive policy is not evaluated by the subscriber and is not included in setup-assistant
coverage analysis. To validate a production policy, activate it during the change window, run the
assistant immediately, and deactivate it again if an ERROR or WARNING must be fixed.

### 5C. Selection type

1. Click **Selection type**.
2. Select **Check**.

Choose **Check Set** only when the same audience, channel, statuses, severity, and cooldown should
apply to matching Result events from all active Checks in one set.

Changing Selection type clears the current Qualified API Name and reloads the correct picker.

### 5D. Qualified API name

1. Click **Qualified API name**.
2. Search or scroll for the row labeled with the intended Check and its exact API identity.
3. Select **Example: Deal Readiness - Next Step** and preserve the exact Qualified API Name shown by
   the picker. In an installed namespaced org it is typically
   `rhc__Example_Opportunity_DR_Next_Step`.

The list contains active definitions from core. RHC Alerts stores the exact value. For a namespaced
Check, select the prefixed value such as `partnerpkg__Opportunity_Has_Primary_Contact`; never remove
or add the prefix.

If the expected Check is absent:

1. Confirm the Check and parent Check Set are active in core.
2. Confirm you selected the correct Selection type.
3. Refresh the Alerts Administration page.
4. Do not type a substitute or choose a similarly named Check.

### 5E. Matching statuses

The left list is **Available** and the right list is **Selected**.

1. Select **FAIL** under Available.
2. Move it to Selected using the right-arrow control.
3. Select **UNABLE TO EVALUATE** and move it to Selected.
4. Select **ERROR** and move it to Selected.
5. Remove **PASS** or **SKIPPED** unless the business explicitly wants healthy or skipped outcome
   notifications.

Canonical meanings:

| Status               | Meaning                                                              | Common alert use                                                   |
| -------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `PASS`               | Check succeeded                                                      | Usually not selected; useful for recovery or confirmation policies |
| `FAIL`               | Business condition failed                                            | Commonly selected                                                  |
| `SKIPPED`            | Check was deliberately not evaluated                                 | Select only when skipped evaluation needs human attention          |
| `UNABLE_TO_EVALUATE` | Required facts were unavailable or evaluation could not be completed | Commonly selected                                                  |
| `ERROR`              | Framework/system evaluation error                                    | Commonly selected                                                  |

At least one status must remain under Selected.

### 5F. Minimum severity

1. Click **Minimum severity**.
2. Select **WARNING** for the example.

| Choice   | Matches when event severity is present |
| -------- | -------------------------------------- |
| INFO     | INFO, WARNING, or CRITICAL             |
| WARNING  | WARNING or CRITICAL                    |
| CRITICAL | CRITICAL only                          |

When a canonical event legitimately has no severity, status remains the governing filter. Do not use
Minimum severity as a replacement for Matching statuses.

### 5G. Notification channel

1. Click **Notification channel**.
2. Select **Salesforce notification (bell)**.

Channel behavior:

- **Salesforce notification (bell)**: a Custom Notification that appears under the notification bell and can appear in the
  Salesforce mobile app. If a valid checked record ID is present, selecting the notification targets
  that record; Salesforce still enforces record access.
- **Email**: sends a plain-text Salesforce email to each resolved User. It does not create an
  activity and is subject to deliverability and daily email allocations.

The message includes only exact Check/Check Set identity, status, and severity when present. It does
not include raw payload, found/expected values, checked-record ID text, exception message, restricted
detail, or stack trace.

### 5H. Recipient type and recipient

1. Click **Recipient type**.
2. Select **Public Group**.
3. Wait for the Recipient picker to reload.
4. Click **Recipient**.
5. Select **Sales Operations**.

Changing Recipient type clears the previous recipient. For a one-person alert, select **User**, then
select one active User from the picker.

### 5I. Cooldown minutes

1. Click **Cooldown minutes**.
2. Enter `1440`.

The cooldown applies to successful delivery for the same policy and checked record:

| Minutes | Quiet period                                                |
| ------: | ----------------------------------------------------------- |
|     `0` | No cooldown; every later distinct matching event can notify |
|    `15` | 15 minutes                                                  |
|    `60` | 1 hour                                                      |
|   `480` | 8 hours                                                     |
|  `1440` | 24 hours                                                    |
| `10080` | 7 days                                                      |

A duplicate Event ID is blocked independently of cooldown. If an event contains no Record ID, the
cooldown is effectively policy-wide because all such events use the `NO_RECORD` correlation key.

### 5J. Review and save

Before saving, compare your screen with this table:

| Field                | Expected value                                             |
| -------------------- | ---------------------------------------------------------- |
| Policy name          | Opportunity next-step alerts — Sales Operations            |
| Active               | On in sandbox                                              |
| Selection type       | Check                                                      |
| Qualified API name   | Exact picker value for Example: Deal Readiness - Next Step |
| Matching statuses    | FAIL; UNABLE TO EVALUATE; ERROR                            |
| Minimum severity     | WARNING                                                    |
| Notification channel | Salesforce notification (bell)                             |
| Recipient type       | Public Group                                               |
| Recipient            | Sales Operations                                           |
| Cooldown minutes     | 1440                                                       |

1. Click **Save policy** once.
2. Wait for the spinner to disappear.
3. Confirm the green toast titled **Policy saved**.
4. Read the message: **RHC Alerts will evaluate future published events.**
5. Scroll to **Existing policies**.
6. Confirm the new row shows the policy name, `CHECK`, exact Qualified API Name,
   `CUSTOM_NOTIFICATION`, and Active selected.

**Screen checkpoint:** The policy exists in Existing policies. The form has reset to its defaults,
ready to create another policy. Saving does not run a Check and does not process older outcomes.

If validation stays on the form, complete every field marked required. If a red toast says the policy
was not saved, verify permission-set assignment and use only picker values.

## Step 6: Run and resolve the setup assistant

1. On **RHC Alerts Administration**, click **Analyze publication coverage**.
2. Wait for the spinner to stop.
3. Scroll to **Setup assistant**.
4. Read every finding from highest severity to lowest.

The assistant evaluates saved active policies. Its possible findings are:

### ERROR — DEFINITION_NOT_FOUND

The exact Check identity on an active policy does not match an active core Check.

1. Open **Record Health Check Alert Policies** in the RHC Alerts app.
2. Open the affected policy.
3. Click **Edit** and clear **Active**; click **Save**.
4. Return to Administration and create a replacement using the picker, or correct the core
   activation/configuration through the approved core process.

### ERROR — CHECK_SET_NOT_FOUND

The selected Check Set has no active matching Checks.

1. Deactivate the policy.
2. Confirm the Check Set identity and active child Checks in core.
3. Create or reactivate only after the active set is correct.

### WARNING — INTERACTIVE_RESULT_DISABLED

Interactive Run/Rerun does not publish Result events for the selected Check.

1. Return to **Setup → Custom Metadata Types**.
2. Click **Manage Records** beside **Record Health Check**.
3. Edit the named Check.
4. Select **Publish User Result Event**.
5. Save.
6. Return to Alerts and run analysis again.

### WARNING — CHECK_SET_RESULT_GAP

One or more active Checks in a selected Check Set do not publish interactive Results.

1. Note how many active Checks the finding says are disabled.
2. Open every active Check in that set through Custom Metadata Types.
3. Select **Publish User Result Event** and save each one.
4. Run analysis again.

### INFO — PROGRAMMATIC_CALLER_CHOICE

This is always shown when at least one active policy exists. Confirm each Flow/Apex/Batch/Queueable/
Scheduled owner uses `ACTIONABLE` or `ALL`; the assistant cannot verify a runtime parameter.

### INFO — SET_RUN_CONTRACT_1_0

This appears when an active Check Set policy exists. It is informational: Check Set human alerts use
Result events. Matching Set Run summaries are stored as `SUPPRESSED /
RUN_CONTRACT_INSUFFICIENT` and never sent.

**Screen checkpoint:** Every ERROR and WARNING has been fixed or formally accepted by the change
owner. INFO rows are understood. Click Analyze publication coverage again after every correction.

## Step 7: Produce a controlled matching result

Use a sandbox record that Maya can view and that will not trigger unwanted downstream automation.

1. Open the test Opportunity.
2. Use an open Opportunity and leave **Next Step** blank so the installed example can produce a
   WARNING `FAIL`. If your org changed or removed the example, use an approved active Check and a
   record condition that safely produces its configured matching outcome.
3. Open your organization's Record Health Check component or approved run entry point.
4. Click **Run** or **Rerun**.
5. Confirm the displayed result has the expected exact Check, `FAIL` status, and WARNING severity.
6. Do not change the test record while waiting.
7. Allow time for asynchronous Platform Event and Queueable processing.

If testing through Flow or Apex, the automation owner must confirm the request uses `ACTIONABLE` or
`ALL` before you run it.

**Screen checkpoint:** Core shows the intended finalized outcome. This confirms evaluation, not yet
notification delivery.

## Step 8: Confirm the Custom Notification

Ask a direct active member of Sales Operations to perform these steps:

1. Refresh Lightning Experience.
2. Click the **notification bell**.
3. Look for the title **Record health check alert**.
4. Open the notification.
5. Confirm the body follows this safe pattern:

   `Health check rhc__Example_Opportunity_DR_Next_Step reported FAIL (WARNING). Open Salesforce to review the record if you have access.`

6. Confirm no raw values, payload, exception text, stack trace, or record ID text is displayed.
7. If the notification targets the Opportunity, confirm only users with existing Opportunity access
   can open it.

**Screen checkpoint:** One notification is visible to each direct active group member. A recipient
who is not a direct member should not receive one through this policy.

## Step 9: Verify delivery history

1. In the RHC Alerts app, click **RHC Alerts Delivery History**.
2. Click **Refresh**.
3. Find the newest row for the worked example policy.
4. Confirm:

| Column        | Expected successful value                           |
| ------------- | --------------------------------------------------- |
| Policy        | Opportunity next-step alerts — Sales Operations     |
| Outcome       | DELIVERED                                           |
| Status        | FAIL, UNABLE_TO_EVALUATE, or ERROR used by the test |
| Severity      | WARNING                                             |
| Attempts      | 1                                                   |
| Recipients    | Number of direct active Sales Operations Users      |
| Suppression   | Blank                                               |
| Failure class | Blank                                               |
| Error code    | Blank                                               |
| Occurred      | Time core created the event                         |

The table shows the newest 500 rows. It does not show restricted payloads or stack traces.

### What each outcome means

| Outcome      | Meaning                                                                        | What Maya does                                                                                                                           |
| ------------ | ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `PENDING`    | Claimed and queued, or waiting for a bounded transient retry                   | Open the Delivery object record to inspect **Next Retry At**, refresh after that time, and check Setup → Apex Jobs if it remains pending |
| `DELIVERED`  | Salesforce accepted the Custom Notification or email request                   | No action unless a recipient reports a platform/mail problem                                                                             |
| `SUPPRESSED` | Cooldown, inactive policy, or Set Run contract intentionally prevented sending | Read Suppression and verify it matches the intended control                                                                              |
| `FAILED`     | Configuration, limit, permanent, or exhausted transient problem                | Read Failure class and safe Error code; use the operations runbook                                                                       |
| `DUPLICATE`  | The same Event ID + Policy claim was already processed                         | No action; duplicate success was prevented                                                                                               |

`DELIVERED` does not prove that a person read the notification or that email reached an inbox.

## Step 10: Test cooldown

Cooldown requires a later event with a different Event ID for the same policy and checked record.

1. Leave the worked example policy at 1,440 minutes.
2. Run the same Check again on the same Opportunity so core publishes a new matching Event ID.
3. Wait for asynchronous processing.
4. Open **RHC Alerts Delivery History** and click **Refresh**.
5. Find the new row.
6. Confirm **Outcome** is `SUPPRESSED`.
7. Confirm **Suppression** is `COOLDOWN`.
8. Confirm the group received no second notification.

**Screen checkpoint:** The first distinct event is DELIVERED and the later event inside cooldown is
SUPPRESSED. Both remain explainable in the operational ledger.

## Step 11: Verify duplicate-event idempotency

This test requires Alex or a developer because the standard Run button creates a new Event ID.

1. In a sandbox, republish or replay the same canonical Result event with the exact same Event ID.
2. Wait for Platform Event processing.
3. Refresh delivery history.
4. Confirm one original claim is `DELIVERED` (or its original terminal result).
5. Confirm the redelivery created `DUPLICATE` evidence.
6. Confirm no second successful notification was sent for that policy.

Do not edit `DeliveryKey__c` or simulate this by copying a Delivery record. The subscriber must
exercise the unique claim.

## Step 12: Create and test an Email policy

Use a separate sandbox policy so Custom Notification and Email outcomes are independently visible.

1. Return to **RHC Alerts Administration**.
2. Enter policy name `Opportunity next-step email — Maya`.
3. Select **Check**.
4. Select the same exact Check.
5. Select the approved statuses.
6. Select **WARNING**.
7. For **Notification channel**, select **Email**.
8. For **Recipient type**, select **User**.
9. Select Maya.
10. Enter the approved cooldown.
11. Save the policy.
12. Run publication analysis.
13. In **Setup**, enter `Deliverability` in Quick Find and click **Deliverability**.
14. Confirm the environment's Access Level permits the intended test. Do not broaden production
    deliverability without email-administrator approval.
15. Produce a new matching event.
16. Check Maya's inbox, junk/spam folder, and any sandbox email-rewriting destination.
17. Refresh Delivery History and confirm the Email policy row.

Email sends one plain-text message per resolved User, saves no activity, and permits at most 10
recipients per attempt.

## Step 13: Change, pause, or retire a policy

The Administration card creates policies. Existing policies are maintained through the object tab.

### Pause a policy

1. In the RHC Alerts app, click **Record Health Check Alert Policies**.
2. Select the appropriate list view if the record is not immediately visible.
3. Open the policy.
4. Click **Edit**.
5. Clear **Active**.
6. Click **Save**.
7. Return to Administration and confirm Existing policies shows Active off.

A claimed row that reaches delivery after deactivation becomes `SUPPRESSED / POLICY_INACTIVE`.

### Change a recipient, channel, cooldown, or matching rule

Use a replacement policy so all routing and matching values pass the guided form's server validation.
The generic Salesforce record Edit page does not invoke the RHC Alerts form validator.

1. Open **RHC Alerts Administration**.
2. Recreate the approved policy with the new recipient, channel, cooldown, identity, status, or
   severity.
3. Leave the replacement **Active** off until the approved change window.
4. Click **Save policy**.
5. During the change window, open the old policy record, click **Edit**, clear **Active**, and save.
6. Open the replacement policy record, click **Edit**, select **Active**, and save. Change only the
   Active checkbox on this generic record page.
7. Return to Administration and run the setup assistant.
8. Perform a controlled test.

Do not directly edit `Qualified API Name`, `Matching Statuses`, recipient ID/type, channel, severity,
or cooldown on the generic object page. The replacement workflow preserves picker values and closed
validation.

Prefer deactivation to deletion when delivery-history explanation matters. Deleting a policy can
leave its existing delivery rows without the policy lookup because the relationship uses SetNull.

## Step 14: Verify Jordan's read-only experience

1. Ask Jordan to sign in or use **Login As** according to your security policy.
2. Open the App Launcher.
3. Search for and open **RHC Alerts**.
4. Confirm **RHC Alerts Delivery History** is visible.
5. Confirm Jordan can read delivery rows.
6. Confirm **RHC Alerts Administration** is hidden.
7. Open **Record Health Check Alert Policies** and a policy record.
8. Confirm Jordan cannot create, edit, or delete policies.
9. Confirm Jordan cannot create, edit, or delete delivery rows.
10. Confirm this permission set did not grant access to the test Opportunity.

**Screen checkpoint:** Jordan can investigate bounded operational outcomes and cannot change Alerts
configuration or business data.

## Troubleshooting by symptom

### The expected Check is missing from Qualified API name

1. Confirm Selection type is correct.
2. Confirm the Check and parent Check Set are active in core.
3. Refresh Administration.
4. Confirm Maya can read the public core metadata through the installed versions.
5. Do not manually alter a namespace or select a similarly named definition.

### No delivery row appears

1. Confirm the policy was Active before the event.
2. Confirm exact identity, status, and severity.
3. Run Analyze publication coverage.
4. Confirm Publish User Result Event for interactive runs.
5. Confirm `ACTIONABLE` or `ALL` for programmatic runs.
6. Remember that `NONE` produces no event and no Alerts evidence.
7. Check Setup → Apex Jobs for subscriber/Queueable failure.

### FAILED / CONFIGURATION

| Error code                   | Fix                                                 |
| ---------------------------- | --------------------------------------------------- |
| `INVALID_RECIPIENT_ID`       | Edit the policy and select the recipient again      |
| `RECIPIENT_USER_UNAVAILABLE` | Select an active User                               |
| `PUBLIC_GROUP_UNAVAILABLE`   | Select an available regular Public Group            |
| `NO_DIRECT_ACTIVE_USERS`     | Add direct active User members or switch to User    |
| `UNSUPPORTED_RECIPIENT_TYPE` | Recreate/correct the policy through the packaged UI |

### FAILED / LIMIT

- `CUSTOM_NOTIFICATION_RECIPIENT_LIMIT`: reduce direct group membership below 501 or split the
  audience across approved policies.
- `EMAIL_RECIPIENT_LIMIT`: reduce direct recipients to 10 or fewer; consider Custom Notification if
  appropriate.

### DELIVERED but email did not arrive

1. Confirm the User email address.
2. Check Setup → Deliverability.
3. Check sandbox rewriting, spam, quarantine, and corporate gateway rules.
4. Review daily email allocations.
5. Remember DELIVERED means Salesforce accepted the request, not inbox placement.

### Delivery remains PENDING

1. Open **Record Health Check Alert Deliveries** in the RHC Alerts app.
2. Open the PENDING delivery record and note **Next Retry At**.
3. Wait until after that time and click Refresh in Delivery History.
4. Open Setup → Apex Jobs and inspect `RHCAlertsDeliveryQueueable` status.
5. If no job is running and the row remains PENDING, collect only the safe support evidence listed
   in [the operations runbook](docs/OPERATIONS.md).

## Production go-live checklist

Do not activate production policies until every item is complete.

- [ ] Approved core and Alerts package versions are installed.
- [ ] RHC Alerts Admin is limited to configuration owners.
- [ ] Viewer Runtime is assigned only to approved read-only viewers.
- [ ] Recipients are active Users or regular Public Groups with direct active User members.
- [ ] Interactive publication is enabled on every required Check.
- [ ] Programmatic caller owners confirmed `ACTIONABLE` or `ALL`.
- [ ] Exact namespaced Qualified API Names were selected from the picker.
- [ ] Matching statuses and minimum severity were business-approved.
- [ ] Channel and cooldown were business-approved.
- [ ] Setup assistant has no unresolved ERROR or WARNING.
- [ ] Controlled Custom Notification test passed.
- [ ] Email test passed if Email is used.
- [ ] Delivery History showed expected DELIVERED and cooldown SUPPRESSED outcomes.
- [ ] Duplicate Event ID test passed during release acceptance.
- [ ] Viewer read-only behavior was tested with a separate user.
- [ ] Platform Event, Queueable, notification, email, and storage capacity were reviewed.
- [ ] An operational retention period and support owner were named.

## Where to go next

- [Operations runbook](docs/OPERATIONS.md): outcome/error response, monitoring, retention, support
  evidence.
- [Architecture](docs/ARCHITECTURE.md): event transactions, idempotency, bulk behavior, and package
  boundary.
- [Data model](docs/DATA_MODEL.md): every policy/delivery field and state.
- [Security and threat model](docs/SECURITY.md): permissions, protected data, controls, and residual
  risks.
- [Development and package validation](docs/DEVELOPMENT_AND_VALIDATION.md): test and release gates.
- [Core gap analysis](GAP_ANALYSIS.md): minimum compatible core version and Set Run limitation.

## Official Salesforce Setup references

- [Manage Permission Set Assignments](https://help.salesforce.com/s/articleView?id=perm_sets_assignment_summary.htm&language=en_US&type=5)
- [Create, Edit, and Delete Custom Metadata Types and Records](https://help.salesforce.com/s/articleView?id=sf.custommetadatatypes_metadata_api.htm&language=en_US&type=5)
- [Send a Custom Notification with a Flow](https://help.salesforce.com/s/articleView?id=platform.automate_flow_build_example_send_custom_notification.htm&language=en_US&type=5)

Salesforce can vary Setup labels slightly by release, edition, locale, and whether Setup with
Agentforce is enabled. The package-specific names, buttons, fields, outcomes, and error codes in this
guide match RHC Alerts `0.1.0` source.
