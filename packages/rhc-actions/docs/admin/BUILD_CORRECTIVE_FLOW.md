# Build `Create_Data_Steward_Task`

## Outcome

You will build and activate a no-trigger autolaunched Flow that accepts only approved RHC facts,
creates one stewardship Task related to an Account, and returns the Flow interview GUID.

Build and debug this Flow in a sandbox. The package validates its interface but cannot prove its
business effects.

## Approved contract for this example

Create exactly these resources:

| API name                     | Type | Input | Output | Collection |
| ---------------------------- | ---- | ----- | ------ | ---------- |
| `rhcRecordIdV1`              | Text | Yes   | No     | No         |
| `rhcCheckQualifiedApiNameV1` | Text | Yes   | No     | No         |
| `rhcStatusV1`                | Text | Yes   | No     | No         |
| `rhcSeverityV1`              | Text | Yes   | No     | No         |
| `rhcReasonCodeV1`            | Text | Yes   | No     | No         |
| `rhcInterviewGuidV1`         | Text | No    | Yes    | No         |

No other exposed input is used in this example.

## Step 1: Open Flow Builder

1. Click the gear icon.
2. Click **Setup**.
3. Enter `Flows` in **Quick Find**.
4. Click **Flows**.
5. Click **New Flow**.
6. Select **Autolaunched Flow (No Trigger)**.
7. Click **Create**.

**What you should see:** Flow Builder opens with Start and End, without a record trigger or screen.

**Stop if:** you see Start configuration for a record, schedule, or event, or a Screen element is
required. Return to Flows and create **Autolaunched Flow (No Trigger)**.

## Step 2: Create `rhcRecordIdV1`

1. Click **Toolbox** in the upper-left if the panel is closed.
2. Click **New Resource**.
3. For **Resource Type**, select **Variable**.
4. For **API Name**, enter `rhcRecordIdV1`.
5. For **Description**, enter `Account ID supplied by RHC Actions contract 1.0.`
6. For **Data Type**, select **Text**.
7. Leave the collection option clear.
8. Under **Availability Outside the Flow**, select **Available for input**.
9. Leave **Available for output** clear.
10. Click **Done**.

**What you should see:** `rhcRecordIdV1` under Toolbox resources as a Text variable available for
input.

## Step 3: Create the other four inputs

Repeat Step 2 with these exact values:

| API Name                     | Description                                                   |
| ---------------------------- | ------------------------------------------------------------- |
| `rhcCheckQualifiedApiNameV1` | Exact Check identity supplied by RHC Actions contract 1.0.    |
| `rhcStatusV1`                | Finalized result status supplied by RHC Actions contract 1.0. |
| `rhcSeverityV1`              | Finalized severity supplied by RHC Actions contract 1.0.      |
| `rhcReasonCodeV1`            | Bounded reason code supplied by RHC Actions contract 1.0.     |

For each one:

- select Text;
- select Available for input;
- do not select Available for output; and
- do not make it a collection.

**Stop if:** an API name was automatically changed, misspelled, or given a numeric suffix. Delete
that resource and recreate it with the exact case-sensitive name.

## Step 4: Create the required output

1. Click **New Resource**.
2. Select **Variable**.
3. Enter API Name `rhcInterviewGuidV1`.
4. Enter Description `Flow interview GUID returned to RHC Actions contract 1.0.`
5. Select **Text**.
6. Leave the collection option clear.
7. Leave **Available for input** clear.
8. Select **Available for output**.
9. Click **Done**.

**What you should see:** one Text output named exactly `rhcInterviewGuidV1`.

## Step 5: Add the Task creation element

Obtain the approved Task Owner ID, Subject, Status, Priority, and any required record type from the
business owner before continuing.

1. On the canvas between Start and End, click the plus icon.
2. Click **Create Records**.
3. For **Label**, enter `Create Data Steward Task`.
4. Confirm API Name becomes `Create_Data_Steward_Task` for the element.
5. For the number of records, select **One**.
6. Select **Use separate resources, and literal values**.
7. For **Object**, select **Task**.
8. Add **What ID** and set it to `{!rhcRecordIdV1}`.
9. Add **Subject** and enter the approved subject. For the repository demo kit, enter exactly
   `[RHC Actions Demo] Review primary contact` so verification and cleanup can identify it.
10. Add **Status** and select an approved open status such as `Not Started`.
11. Add **Priority** and select the approved priority.
12. Add **Owner ID** and enter or reference the approved stewardship User or Queue ID.
13. Add only approved bounded context fields. Do not place a raw payload, arbitrary JSON, stack
    trace, or `$Flow.FaultMessage` in a Task field.
14. Click **Done**.

**What you should see:** Start connects to Create Data Steward Task.

**Stop if:** the Task object has required fields you have not mapped, the owner is unknown, or the
Flow would notify a person or call an external system. Resolve the design review first.

## Step 6: Add the interview GUID Assignment

1. Click the plus icon after **Create Data Steward Task**.
2. Click **Assignment**.
3. For **Label**, enter `Set RHC Interview GUID`.
4. Confirm the API name is readable, such as `Set_RHC_Interview_GUID`.
5. Under **Set Variable Values**, choose `rhcInterviewGuidV1`.
6. For Operator, select **Equals**.
7. For Value, select **Running Flow Interview → InterviewGuid**, shown technically as
   `$Flow.InterviewGuid`.
8. Click **Done**.
9. Confirm the Assignment connects to End.

**What you should see:** Start → Create Data Steward Task → Set RHC Interview GUID → End.

## Step 7: Add fault handling

Follow the org's Flow fault-handling standard. At minimum:

1. Select **Create Data Steward Task**.
2. Drag or configure its fault connector to an approved internal fault-handling path.
3. Ensure the path does not send email, Slack, Custom Notification, or an external callout for this
   Actions Flow.
4. Do not pass `$Flow.FaultMessage` into RHC Actions or store it on package records.
5. If the org logs Flow faults, confirm the log is access-controlled and follows retention policy.

RHC Actions stores only a safe package-authored failure code and summary.

## Step 8: Save the Flow

1. Click **Save**.
2. For **Flow Label**, enter `Create Data Steward Task`.
3. Confirm **Flow API Name** is exactly `Create_Data_Steward_Task`.
4. Enter a description explaining the approved Task behavior, owner, and RHC Actions contract `1.0`.
5. Click **Save**.

**Stop if:** Salesforce adds a suffix such as `_2`. Use the exact resulting API name in the policy,
or rename/recreate the Flow according to the org's naming standard. Never assume the label is the
API name.

## Step 9: Debug in the sandbox

1. Create or identify a sandbox Account approved for testing.
2. Copy its 18-character Salesforce record ID from the browser URL or record details.
3. Return to Flow Builder.
4. Click **Debug**.
5. Enter the Account ID for `rhcRecordIdV1`.
6. Enter `Account_Has_Primary_Contact` for `rhcCheckQualifiedApiNameV1`.
7. Enter `FAIL` for `rhcStatusV1`.
8. Enter an approved test severity value for `rhcSeverityV1`.
9. Enter a safe test reason code for `rhcReasonCodeV1`.
10. Run the debug.
11. Read the debug details from start to finish.
12. Open the test Account.
13. Confirm exactly one expected Task exists with the correct owner and fields.
14. Delete or close the test Task according to the sandbox test procedure before repeating.

**Stop if:** zero Tasks, multiple Tasks, an unexpected business-record change, notification, or
external interaction occurs. Do not activate the Flow.

## Step 10: Activate and recheck the active version

1. Return to Flow Builder.
2. Click **Activate**.
3. Return to **Setup → Flows**.
4. Open `Create Data Steward Task`.
5. Confirm the intended version is marked Active.
6. Open the active version and recheck all six contract resources.

**What you should see:** one active no-trigger autolaunched version with five approved inputs and
one required output.

## Flow acceptance checklist

- [ ] Type is Autolaunched Flow (No Trigger).
- [ ] API name is recorded exactly.
- [ ] Five example inputs are scalar Text and Available for input only.
- [ ] No unapproved input is exposed.
- [ ] `rhcInterviewGuidV1` is scalar Text and Available for output only.
- [ ] Every success path sets the interview output.
- [ ] Sandbox Debug creates exactly one expected Task.
- [ ] No alert or external callout exists directly or through dependencies.
- [ ] Intended version is active.
- [ ] Maya and the future runtime identity have least-privilege access.

Next: [Create the manual policy](CREATE_MANUAL_POLICY.md).
