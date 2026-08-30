# Monitor and troubleshoot RHC Actions

## Daily navigation

1. Open App Launcher.
2. Search for and open **RHC Actions**.
3. Open **Pending Actions**.
4. Select **All** or the approved operational list view.
5. Review non-terminal and failed records.
6. Open **Action History**.
7. Review failed and suppressed outcomes.

Do not edit system-managed queue, identity, attempt, event, or error fields to make a dashboard look
healthy.

## Pending Action statuses

| Status           | Plain-language meaning                                                     | Administrator response                             |
| ---------------- | -------------------------------------------------------------------------- | -------------------------------------------------- |
| `PENDING_REVIEW` | Waiting for a human decision                                               | Review the record and proposal; run or reject      |
| `QUEUED`         | Approved and waiting for asynchronous Apex                                 | Check Apex Jobs if it remains old                  |
| `RUNNING`        | Reserved value; current Day-1 execution normally replaces it before commit | Treat a persisted value as unexpected and escalate |
| `SUCCEEDED`      | Flow completed and audit was written                                       | Confirm business result when sampled               |
| `RETRY_WAIT`     | A retryable Flow start failed and a delayed retry remains                  | Check Available At, Flow access, and dependencies  |
| `FAILED`         | Contract invalid or attempts exhausted                                     | Read safe error fields and correct the cause       |
| `SUPPRESSED`     | Recent success for this policy/record is inside cooldown                   | Usually expected loop protection                   |
| `REJECTED`       | Approver declined the proposal                                             | No Flow attempt or History record is expected      |

## Action History outcomes

| Outcome            | Meaning                                                 |
| ------------------ | ------------------------------------------------------- |
| `SUCCEEDED`        | The attempt completed and returned `rhcInterviewGuidV1` |
| `FAILED_RETRYABLE` | The attempt failed, and another attempt was permitted   |
| `FAILED_FINAL`     | The attempt failed without another retry                |
| `SUPPRESSED`       | Cooldown prevented Flow execution                       |

## Empty review queue troubleshooting

Check in this exact order:

1. Open the policy and confirm **Active** is selected.
2. Compare Check Qualified API Name character by character with core.
3. If Check Set is populated, compare it character by character.
4. Confirm Matching Statuses includes the exact event status separated with semicolons.
5. Confirm Matching Severity is blank or exact.
6. Confirm the health check actually ran after the policy was activated.
7. Confirm the caller published Result events:
   - publication `NONE` produces nothing;
   - programmatic callers need `ACTIONABLE` or `ALL`;
   - interactive configuration must publish the Result event.
8. Confirm the event subscriber identity has RHC Actions Runtime and record access.
9. Allow for asynchronous Platform Event delivery.
10. Review failed Platform Event subscribers and Apex errors with the release administrator.

Saving a policy does not evaluate historical results.

## “Approval permission is required”

1. Open **Setup → Permission Sets → RHC Actions Approver**.
2. Click **Manage Assignments**.
3. Confirm Maya is listed.
4. If not, click **Add Assignments**, select Maya, click **Next**, then **Assign**.
5. Ask Maya to refresh or sign out and back in.
6. Retry from RHC Actions Review.

Do not grant RHC Actions Admin solely to bypass this message.

## Flow contract invalid

Open **Setup → Flows → Create Data Steward Task**, then confirm:

1. the intended version is active;
2. type is Autolaunched Flow (No Trigger);
3. every exposed input name belongs to the contract allow-list;
4. every selected policy mapping has a matching Text input;
5. no contract variable is a collection;
6. `rhcInterviewGuidV1` is Text, non-collection, Available for output, and not input; and
7. the success path assigns `$Flow.InterviewGuid` to it.

Then compare the policy's Flow API Name and mapping checkboxes. Correct and activate a new Flow
version if needed. Do not edit a failed Pending Action into QUEUED; generate a new controlled event
after the fix.

## Flow start failure

1. Open the Pending Action.
2. Read **Last Error Code**, **Last Error Summary**, **Attempt Count**, and **Available At**.
3. Open the related History attempts.
4. Use Flow Interview ID in Flow monitoring if present.
5. Identify the execution identity from History **Initiated By**.
6. Confirm that identity's Flow, Account, Task, field, queue, record type, subflow, Apex, and
   downstream access.
7. Debug the same active Flow version with safe equivalent inputs in a sandbox.
8. Correct the cause before generating another event.

RHC Actions does not store exception text or stack traces. Use protected Salesforce Flow/Apex
monitoring for technical detail.

## Cooldown suppression

1. Open the suppressed Pending Action.
2. Note Policy and Record ID.
3. Open the policy and note Cooldown Minutes.
4. Find the recent successful History record for the same policy and record.
5. Compare its Completed At time to the suppressed proposal.
6. Confirm suppression occurred inside the configured period.

Do not reduce cooldown merely to make a suppressed test run. Wait for the approved period or use a
different sandbox record.

## Queueable delay

If QUEUED or RETRY WAIT is older than the operational threshold, or RUNNING is persisted at all:

1. Open **Setup**.
2. Enter `Apex Jobs` in **Quick Find**.
3. Click **Apex Jobs**.
4. Look for RHC Actions Queueable failures near the Pending Action time.
5. Record Job ID, status, submitting user, and times.
6. Review org asynchronous Apex limits and competing backlog.
7. Escalate to the release/Flow support owner.

## Incident: unexpected Flow side effect

1. Open the affected policy.
2. Click **Edit**.
3. Clear **Active**.
4. Click **Save**.
5. Repeat for every policy using the same Flow.
6. Preserve Pending Action, History, Event ID, Run ID, Record ID, users, times, and Flow Interview ID.
7. Notify the Flow and data owners.
8. Review committed business changes and downstream automation.
9. Use an approved remediation process; RHC Actions cannot roll back committed Flow effects.
10. Re-test in a sandbox before reactivation.

## Information to include in a support ticket

Include safe identifiers only:

- org ID and environment;
- Actions and core versions;
- Policy number and ID;
- Pending Action number and ID;
- History number and ID;
- Event ID, Run ID, and Record ID;
- Queue Status, Outcome, Attempt Count, and times;
- Approved By and Initiated By;
- Flow API name, active version, and interview ID;
- safe Error Code and Error Summary; and
- relevant Apex Job ID.

Do not paste raw payloads, unrestricted field values, stack traces, tokens, credentials, or
installation keys into general support tickets.
