# Troubleshooting

Start with the observed symptom. Do not delete facts, change retention, or republish large volumes
until the cause is known.

## RHC Reports is not in the App Launcher

1. Open Setup → Installed Packages and confirm RHC Reports is installed.
2. Open Setup → Permission Sets → RHC Reports Admin or Viewer → Manage Assignments.
3. Confirm the current user is assigned.
4. Log out and back in if the assignment was just added.
5. In App Launcher, click View All and search both `RHC Reports` and `RHC Reporting Coverage`.
6. If the tabs appear but the app does not, ask an app administrator to review App Menu/App Manager
   visibility for the user's profile.

## Setup Assistant says permission is required

The controller requires `Manage_RHC_Reports`.

1. Confirm the user has RHC Reports Admin, not only Viewer.
2. Open the Permission Set and confirm the Manage RHC Reports Custom Permission is present.
3. Re-authenticate the user.
4. If a cloned permission set is used, add the Custom Permission and all required Apex access.

## Save and Apply fails

Check every input:

- Detailed retention must be an integer from 1 through 3,650.
- Snapshot retention must be an integer from 1 through 36,500.
- Aggregation time zone must be a Salesforce-recognized ID; use `America/Chicago`, not `CST`.
- The user must be allowed to schedule Apex when Schedule Daily Maintenance is on.

If an old job was deleted directly from Scheduled Jobs, turn scheduling off, Save and Apply, then
turn it on and Save and Apply again to register a new job cleanly.

## Publication disabled

This state means no facts were observed and the page sees interactive Set Run publication off plus
zero active Checks with interactive Result publication on.

For card runs:

1. Setup → Custom Metadata Types → Record Health Check Set → Manage Records.
2. Edit the intended Check Set and inspect Publish User Run Event.
3. Setup → Custom Metadata Types → Record Health Check → Manage Records.
4. Inspect Publish User Result Event on the intended active Checks.
5. Save, then perform a new explicit Run/Rerun. Page-load evaluation does not publish.

For Flow/Apex, ignore those card checkboxes and inspect the caller's Event Publication value.

## No events received

1. Confirm an explicit publishing run occurred after RHC Reports was installed.
2. Confirm the programmatic caller selected ACTIONABLE or ALL, not NONE.
3. Confirm the surrounding Salesforce transaction committed.
4. Confirm core 2.0.4.2 or newer is installed.
5. In Setup, inspect the two core Platform Event definitions and their Subscriptions related lists.
6. Confirm both RHC Reports Apex trigger subscriptions are Running, not Error or Suspended.
7. Review Apex Jobs and debug logs for the publishing and subscriber identities.
8. Review Platform Event usage/allocation before generating another test.

Historical/unpublished outcomes cannot be backfilled after this is fixed.

## Run Facts exist but Result Facts do not

This can be correct when:

- `ACTIONABLE` was selected and all outcomes were PASS or SKIPPED;
- only the card's Publish User Run Event checkbox is on;
- Result delivery is still asynchronous; or
- the event claimed restricted detail or used an unsupported contract and was rejected.

Compare the Run Fact's five status counts. If any FAIL, UNABLE, or ERROR count is nonzero under
ACTIONABLE and no details ever arrive, inspect the Result subscriber state and logs.

## Result Facts appear before Run Facts

This is allowed. The events are independent and cross-transaction ordering is not guaranteed. Wait
for delivery, refresh Coverage, and do not create a synthetic Run Fact.

## Duplicate facts appear to exist

First distinguish repeated runs from redelivery:

- Different Event IDs are distinct legitimate facts even if Run ID, Check, Record ID, and time are
  similar.
- The same Event ID must correspond to one fact because it is a unique external ID.

Build a Result or Run Fact report grouped by Event ID. If one Event ID appears more than once,
capture package/core versions and escalate because the object uniqueness contract is broken.

## Coverage says Full ALL too early or changes state

Coverage is an inference across all retained facts for a Check Set, not a per-run reconciliation.
Independent delivery and retained history can affect totals. Use Run ID and occurrence time reports
for a specific run investigation. The page is a coverage warning surface, not a ledger proof.

## Daily dashboard is empty

1. Confirm Coverage shows received facts.
2. Confirm Daily Snapshots is on.
3. Confirm the scheduled job exists and has run after a completed local day.
4. Check Setup → Apex Jobs for the Queueable.
5. Confirm Last Aggregated Date advanced.
6. Confirm the report's Check Set qualified API name filter matches exactly.
7. Refresh the dashboard and inspect Last Refreshed.
8. Confirm the user has Viewer/Admin, object read access, Run Reports, and folder access.

Detailed fact reports can populate before daily snapshot reports.

## Scheduled maintenance did not run

1. Setup → Scheduled Jobs → find RHC Reports Daily Maintenance.
2. Confirm Next Scheduled Run is present.
3. Confirm the scheduling user is active and still authorized.
4. Check Apex Jobs around 2:15 AM in that user's time zone.
5. Open the assistant and confirm Schedule Daily Maintenance is on.
6. Save and Apply to replace the tracked schedule when necessary.

## Retention did not remove old rows

1. Confirm Retention Cleanup is on.
2. Confirm scheduled maintenance ran successfully after the setting changed.
3. Compare Run/Result `OccurredAt__c` with the fact cutoff.
4. Compare Snapshot Date with the snapshot cutoff.
5. Remember that the cutoff comparison is older-than, not older-than-or-equal.
6. Review the chained Batch jobs: Result, then Run, then Snapshot.

Do not manually delete facts to imitate retention unless the data owner explicitly authorizes that
destructive action.

## Failure or recovery metrics look wrong

- Recovery needs PASS detail, so use ALL publication.
- Recurrence compares the same Record ID and Check qualified API name.
- A blank/deleted source reference remains only a Text ID.
- Record Count is distinct only inside one snapshot group, not across groups.
- Changing aggregation time zone creates different snapshot identities.
- Opportunity Close Readiness can mix RUN and RESULT grain; use a cloned report with an explicit
  Grain filter when a single grain is required.

## Escalation bundle

Provide only nonrestricted evidence:

- org type and package/core versions;
- Check Set and Check qualified API names;
- approximate occurrence time and canonical Source;
- Event ID, Run ID, Status, Severity, and Reason Code when available;
- Coverage state and fact counts;
- Scheduled/Apex job IDs and statuses;
- contract and framework versions; and
- relevant package debug logs with restricted business values removed.

Never attach found/expected values, raw payloads, messages, fix instructions, or stack traces to an
ordinary reporting ticket.

