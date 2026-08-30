# Create demo data and test every RHC Actions control

## Outcome

You will create a clearly marked sandbox Account and manual policy, then work through a demo as
Maya. The successful path is:

1. a synthetic finalized Result event says the Account failed `Account_Has_Primary_Contact`;
2. one Pending Action appears;
3. Maya opens the Account and chooses **Run Action**;
4. RHC Actions starts `Create_Data_Steward_Task` once; and
5. one Flow interview, one Action History attempt, and one Task are recorded.

You will also prove rejection, duplicate handling, nonmatching results, contract rejection,
cooldown/loop protection, Flow validation, bounded retries, optional automatic execution, bulk
capture, and cleanup.

This is a sandbox demonstration, not a production data-loading procedure.

## People and time

Reserve two to three hours for the first full run, plus asynchronous wait time.

| Person              | Responsibility                                                |
| ------------------- | ------------------------------------------------------------- |
| Setup administrator | installs, builds Flow, seeds data, changes the policy         |
| Maya                | uses her own Approver user to review, run, and reject actions |
| Runtime user owner  | verifies the dedicated subscriber identity and permissions    |
| Release engineer    | runs CLI scripts, collects logs, and performs exact cleanup   |

One person can wear multiple roles in a disposable sandbox, but Maya's approval must still be made
while signed in as the Approver test user.

## Before you touch data

1. Confirm this is a sandbox or disposable test org. The URL normally contains `sandbox` or your
   organization's test-domain name.
2. Open **Setup → Company Information** and record the Organization ID in the test evidence.
3. Open **Setup → Installed Packages** and confirm Record Health Check core and RHC Actions are
   installed.
4. Complete [Assign permissions](ASSIGN_PERMISSIONS.md).
5. Complete [Build the corrective Flow](BUILD_CORRECTIVE_FLOW.md).
6. In the Flow's Create Records element, make Subject exactly
   `[RHC Actions Demo] Review primary contact`.
7. Activate the intended Flow version.
8. Confirm the Flow has no email, Slack, Custom Notification, external callout, or unreviewed
   subflow.

**Stop if:** this is production, the Account or Task automation can reach real people, the Task
owner is not a sandbox user/queue, or the release engineer cannot perform cleanup.

## Step 1: Open a terminal in the package

The release engineer performs this step while sharing the screen with the administrator.

1. Open Terminal.
2. Change directory to the checked-out `packages/rhc-actions` directory.
3. Enter `sf org list` and press Return.
4. Find the sandbox username and note its Alias. In the commands below, replace
   `<sandbox-alias>` with that Alias; do not type `<` or `>`.
5. Enter this read-only command and press Return:

```bash
sf apex run --file scripts/demo/apex/00_preflight.apex --target-org <sandbox-alias>
```

6. Read the final output.

**What you should see:** `RHC_ACTIONS_DEMO_PREFLIGHT=PASS` and an Active Flow Version ID.

**Stop if:** an object is missing, the Flow is missing/inactive, or the Flow is not Autolaunched
Flow. Correct the installation or Flow before creating demo data.

## Step 2: Seed the synthetic Account and policy

1. In Terminal, enter:

```bash
sf apex run --file scripts/demo/apex/01_seed_demo.apex --target-org <sandbox-alias>
```

2. Press Return.
3. Copy the logged `RHC_ACTIONS_DEMO_ACCOUNT_ID` and `RHC_ACTIONS_DEMO_POLICY_ID` into the evidence
   sheet.
4. In Salesforce, click the App Launcher.
5. Search for and open **RHC Actions**.
6. Click **Corrective Action Policies**.
7. Select the **All** list view.
8. Open the policy whose Check Set is `RHC_Actions_Demo` and Check is
   `Account_Has_Primary_Contact`.
9. Confirm every value:

| Field                        | Demo value                                      |
| ---------------------------- | ----------------------------------------------- |
| Active                       | selected                                        |
| Check Set Qualified API Name | `RHC_Actions_Demo`                              |
| Check Qualified API Name     | `Account_Has_Primary_Contact`                   |
| Matching Statuses            | `FAIL`                                          |
| Matching Severity            | `HIGH`                                          |
| Flow API Name                | `Create_Data_Steward_Task`                      |
| Mode                         | MANUAL APPROVAL                                 |
| Automatic Execution Enabled  | clear                                           |
| Cooldown Minutes             | `60`                                            |
| Retry Limit                  | `1`                                             |
| Input Contract Version       | `1.0`                                           |
| Selected mappings            | Record ID, Check, Status, Severity, Reason Code |

10. Open the App Launcher, search **Accounts**, and open Accounts.
11. Search for `[RHC ACTIONS DEMO] Account Missing Primary Contact` and open it.
12. Confirm it contains no real customer information.

The seed can be run again. It reuses the exact Account and policy and restores the policy to the
safe manual baseline. It does not delete prior Pending Actions, History, or Tasks, and deterministic
Event IDs intentionally cannot be reused to create another execution. Run the cleanup preview and
approved cleanup before repeating a completed scenario from the beginning. The seed stops instead
of guessing if duplicate exact records already exist.

### Confirm the four package personas against the seeded records

1. As the package administrator, open the policy and confirm **Edit** is available.
2. As Maya, open **RHC Actions Review** and the marked Account; confirm she can review but does not
   use the policy editor for this test.
3. As the Viewer, open Corrective Action Policies, Pending Actions, and Action History; confirm
   shared records are readable and **New**, **Edit**, **Run Action**, and **Reject** are unavailable.
4. Do not use the Runtime identity interactively. The release engineer verifies it from subscriber
   and History evidence during automatic execution.

**Stop if:** the Viewer can mutate package records, Maya cannot read the Account/execute the Flow,
or an individual approver is configured as the automatic runtime identity.

## Step 3: Demonstrate Maya's manual success path

1. Ask Maya to sign in using the test Approver user.
2. In Terminal, publish one matching event:

```bash
sf apex run --file scripts/demo/apex/02_publish_manual_fail.apex --target-org <sandbox-alias>
```

3. Copy the logged Event ID into the evidence sheet.
4. Maya opens **App Launcher → RHC Actions → RHC Actions Review**.
5. Wait briefly for Platform Event delivery, then refresh once.
6. Locate Check `Account_Has_Primary_Contact`, Status `FAIL`, Severity `HIGH`.
7. Open the row action menu and click **Review**.
8. Click the Record link and confirm it opens the marked demo Account.
9. Return to the review card.
10. Confirm the Flow is `Create_Data_Steward_Task` and the Reason Code is
    `NO_PRIMARY_CONTACT`.
11. Click **Run Action** exactly once.
12. Wait for the **Action queued** toast. Do not click again.
13. Open **RHC Actions → Pending Actions**, select **All**, and open the matching Event ID.
14. Refresh until Queue Status is `SUCCEEDED`.
15. Confirm Attempt Count is `1`, Approved By is Maya, and Flow Interview ID is populated.
16. Open **RHC Actions → Action History**, select **All**, and open the related record.
17. Confirm Outcome `SUCCEEDED`, Attempt Number `1`, the same interview ID, and no error.
18. Open the demo Account's Activity/Tasks related list.
19. Confirm exactly one Task has subject `[RHC Actions Demo] Review primary contact`.

**Pass:** one event produced one Pending Action, one execution attempt, one interview, and one Task.

## Step 4: Prove re-running the same Event ID does not execute twice

First, re-run `02_publish_manual_fail.apex`. Its deterministic Event ID is unchanged.

1. Wait for event delivery.
2. Refresh RHC Actions Review and Pending Actions.
3. Confirm there is still only one Pending Action for the `...-MANUAL-...` Event ID.
4. Confirm there is still one History attempt and one demo Task.
5. Now run the two-in-one duplicate script:

```bash
sf apex run --file scripts/demo/apex/04_publish_duplicate_fail.apex --target-org <sandbox-alias>
```

6. Wait and refresh.
7. Confirm exactly one new proposal has the logged duplicate Event ID, even though the script
   published it twice.
8. Maya clicks **Reject** for that proposal so it cannot create another Task.

**Pass:** the unique policy-plus-Event-ID claim prevents duplicate events and retries from creating
two executions.

## Step 5: Demonstrate rejection

1. Run:

```bash
sf apex run --file scripts/demo/apex/03_publish_rejection_fail.apex --target-org <sandbox-alias>
```

2. Maya refreshes **RHC Actions Review** and opens the matching proposal.
3. Maya reviews the demo Account and clicks **Reject**.
4. Open **Pending Actions → All** and confirm Queue Status `REJECTED`.
5. Confirm Approved By is Maya and Completed At is populated.
6. Confirm no Action History exists for this proposal and no additional demo Task exists.

**Pass:** rejection records the human decision without starting Flow.

## Step 6: Demonstrate policy matching and publication boundaries

Run the PASS event:

```bash
sf apex run --file scripts/demo/apex/05_publish_nonmatching_pass.apex --target-org <sandbox-alias>
```

Wait, then confirm no Pending Action has its Event ID. The policy matches only `FAIL` plus `HIGH`.

Run the unsupported contract event:

```bash
sf apex run --file scripts/demo/apex/07_publish_unsupported_contract.apex --target-org <sandbox-alias>
```

Wait, then confirm no Pending Action has its Event ID. RHC Actions accepts only core contract `1.0`.

To test publication `NONE`, do not use a synthetic event script:

1. Open the approved core entry point for the marked demo Account.
2. Choose or configure publication mode `NONE`.
3. Run `Account_Has_Primary_Contact` once.
4. Record the core run time and result.
5. Wait longer than normal event delivery time.
6. Confirm there is no new Result Platform Event evidence and no new Pending Action.

**Pass:** `NONE` publishes nothing, while a published nonmatching or unsupported result is safely
ignored.

## Step 7: Demonstrate cooldown and loop prevention

Complete this within 60 minutes of Step 3's successful action.

1. Run:

```bash
sf apex run --file scripts/demo/apex/06_publish_cooldown_fail.apex --target-org <sandbox-alias>
```

2. Maya waits for the new proposal, opens it, reviews it, and clicks **Run Action** once.
3. Open the Pending Action and refresh until terminal.
4. Confirm Queue Status `SUPPRESSED`.
5. Open its Action History and confirm Outcome `SUPPRESSED` and Error Code `COOLDOWN_ACTIVE`.
6. Confirm the Account still has exactly one demo Task.

This is the visible loop guard: a Flow may trigger another core evaluation, but the same policy and
record cannot execute successfully again inside the policy cooldown.

## Step 8: Demonstrate active Flow and contract validation

1. As setup administrator, open the demo policy.
2. Click **Edit**.
3. Replace Flow API Name with `RHC_Actions_Demo_Missing_Flow`.
4. Click **Save**.
5. Run:

```bash
sf apex run --file scripts/demo/apex/08_publish_contract_validation_fail.apex --target-org <sandbox-alias>
```

6. Maya opens the proposal and clicks **Run Action**.
7. Confirm the page reports that policy/Flow validation failed and no success toast appears.
8. Confirm no Flow interview, History attempt, or Task was created for this Event ID.
9. Maya rejects the still-pending proposal.
10. The administrator edits the policy, restores Flow API Name
    `Create_Data_Steward_Task`, and saves.

Repeat this exercise if desired with an inactive Flow version or one missing a selected scalar Text
input. Restore the approved active version afterward.

## Step 9: Demonstrate retry limit with an intentionally failing Flow

This Flow exists only in the sandbox. It must fail before committing a business mutation.

### Create the failing Flow

1. Open **Setup → Flows → New Flow**.
2. Select **Autolaunched Flow (No Trigger)** and click **Create**.
3. Create scalar Text input `rhcRecordIdV1`, Available for input.
4. Create scalar Text input `rhcEventIdV1`, Available for input.
5. Create scalar Text output `rhcInterviewGuidV1`, Available for output.
6. Add **Create Records** for one Task using separate literal values.
7. Set Subject to `[RHC Actions Demo] This Task must never commit`.
8. Set What ID to `{!rhcRecordIdV1}`.
9. Set Owner ID to `{!rhcEventIdV1}`. The demo Event ID is deliberately not a Salesforce User or
   Queue ID, so Task creation fails at runtime.
10. Add any org-required Task fields, but do not add a fault connector that converts the fault to a
    successful end.
11. Add an Assignment after Create Records that sets `rhcInterviewGuidV1` to
    `$Flow.InterviewGuid`.
12. Save as label `RHC Actions Demo Always Fail` and API name
    `RHC_Actions_Demo_Always_Fail`.
13. Activate it.

### Point the policy to the failure Flow

1. Edit the demo policy.
2. Set Flow API Name to `RHC_Actions_Demo_Always_Fail`.
3. Keep Mode MANUAL APPROVAL and Retry Limit `1`.
4. Select only **Map Record ID** and **Map Event ID**.
5. Clear the other mapping checkboxes and save.
6. Run:

```bash
sf apex run --file scripts/demo/apex/09_publish_retry_fail.apex --target-org <sandbox-alias>
```

7. Maya opens the proposal and clicks **Run Action** once.
8. Open its Pending Action. Confirm first that Queue Status becomes `RETRY WAIT`, Attempt Count `1`,
   and Last Error Code `FLOW_START_RETRYABLE`.
9. Wait at least one minute for the delayed Queueable retry, then refresh.
10. Confirm final Queue Status `FAILED`, Attempt Count `2`, and Last Error Code
    `FLOW_START_FAILED`.
11. Confirm two History records: attempt 1 `FAILED_RETRYABLE`, attempt 2 `FAILED_FINAL`.
12. Confirm the failure Task does not exist.
13. Restore the policy by running `01_seed_demo.apex` again.
14. In **Setup → Flows**, deactivate the intentionally failing Flow.

**Pass:** Retry Limit `1` means one initial attempt plus one retry—never unlimited retries.

## Step 10: Optional automatic-execution demonstration

Do this only after the manual tests pass. Complete
[Enable automatic execution](ENABLE_AUTOMATIC_EXECUTION.md), including the dedicated subscriber
identity. Automatic execution has three gates:

1. Mode is AUTOMATIC;
2. Automatic Execution Enabled is selected; and
3. the Platform Event subscriber identity has the dedicated
   `RHC_Actions_Automatic_Execution` Custom Permission through RHC Actions Runtime.

Before any positive automatic test, preserve the manual evidence, run the exact cleanup, seed
again, and then enable the three gates. Otherwise the earlier successful manual action can correctly
trigger the 60-minute cooldown and make an automatic test appear to fail.

### Prove fail-closed behavior

1. Keep Mode AUTOMATIC and Automatic Execution Enabled selected.
2. Use the standard Apex test evidence for the missing-Custom-Permission branch unless the release
   engineer has prepared an approved test-only subscriber identity. `RHC Actions Runtime` includes
   the automatic Custom Permission, so do not simply unassign Runtime: doing that also removes
   package object/field access and can stop capture instead of proving fail-closed behavior.
3. For an installed-org negative test, the security owner creates a temporary customer-owned
   least-privilege Permission Set with the same event, package object/field, and required Apex
   access as Runtime but without `RHC_Actions_Automatic_Execution`; the release engineer configures
   the subscriber to that test identity. Record this as a temporary security artifact and remove it
   after the test.
4. Run:

```bash
sf apex run --file scripts/demo/apex/10_publish_automatic_fail.apex --target-org <sandbox-alias>
```

5. Confirm the event becomes `PENDING REVIEW` and does not execute automatically.
6. Reject it, restore the approved subscriber identity and Runtime assignment, and remove the
   temporary customer Permission Set according to change control.

Because that script's Event ID is deterministic, clean and reseed before the positive test, or
change neither evidence nor expectations. For a clean positive run, execute the preview and cleanup
steps below, seed again, restore all three gates, then run `10_publish_automatic_fail.apex`.

### Prove all gates pass

1. Confirm the runtime subscriber identity and all three gates.
2. Run:

```bash
sf apex run --file scripts/demo/apex/10_publish_automatic_fail.apex --target-org <sandbox-alias>
```

3. Do not sign in as Maya and do not click Run Action.
4. Wait for event delivery and Queueable execution.
5. Confirm Pending Action `SUCCEEDED`, Approved By blank, one History, one interview, and one Task.
6. Confirm History Initiated By is the dedicated runtime identity.
7. Immediately restore the policy to manual mode by running `01_seed_demo.apex`.

## Step 11: Optional bulk demonstration

This creates 251 manual proposals and consumes sandbox event/storage capacity. Run it only in a
disposable environment with the policy in manual mode.

1. Confirm the demo policy is MANUAL APPROVAL.
2. Record the current number of demo Pending Actions.
3. Run:

```bash
sf apex run --file scripts/demo/apex/11_publish_bulk_251.apex --target-org <sandbox-alias>
```

4. Confirm the terminal reports `RHC_ACTIONS_DEMO_BULK_ACCEPTED=251`.
5. Wait for all asynchronous event batches.
6. Confirm 251 new Pending Actions with Event IDs beginning `RHC-ACT-DEMO-BULK-`.
7. Confirm none executed because the policy is manual.
8. Do not approve 251 actions. Proceed to cleanup.

The package's Apex tests are the authoritative governor-limit regression proof. This operator
exercise additionally proves the installed subscriber accepts multiple asynchronous batches.

## Step 12: Capture a read-only evidence summary

Run:

```bash
sf apex run --file scripts/demo/apex/12_verify_demo.apex --target-org <sandbox-alias>
```

Attach the output to the test record. It lists only the exact demo policy's actions/history and the
exact-subject Tasks on the exact demo Account. Also capture screenshots of the manual review,
successful Pending Action, matching History, Task, cooldown suppression, and retry failure.

## Step 13: Preview and perform cleanup

Cleanup deletes audit data and therefore requires an authorized release or System Administrator.
The normal Admin/Approver/Runtime/Viewer permission sets intentionally do not grant this delete.

1. Run the read-only preview:

```bash
sf apex run --file scripts/demo/apex/13_cleanup_preview.apex --target-org <sandbox-alias>
```

2. Compare Account, policy, Pending Action, History, and Task counts to the evidence.
3. Stop if any count is unexpected. Inspect records before deleting.
4. When approved, run:

```bash
sf apex run --file scripts/demo/apex/14_cleanup_execute.apex --target-org <sandbox-alias>
```

5. Run `13_cleanup_preview.apex` again.
6. Confirm every count is zero.
7. In **Setup → Flows**, deactivate or delete the sandbox-only
   `RHC_Actions_Demo_Always_Fail` Flow according to change control.

The execute script deletes only:

- the exact `[RHC ACTIONS DEMO] Account Missing Primary Contact` Account;
- the exact `RHC_Actions_Demo` / `Account_Has_Primary_Contact` policy;
- Actions and History related to that policy;
- Tasks on that Account with exact subject `[RHC Actions Demo] Review primary contact`.

## Final acceptance checklist

- [ ] Preflight passed in the recorded sandbox.
- [ ] Seed created one marked Account and one safe manual policy.
- [ ] Maya manually approved one action after reviewing the Account.
- [ ] Success produced one Flow interview, History attempt, and Task.
- [ ] Same Event ID did not create or execute twice.
- [ ] Rejection started no Flow.
- [ ] PASS and unsupported contract created no action.
- [ ] Core publication `NONE` created no event and no action.
- [ ] Cooldown suppressed a second policy/record execution.
- [ ] Missing/inactive/incompatible Flow failed validation without execution.
- [ ] Retry Limit 1 stopped after two total attempts.
- [ ] Automatic mode failed closed without its dedicated permission.
- [ ] If enabled, automatic execution used the dedicated runtime identity.
- [ ] Admin, Approver, Runtime, and Viewer behavior matched the permission matrix.
- [ ] The Flow exposed only selected versioned allow-listed inputs and the interview GUID output.
- [ ] Optional 251-event capture completed without automatic execution.
- [ ] No human alert, external callout, or unrelated mutation occurred.
- [ ] Preview matched evidence and exact-scope cleanup returned all counts to zero.

## What this demo cannot prove

- It cannot make the original health check and later corrective Flow atomic; they are separate
  asynchronous transactions by design.
- It cannot prove every possible Flow side effect. Review the active version, subflows, record
  automation, and permissions.
- It cannot override the execution identity's sharing, CRUD, FLS, Flow, queue, or Apex access.
- Synthetic events isolate the extension. Before release, also execute one approved real core
  Check with publication enabled and repeat the successful manual path.
