# Create the manual corrective action policy

## Outcome

You will create one inactive policy, review every value, then activate it in manual mode. The policy
matches `Account_Has_Primary_Contact` with status `FAIL` and maps five facts to
`Create_Data_Steward_Task`.

## Obtain exact identities before creating the policy

Record these values in the implementation ticket:

- exact Check Qualified API Name: `Account_Has_Primary_Contact`;
- exact Check Set Qualified API Name, or an approved decision to leave it blank;
- expected result status: `FAIL`;
- optional exact severity, or an approved decision to match any severity;
- active Flow API name: `Create_Data_Steward_Task`;
- cooldown approved by the business and automation owners; and
- retry limit approved for the Flow's side-effect risk.

Do not copy a translated label into an API-name field. Qualified API Names are case-sensitive and
can include a namespace.

## Step 1: Open Corrective Action Policies

1. Click the App Launcher nine-dot grid.
2. Click **View All** if needed.
3. Enter `RHC Actions` in **Search apps and items**.
4. Click **RHC Actions**.
5. In the app navigation bar, click **Corrective Action Policies**.
6. Select the **All** list view if another view is active.
7. Click **New**.

**What you should see:** a new Corrective Action Policy form. The policy number is generated after
save.

**Stop if:** **New** is missing. Confirm RHC Actions Admin is assigned; do not create the record
through Data Loader or another bypass.

## Step 2: Enter the matching identity

1. Leave **Active** clear.
2. For **Check Set Qualified API Name**:
   - leave it blank when the policy is intentionally allowed to match this Check in any Check Set;
   - otherwise enter the exact approved Check Set Qualified API Name.
3. For **Check Qualified API Name**, enter `Account_Has_Primary_Contact`.
4. For **Matching Statuses**, enter `FAIL`.
5. For **Matching Severity**, leave blank to match any severity, or enter one exact approved value.

**Why:** Check, optional Check Set, status, and optional severity are all exact comparisons. `FAIL`
does not match `fail`, and spaces around identifiers change the identity.

For multiple statuses, use semicolons with no commentary, for example `FAIL;ERROR`. Do not use
commas.

## Step 3: Enter the Flow and execution controls

1. For **Flow API Name**, enter `Create_Data_Steward_Task`.
2. For **Mode**, select **MANUAL APPROVAL**.
3. Leave **Automatic Execution Enabled** clear.
4. For **Cooldown Minutes**, enter `60` for the example, or the approved value of at least 1.
5. For **Retry Limit**, enter `1` for the example, or the approved whole number from 0 through 3.
6. For **Input Contract Version**, enter `1.0`.

**Stop if:** someone requests automatic mode to avoid testing manual approval. Finish the manual
acceptance test first.

## Step 4: Select only the mappings used by the Flow

Select:

- **Map Record ID**
- **Map Check**
- **Map Status**
- **Map Severity**
- **Map Reason Code**

Leave clear:

- **Map Run ID**
- **Map Check Set**
- **Map Event ID**

**Why:** each selected checkbox requires a matching scalar Text input in the active Flow. The
example Flow created exactly the five selected inputs.

**Stop if:** the Flow resource list does not match these selections. Return to the active Flow and
correct the contract before activating the policy.

## Step 5: Save the inactive policy

1. Review every field against this table.

| Field                        | Expected example value                          |
| ---------------------------- | ----------------------------------------------- |
| Active                       | Clear                                           |
| Check Set Qualified API Name | Approved exact value or blank by design         |
| Check Qualified API Name     | `Account_Has_Primary_Contact`                   |
| Matching Statuses            | `FAIL`                                          |
| Matching Severity            | Approved exact value or blank by design         |
| Flow API Name                | `Create_Data_Steward_Task`                      |
| Mode                         | MANUAL APPROVAL                                 |
| Automatic Execution Enabled  | Clear                                           |
| Cooldown Minutes             | `60`                                            |
| Retry Limit                  | `1`                                             |
| Input Contract Version       | `1.0`                                           |
| Selected mappings            | Record ID, Check, Status, Severity, Reason Code |

2. Click **Save**.
3. Record the generated Corrective Action Policy Number in the implementation ticket.

**What you should see:** a saved policy detail page with Active unchecked.

## Step 6: Conduct a second-person review

Have another approved administrator or Flow owner compare:

1. the policy Check identity to the core Check definition;
2. the Flow API Name to the active Flow;
3. the policy mapping checkboxes to active Flow inputs;
4. the cooldown to expected reevaluation timing;
5. the retry limit to Task duplicate risk; and
6. manual mode and automatic checkbox state.

Record reviewer name and date in the change ticket. The Day-1 package does not include a standalone
policy validation button or a policy approval object.

## Step 7: Activate the policy

1. On the policy record, click **Edit**.
2. Select **Active**.
3. Reconfirm **Mode** is MANUAL APPROVAL.
4. Reconfirm **Automatic Execution Enabled** is clear.
5. Click **Save**.

**What you should see:** Active selected on the saved record.

The policy is now eligible for future events only. Saving or activating it does not scan historical
results and does not run a Check.

## Understand when validation happens

There is no **Validate Policy** button in the current package.

For manual actions:

1. a matching event creates a Pending Action;
2. Maya clicks **Run Action**;
3. the server validates the active Flow and contract;
4. the request is queued; and
5. execution locks the Pending Action and validates again before starting Flow.

If validation fails, the Flow does not start. The failed proposal remains available for operational
review.

## Policy acceptance checklist

- [ ] Exact identities came from approved core configuration.
- [ ] Status uses semicolon syntax and exact case.
- [ ] Active Flow API name is exact.
- [ ] Mode is manual and automatic checkbox is clear.
- [ ] Cooldown is at least one minute and covers reevaluation timing.
- [ ] Retry limit is 0 through 3 and accepted for duplicate side-effect risk.
- [ ] Contract version is `1.0`.
- [ ] Mapping checkboxes exactly match active Flow inputs.
- [ ] Second-person review completed.
- [ ] Policy is active only after review.

Next: [Test manual approval](TEST_MANUAL_APPROVAL.md).
