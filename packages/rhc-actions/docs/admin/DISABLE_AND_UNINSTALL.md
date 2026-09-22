# Disable and uninstall RHC Actions

## Choose the correct action

| Goal                                             | Safest action                                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------------------ |
| Stop one behavior temporarily                    | Deactivate that policy                                                         |
| Stop all new proposals                           | Deactivate every policy                                                        |
| Preserve records but prevent automatic execution | Return policies to manual and clear automatic checkbox                         |
| Contain an incident                              | Deactivate affected policies immediately, then investigate                     |
| Permanently remove package                       | Export required evidence, clear work, remove subscriber config, then uninstall |

Do not uninstall as the first response to a Flow incident. Uninstalling can remove the audit data
needed to understand what happened.

## Pause one policy

1. Open App Launcher.
2. Open **RHC Actions**.
3. Click **Corrective Action Policies**.
4. Open the policy.
5. Click **Edit**.
6. Clear **Active**.
7. Click **Save**.
8. Record reason, operator, and time in the change ticket.

**What you should see:** future events no longer match this policy. Existing Pending Actions remain.

## Return automatic mode to manual

1. Open the policy and click **Edit**.
2. Select Mode **MANUAL APPROVAL**.
3. Clear **Automatic Execution Enabled**.
4. Click **Save**.
5. Generate no new event until the change is reviewed when this is incident containment.

## Prepare for uninstall

1. Deactivate every Corrective Action Policy.
2. Open **Pending Actions** and check for `QUEUED`, `RUNNING`, or `RETRY_WAIT`.
3. Wait for safe completion or follow the incident procedure; do not edit statuses manually.
4. Decide how to handle `PENDING_REVIEW` records under the retention policy.
5. Export required Policy, Pending Action, and Action History records through an approved secure
   export method.
6. Verify the export contains safe correlation and audit fields needed by retention policy.
7. Store the export in the approved access-controlled location.
8. Have the release administrator remove the subscriber-org `PlatformEventSubscriberConfig` for
   the installed Actions trigger.
9. Remove RHC Actions Permission Set assignments from users.
10. Confirm no Flow, report, integration, or custom automation outside the package depends on the
    four Actions objects, tabs, Apex APIs, or LWC.

**Stop if:** a non-terminal action remains, required audit evidence is not preserved, or subscriber
metadata still references the package trigger.

## Uninstall through Setup

1. Click the gear icon, then **Setup**.
2. Enter `Installed Packages` in **Quick Find**.
3. Click **Installed Packages**.
4. Find **RHC Actions**.
5. Click **Uninstall** next to RHC Actions.
6. Read Salesforce's component and data-removal warning.
7. Select the option for handling package data only according to the approved retention procedure.
8. Confirm the uninstall.
9. Wait for completion or the Salesforce confirmation email.

Do not uninstall Record Health Check core or another extension as part of this procedure.

## Verify the uninstall boundary

1. Return to **Setup → Installed Packages**.
2. Confirm RHC Actions is absent.
3. Confirm Record Health Check remains installed.
4. Open the normal core health-check experience.
5. Run a safe core smoke test.
6. Confirm other RHC extensions remain operational.
7. Confirm the RHC Actions app, tabs, Permission Sets, objects, and subscriber config are removed.
8. Confirm the customer-owned `Create_Data_Steward_Task` Flow remains only if the uninstall plan
   intentionally retained it.

**What you should see:** core and sibling extensions continue working. RHC Actions-owned metadata
and data are removed; customer-owned Flow behavior is not automatically deleted.

## Uninstall acceptance checklist

- [ ] Policies were deactivated.
- [ ] No queued, running, or retry-wait action remained.
- [ ] Required audit evidence was exported securely.
- [ ] Subscriber configuration was removed.
- [ ] Permission Set assignments were removed.
- [ ] External dependencies were reviewed.
- [ ] Actions uninstalled successfully.
- [ ] Core smoke test passed afterward.
- [ ] Customer-owned Flow disposition was recorded.
