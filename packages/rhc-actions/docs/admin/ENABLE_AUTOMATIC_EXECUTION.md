# Enable automatic execution

## Read this first

Automatic execution removes the human decision from each matching event. Use it only for a reviewed,
deterministic, repeatable, low-risk Flow after manual acceptance succeeds.

This procedure has two parts:

- administrator clicks for policy and Permission Set preparation; and
- a release-engineer metadata deployment for the Platform Event subscriber identity.

Salesforce does not provide a complete click-only procedure for changing a Platform Event Apex
trigger's running user. Do not skip the metadata handoff.

## Approval gate

Record approval from:

- business/data owner;
- Flow owner;
- Salesforce security owner;
- package owner;
- runtime identity owner; and
- release/change owner.

The approval documents:

- exact policy and Flow version;
- exact business mutations;
- absence of alerts and external callouts;
- idempotent/repeat-safe Flow design;
- CRUD, FLS, sharing, Flow, queue, subflow, and Apex access;
- cooldown and retry choices;
- expected event volume and async capacity; and
- containment and rollback procedure.

**Stop if:** the Flow can make an irreversible judgment, has broad/unknown effects, calls an
external system, sends human alerts, or lacks a tested fault path. Keep manual mode.

## Step 1: Re-run manual acceptance

1. Confirm policy Mode is MANUAL APPROVAL.
2. Complete the full manual acceptance runbook with the exact active Flow version.
3. Confirm one event, one Pending Action, one Flow attempt, and one Task.
4. Confirm cooldown suppression using a controlled later event when required by the test plan.
5. Attach evidence to the change ticket.

## Step 2: Verify the dedicated runtime user

1. Open **Setup → Users → Users**.
2. Open the dedicated runtime user.
3. Confirm Active, license, profile, email owner, and account lifecycle.
4. In **Permission Set Assignments**, confirm **RHC Actions Runtime**.
5. Confirm the separate customer Permission Set provides only required Account, Task, field, Flow,
   queue, record-type, subflow, and Apex access.
6. Confirm the user is not Maya or another individual approver.

## Step 3: Release engineer configures the subscriber identity

The release engineer must use the installed namespaced identity of `RHCActionResultSubscriber` and
deploy a subscriber-org `PlatformEventSubscriberConfig` through Metadata API or Tooling API.

The configuration contains:

- the installed trigger as `platformEventConsumer`;
- a reviewed batch size;
- a clear master label;
- the dedicated runtime username; and
- the org-approved protection setting.

Do not copy a guessed namespace form from documentation. Resolve the installed trigger's exact API
identity in the target org.

Example shape for the release engineer—not a copy/paste production value:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PlatformEventSubscriberConfig xmlns="http://soap.sforce.com/2006/04/metadata">
    <platformEventConsumer>INSTALLED_NAMESPACED_TRIGGER_API_NAME</platformEventConsumer>
    <batchSize>200</batchSize>
    <masterLabel>RHC Actions Result Subscriber</masterLabel>
    <user>dedicated.runtime.user@example.com</user>
    <isProtected>false</isProtected>
</PlatformEventSubscriberConfig>
```

After deployment, the release engineer verifies the subscription is active and configured for the
intended user and batch size. If Salesforce requires suspend/resume for a changed subscriber
configuration to take effect, follow the current Salesforce subscriber-management procedure.

**Stop if:** the trigger still runs as Automated Process or a personal user. Do not change the policy
to automatic.

## Step 4: Test event capture under the runtime identity

1. Keep the policy in MANUAL APPROVAL.
2. Generate one controlled matching sandbox event.
3. Confirm a Pending Action appears.
4. Have the release engineer confirm capture used the configured runtime context and had no
   permission failures.
5. Reject or manually complete the proposal according to the test plan.

## Step 5: Change the policy controls

1. Open **RHC Actions → Corrective Action Policies**.
2. Open the approved policy.
3. Click **Edit**.
4. For **Mode**, select **AUTOMATIC**.
5. Select **Automatic Execution Enabled**.
6. Reconfirm Cooldown Minutes and Retry Limit.
7. Reconfirm Flow API Name and mapping checkboxes.
8. Click **Save**.

All three automatic controls must now be true:

- Mode is AUTOMATIC;
- Automatic Execution Enabled is selected; and
- configured subscriber identity has RHC Actions Automatic Execution through Runtime.

If the permission condition is absent, the proposal fails closed to PENDING REVIEW.

## Step 6: Run the automatic sandbox acceptance test

1. Prepare a new approved failing Account with no matching test Task.
2. Run the Check through the intended production-like caller.
3. Wait for event and Queueable processing.
4. Confirm no manual review click was required.
5. Open Pending Actions and confirm SUCCEEDED with Approved By blank.
6. Open History and confirm Initiated By is the dedicated runtime user.
7. Confirm one Flow Interview ID and exactly one expected Task.
8. Confirm no alert, callout, or unrelated record mutation occurred.
9. Deliver the duplicate-event test and confirm no second execution.
10. Deliver a later event inside cooldown and confirm suppression.

**Stop if:** Initiated By is wrong, more than one Task exists, approval fields are populated, or
unexpected automation occurs. Deactivate the policy immediately.

## Step 7: Production enablement

Repeat the approved subscriber configuration and policy change through production change control.
Do not assume sandbox user IDs, Flow versions, queue IDs, permissions, or installed trigger identity
match production.

## Emergency rollback to manual

1. Open the policy.
2. Click **Edit**.
3. Change Mode to **MANUAL APPROVAL**.
4. Clear **Automatic Execution Enabled**.
5. Click **Save**.
6. If risk remains, also clear **Active**.
7. Remove RHC Actions Runtime or the automatic Custom Permission only through approved access change
   control; remember that doing so can also stop event processing writes.
8. Preserve all audit records and investigate.

## Official Salesforce references

- [Configure the User and Batch Size for Your Platform Event Trigger](https://help.salesforce.com/s/articleView?id=release-notes.rn_messaging_trigger_config.htm&language=en_US&release=230&type=5)
- [Manage Permission Set Assignments](https://help.salesforce.com/s/articleView?id=perm_sets_assignment_summary.htm&language=en_US&type=5)
