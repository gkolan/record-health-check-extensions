# RHC Reports click-by-click setup

**Audience:** A Salesforce administrator who is comfortable opening Setup but has not configured
RHC Reports before.  
**Example:** Opportunity Close Readiness, 90-day detailed retention, daily snapshots, weekly trends.  
**Environment:** Lightning Experience; complete this in a sandbox first.

This guide tells you what to click, what to enter, what you should see, and when to stop. Do not
continue after a failed checkpoint.

After setup, use [Demo data and complete functional test](DEMO_TEST_DATA.md) for four reusable demo
Opportunities, event-order and duplicate tests, all coverage states, six weeks of reporting trends,
dashboard verification, recovery, permissions, retention, and cleanup.

## Setup worksheet

Fill this in before opening Salesforce:

| Decision | Example | Your approved value |
| --- | --- | --- |
| Sandbox org | Full sandbox | |
| Core minimum | 2.0.4.2 | |
| Check Set label | Opportunity Close Readiness | |
| Check Set qualified API name | `Opportunity_Close_Readiness` | |
| Publication for Flow/Apex | `ALL` | |
| Detailed retention | 90 days | |
| Snapshot retention | 730 days | |
| Reporting time zone | `America/Chicago` | |
| Schedule owner | Junior Admin | |
| Admin users | named people | |
| Viewer users | Sales Operations | |
| Data owner approval | ticket/change number | |

Why choose `ALL` for this example: weekly Set Run trends work with ACTIONABLE, but recovery requires
PASS details and complete Check-level analysis needs PASS and SKIPPED details. If volume approval is
only for ACTIONABLE, accept that recovery is incomplete.

## Procedure 1: Verify the correct org

1. Log in to Salesforce Lightning Experience.
2. Look at the browser URL and your avatar menu.
3. Confirm the organization is the intended sandbox.
4. If Salesforce shows a production org, stop and switch to the sandbox.
5. Click the **gear** icon.
6. Click **Setup**. Salesforce opens Setup in a new tab.

**Checkpoint:** The Setup page shows the intended sandbox name. Keep the application tab and Setup
tab open so you can move between them.

## Procedure 2: Verify installed package versions

1. In Setup's left-side **Quick Find** box, enter `Installed Packages`.
2. Click **Installed Packages** under the matching result.
3. In the package list, find **Record Health Check**.
4. Read its **Version Number**.
5. Confirm the version is 2.0.4.2 or a later version explicitly listed as compatible in the RHC
   Reports release notes.
6. In the same list, find **RHC Reports**.
7. Read and record its Version Number.

**Stop if:** Record Health Check is older than 2.0.4.2, RHC Reports is missing, or the package name
is similar but not exact. Ask the release administrator to correct installation first.

## Procedure 3: Assign RHC Reports Admin

1. In Setup Quick Find, replace the current text with `Permission Sets`.
2. Click **Permission Sets**.
3. In the list, click the label **RHC Reports Admin**.
4. On the Permission Set page, click **Manage Assignments**.
5. Click **Add Assignments**.
6. Use Search to find the administrator who will own the schedule.
7. Select the checkbox beside that user.
8. Select any additional approved RHC Reports administrators.
9. Click **Next**.
10. If your company requires temporary access, enter the approved expiration. Otherwise leave it
    without an expiration.
11. Click **Assign**.
12. Read the result message for every selected user.
13. Click **Done**.

**Checkpoint:** The schedule owner's name appears in the Current Assignments list.

**If assignment fails:** Open the error details. Confirm the user's Salesforce license supports Run
Reports and Create and Customize Reports. Do not grant a broader profile merely to bypass the error.

## Procedure 4: Assign RHC Reports Viewer

1. Return to the Permission Sets list.
2. Click **RHC Reports Viewer**.
3. Click **Manage Assignments**.
4. Click **Add Assignments**.
5. Select only users approved to view organization-wide reporting coverage and snapshots.
6. Click **Next**.
7. Set an expiration only when policy requires it.
8. Click **Assign**.
9. Click **Done**.

Viewer is read-only and cannot open RHC Reports Setup. It can query only the raw aggregate fields
needed by Reporting Coverage; Record IDs, Run/Event IDs, Reason Codes, and version fields remain
hidden. Both Permission Sets use View All Records on the analytical objects, so assignment is still
an organization-wide reporting decision.

## Procedure 5: Copy the exact Check Set qualified API name

1. In Setup Quick Find, enter `Custom Metadata Types`.
2. Click **Custom Metadata Types**.
3. Find **Record Health Check Set**.
4. Click **Manage Records** on that row. If your Salesforce page shows a Manage button on the type
   detail page instead, click the type label and then **Manage Record Health Check Sets**.
5. Find the row labeled **Opportunity Close Readiness**.
6. Click the record label to open it.
7. Find **Qualified API Name**.
8. Copy the entire value exactly, including any namespace prefix.
9. Paste it into the setup worksheet.
10. Confirm **Active** is selected.

**Do not:** copy only the label, add `rhc__` yourself, remove an existing namespace, or guess from
the Developer Name.

## Procedure 6A: Configure an explicit Lightning-card Run/Rerun

Use this procedure only when a person will click Run or Rerun on the Record Health Check card.
Automatic page-load checks never publish reporting events.

### Enable the Set Run heartbeat

1. Return to the **Record Health Check Set** Manage Records list.
2. Find Opportunity Close Readiness.
3. Click **Edit** beside the record.
4. Find **Publish User Run Event**.
5. Select the checkbox.
6. Review that the record is still Active.
7. Click **Save**.
8. Reopen the record and confirm the checkbox remained selected.

### Enable selected Check Result details

1. Return to the **Custom Metadata Types** page.
2. Find **Record Health Check**.
3. Click **Manage Records**.
4. Open the first active Check that belongs to Opportunity Close Readiness.
5. Confirm its Check Set relationship is Opportunity Close Readiness.
6. Find **Publish User Result Event**.
7. Select it when this Check's detail is approved for reporting.
8. Click **Save**.
9. Repeat for every approved active Check in the Set.
10. Record which Checks were enabled.

**Important:** The card checkboxes are not an ACTIONABLE filter. An enabled Check publishes its
result for explicit Run/Rerun regardless of whether it passed, failed, skipped, was unable, or
errored. For exact ACTIONABLE behavior, use Procedure 6B.

## Procedure 6B: Configure a Flow caller

Use this procedure when a Flow runs the health check. Follow your org's Flow change-control policy.

1. In Setup Quick Find, enter `Flows`.
2. Click **Flows**.
3. Find the Flow responsible for Opportunity Close Readiness.
4. Click the Flow label.
5. Open the current version in Flow Builder.
6. If it is active and your policy requires a new version, click **Save As** and choose **A New
   Version** before changing it.
7. On the canvas, find the Action element that invokes Record Health Check.
8. Click the element.
9. Confirm the action is **Run Record Health Check Set**. If it is **Run Record Health Check**, the
   action runs only one Check and its qualified API name must be documented separately.
10. In **Check Set Qualified API Name**, compare the full value with the worksheet.
11. In **Record ID**, confirm the Flow supplies the intended Opportunity ID, commonly `$Record.Id`.
12. Open **Event Publication**.
13. Select **Actionable (ACTIONABLE)** for problem-only details, or **All (ALL)** for every result.
14. Do not select None when RHC Reports history is required.
15. Click **Done** on the Action element.
16. Click **Save**.
17. Click **Debug**.
18. Choose one approved sandbox Opportunity.
19. Run the debug.
20. Confirm the action output **Success** is true.
21. Record Status and the five counts.
22. Follow the Flow fault connector if Success is false; do not activate a failing version.
23. When testing and approval are complete, click **Activate**.

**Checkpoint:** The active Flow version contains the exact qualified API name and approved Event
Publication value.

## Procedure 7: Open the RHC Reports app

1. Return to the normal Salesforce application tab.
2. Click the nine-dot **App Launcher** at the upper-left.
3. In the quick search, enter `RHC Reports`.
4. If the app appears, click **RHC Reports**.
5. If it does not appear, click **View All**.
6. Search `RHC Reports` again.
7. Click the RHC Reports app tile.

**Checkpoint:** The navigation bar contains **RHC Reporting Coverage**, **RHC Reports Setup** for an
Admin, **Reports**, and **Dashboards**.

**Stop if:** The app or tabs are missing. Recheck Permission Set assignment, sign out/in, and ask an
app administrator to confirm App Menu visibility before continuing.

## Procedure 8: Save the 90-day configuration

1. In the RHC Reports app, click **RHC Reports Setup**.
2. Wait until the spinner disappears.
3. Read the NONE, ACTIONABLE, and ALL explanation at the top.
4. Find **Detailed retention days**.
5. Replace the value with `90`.
6. Find **Snapshot retention days**.
7. Enter `730` for the example, or the approved worksheet value.
8. Find **Aggregation time zone**.
9. Enter the exact time-zone ID, for example `America/Chicago`.
10. Confirm **Daily snapshots** is on.
11. Leave **Retention cleanup** off if deletion approval is still pending. Otherwise turn it on.
12. Turn **Schedule daily maintenance** on.
13. Recheck every number; the Setup Assistant allows detailed retention 1–3,650 and snapshot
    retention 1–36,500.
14. Read the yellow irreversible-deletion warning.
15. Click **Save and Apply** once.
16. Wait for the save to finish.
17. Confirm the green toast **RHC Reports configured** with message **Settings and maintenance
    schedule were saved.**
18. Refresh the page.
19. Confirm all saved values reload correctly and Schedule Daily Maintenance remains on.

**Stop if:** The red error toast appears. Copy the safe error text, correct the field named by the
message, and retry. Do not repeatedly click Save.

## Procedure 9: Verify the scheduled job

1. Click the gear and open **Setup**.
2. In Quick Find, enter `Scheduled Jobs`.
3. Click **Scheduled Jobs**.
4. Search the page for **RHC Reports Daily Maintenance**.
5. Confirm exactly one active row is present.
6. Confirm **Next Scheduled Run** is in the future.
7. Confirm **Submitted By** is the intended schedule owner.
8. Record the next run and owner in the worksheet/change ticket.

The cron is 2:15 AM in the schedule owner's Salesforce time zone. The saved aggregation time zone
controls which events belong to each Snapshot Date. These can be different.

Do not use **Del** to reschedule. Return to the assistant, turn scheduling off, Save and Apply, turn
it back on, and Save and Apply.

## Procedure 10: Publish one controlled test

### Card test

1. Open the approved sandbox Opportunity.
2. Locate the Record Health Check card.
3. Wait for any automatic page-load check to finish; it does not publish.
4. Click **Run** or **Rerun** once.
5. Wait for the explicit run to finish.
6. Record the displayed overall outcome and counts.

### Flow test

1. Use the already approved Flow Debug result from Procedure 6B or perform the approved trigger
   action on one sandbox Opportunity.
2. Confirm the transaction completed rather than rolling back.
3. Record the Flow version and result.

Platform Events are asynchronous. Do not repeatedly run the Check Set merely because Coverage has
not changed immediately.

For a repeatable demo rather than one existing Opportunity, create the four marked records in
[Demo data and complete functional test](DEMO_TEST_DATA.md), then return to this procedure.

## Procedure 11: Verify Reporting Coverage

1. Open the RHC Reports app.
2. Click **RHC Reporting Coverage**.
3. Wait for the table to load.
4. Find Opportunity Close Readiness by label.
5. Confirm the qualified API name below the label matches the worksheet.
6. Record **Coverage state**, **Run facts**, **Result facts**, and **Latest event**.
7. If the event was just published, wait briefly and refresh the browser once.

Interpret the result:

| Badge | Accept it when | Investigate when |
| --- | --- | --- |
| No failures | Run Facts exist and the run had zero FAIL/UNABLE/ERROR. | The known run had an actionable count. |
| No events received | No publishing test has occurred yet. | A committed ACTIONABLE/ALL or explicit card run completed. |
| Publication disabled | No reporting is intended. | Reporting was approved and configured. |
| Partial ACTIONABLE coverage | ACTIONABLE produced problem details without PASS/SKIPPED. | ALL was required and delivery has settled. |
| Full ALL coverage | Result detail covers evaluated Checks. | Volume policy required ACTIONABLE only. |
| Events received; coverage still converging | Delivery is recent. | It remains indefinitely without an explained publication pattern. |

## Procedure 12: Create a temporary immediate-fact verification report

Daily Snapshot reports do not populate until aggregation. To verify ingestion now:

1. In the RHC Reports app, click **Reports**.
2. Click **New Report**.
3. Search report types for `RHC Report Runs`.
4. Select **RHC Report Runs**.
5. Click **Start Report**.
6. In Filters, set the Occurred At range to include today.
7. Add a filter: Check Set Qualified API Name equals the worksheet value.
8. Click **Run**.
9. Confirm a row exists for the controlled test.
10. Check Source, Run ID, Contract Version `1.0`, Framework Version, Phase, and five counts.
11. Click **Save & Run** only if policy permits a temporary admin report.
12. Save it in a private or administrator-controlled folder, not the packaged read-only folder.

For Result detail, repeat with report type **RHC Report Results** and confirm Status, Severity,
Reason Code, Source, Run ID, and exact Check identities. Do not expect PASS under ACTIONABLE.

## Procedure 13: Verify the first daily snapshot

Perform this after `RHC Reports Daily Maintenance` runs for the first completed local day.

1. Setup → **Apex Jobs**.
2. Filter or scan for the RHC Reports Queueable and Batch executions around the scheduled time.
3. Confirm the Queueable completed.
4. If Retention Cleanup is on, confirm the Result, Run, and Snapshot Batch chain completed.
5. Return to the RHC Reports app.
6. Click **Reports**.
7. Click **New Report**.
8. Choose **RHC Daily Snapshots**.
9. Set Snapshot Date to the expected prior local date.
10. Filter Check Set Qualified API Name to the worksheet value.
11. Click **Run**.
12. Confirm RUN-grain and, when details were published, RESULT-grain rows exist.
13. Confirm Aggregation Time Zone matches the worksheet exactly.

The current Setup Assistant stores Last Aggregated Date but does not display it. The Daily Snapshot
report is therefore the supported junior-admin verification surface.

## Procedure 14: Open the packaged reports

1. Click **Reports**.
2. Click **All Folders**.
3. Open the public read-only **RHC Reports** folder.
4. Open each report once:
   - Opportunity Close Readiness;
   - Weekly Failure Rate;
   - Recurring Failures;
   - Error and Unable Hotspots;
   - Recovery Rate; and
   - Volume by Execution Source.
5. For each report, click **Run** or Refresh.
6. Read the filters before interpreting results.
7. Confirm Opportunity Close Readiness's Check Set filter matches the worksheet.

If the qualified API name differs:

1. Click the report action menu.
2. Choose **Save As** or **Clone**.
3. Give the copy a name that includes the Check Set label.
4. Save it in an administrator-owned folder.
5. Edit Filters.
6. Replace `Opportunity_Close_Readiness` with the exact worksheet value.
7. Add `Grain equals RUN` when the team wants a pure Set Run failure trend.
8. Save and Run the copy.

Packaged folder content is read-only; do not expect to overwrite the original.

## Procedure 15: Open and refresh the dashboard

1. In the RHC Reports app, click **Dashboards**.
2. Click **All Folders**.
3. Open the public read-only **RHC Reports** dashboard folder.
4. Click **Data Quality Trend**.
5. Find **Last Refreshed**.
6. Click **Refresh** once.
7. Wait for Salesforce to finish.
8. Confirm the five widgets appear: weekly trend, recurring failures, technical hotspots, recovery,
   and source distribution.
9. Click one data point in each widget and confirm drill-down respects Viewer access.

An empty dashboard on setup day is not proof of failure; detailed facts can arrive before the first
daily aggregation.

## Procedure 16: Test as a Viewer

Use a real approved Viewer account or Salesforce's supported login-as process.

1. Sign in as the Viewer.
2. Open App Launcher → RHC Reports.
3. Confirm **RHC Reporting Coverage**, Reports, and Dashboards are available.
4. Confirm **RHC Reports Setup** is not available.
5. Open Reporting Coverage.
6. Open one report and Data Quality Trend.
7. Confirm the Viewer cannot edit/delete Run Facts, Result Facts, or Daily Snapshots.
8. Confirm the Viewer sees only the intended public reporting folders.
9. End the Viewer session.

## Procedure 17: Record the production handoff

Attach this completed record to the deployment/change ticket:

- org ID and environment;
- Record Health Check and RHC Reports versions;
- package installation result;
- Admin and Viewer assignees or governed groups;
- Check Set label and exact qualified API name;
- caller type and publication configuration;
- 90-day detailed and approved snapshot retention;
- aggregation time zone;
- schedule owner and next run;
- controlled test time, Source, Run Fact count, Result Fact count, and Coverage state;
- first Daily Snapshot date;
- report/dashboard Viewer test result;
- data/event/async limit approval; and
- known caveats, especially ACTIONABLE recovery incompleteness.

## Do not declare setup complete until

- both packages and compatible versions are confirmed;
- Permission Sets are assigned and Viewer behavior is tested;
- a deliberate publishing path is configured;
- one controlled event is observed without repeated test runs;
- the schedule exists under the correct user;
- retention and time zone match approval;
- the first completed-day snapshot exists; and
- reports/dashboard are interpreted with their documented filters and limitations.

For symptom-based recovery, continue with [Troubleshooting](TROUBLESHOOTING.md). For how the facts
and snapshots are built, read [Architecture and data model](ARCHITECTURE_AND_DATA_MODEL.md).
