# RHC Reports junior administrator guide

**Applies to:** RHC Reports 0.1.0, Record Health Check core 2.0.4.2, event contract 1.0  
**Last reviewed:** 2026-08-25

For a first installation, use the more literal [click-by-click setup](CLICK_BY_CLICK_SETUP.md),
which includes checkpoints, stop conditions, temporary verification reports, Viewer testing, and a
production handoff record. This guide is the shorter task-oriented operating reference.

Use this guide in Lightning Experience after both packages are installed. Complete the first setup
in a sandbox before production. Buttons can move slightly between Salesforce releases, so use the
Setup **Quick Find** box when a menu is not where you expect it.

## What this package does

RHC Reports listens to the canonical Record Health Check Set Run and Result Platform Events. It
saves minimal facts, builds daily snapshots, and supplies reports and a dashboard. It does not run
health checks itself.

Publication controls whether there is anything to report:

| Choice | Reporting coverage |
| --- | --- |
| **NONE** | No reporting coverage. No Set Run or Result events are published. |
| **ACTIONABLE** | Run summaries plus Result details for `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`. |
| **ALL** | Run summaries plus every published Result, including `PASS` and `SKIPPED`. |

Historical and unpublished outcomes cannot be reconstructed. Enabling publication today does not
backfill yesterday's outcomes.

## Before you begin

Have these items ready:

- a Salesforce System Administrator or delegated administrator who can assign Permission Sets and
  edit Custom Metadata records;
- the promoted **Record Health Check 2.0.4.2** package;
- the **RHC Reports** package;
- one active Check Set to test, such as **Opportunity Close Readiness**;
- one Opportunity record where the Record Health Check Lightning card is available; and
- the business reporting time zone, such as `America/Chicago`.

RHC Reports Admin grants package access. It does not grant every Salesforce Setup permission needed
to administer users or edit the core package's Custom Metadata.

## Step 1: Confirm the packages are installed

1. Click the **gear** icon in the upper-right corner.
2. Click **Setup**.
3. In **Quick Find**, enter `Installed Packages`.
4. Click **Installed Packages**.
5. Find **Record Health Check** and confirm its version is **2.0.4.2** or newer.
6. Find **RHC Reports**.
7. If either package is missing, stop and ask the release administrator to install it. Do not
   continue with partial setup.

RHC Reports depends only on Record Health Check. RHC Run Manager and the other RHC extensions are
not prerequisites.

## Step 2: Give administrators and viewers access

Assign **RHC Reports Admin** to the small group that manages retention and scheduling:

1. From Setup, enter `Permission Sets` in **Quick Find**.
2. Click **Permission Sets**.
3. Click **RHC Reports Admin**.
4. Click **Manage Assignments**.
5. Click **Add Assignments**.
6. Select the administrators who will configure reporting.
7. Click **Next**.
8. Leave the assignment without an expiration unless your access policy requires one.
9. Click **Assign**.
10. Click **Done**.

Assign **RHC Reports Viewer** to users who only need coverage, reports, and dashboards by repeating
the same clicks and selecting **RHC Reports Viewer** in step 3. Do not assign both sets to the same
person unless there is a documented reason.

If Salesforce rejects an assignment, confirm that the user's license supports **Run Reports** and
the other permissions shown on the assignment error.

## Step 3: Choose the publication level

Choose this before generating test data:

- Choose **ACTIONABLE** for a lower-volume operational view focused on problems.
- Choose **ALL** when success, skipped outcomes, recovery rate, or complete audit-style Check detail
  is required.
- Choose **NONE** only when no RHC Reports history is wanted for that caller.

`ALL` creates approximately one Result event per eligible Check per evaluated record. Review your
Platform Event and data-storage limits before selecting it for high-volume jobs.

### If a Flow starts the health check

Flow is the clearest way for a junior administrator to select `ACTIONABLE` or `ALL` exactly:

1. In Setup, enter `Flows` in **Quick Find**.
2. Click **Flows**.
3. Open the Flow that runs Opportunity Close Readiness.
4. Click **Edit** or create a new version if the active version is locked.
5. Find the **Run Record Health Check Set** action and open it.
6. Locate **Event Publication**.
7. Select **Actionable** for `ACTIONABLE`, or **All** for `ALL`.
8. Confirm **Check Set Qualified API Name** is the exact value for Opportunity Close Readiness.
9. Click **Done**.
10. Click **Save As** when your change-control process requires a new version.
11. Click **Debug** with a safe Opportunity test record.
12. Review the returned **Success**, **Status**, and counts.
13. Click **Activate** only after the debug run succeeds and the change is approved.

Do not change a Flow from `NONE` merely to make a chart populate unless the data owner has approved
the resulting event volume and retention.

### If a user clicks Run or Rerun on the Lightning card

The Lightning card uses two checkboxes, not the programmatic `NONE` / `ACTIONABLE` / `ALL` selector.
An automatic page-load evaluation never publishes reporting events.

Enable the Set Run summary:

1. In Setup, enter `Custom Metadata Types` in **Quick Find**.
2. Click **Custom Metadata Types**.
3. Find **Record Health Check Set**.
4. Click **Manage Records** next to it.
5. Find **Opportunity Close Readiness** and click **Edit**.
6. Select **Publish User Run Event**.
7. Click **Save**.

Enable Result details only for the Checks that reporting needs:

1. Return to **Custom Metadata Types**.
2. Find **Record Health Check**.
3. Click **Manage Records** next to it.
4. Open each Check that belongs to Opportunity Close Readiness.
5. Confirm the Check references the intended Check Set.
6. Select **Publish User Result Event**.
7. Click **Save**.
8. Repeat for each required Check.

These Check-level boxes publish that Check's result for an explicit card Run or Rerun regardless of
status. They are not a literal `ACTIONABLE` filter. Use Flow or Apex when exact `ACTIONABLE`
behavior is required.

## Step 4: Configure 90-day reporting retention

1. Click the **App Launcher** grid at the upper-left of Lightning Experience.
2. Click **View All** if the quick list does not show the app.
3. In **Search apps and items**, enter `RHC Reports`.
4. Click **RHC Reports**.
5. Click the **RHC Reports Setup** navigation tab.
6. Wait for **RHC Reports Setup Assistant** to finish loading.
7. Enter `90` in **Detailed retention days**.
8. Enter `730` in **Snapshot retention days** to keep two years of daily trends, or enter the
   approved period from your data-retention policy.
9. Enter the explicit business time-zone ID in **Aggregation time zone**, for example
   `America/Chicago`.
10. Turn on **Daily snapshots**.
11. Turn on **Retention cleanup** only after confirming that 90 days is approved.
12. Turn on **Schedule daily maintenance**.
13. Re-read the irreversible-deletion warning.
14. Click **Save and Apply**.
15. Confirm the green **RHC Reports configured** message.

Shortening retention is irreversible after cleanup runs. Export facts first when policy requires a
backup. Deleted source records can leave historical facts containing only their former Record ID.

## Step 5: Verify the maintenance schedule

1. Return to Setup using the **gear** icon.
2. In **Quick Find**, enter `Scheduled Jobs`.
3. Click **Scheduled Jobs**.
4. Find **RHC Reports Daily Maintenance**.
5. Confirm it has a future **Next Scheduled Run**. To aggregate immediately instead of waiting for
   the schedule, click **Run aggregation now** on the setup page.

The job is registered for 2:15 AM in the scheduling administrator's Salesforce time zone. Snapshot
date assignment separately uses the **Aggregation time zone** saved in the assistant. Daily
aggregation processes the prior completed local day.

Do not click **Del** on the Scheduled Jobs page to change RHC Reports scheduling. Return to the
assistant, turn **Schedule daily maintenance** off or on, and click **Save and Apply** so the saved
job ID remains consistent.

## Step 6: Generate the first reporting events

For a Lightning-card test:

1. Open the approved test Opportunity.
2. Find the Record Health Check card.
3. Click **Run** or **Rerun**. Merely opening or refreshing the page does not publish events.
4. Wait for the health check to finish.
5. Note whether the Check Set has failures.
6. Because Platform Events are asynchronous, allow delivery to complete before judging coverage.
7. Do not repeatedly click Run to force an immediate refresh; every explicit run can consume event
   allocation and create another legitimate run fact.

For a Flow test, use Flow Builder **Debug** with one safe Opportunity and the approved publication
choice. Platform Events publish only if the surrounding transaction commits.

## Step 7: Check Reporting Coverage

1. Open the **RHC Reports** app from the App Launcher.
2. Click **RHC Reporting Coverage**.
3. Find **Opportunity Close Readiness**.
4. Refresh the browser after a brief wait if the just-published event is not visible yet.
5. Interpret the badge using this table.

| Coverage state | What it means | What the administrator should do |
| --- | --- | --- |
| **No failures** | Run summaries arrived and their `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` counts are zero. | Treat the run as clean; do not confuse zero Result facts under `ACTIONABLE` with missing coverage. |
| **No events received** | No Run or Result facts have arrived. | Confirm an explicit Run/Rerun or publishing Flow ran, its transaction committed, and the caller did not use `NONE`. |
| **Publication disabled** | Interactive publication is configured off and no events were observed. | Enable the intended publication settings, or accept that this Check Set has no reporting coverage. |
| **Partial ACTIONABLE coverage** | Run facts and actionable Result details arrived, but PASS/SKIPPED detail was not observed. | This is expected for `ACTIONABLE`; select `ALL` only when complete detail is required. |
| **Full ALL coverage** | Observed Result detail covers the evaluated Check count, including non-actionable outcomes. | No change is needed unless volume or retention is too high. |

Run summaries and Result details are independent events. During delivery, the page can temporarily
show partial or converging coverage. The page observes facts; it cannot reconstruct the exact
programmatic publication choice after the fact.

## Step 8: Open the reports and dashboard

Detailed facts can appear as soon as events are ingested. Daily trend reports require the scheduled
aggregation to process a completed day.

To open the dashboard:

1. In the **RHC Reports** app, click **Dashboards**.
2. Click **All Folders** if necessary.
3. Open the **RHC Reports** folder.
4. Click **Data Quality Trend**.
5. Click **Refresh**.
6. Check the **Last Refreshed** time before interpreting the widgets.

To open an individual report:

1. Click **Reports** in the RHC Reports app.
2. Click **All Folders**.
3. Open the **RHC Reports** folder.
4. Open the required report.
5. Click **Run** or refresh the report.

The packaged reports answer these questions:

| Report | Junior-admin question |
| --- | --- |
| **Opportunity Close Readiness** | Is this specific Check Set improving day by day? |
| **Weekly Failure Rate** | Is the overall percentage of failed Checks improving week over week? |
| **Recurring Failures** | Which Checks keep failing on the same records? |
| **Error and Unable Hotspots** | Which Checks produce the most `ERROR` or `UNABLE_TO_EVALUATE` outcomes? |
| **Recovery Rate** | Which previously actionable record/Check pairs later passed? |
| **Volume by Execution Source** | How much reporting comes from Flow, user, Batch, Scheduled, or other canonical sources? |

The Opportunity report filters on Check Set qualified API name `Opportunity_Close_Readiness`. If
your Check Set uses a different qualified API name, clone or save a copy of the report, edit that
filter, and save the copy in an administrator-controlled folder. Do not guess or remove namespace
prefixes; copy the exact **Qualified API Name** from the Custom Metadata record.

## Step 9: Complete the first-day acceptance check

Check every box before declaring reporting ready:

- [ ] Record Health Check 2.0.4.2 or newer and RHC Reports appear under Installed Packages.
- [ ] Administrators have RHC Reports Admin; viewers have RHC Reports Viewer.
- [ ] The intended caller uses `ACTIONABLE` or `ALL`, or the explicit card publication boxes are
      selected.
- [ ] One approved Opportunity test produced a Set Run fact.
- [ ] The release administrator's duplicate-Event-ID validation confirmed that redelivery does not
      create another fact.
- [ ] Reporting Coverage shows the expected state, not **No events received** or an unexplained
      **Publication disabled** state.
- [ ] Detailed retention is 90 days and the business time zone is explicit.
- [ ] RHC Reports Daily Maintenance appears under Scheduled Jobs.
- [ ] The packaged report and dashboard folders are visible to intended users.
- [ ] After the first completed-day aggregation, Data Quality Trend refreshes successfully.
- [ ] The data owner accepted storage, Platform Event, report, dashboard, and scheduled-job usage.

## Troubleshooting

| Symptom | Check in this order |
| --- | --- |
| RHC Reports is missing from the App Launcher | Confirm package installation, Permission Set assignment, then ask an app administrator to confirm app visibility. |
| Setup Assistant says Manage RHC Reports permission is required | Assign RHC Reports Admin, log out and back in, then retry. |
| Save and Apply fails | Confirm each retention value is within the displayed minimum/maximum and use a valid Salesforce time-zone ID such as `America/Chicago`. |
| Publication disabled | Revisit the Check Set and Check publication fields for explicit card runs. For Flow/Apex, inspect the caller's Event Publication input instead. |
| No events received | Confirm this was an explicit Run/Rerun or publishing programmatic call, the transaction committed, and Platform Event delivery was not exhausted or delayed. |
| Run facts appear before Result facts | Wait for asynchronous delivery and refresh. Do not delete or recreate the Run fact. |
| Dashboard is empty on setup day | Detailed events can exist before the first completed-day snapshot. Verify coverage now and check the dashboard after daily maintenance. |
| Old facts remain after retention was shortened | Verify Retention cleanup and Schedule daily maintenance are on, then check Scheduled Jobs and Apex Jobs after the next run. |
| A historical row has only a Record ID | The source record was deleted or is no longer visible. Historical facts intentionally do not copy the source record. |

## Limits and safety

Daily recomputation fails closed before replacement when it reaches 15,000 candidate Run Facts,
20,000 candidate Result Facts, or 5,000 prior Result Facts. Those conservative boundaries share
one Apex transaction query-row budget and intentionally leave headroom for snapshot replacement.
Monitor org data storage, Platform Event allocation, scheduled jobs, report rows, and dashboard
limits. High-volume days beyond those bounds require a partitioned aggregation path.

RHC Reports never retains restricted found/expected values, messages, raw payloads, fix
instructions, or stack traces. It does not schedule health checks, notify users, execute corrective
Flows, call external systems, or read any RHC Run Manager object.

## Official Salesforce navigation references

- [Manage Permission Set Assignments](https://help.salesforce.com/s/articleView?id=perm_sets_assigning.htm&language=en_US&type=5)
- [App Switching in Lightning Experience](https://help.salesforce.com/s/articleView?id=sf.basics_app_launcher_lex.htm&language=en_US&type=5)
- [Refresh Dashboard Data](https://help.salesforce.com/s/articleView?id=dashboards_refresh.htm&language=en_US&type=0)
- [Monitoring Scheduled Jobs](https://help.salesforce.com/s/articleView?id=xcloud.data_monitoring_jobs.htm&language=en_US&type=5)
- [Reports and Dashboards Limits and Allocations](https://help.salesforce.com/s/articleView?id=analytics.faq_reports_common_limits.htm&language=en_US&type=5)
