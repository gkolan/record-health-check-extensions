# RHC Alerts sandbox demo and acceptance guide

This kit creates recognizable sandbox data and walks a junior administrator through the visible
behavior of RHC Alerts. It tests real Platform Event subscribers and real delivery services; it is
not a mock-data-only presentation.

> **Sandbox only.** The Custom Notification scenarios notify the user who runs the seed script. The
> Email scenario can send a real email to that user and therefore stays inactive until its separate
> opt-in script is run. Never run these scripts in production.

## What the kit creates

| Demo item          | Value                                           | Purpose                                                          |
| ------------------ | ----------------------------------------------- | ---------------------------------------------------------------- |
| Account            | `[RHC Alerts Demo] Acme`                        | Parent for the checked record                                    |
| Opportunity        | `[RHC Alerts Demo] Renewal`                     | Stable checked Record ID; `Next Step` is blank                   |
| Public Group       | `[RHC Alerts Demo] Recipients`                  | Contains the script-running user as a direct member              |
| Empty Public Group | `[RHC Alerts Demo] Empty Group`                 | Demonstrates safe recipient failure                              |
| Active policy      | `[RHC Alerts Demo] Custom Notification Success` | Check match, current user, Custom Notification, 24-hour cooldown |
| Active policy      | `[RHC Alerts Demo] Empty Group Failure`         | Same Check, empty group, Custom Notification, no cooldown        |
| Inactive policy    | `[RHC Alerts Demo] Email Opt-In`                | Email test that requires explicit activation                     |
| Inactive policy    | `[RHC Alerts Demo] Set Run Contract Gap`        | Check Set contract-gap suppression test                          |

The scripts detect whether core metadata is local or installed with the `rhc` namespace. They use
the exact resulting Qualified API Names and never remove or rewrite a namespace.

## Before running anything

Ask a release administrator to perform these checks. A junior administrator can then complete the
UI checkpoints in this guide.

1. Use a disposable scratch org or sandbox.
2. Confirm Record Health Check core `2.0.4-2` or a documented compatible later version is present.
3. Confirm RHC Alerts source or an installable RHC Alerts package is present.
4. Confirm the user running the scripts has RHC Alerts Admin and can create Account and Opportunity
   records and Regular public groups.
5. Confirm the core example definitions are installed:
   - `Example: Deal Readiness - Next Step`
   - `Example: Deal Readiness - Probability`
   - `Example: Opportunity Deal Readiness`
6. Decide whether a real email attempt is allowed. Scripts 01 through 05 do not send email.

Run every command below from `packages/rhc-alerts`. Replace `<sandbox-alias>` with the Salesforce CLI
alias for the disposable org.

## Part 1: Create the demo data

### 1A. Create recipient groups

The release administrator runs:

```bash
sf apex run --file demo/apex/01_seed_recipient_groups.apex --target-org <sandbox-alias>
```

The script is safe to rerun. It creates the two Regular public groups and makes the current user a
direct member of the recipient group.

Junior administrator UI check:

1. Click the **gear** icon, then **Setup**.
2. Enter `Public Groups` in **Quick Find**.
3. Click **Public Groups**.
4. Click **[RHC Alerts Demo] Recipients**.
5. Under **Selected Members**, confirm the script-running user appears.
6. Return to Public Groups and open **[RHC Alerts Demo] Empty Group**.
7. Confirm no User is a selected member.

### 1B. Create the business records and policies

The release administrator runs:

```bash
sf apex run --file demo/apex/02_seed_records_and_policies.apex --target-org <sandbox-alias>
```

The script is safe to rerun and resets the demo Opportunity to a blank Next Step. It creates or
updates all four policies. Email and Check Set policies remain inactive.

Junior administrator UI check:

1. Click the **App Launcher** (nine dots).
2. Enter `RHC Alerts` in **Search apps and items**.
3. Click **RHC Alerts**.
4. Open the **Alert Policies** tab.
5. Select the **All** list view if the four demo rows are not immediately visible.
6. Confirm all four names from the table above appear.
7. Open **[RHC Alerts Demo] Custom Notification Success**.
8. Confirm:
   - Active is selected.
   - Selection Type is Check.
   - Qualified API Name ends in `Example_Opportunity_DR_Next_Step` and retains `rhc__` when shown.
   - Matching Statuses contains FAIL, UNABLE TO EVALUATE, and ERROR.
   - Minimum Severity is WARNING.
   - Recipient Type is User and the recipient is the script-running user.
   - Notification Channel is Custom Notification.
   - Cooldown Minutes is 1,440.
9. Open **[RHC Alerts Demo] Email Opt-In** and confirm Active is not selected.
10. Open **[RHC Alerts Demo] Set Run Contract Gap** and confirm Active is not selected.
11. Open the demo Opportunity and confirm **Next Step** is blank.

## Part 2: Validate setup coverage

1. In the RHC Alerts app, open **RHC Alerts Administration**.
2. Click **Analyze publication coverage**.
3. Wait for the spinner to stop.
4. Find the active Next Step policies.
5. If the assistant reports that interactive Result publication is disabled, open **Setup**, enter
   `Record Health Check` in Quick Find, open the core administration page, edit the example Next
   Step Check, enable **Publish User Result Event**, and save.
6. Return to RHC Alerts Administration and click **Analyze publication coverage** again.
7. Confirm the interactive warning is resolved.
8. Read the programmatic publication note: an Apex/Flow caller must request `ACTIONABLE` or `ALL`.
   The assistant cannot prove the value used by every runtime caller.

This demo publishes canonical events directly so delivery behavior can be tested independently of a
particular core UI. The normal production path must still have publication enabled.

## Part 3: Test success, duplicate idempotency, and safe failure

The release administrator runs:

```bash
sf apex run --file demo/apex/03_publish_success_and_duplicate.apex --target-org <sandbox-alias>
```

The script publishes two event envelopes with the same Event ID. Platform Event processing and
Queueable delivery are asynchronous. Wait up to two minutes, refresh Delivery History, and do not
assume row order.

Junior administrator UI check:

1. In the RHC Alerts app, open **Delivery History**.
2. Click **Refresh** until four rows with Event ID
   `rhc-alerts-demo-result-duplicate-v1` appear.
3. For **Custom Notification Success**, confirm one row is **DELIVERED** and one is **DUPLICATE**.
4. For **Empty Group Failure**, confirm one row is **FAILED** with failure class
   **CONFIGURATION** and error code **NO_DIRECT_ACTIVE_USERS**, and one is **DUPLICATE**.
5. Confirm no duplicate row is DELIVERED.
6. Click the bell icon in the Salesforce header and confirm one RHC Alerts notification appears.
7. Open the notification and verify it identifies only the Check, status, and severity. It must not
   expose a raw event payload, found/expected values, a stack trace, or exception text.
8. Open the demo Opportunity. Confirm Next Step is still blank and no business field was updated by
   RHC Alerts.

Why four rows: one incoming Event ID matches two active policies. Each policy receives one unique
claim plus one duplicate-evidence row. A duplicate is intentionally visible but never retried or
sent.

## Part 4: Test per-policy and per-record cooldown

Only continue after the success policy row from Part 3 shows DELIVERED. The release administrator
runs:

```bash
sf apex run --file demo/apex/04_publish_cooldown_event.apex --target-org <sandbox-alias>
```

Junior administrator UI check:

1. Wait up to two minutes and refresh **Delivery History**.
2. Find rows with Event ID `rhc-alerts-demo-result-cooldown-v1`.
3. For **Custom Notification Success**, confirm **SUPPRESSED** and suppression reason **COOLDOWN**.
4. For **Empty Group Failure**, confirm another **FAILED / CONFIGURATION /
   NO_DIRECT_ACTIVE_USERS** row. Its policy has zero cooldown and its prior attempt was not a
   successful delivery.
5. Confirm no second Custom Notification was generated for the success policy.

Cooldown is scoped to the combination of policy and checked Record ID. It does not globally silence
another policy or another record.

## Part 5: Test exact identity, status, and severity non-matches

Before this step, note the number of demo rows shown in Delivery History. The release administrator
runs:

```bash
sf apex run --file demo/apex/05_publish_nonmatching_events.apex --target-org <sandbox-alias>
```

The three events use, respectively, a different Check identity, PASS instead of a selected status,
and INFO below the WARNING threshold.

1. Wait two minutes and refresh **Delivery History**.
2. Confirm the demo-row count did not increase.
3. Confirm no notification was received.

No row is expected: non-matching events are outside the delivery ledger rather than suppressed
claims. The identity comparison is exact and namespace-sensitive.

## Part 6: Explicitly test Email

Skip this part if outbound sandbox email is not approved. The script activates the previously
inactive Email policy and attempts one real email to the script-running user's Salesforce email
address.

1. In Setup, enter `Deliverability` in Quick Find.
2. Click **Deliverability**.
3. Review **Access Level** with the sandbox owner. Use the approved value; do not weaken an
   organization's email policy solely for this demo.
4. The release administrator runs:

```bash
sf apex run --file demo/apex/06_activate_and_publish_email.apex --target-org <sandbox-alias>
```

5. Wait up to two minutes and refresh Delivery History.
6. Find Event ID `rhc-alerts-demo-email-v1`.
7. Normally, confirm **DELIVERED** and receipt of a plain-text email.
8. If Salesforce rejects or blocks the attempt, confirm **FAILED** with a bounded failure class and
   error code. Use the operations runbook; do not expect raw platform exception text.
9. Confirm the message omits payloads, found/expected values, stack traces, and restricted detail.

`DELIVERED` means Salesforce accepted the send request. It does not guarantee mailbox delivery,
reading, or engagement.

## Part 7: Test the Check Set contract limitation

The release administrator runs:

```bash
sf apex run --file demo/apex/07_activate_and_publish_set_run.apex --target-org <sandbox-alias>
```

1. Wait up to two minutes and refresh Delivery History.
2. Find Event ID `rhc-alerts-demo-set-run-duplicate-v1`.
3. Confirm one **SUPPRESSED** row with suppression reason **RUN_CONTRACT_INSUFFICIENT**.
4. Confirm one **DUPLICATE** row.
5. Confirm no human notification was sent.

Core Set Run contract `1.0` has phase and counts but no canonical aggregate status/severity. Alerts
therefore records the gap safely instead of inventing an alert condition. Normal Check Set policies
receive actionable alerts through matching Result events for Checks in the set.

## Part 8: Verify publication NONE

Publication `NONE` produces no Platform Event, so an Alerts-side script cannot manufacture an honest
`NONE` event test. Test it through the actual core caller:

1. Record the current demo delivery-row count.
2. Ask the automation owner to run the demo Opportunity through its programmatic core path with
   publication mode explicitly set to `NONE`.
3. Wait two minutes and refresh Delivery History.
4. Confirm the count is unchanged and no notification was received.
5. Repeat with `ACTIONABLE` or `ALL`; a matching failing Result should then be observable.

For interactive runs, disabling **Publish User Result Event** is the equivalent coverage gap. The
setup assistant identifies that configuration.

## Part 9: Verify least-privilege access

Use a second test user assigned only **RHC Alerts Viewer Runtime** plus its normal business access.

1. Log in as the viewer.
2. Open the App Launcher and search for RHC Alerts.
3. Confirm only Delivery History is available; both generic package object tabs are hidden.
4. Confirm delivery rows cannot be edited or deleted from the bounded history experience.
5. Confirm **RHC Alerts Administration** is hidden.
6. Confirm the viewer cannot invoke or navigate to recipient and policy administration.
7. Confirm this permission set did not grant access to the demo Opportunity if the viewer did not
   already have it.

## Part 10: Inspect limits and operational states

1. Log back in as RHC Alerts Admin.
2. Open **RHC Alerts Administration**.
3. Find the platform-limits information.
4. Confirm it states the package attempt caps of 500 Custom Notification recipients, 10 email
   recipients, and 3 attempts for a classified retryable failure.
5. Follow the link/instruction to **Setup → Company Information** to inspect live org allocations.
6. Confirm Delivery History visibly distinguishes DELIVERED, FAILED, SUPPRESSED, and DUPLICATE.

Do not create hundreds of users to force recipient limits. Bulk, locking, retry, and platform-limit
boundary cases are safer and deterministic in the automated Apex suite; see [TEST_MATRIX.md](TEST_MATRIX.md).

## Expected cumulative result summary

Assuming cleanup was run first, async work has completed, and the Email attempt is approved:

| After script | New rows | Cumulative rows | Key result                                                   |
| ------------ | -------: | --------------: | ------------------------------------------------------------ |
| 03           |        4 |               4 | DELIVERED + DUPLICATE; FAILED + DUPLICATE                    |
| 04           |        2 |               6 | COOLDOWN suppression plus empty-group failure                |
| 05           |        0 |               6 | Exact identity/status/severity non-matches                   |
| 06           |        1 |               7 | Email DELIVERED, or bounded FAILED if the platform blocks it |
| 07           |        2 |               9 | RUN_CONTRACT_INSUFFICIENT + DUPLICATE                        |

If a script is rerun without cleanup, deterministic Event IDs can create additional duplicate
evidence. Use the cleanup procedure before repeating the complete acceptance run.

## Cleanup

Cleanup is intentionally split to avoid mixed setup/non-setup DML. It deletes only records whose
names or Event IDs use the `[RHC Alerts Demo]` / `rhc-alerts-demo-` markers.

Run in this order:

```bash
sf apex run --file demo/apex/98_cleanup_demo_data.apex --target-org <sandbox-alias>
sf apex run --file demo/apex/99_cleanup_recipient_groups.apex --target-org <sandbox-alias>
```

The first script removes demo delivery rows, policies, Opportunity, and Account. The second removes
demo GroupMember and Group records. Salesforce deleted-record retention may allow temporary recovery
from the Recycle Bin; do not rely on recovery in a disposable org.

## Files and ownership

| File                                         | Action                                              |
| -------------------------------------------- | --------------------------------------------------- |
| `apex/01_seed_recipient_groups.apex`         | Setup-only recipient seed                           |
| `apex/02_seed_records_and_policies.apex`     | Business records and four policies                  |
| `apex/03_publish_success_and_duplicate.apex` | Success, failure, and Event ID idempotency          |
| `apex/04_publish_cooldown_event.apex`        | Per-policy/per-record cooldown                      |
| `apex/05_publish_nonmatching_events.apex`    | Exact match, status, and severity negative controls |
| `apex/06_activate_and_publish_email.apex`    | Explicit real-email opt-in                          |
| `apex/07_activate_and_publish_set_run.apex`  | Set Run contract-gap and duplicate evidence         |
| `apex/98_cleanup_demo_data.apex`             | Package and business-record cleanup                 |
| `apex/99_cleanup_recipient_groups.apex`      | Setup-record cleanup                                |
| [TEST_MATRIX.md](TEST_MATRIX.md)             | Manual and automated evidence for every capability  |
