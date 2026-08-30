# Test manual approval end to end

## Outcome

One controlled Account failure produces one Pending Action. Maya reviews it, queues the Flow once,
and verifies one Task, one Flow interview GUID, and one Action History attempt.

## Test safety

- Use a sandbox.
- Use a test Account approved for mutation.
- Ensure the Task owner knows this is a test.
- Remove or close prior test Tasks so duplicate detection is unambiguous.
- Do not repeatedly click Run/Rerun or Run Action while asynchronous work is pending.

## Step 1: Prepare the Account

1. Open the App Launcher.
2. Open the app used to manage Accounts.
3. Open or create the approved test Account.
4. Make the Account intentionally fail `Account_Has_Primary_Contact` using the approved test setup.
5. Copy the Account's 18-character record ID from the URL or record details.
6. Confirm Maya can open this Account.
7. Confirm no existing open Task has the test subject used by the Flow.

**Stop if:** making the record fail would affect real customer work or production automation.

## Step 2: Confirm the policy and Flow are ready

1. Open **RHC Actions**.
2. Open **Corrective Action Policies**.
3. Open the example policy.
4. Confirm Active is selected.
5. Confirm Mode is MANUAL APPROVAL.
6. Confirm Automatic Execution Enabled is clear.
7. Open **Setup → Flows** in another tab.
8. Open `Create Data Steward Task`.
9. Confirm the intended version is active.

## Step 3: Run the health check through the real intended route

Use the same approved core entry point that will publish results in normal operation. This may be a
core record card, an approved Flow, or an Apex-based process.

1. Open the test Account.
2. Start `Account_Has_Primary_Contact` or its Check Set through the approved route.
3. Confirm the resulting status is `FAIL`.
4. Confirm the caller publishes finalized Result events:
   - interactive configuration must publish the Result event; or
   - programmatic invocation must request `ACTIONABLE` or `ALL`.
5. Do not use publication `NONE`.
6. Record the run time and, when displayed, the Run ID.

**What you should see:** the health check reports FAIL. The RHC Actions queue can still be empty for
a short time because event delivery is asynchronous.

## Step 4: Wait for the Pending Action without creating duplicates

1. Open **RHC Actions → RHC Actions Review**.
2. Refresh the browser after a brief wait.
3. Look for a row with:
   - Check `Account_Has_Primary_Contact`;
   - Status `FAIL`;
   - the test Account Record ID; and
   - Flow `Create_Data_Steward_Task`.
4. If the row is not present, wait according to the org's Platform Event service level and refresh
   once more.
5. Do not rerun the health check merely to force an immediate row.

**What you should see:** exactly one matching row.

**Stop if:** more than one row exists for the same policy and Event ID, the wrong Flow is displayed,
or the Record ID is not the test Account. Preserve the rows and investigate before approving.

## Step 5: Maya reviews the proposal

1. Maya signs in using her own user.
2. Maya opens **RHC Actions → RHC Actions Review**.
3. Maya locates the matching row.
4. Maya opens the row-action menu at the right side of the row.
5. Maya clicks **Review**.
6. In the review card, Maya reads:
   - Pending Action number;
   - Record link;
   - Check;
   - result status and severity;
   - reason code; and
   - Flow API name.
7. Maya clicks the Record link, which opens the Account in a new tab.
8. Maya confirms this is the intended test Account and a stewardship Task is appropriate.
9. Maya returns to the RHC Actions tab.

**Stop if:** Maya cannot see the Account, the record is wrong, the result is no longer understood,
or the Flow is not approved. Maya should click **Reject** or Cancel according to the test plan.

## Step 6: Maya runs the action once

1. Maya clicks **Run Action** once.
2. Maya waits without clicking the button again.
3. Maya confirms the green **Action queued** toast appears.
4. Maya confirms the row leaves the manual review list after refresh.

**What this means:** approval was authorized, the Pending Action was locked and moved to QUEUED,
and asynchronous execution was requested. It does not yet prove Flow success.

If the page shows a contract error, stop and follow the Flow contract troubleshooting steps. The
Flow was not started by the approval request.

## Step 7: Verify the Pending Action

1. In RHC Actions, click **Pending Actions**.
2. Select the **All** list view.
3. Sort by Created Date descending if needed.
4. Open the matching Pending Action.
5. Refresh until Queue Status is terminal.
6. For the successful test, confirm:
   - Queue Status = `SUCCEEDED`;
   - Attempt Count = `1`;
   - Approved By = Maya;
   - Approved At is populated;
   - Flow Interview ID is populated;
   - Event ID and Run ID are populated as supplied by core; and
   - Last Error Code and Last Error Summary are blank.

**Stop if:** status is FAILED, RETRY WAIT, or SUPPRESSED. Do not generate another event until the
state is understood.

## Step 8: Verify Action History

1. Click **Action History**.
2. Select the **All** list view.
3. Open the record related to the test Pending Action.
4. Confirm:
   - Outcome = `SUCCEEDED`;
   - Attempt Number = `1`;
   - Approved By = Maya;
   - Initiated By is the identity that executed the queued work;
   - Started At and Completed At are populated;
   - Flow Interview ID matches Pending Action;
   - Event ID, Record ID, and Run ID match; and
   - Error Code and Error Summary are blank.

**What you should see:** exactly one successful History record for the first attempt.

## Step 9: Verify the business result

1. Open the test Account.
2. Open its Activity or Tasks related list.
3. Confirm exactly one new Task with the approved subject.
4. Confirm What ID relates it to the correct Account.
5. Confirm Status, Priority, Owner, and approved context fields are correct.
6. Confirm no Account field, Contact, notification, email, or external system changed unexpectedly.

## Step 10: Test duplicate-event protection with a release engineer

Do not fabricate package records through the UI. A release engineer performs the automated or
controlled duplicate-delivery test and shows the administrator the evidence:

1. deliver the same Event ID twice for the same policy;
2. confirm the unique idempotency claim allows only one Pending Action;
3. confirm the Flow starts once; and
4. preserve the Apex test or sandbox evidence in the release record.

The standard Apex suite includes this scenario. A normal administrator should not replay Platform
Events manually in production.

## Step 11: Optional rejection test

Use a separate controlled event.

1. Create another approved matching test result.
2. Wait for its Pending Action.
3. Maya opens **Review**.
4. Maya clicks **Reject**.
5. Confirm the row leaves RHC Actions Review.
6. Open Pending Actions and confirm Queue Status = `REJECTED`, Approved By = Maya, and Completed At
   is populated.
7. Confirm no Flow started and no Task was created.
8. Confirm no Action History attempt exists for the rejection. This is expected because no Flow
   attempt occurred.

## Manual acceptance checklist

- [ ] One approved failing Account produced one Pending Action.
- [ ] Maya reviewed the actual Account before approval.
- [ ] Action queued toast appeared after one click.
- [ ] Pending Action succeeded with Attempt Count 1 and Maya recorded.
- [ ] One History record contains the matching interview GUID.
- [ ] Exactly one expected Task was created.
- [ ] No unexpected alert, callout, or business mutation occurred.
- [ ] Duplicate-event protection evidence exists.
- [ ] Optional rejection test produced no Flow attempt.

Next: [Monitor and troubleshoot](MONITOR_AND_TROUBLESHOOT.md).
