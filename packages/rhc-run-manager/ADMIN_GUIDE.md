# RHC Run Manager Administrator Guide

This guide is for Salesforce administrators who are comfortable with Setup and Flow Builder but do
not write Apex or SOQL. It explains the normal setup path from installation through monitoring.

Related guides:

- [Installation and first-time access](docs/INSTALLATION.md)
- [Expanded Contact-to-Account Flow Builder guide](docs/FLOW_GUIDE.md)
- [Operations runbook](docs/OPERATIONS.md)
- [Data dictionary](docs/DATA_DICTIONARY.md)

> **Day 1 release note:** use the package version ID supplied with the release. The beta install ID
> is not hard-coded here because a new `04t` ID is issued for every beta build.

## What Run Manager does

Run Manager answers four questions without asking an administrator to write code:

1. Which Record Health Check Check Set or individual Check should run?
2. Which accessible records should be checked?
3. When should the work run, and how large should each Batch scope be?
4. Which detailed results should be retained for monitoring?

Run Manager owns execution. Do not provide a Batch Apex class, SOQL query, CRON expression, target
object, namespace, or event-publication option. Run Manager derives and validates those details.

## Before you begin

Confirm all of the following:

- Record Health Check core `2.0.4-2` is installed.
- The RHC Run Manager beta is installed.
- The Check Sets and Checks you intend to use are active in Record Health Check core.
- The person configuring Run Manager can read the target records and fields.
- You know whether users need administrator, viewer, or Flow execution access.

Run Manager depends only on Record Health Check core. Builder, Alerts, Reports, Actions, and
Integrations are not required.

## How to read the screen

The RHC Run Manager card contains three numbered tabs. Complete them from left to right the first
time:

1. **Run Definitions** answers what should run, which records are eligible, scope size, and retained
   history.
2. **Schedules** optionally starts eligible definitions on a safe recurrence.
3. **Monitoring** shows one Batch Run per asynchronous job, one Run per Batch scope, and retained
   Results under each Run.

Every table row has a downward-arrow action menu on the right. If you do not see it, widen the
browser or horizontally scroll the table.

Buttons show a Salesforce toast after completion. A green toast means the request was accepted; it
does not mean asynchronous evaluation has already finished. Use Monitoring to confirm completion.

## Terminology in plain language

| Term | Plain-language meaning |
| --- | --- |
| Check Set | A named group of Record Health Check Checks |
| Check | One individual health rule |
| Run Definition | Reusable instructions for what records/checks to run |
| Batch Size | Maximum target records in one independently captured scope |
| Batch Run | One Salesforce Batch job |
| Run | One scope inside that Batch job |
| Result | One retained record/check detail |
| Capture Mode | Which detailed Results are kept; all statuses are still counted |
| Supplied IDs | Exact target record IDs delivered by Flow |
| Consolidation Window | Short delay used to group IDs from separate committed transactions |

## 1. Assign access

1. In Salesforce, click the **gear** icon.
2. Click **Setup**.
3. In **Quick Find**, enter `Permission Sets`.
4. Click **Permission Sets**.
5. Choose the permission set that matches the person's job:

   | Permission set | Assign to | What it allows |
   | --- | --- | --- |
   | **RHC Run Manager Admin** (`RHC_Run_Manager_Admin`) | Administrators | Create definitions and schedules, start runs, and monitor results |
   | **RHC Run Manager Viewer** (`RHC_Run_Manager_Viewer`) | Operations/support users | Read monitoring data without changing configuration |
   | **RHC Run Manager Executor** (`RHC_Run_Manager_Executor`) | Users whose record-triggered Flows submit IDs | Invoke the packaged Flow action and allow Run Manager-owned processing |

6. Click **Manage Assignments**.
7. Click **Add Assignments**.
8. Select the users.
9. Click **Next**, then **Assign**.
10. Also assign the appropriate Record Health Check core permission set. A Run Manager administrator
    normally needs **Record Health Check Admin**; an operational user normally needs the core access
    appropriate to their role.

Tip: use the Executor permission set for automation users. Do not give them Admin simply to make a
Flow action work.

## 2. Open Run Manager

1. Click the **App Launcher** (the nine-dot grid).
2. Search for `RHC Run Manager`.
3. Click **RHC Run Manager**.
4. Confirm that you see three tabs:
   **1. Run Definitions**, **2. Schedules**, and **3. Monitoring**.

If the app is not visible, confirm that the RHC Run Manager Admin or Viewer permission set is
assigned, then refresh the browser.

## 3. Create a Run Definition

A Run Definition is the saved configuration reused by Run Now, schedules, and supplied-ID Flow
requests.

1. Open **1. Run Definitions**.
2. In **Name**, enter a purpose-oriented name. Example: `Accounts affected by Contact changes`.
3. In **Selection Type**, choose:

   - **Check Set** to run every active Check in one Check Set.
   - **Check** to run one individual Check.

4. In **Check Set or Check**, select the active core metadata. You do not type a Qualified API Name.
5. Read the target-object message displayed below the picker. Confirm that it is the object you
   expect. Run Manager derives this object from core metadata.
6. In **Records to Check**, choose one mode:

   - **All Accessible**: checks every target record the running user can access.
   - **Guided Filtered**: checks only records matching administrator-built filters.
   - **Supplied Ids**: waits for a Flow to provide target IDs.

7. In **Batch Size**, enter a whole number from 1 through 200. Start with `100` unless record checks
   are unusually expensive or your implementation team recommends another size.
8. In **Retain Results**, choose:

   | Choice | Detailed history retained | Core publication requested |
   | --- | --- | --- |
   | **Fail** | `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` | `ACTIONABLE` |
   | **Pass** | `PASS` | `ALL` |
   | **Both** | Passing and actionable groups | `ALL` |

   `SKIPPED` is always counted but is not retained as detailed history. **Fail** is usually the
   simplest operational choice because it retains records needing attention.

9. Select **Active**.
10. Click **Save Run Definition**.
11. Confirm the new definition appears in the table below the form.

### Run Definition field reference

| Screen field | Required | What to choose | Common mistake |
| --- | --- | --- | --- |
| Name | Yes | A unique purpose, object, and trigger, such as `Accounts affected by Contact changes` | Reusing a vague name such as `Account Run` |
| Selection Type | Yes | Check Set for a group; Check for exactly one rule | Choosing Check Set then searching for an individual Check |
| Check Set or Check | Yes | Select from active core metadata | Trying to type an API name manually |
| Records to Check | Yes | All Accessible, Guided Filtered, or Supplied Ids | Choosing Supplied Ids for a schedule |
| Batch Size | Yes | 1–200; begin with 100 | Assuming a larger number is always faster |
| Retain Results | Yes | Usually Fail; Both for controlled validation | Expecting excluded statuses to appear as detail |
| Consolidation Window | Supplied Ids only | 1–10 minutes; begin with 1 | Expecting an immediate Batch per Flow interview |
| Active | Yes for execution | Selected when ready to run | Saving inactive and expecting Run Now/Flow to execute |

After changing Selection Type or Check selection, wait for **Target object: ...** to refresh before
choosing filters. The target field list is derived from that object and the current user's access.

### Edit an existing definition

1. Find the definition in the table.
2. Open its row-action menu.
3. Click **Edit**.
4. Confirm the form above is populated with that definition.
5. Make the change.
6. Recheck the derived target object and any guided filters.
7. Click **Save Run Definition**.
8. Confirm the success toast and updated table row.

Editing affects future launches only. Existing Batch Runs remain historical evidence of their saved
execution snapshot.

### Guided filtered records

Use this mode when the administrator can describe the population with simple field conditions.
Run Manager never accepts raw SOQL.

1. Choose **Guided Filtered** in **Records to Check**.
2. In **Field**, select an available field on the derived target object.
3. In **Operator**, select the comparison.
4. In **Value**, enter the comparison value.
5. Click **Add Filter**.
6. Repeat for additional conditions. All conditions are combined with **AND**.
7. Review the filter table. Use the row action to remove an incorrect condition.
8. Click **Save Run Definition**.

Example: `Account.Active__c Eq true` AND `Account.Type Eq Customer` checks accessible Accounts
that satisfy both conditions.

#### Operator guide

| Operator | Use it for | Example |
| --- | --- | --- |
| Eq | Exact value match | Type equals Customer |
| Ne | Exclude one value | Status does not equal Closed |
| Gt / Gte | Numeric/date lower boundary | Annual Revenue greater than 1000000 |
| Lt / Lte | Numeric/date upper boundary | Created Date less than a cutoff |
| Contains | Text contains a value | Name contains Foundation |
| Starts With | Text begins with a value | Name starts with Test |
| Is Null | Field is or is not empty according to entered Boolean value | Parent ID is null |

Only operators valid for the selected field type are accepted by the server. If Save rejects a
value, verify its Salesforce data type and use the org's normal API-compatible date/number format.

### Supplied record IDs

Use this mode for related-record changes or when another Flow already knows the exact records to
check.

1. Choose **Supplied Ids** in **Records to Check**.
2. Set **Consolidation Window (minutes)** from 1 through 10. Start with `1`.
3. Complete the remaining fields and click **Save Run Definition**.
4. Note the definition's unique **Name**. The Flow steps below retrieve the definition by Name so a
   record ID is not hard-coded into the Flow.

**Run Now and schedules are not available for Supplied Ids definitions.** These definitions
run only after the packaged Flow action supplies IDs.

## 4. Run a definition immediately

Use Run Now for **All Accessible** or **Guided Filtered** definitions.

1. In **1. Run Definitions**, find the saved definition.
2. Open the row-action menu at the right side of the row.
3. Click **Run Now**.
4. Wait for the success message.
5. Open **3. Monitoring**.
6. Click the refresh icon until the Batch Run appears.

What you should see:

1. A new Batch Run with Source `RUN_NOW`.
2. Status normally progresses from `QUEUED` to `PROCESSING` to `COMPLETED`.
3. Submitted and Processed counts populate when Batch finishes.
4. **View scopes** becomes the path to scope summaries.

Run Now uses the same owned execution path as scheduled runs. A Supplied Ids definition will
direct you to use Flow instead.

## 5. Create a schedule

Schedules are supported for **All Accessible** and **Guided Filtered** definitions.

1. Open **2. Schedules**.
2. In **Run Definition**, select the saved definition.
3. In **Frequency**, choose the required recurrence.
4. In **Preferred Start Time**, choose the time. Salesforce evaluates the schedule in the scheduling
   user's time zone.
5. If the frequency is weekly, choose **Day of Week**.
6. Optionally choose **Start Date** and **End Date**.
7. Select **Active**.
8. Click **Save Schedule**.
9. Confirm that the schedule appears in the table.

To change a schedule, open its row-action menu and click **Edit**, update the form, and click
**Save Schedule**. To stop future runs safely, choose **Pause** from the row-action menu. Run Manager
only manages the Salesforce scheduled jobs that it owns.

### Frequency examples

| Business request | Frequency | Additional choice |
| --- | --- | --- |
| Every night | Daily | Preferred Start Time |
| Monday through Friday | Weekdays | Preferred Start Time |
| Every Sunday | Weekly | Day of Week = Sun |
| Temporary campaign | Any supported frequency | Start Date and End Date |

The time is interpreted in the scheduling user's Salesforce time zone. Check the user's time-zone
setting before configuring an overnight production schedule.

### What Pause does

Pause marks the packaged Schedule inactive and aborts only the CronTrigger whose stored identity and
job name prove it belongs to that Schedule. It does not delete the Run Definition or history.

## 6. Contact change → Account Check Set Flow

This example checks both the Contact's new Account and previous Account when `AccountId` changes.
It also handles bulk updates without launching one asynchronous job per Contact.

### Create the Run Definition first

1. In **RHC Run Manager**, open **1. Run Definitions**.
2. Enter a name such as `Accounts affected by Contact changes`.
3. Choose **Check Set**.
4. Select the Account Check Set.
5. Confirm the displayed target object is **Account**.
6. Choose **Supplied Ids**.
7. Set **Batch Size** (for example, `100`).
8. Choose a capture mode, normally **Fail**.
9. Set **Consolidation Window (minutes)** to `1`.
10. Select **Active** and click **Save Run Definition**.

### Build the record-triggered Flow

1. Click the **gear** icon, then **Setup**.
2. In **Quick Find**, enter `Flows`.
3. Click **Flows**.
4. Click **New Flow**.
5. Choose **Record-Triggered Flow**, then click **Create**.
6. For **Object**, choose **Contact**.
7. For the trigger, choose **A record is updated**.
8. Add the entry condition **AccountId — Is Changed — True**.
9. For **When to Run the Flow for Updated Records**, choose **Every time a record is updated and meets
   the condition requirements**.
10. For **Optimize the Flow For**, choose **Actions and Related Records**. This creates an after-save
    Flow.
11. Click **Done**.
12. On the path after Start, click the **plus** icon.
13. Choose **Get Records**.
14. Enter the label `Get Run Definition`.
15. For **Object**, choose **Record Health Check Run Definition**.
16. Set the conditions to **Name — Equals — Accounts affected by Contact changes** and
    **Active — Equals — True**.
17. For **How Many Records to Store**, choose **Only the first record**.
18. For **How to Store Record Data**, choose **Automatically store all fields**.
19. Click **Done**.
20. After Get Run Definition, click the **plus** icon and choose **Decision**.
21. Label it `Run Definition Found`. Add an outcome named `Found` where
    **Get Run Definition > Id — Is Null — False**. Leave the default outcome as the no-op path.
22. Click **Done**.
23. On the **Found** outcome, click the **plus** icon and choose **Action**.
24. Search for `Submit Record IDs to RHC Run Manager` and select it.
25. Enter a label such as `Submit affected Account IDs`.
26. Set **Run Definition ID** to **Get Run Definition > Record ID**.
27. Set **Target Record ID** to `{!$Record.AccountId}`.
28. Set **Prior Target Record ID** to `{!$Record__Prior.AccountId}`.
29. Leave the optional **Target Record IDs** collection empty for this example.
30. Click **Done**.
31. Click **Save**, enter a clear Flow label, and click **Save** again.
32. Click **Activate**.

### What happens at runtime

- Null IDs are removed.
- Duplicate current/prior Account IDs are removed.
- A Contact moved from Account A to Account B causes both Accounts to be submitted.
- Requests from separate committed Contact transactions are consolidated during the configured
  window.
- Run Manager starts one owned Account Batch for the consolidated IDs instead of one asynchronous
  job per changed Contact.

## 7. Monitor a run

1. Open **3. Monitoring**.
2. Click the refresh icon.
3. Find the Batch Run. Review its source, status, submitted count, processed count, and failed-scope
   count.
4. Open the Batch Run row-action menu and choose the action to view its scope Runs.
5. Review each scope Run's status and counts. Each scope commits independently, so an earlier scope
   can remain available even if a later scope fails.
6. Open a scope Run's row-action menu to view retained Results.
7. Remember that the result table reflects the definition's capture mode; `SKIPPED` appears only in
   counts.

Common statuses:

- **Queued/Processing**: work is waiting or running.
- **Completed**: the Batch finished without a recorded scope failure.
- **Partial Failure**: at least one scope failed; inspect the scope Runs and error summary.

### Monitoring drilldown example

1. In the Batch Run table, locate Source `SUPPLIED_IDS` and Status `COMPLETED`.
2. Open its row menu and select **View scopes**.
3. A heading appears: **Scopes for _Batch Run name_**.
4. Review Scope, Status, Records, Pass, Fail, Skipped, Unable, and Errors.
5. Open a scope row menu and select **View retained results**.
6. A heading appears: **Retained results for _Run name_**.
7. Review Record ID, Check, Status, Severity, Reason, and Summary.

If a completed scope has Fail count 10 but only 8 retained result rows, investigate Capture Mode and
status mix before treating it as data loss. SKIPPED is never retained; capture rules can exclude PASS
or actionable details.

## Common configuration recipes

### Recipe A: nightly exception scan

1. Selection Type: Check Set.
2. Records to Check: All Accessible.
3. Batch Size: 100.
4. Retain Results: Fail.
5. Save active definition.
6. Create a Daily schedule at the approved off-hours time.

### Recipe B: one-time filtered validation

1. Selection Type: Check Set or Check.
2. Records to Check: Guided Filtered.
3. Add filters that select a small known population.
4. Batch Size: 10.
5. Retain Results: Both.
6. Save, Run now, and verify Monitoring.
7. Change Capture Mode to Fail or deactivate after validation.

### Recipe C: relationship-change recheck

1. Selection Type: Check Set.
2. Confirm derived target object is the parent object.
3. Records to Check: Supplied Ids.
4. Consolidation Window: 1 minute.
5. Retain Results: Fail.
6. Build an after-save child-object Flow that submits current and prior parent IDs.
7. Do not create a schedule for this definition.

## Troubleshooting

### The Check Set or Check is missing from the picker

- Confirm it is active in Record Health Check core.
- Confirm the selected **Selection Type** is correct.
- Confirm the administrator has core metadata access.
- Refresh the RHC Run Manager app.

### Save or Run Now reports an access error

- Confirm **RHC Run Manager Admin** is assigned.
- Confirm the appropriate Record Health Check core permission set is assigned.
- Confirm the running user can access the target object, target records, and fields used by checks or
  filters.

### The Flow action is missing

- Confirm RHC Run Manager is installed.
- Confirm the Flow is an after-save record-triggered Flow when asynchronous related-record handling
  is intended.
- Confirm the automation user has **RHC Run Manager Executor**.
- Search Actions for the full label: **Submit Record IDs to RHC Run Manager**.

### A supplied-ID request did not start immediately

This is expected. Run Manager waits for the configured consolidation window so requests from many
transactions can be grouped. Refresh Monitoring after that window plus normal Salesforce async
queue time.

### A run retained no detailed results

Check **Retain Results** on the Run Definition. For example, a **Fail** definition with only passing
records retains no detailed Results, although its PASS totals are still counted.

### Run Now is unavailable or rejected

- Confirm the definition is Active.
- Confirm Records to Check is not Supplied Ids.
- Confirm Batch Size is between 1 and 200.
- Confirm the selected core metadata is still active and accessible.

### Schedule cannot be saved

- Confirm the definition is active and is not Supplied Ids.
- Confirm Weekly schedules have a Day of Week.
- Confirm Start Date is not after End Date.
- Confirm Preferred Start Time is present.

### Batch Run shows Partial Failure

1. Open **View scopes**.
2. Locate the scope with Status Error.
3. Record the Batch Run and scope Run IDs.
4. Check permissions, sharing, target data, filters, and recent core metadata changes.
5. Correct the cause and launch a new run; do not delete the historical partial run.
6. Follow the [operations runbook](docs/OPERATIONS.md#partial-failure-response).

## Safe operating checklist

Before activating a production schedule or Flow:

- [ ] The selected Check Set or Check is correct and active.
- [ ] The derived target object is correct.
- [ ] The running/automation user has least-privilege Run Manager and core access.
- [ ] Guided filters were reviewed and contain no unintended conditions.
- [ ] Batch Size is between 1 and 200.
- [ ] Capture Mode matches the required history and storage footprint.
- [ ] A supplied-ID Flow passes both current and prior related IDs where relationships can change.
- [ ] Monitoring was tested with a small, known population.
