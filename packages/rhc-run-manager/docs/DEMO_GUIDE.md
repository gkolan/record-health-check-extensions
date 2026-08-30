# Demo data and complete functional test guide

Use this guide only in a scratch org, developer org, or approved sandbox. The All Accessible demo
definition evaluates every Account visible to the launching user.

## What the demo creates

### Accounts

| Name | Purpose |
| --- | --- |
| RHC Demo - Complete Account | Common standard fields populated; useful for likely passing outcomes |
| RHC Demo - Sparse Account | Common standard fields intentionally blank; useful for actionable outcomes |
| RHC Demo - Previous Parent | Initial parent for relationship-change Contacts |
| RHC Demo - Current Parent | New parent used to prove current/prior handling |

### Contacts

- Demo RHC Demo Relationship Change
- Demo RHC Demo Bulk One
- Demo RHC Demo Bulk Two

All three begin on **RHC Demo - Previous Parent**.

### Run Definitions

| Name | Population | Batch size | Capture | Purpose |
| --- | --- | --- | --- | --- |
| RHC Demo - All Accessible Accounts | All Accessible | 2 | Fail | Full visible population and multiple-scope behavior |
| RHC Demo - Filtered Accounts | Guided Filtered | 2 | Both | Exact four-account demo population and full retained detail |
| RHC Demo - Accounts from Contact Changes | Supplied Ids | 2 | Fail | Flow, current/prior IDs, deduplication, consolidation |

The loader chooses the first active Account Check Set from Record Health Check core and derives
Account as the target. It also creates one inactive Sunday 02:00 Schedule for the filtered definition.

## Prerequisites

1. Install Record Health Check core and RHC Run Manager.
2. Confirm at least one active Account Check Set exists.
3. Assign **Record Health Check Admin** and **RHC Run Manager Admin** to the demo administrator.
4. Use a nonproduction org.
5. If testing supplied IDs, assign **RHC Run Manager Executor** to the Flow-running user.

## Load the demo

From `packages/rhc-run-manager`:

```bash
sf apex run \
  --file scripts/demo/create-demo-data.apex \
  --target-org <demo-org-alias> \
  --json
```

Expected result:

- command status `0`;
- debug output contains `RHC DEMO READY`;
- four Account IDs, three Run Definition IDs, one relationship Contact ID, and the selected Account
  Check Set identity are printed.

The script is idempotent: rerunning it updates the same exact-name demo records and resets the three
Contacts to Previous Parent. It does not delete existing monitoring history.

## Verify setup in Salesforce

1. Open **App Launcher → RHC Run Manager**.
2. On **1. Run Definitions**, confirm all three `RHC Demo` definitions appear.
3. Open **2. Schedules** and confirm an inactive Weekly/Sunday schedule exists for
   **RHC Demo - Filtered Accounts**.
4. Open the Accounts list and confirm all four demo Accounts.
5. Open each demo Contact and confirm Account is **RHC Demo - Previous Parent**.

If a definition is missing, rerun the loader and inspect its error. The most common cause is no active
Account Check Set.

## Test matrix

Record the Batch Run ID and outcome for every case.

| Test | Function | Expected evidence |
| --- | --- | --- |
| 1 | Metadata selection/target derivation | Definition shows Check Set and target Account |
| 2 | Guided filtered Run Now | Exactly four demo Accounts submitted; two scopes at Batch Size 2 |
| 3 | Capture Both | Passing/actionable retained as available; SKIPPED summary-only |
| 4 | All Accessible Run Now | Every accessible Account submitted, not only demo Accounts |
| 5 | Schedule save/edit/pause | Owned schedule activates, edits, and pauses without CRON input |
| 6 | Supplied current/prior IDs | Moving Contact submits both previous and current Account |
| 7 | Null/duplicate removal | Same or null parent does not create duplicate target request |
| 8 | Cross-transaction consolidation | Multiple Contact saves yield one supplied-ID Batch for the window |
| 9 | Monitoring drilldown | Batch Run → scope Runs → retained Results |
| 10 | Least privilege | Viewer cannot edit; Executor can submit but not configure |

## Test 1: metadata picker and derived target

1. On **1. Run Definitions**, open the row action for **RHC Demo - Filtered Accounts**.
2. Click **Edit**.
3. Confirm **Selection Type** is **Check Set**.
4. Confirm **Check Set or Check** contains the selected core Account Check Set.
5. Confirm the message reads **Target object: Account**.
6. Confirm the guided-filter row is Name / Starts With / `RHC Demo -`.
7. Do not change anything; click **Save Run Definition**.

Pass evidence: success toast and unchanged definition row. The administrator never entered Account,
Qualified API Name, or SOQL.

## Test 2: guided filtered execution and Batch scopes

1. Find **RHC Demo - Filtered Accounts**.
2. Open its row action and click **Run now**.
3. Open **3. Monitoring**.
4. Refresh until a Source `RUN_NOW` Batch Run appears and completes.
5. Confirm **Submitted = 4** and **Processed = 4**.
6. Choose **View scopes**.
7. Confirm two scope Runs exist because Batch Size is 2.
8. Add the Records counts across scopes; total must be 4.

If the org contains more Accounts, they must not appear in this filtered population.

## Test 3: Capture Both and SKIPPED handling

1. Continue from Test 2.
2. Review each scope's Pass, Fail, Skipped, Unable, and Errors totals.
3. Choose **View retained results** for each scope.
4. Confirm retained details include both PASS and actionable statuses produced by the chosen Check Set.
5. Confirm no retained Result has status SKIPPED.
6. Confirm any SKIPPED count remains visible on the scope summary.

The exact PASS/FAIL mix depends on the active core Check Set. The invariant is retention behavior, not
a hard-coded outcome for an unknown customer Check Set.

## Test 4: All Accessible population

1. Find **RHC Demo - All Accessible Accounts**.
2. Choose **Run now**.
3. Refresh Monitoring until complete.
4. Compare Submitted with this user-mode query/count of accessible Accounts.
5. Confirm the Batch may include non-demo Accounts visible to the launching user.
6. Confirm only actionable detailed Results are retained because Capture Mode is Fail.

Do not use this test in production unless evaluating all visible Accounts is explicitly approved.

## Test 5: schedule lifecycle

The demo Schedule starts inactive so loading data cannot unexpectedly launch work.

1. Open **2. Schedules**.
2. Find the schedule for **RHC Demo - Filtered Accounts**.
3. Open its row action and click **Edit**.
4. Change Frequency to **Daily** and choose a time several minutes in the future.
5. Select **Active** and click **Save Schedule**.
6. Confirm Active is true in the table.
7. Edit it again and change the time; save.
8. Confirm no administrator CRON field is ever shown.
9. Open the row action and click **Pause**.
10. Confirm Active is false.

Optional fire test: activate a near-future time, wait for a Source `SCHEDULED` Batch Run, confirm
Submitted 4, then Pause immediately.

## Test 6: create the supplied-ID Flow

Follow [Related-record Flow guide](FLOW_GUIDE.md) exactly, using Run Definition Name:

```text
RHC Demo - Accounts from Contact Changes
```

Use Contact as the triggered object, after-save update, and map:

- Target Record ID = `$Record.AccountId`
- Prior Target Record ID = `$Record__Prior.AccountId`

Activate the Flow after Debug succeeds.

## Test 7: current/prior IDs and deduplication

1. Open **Demo RHC Demo Relationship Change**.
2. Change Account from **RHC Demo - Previous Parent** to **RHC Demo - Current Parent**.
3. Save.
4. Wait one consolidation minute plus asynchronous queue time.
5. In Monitoring, find Source `SUPPLIED_IDS`.
6. Confirm one Batch Run was launched.
7. Confirm Submitted = 2: previous and current Account.
8. Change an unrelated Contact field without changing Account.
9. Confirm the Flow entry condition prevents a new submission.

To demonstrate per-input duplicate removal in Flow Debug, provide the same Account ID as current and
prior. Expected Accepted Record Count is 1, not 2.

## Test 8: consolidation across separate transactions

1. Ensure the two Bulk demo Contacts are on Previous Parent.
2. In one browser action or data-loader operation, move **Demo RHC Demo Bulk One** to Current Parent.
3. Commit/save.
4. In a separate transaction within the one-minute window, move **Demo RHC Demo Bulk Two** to Current
   Parent.
5. Wait for the window plus queue time.
6. Confirm one new Source `SUPPLIED_IDS` Batch Run, not one per Contact.
7. Confirm Submitted = 2 because both transactions referenced the same two parent Accounts.
8. Inspect Run Requests: one row per definition/Account pair, with no duplicate pair.

This is the primary proof that Run Manager prevents one asynchronous job per changed Contact.

## Test 9: monitoring drilldown and idempotency

1. Open the supplied-ID Batch Run.
2. Choose **View scopes**.
3. Confirm each scope has a correlation Run ID and canonical summary counts.
4. Choose **View retained results**.
5. Confirm Result rows reference one scope Run and contain Record ID, Check, Status, severity/reason,
   and diagnostic summary when provided by core.
6. Repeat a Contact relationship cycle after the earlier Batch finishes.
7. Confirm a new Batch/Run correlation creates new history; duplicate Results do not appear within
   one correlation/record/check combination.

## Test 10: least-privilege personas

Use separate test users if licenses permit.

### Viewer

1. Assign core read access plus **RHC Run Manager Viewer**.
2. Log in as Viewer.
3. Confirm Monitoring can be read according to sharing/access.
4. Confirm the user cannot save definitions, create schedules, or delete operational records.

### Executor

1. Assign target/core execution access plus **RHC Run Manager Executor**.
2. Run the Contact Flow as that user.
3. Confirm the action stages supplied IDs and owned async processing can proceed.
4. Confirm the user does not receive configuration/delete access.

### Admin

1. Assign core Admin plus **RHC Run Manager Admin**.
2. Confirm definitions, schedules, Run Now, and Monitoring work.

## Automated-only resilience evidence

Two destructive/fault-injection behaviors are intentionally not forced through the demo UI:

- partial Batch scope failure while earlier scope data remains committed;
- repeated capture upsert proving Result-key idempotency.

They are covered by `RHCRunManagerExecutionTest.shouldPersistPartialFailure_WhenScopeThrows` and
`RHCRunManagerCaptureServiceTest.shouldUpsertOneResult_WhenCaptureRepeated`. See
[Release Evidence](../RELEASE_EVIDENCE.md) for the verified test run.

## Cleanup

Pause the demo Schedule and deactivate the demo Flow first. Then run:

```bash
sf apex run \
  --file scripts/demo/remove-demo-data.apex \
  --target-org <demo-org-alias> \
  --json
```

Expected debug output: `RHC DEMO REMOVED`.

Cleanup removes only:

- the three exact-name demo definitions;
- their schedules, requests, Batch Runs, scope Runs, and Results;
- the three exact-last-name demo Contacts;
- the four exact-name demo Accounts.

It does not remove the package, core metadata, permission assignments, or non-demo records.

## Demo sign-off sheet

| Test | Tester | Date/time | Evidence ID/screenshot | Pass/Fail | Notes |
| --- | --- | --- | --- | --- | --- |
| Metadata/target derivation | | | | | |
| Guided filtered and scopes | | | | | |
| Capture Both/SKIPPED | | | | | |
| All Accessible | | | | | |
| Schedule lifecycle | | | | | |
| Current/prior supplied IDs | | | | | |
| Duplicate removal | | | | | |
| Cross-transaction consolidation | | | | | |
| Monitoring/idempotency | | | | | |
| Least-privilege personas | | | | | |

