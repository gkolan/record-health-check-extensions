# Assign RHC Actions permissions

## Outcome

This runbook assigns each packaged Permission Set to the correct persona and verifies that business
record and Flow access are handled separately.

## Choose named users first

Record these people in the implementation ticket:

| Persona               | Example                  | Requirement                                                            |
| --------------------- | ------------------------ | ---------------------------------------------------------------------- |
| Package administrator | Alex Admin               | Configures policies and investigates package records                   |
| Manual approver       | Maya                     | Reviews Accounts and authorizes Task creation                          |
| Runtime identity      | RHC Actions Runtime User | Dedicated active user for Platform Event processing and automatic mode |
| Viewer                | Audit Viewer             | Reads configuration and audit records only                             |

Do not use Maya's personal account as the automatic runtime identity. Do not assign Runtime to a
shared generic user without an owner, license, and credential lifecycle.

## Understand the four Permission Sets

| Permission Set       | Package capabilities                                                                    | Does not automatically grant                            |
| -------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| RHC Actions Admin    | Configure policies/retention, approve, and run bounded audit cleanup                     | Automatic execution, direct audit-record delete CRUD, or access to every customer Flow/business object |
| RHC Actions Approver | View queue/history and approve or reject                                                | Task create, Account read, Flow execution, queue access |
| RHC Actions Runtime  | Consume core event and create/update execution audit; holds automatic Custom Permission | Customer Flow and business-object access                |
| RHC Actions Viewer   | Read package records                                                                    | Approval, edits, customer-record visibility             |

## Step 1: Assign RHC Actions Admin

1. Click the gear icon, then **Setup**.
2. Enter `Permission Sets` in **Quick Find**.
3. Click **Permission Sets**.
4. Click **RHC Actions Admin**.
5. Click **Manage Assignments**.
6. Click **Add Assignments**.
7. Select only the approved package administrator.
8. Click **Next**.
9. Choose an expiration only if the access policy requires one.
10. Click **Assign**.
11. Click **Done**.

**What you should see:** the package administrator appears under Current Assignments.

Admin includes **Manage RHC Actions Retention**. It does not expose direct Delete on Pending Action
or Action History; the review page offers only the bounded, explicitly confirmed retention path.

## Step 2: Assign RHC Actions Approver to Maya

1. Return to **Setup → Permission Sets**.
2. Click **RHC Actions Approver**.
3. Click **Manage Assignments**.
4. Click **Add Assignments**.
5. Select Maya.
6. Click **Next**.
7. Click **Assign**.
8. Click **Done**.

**What you should see:** Maya appears under Current Assignments.

## Step 3: Give Maya the customer permissions used by the Flow

RHC Actions Approver is intentionally not a universal business-data Permission Set. Create or reuse
an organization-owned Permission Set for the example Flow.

Ask the Flow owner to identify every dependency, then confirm Maya has:

- Read on Account and field access needed to review it;
- Create and Read on Task;
- edit access to every Task field populated by the Flow;
- access to the Task record type, if one is selected;
- access to the stewardship queue or approved Owner ID;
- permission to run `Create_Data_Steward_Task`;
- access to every called subflow and Apex action; and
- access required by downstream validation rules or automation.

To inspect object access:

1. From the relevant customer Permission Set, click **Object Settings**.
2. Click **Accounts**.
3. Click **Edit**.
4. Confirm **Read** and the required Account fields.
5. Click **Save**.
6. Return to **Object Settings**.
7. Click **Tasks**.
8. Click **Edit**.
9. Confirm **Read** and **Create**, plus every field the Flow writes.
10. Click **Save**.

To inspect Flow access when the org restricts Flow execution:

1. Open the customer Permission Set.
2. Find **Flow Access**.
3. Click **Edit**.
4. Add the active `Create_Data_Steward_Task` Flow if required by the org's Flow access model.
5. Click **Save**.

**Stop if:** the only proposed solution is System Administrator. Ask the security owner for a
least-privilege customer Permission Set.

## Step 4: Prepare the dedicated runtime user

Skip automatic-mode activation for now, but prepare the identity so event capture can be operated
deliberately.

1. From **Setup**, enter `Users` in **Quick Find**.
2. Click **Users**.
3. Open the approved dedicated runtime user.
4. Confirm **Active** is selected.
5. Confirm the username, email owner, user license, profile, and time zone are documented.
6. Confirm the user is not a departing employee's account.
7. Assign **RHC Actions Runtime** using **Permission Set Assignments → Edit Assignments**, or through
   the Permission Set's **Manage Assignments** page.
8. Assign the separate least-privilege customer Permission Set required by the corrective Flow.

**What you should see:** the dedicated user has RHC Actions Runtime and explicit customer access,
but not RHC Actions Admin or Approver unless there is a separately approved reason.

The release administrator must still configure the Platform Event trigger to use this identity.
That occurs in the automatic-execution runbook because Salesforce requires Metadata or Tooling API.

## Step 5: Assign RHC Actions Viewer

1. Open **Setup → Permission Sets → RHC Actions Viewer**.
2. Click **Manage Assignments**.
3. Click **Add Assignments**.
4. Select approved auditors or support viewers.
5. Click **Next**, **Assign**, then **Done**.

Viewer access to private records still follows Salesforce record sharing. If a viewer cannot see a
record, investigate ownership and sharing rather than granting approval rights.

## Step 6: Verify each persona

Have each user refresh Salesforce or sign out and back in.

### Package administrator test

1. Open **RHC Actions** from App Launcher.
2. Open **Corrective Action Policies**.
3. Confirm **New** is available.
4. Cancel without saving.
5. Open **RHC Actions Review** and confirm **Action audit retention** is visible.
6. Do not save or purge until the retention window and evidence-disposition procedure are approved.

### Maya approver test

1. Open **RHC Actions**.
2. Open **RHC Actions Review**.
3. Confirm the page loads without an approval-access error.
4. Open a permitted Account directly and confirm Maya can read it.

### Viewer test

1. Open **RHC Actions**.
2. Open each object tab.
3. Confirm records are readable when shared.
4. Confirm the viewer cannot create or edit policy records.

### Runtime identity review

The dedicated runtime identity usually does not need interactive login. The release administrator
verifies the subscriber configuration and runtime behavior during automatic-mode setup.

## Permission acceptance checklist

- [ ] Admin assigned only to approved package administrators.
- [ ] Approver assigned to Maya and approved reviewers.
- [ ] Maya has separate least-privilege Account, Task, Flow, queue, field, and dependency access.
- [ ] Runtime assigned to a dedicated active user with an accountable owner.
- [ ] Viewer users remain read-only.
- [ ] No user received System Administrator merely to make the example work.
- [ ] Only approved Admin users can see retention controls; Approver, Runtime, and Viewer cannot.

Next: [Build the corrective Flow](BUILD_CORRECTIVE_FLOW.md).
