# Related-record Flow guide: Contact changes check Accounts

This guide assumes no Apex knowledge. The completed after-save Flow submits the Contact's current and
prior Account IDs to one saved Account Run Definition.

## What this Flow solves

When a Contact moves from Account A to Account B, both Accounts may need to be rechecked. A naïve
design launches asynchronous work for every Contact update. Run Manager instead:

- accepts `$Record.AccountId` and `$Record__Prior.AccountId`;
- removes nulls and duplicates;
- upserts durable request rows;
- consolidates requests committed by separate Flow interviews;
- launches one owned Account Batch per consolidation window.

## Part 1: create the supplied-ID definition

1. Open the **RHC Run Manager** app.
2. Open **1. Run Definitions**.
3. In **Name**, enter `Accounts affected by Contact changes`.
4. In **Selection Type**, select **Check Set**.
5. In **Check Set or Check**, select the Account Check Set.
6. Confirm the page displays **Target object: Account**. Stop if it displays another object.
7. In **Records to Check**, select **Supplied Ids**.
8. In **Batch Size**, enter `100`.
9. In **Retain Results**, choose **Fail** for normal operations or **Both** for initial testing.
10. In **Consolidation Window (minutes)**, enter `1`.
11. Ensure **Active** is selected.
12. Click **Save Run Definition**.
13. Confirm the definition appears in the table.

Use a unique Name so Flow's Get Records element retrieves only this configuration.

## Part 2: start a record-triggered Flow

1. Click **gear → Setup**.
2. Enter `Flows` in **Quick Find**.
3. Click **Flows**.
4. Click **New Flow**.
5. Select **Record-Triggered Flow**.
6. Click **Create**.
7. In the Start panel, choose **Contact** for **Object**.
8. Select **A record is updated**.
9. Under **Condition Requirements**, choose **All Conditions Are Met (AND)**.
10. Add the condition:
    - Field: **Account ID**
    - Operator: **Is Changed**
    - Value: **True**
11. For **When to Run the Flow for Updated Records**, choose
    **Every time a record is updated and meets the condition requirements**.
12. For **Optimize the Flow For**, choose **Actions and Related Records**.
13. Click **Done**.

Why after-save? The packaged action performs durable DML and queues asynchronous orchestration after
the Contact transaction is ready to commit.

## Part 3: retrieve the Run Definition

1. On the canvas after Start, click **+**.
2. Select **Get Records**.
3. Label the element `Get Account Run Definition`.
4. For **Object**, search for and choose **Record Health Check Run Definition**.
5. Choose **All Conditions Are Met (AND)**.
6. Add condition 1:
   - Field: **Name**
   - Operator: **Equals**
   - Value: `Accounts affected by Contact changes`
7. Add condition 2:
   - Field: **Active**
   - Operator: **Equals**
   - Value: **True**
8. For **Sort Order**, choose **Not Sorted**.
9. For **How Many Records to Store**, choose **Only the first record**.
10. For **How to Store Record Data**, choose **Automatically store all fields**.
11. Click **Done**.

Do not paste a sandbox record ID into the Flow. Retrieving by a controlled unique name allows the
same Flow metadata to move between orgs.

## Part 4: safely handle missing configuration

1. Click **+** after Get Account Run Definition.
2. Select **Decision**.
3. Label it `Run Definition Found`.
4. Rename the first outcome `Found`.
5. Set the outcome condition:
   - Resource: **Get Account Run Definition → Record ID**
   - Operator: **Is Null**
   - Value: **False**
6. Leave **Default Outcome** as the path used when no definition is found.
7. Click **Done**.

For a mature production Flow, connect the Default Outcome to your organization's logging or admin
notification pattern. Do not invoke Run Manager with a null definition ID.

## Part 5: add the packaged action

1. On the **Found** path, click **+**.
2. Select **Action**.
3. In the action search, enter `Submit Record IDs to RHC Run Manager`.
4. Select the action in category **Record Health Check**.
5. Label it `Submit affected Account IDs`.
6. Set **Run Definition ID** to
   **Get Account Run Definition → Record ID**.
7. Set **Target Record ID** to **$Record → Account ID**.
8. Set **Prior Target Record ID** to **$Record__Prior → Account ID**.
9. Leave **Target Record IDs** empty. It is optional and intended for a Flow collection.
10. Click **Done**.

Expected action outputs are **Success**, **Accepted Record Count**, **Error Message**, and
**Error Type**. A robust enterprise Flow can add a Decision after the action and route
`Success = False` to its logging standard.

## Part 6: save, debug, and activate

1. Click **Save**.
2. Flow Label: `Contact Account Health Submission`.
3. Flow API Name: accept the generated value or follow your naming standard.
4. Add a description explaining that current/prior Account IDs are coalesced by RHC Run Manager.
5. Click **Save**.
6. Click **Debug**.
7. Select a Contact test record whose Account can safely be changed.
8. Run the debug path using rollback mode if your org offers it.
9. Confirm the Flow reaches **Found** and the packaged action reports success.
10. Close Debug.
11. Click **Activate** only after the controlled test succeeds.

## Part 7: end-to-end test

1. Create or identify Account A and Account B.
2. Create or identify a Contact related to Account A.
3. Change the Contact's Account to Account B and save.
4. Optionally update several Contacts in a bulk operation to test consolidation.
5. Wait at least the configured consolidation window plus normal asynchronous queue time.
6. Open **RHC Run Manager → 3. Monitoring**.
7. Click refresh.
8. Confirm one `SUPPLIED_IDS` Batch Run appears for the definition/window.
9. Open **View scopes**.
10. Confirm Account A and Account B contributed to the run population through expected counts/results.

The action's per-interview **Accepted Record Count** can be 0, 1, or 2 in this example:

- 0: both values were null;
- 1: current and prior are the same, or only one exists;
- 2: the Contact moved between two different Accounts.

## Collection-input variant

If an existing Flow already builds a record-ID collection:

1. Create a Text or Record ID collection resource.
2. Populate it using Flow collection operations.
3. Map the collection to **Target Record IDs**.
4. Leave current/prior inputs empty if they are not needed.

All three input sources are merged into the same deduplication path.

## Change and rollback procedure

To stop submissions without deleting configuration:

1. Deactivate the record-triggered Flow, or create a new Flow version and leave it inactive.
2. In Run Manager, edit the supplied-ID definition and clear **Active** if you also need to reject
   pending launches.
3. Do not delete Run Request or monitoring records while diagnosing an incident.
4. Restore service by correcting configuration, activating the definition, testing, then activating
   the intended Flow version.

## Flow troubleshooting

| Symptom | Check |
| --- | --- |
| Action not found | Package installed; Executor permission; search full action label/category |
| Get Records returns nothing | Definition Name spelling; Active checked; record sharing/access |
| Action Success is false | Error Type/Message; definition population mode; object/FLS access |
| No immediate Batch Run | Wait consolidation window and async queue time |
| Too many Batch Runs | Confirm all interviews use the same definition and no duplicate custom async path exists |
| Old Account not checked | Confirm Prior Target Record ID maps to `$Record__Prior.AccountId` |

