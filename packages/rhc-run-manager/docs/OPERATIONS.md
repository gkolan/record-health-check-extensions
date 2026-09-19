# Operations runbook

## Daily monitoring

1. Open **RHC Run Manager** from the App Launcher.
2. Open **3. Monitoring**.
3. Click the refresh icon.
4. Review newest Batch Runs first. Pass, Fail, Unable, and Error totals are rolled up from the
   completed scopes, so a run's business outcome is visible without opening each scope.
5. Investigate any Batch Run with `PARTIAL_FAILURE`, or one that remains unexpectedly queued or
   processing, before changing its definition.
6. Use **View scopes** to find the affected scope.
   Use **Cancel** on a `QUEUED` or `PROCESSING` Batch Run that targets the wrong population.
7. Use **View retained results** to inspect business outcomes retained by Capture Mode.

## Status interpretation

### Batch Run

| Status | Meaning | Operator action |
| --- | --- | --- |
| `QUEUED` | Batch submitted but not started | Check Async Apex queue if prolonged |
| `PROCESSING` | Batch start executed; scopes may be running | Refresh later; do not submit duplicates |
| `COMPLETED` | All Batch scopes completed without caught system exception | Review counts/results as needed |
| `PARTIAL_FAILURE` | At least one scope threw; earlier successful scopes remain committed | Inspect failed scope/error summary and target data/access |
| `ERROR` | Population could not be discovered; no scope ran | Correct the definition or filter, then Run Now |
| `CANCELLED` | An administrator used **Cancel**; the owned platform job was aborted and the cancelling user is in the error summary | Scopes committed before the abort remain; rerun when ready |

### Scope Run

| Status | Meaning |
| --- | --- |
| `IN_PROGRESS` | Scope envelope exists and core evaluation has not completed |
| `COMPLETED` | Core response captured and summary recorded |
| `ERROR` | Scope threw an exception; error summary was sanitized and retained |

Check failures are not platform failures. A completed Run can correctly have a nonzero Fail count.

## Count reconciliation

- **Submitted**: records handed to Batch scopes.
- **Processed**: records in scopes that completed core evaluation.
- **Failed scopes**: scope envelopes marked Error.
- Run **Pass/Fail/Skipped/Unable/Errors**: canonical core summary counts.
- Detailed Results: only statuses selected by Capture Mode.

It is valid for detailed Result count to be lower than total summary count. `SKIPPED` is never
retained, and PASS/FAIL groups can be intentionally excluded.

## Partial-failure response

1. Record the Batch Run ID and Async Apex Job ID.
2. Open its scope Runs and identify `ERROR` scopes.
3. Review the scope error summary.
4. Check recent permission, sharing, validation, core metadata, and target-data changes.
5. Do not delete successful earlier scopes; they are evidence of committed work.
6. Correct the cause.
7. Start a new run using the saved definition. Run Manager does not mutate the historical Batch Run
   into a retry.
8. Compare the new Batch Run with the failed one.

## Schedule operations

### Pause safely

1. Open **2. Schedules**.
2. Find the schedule.
3. Open the row-action menu.
4. Click **Pause**.
5. Confirm Active is false in the table.

Pause uses the stored CronTrigger only after verifying that the platform job name belongs to the
same packaged Schedule record.

### Edit

1. Open the schedule row-action menu.
2. Click **Edit**.
3. Change recurrence, time, weekday, or dates.
4. Click **Save Schedule**.
5. Confirm the old owned platform job is replaced and the table shows the new values.

### End date

After the End Date, the scheduled adapter deactivates its Schedule and clears the stored trigger ID.
Start Date must be on or before End Date.

## Supplied-ID queue operations

Run Requests are durable operational evidence:

- `PENDING`: staged and waiting for the definition's coalescer;
- `SUBMITTED`: drained into an execution attempt or rejected as an invalid stored ID.

Do not manually change statuses during normal operation. If pending rows persist beyond the
consolidation window plus queue latency:

1. Confirm the definition is active and uses Supplied Ids.
2. Confirm the automation user has Executor plus core/target access.
3. Review Apex Jobs for `RHCRunManagerCoalescerQueueable`.
4. Review the newest Batch Run for the definition.
5. Preserve rows until root cause is understood.

An unhandled coalescer failure receives at most two package-owned finalizer retries. After retry
exhaustion, requests remain `PENDING`; investigate the failed Apex Jobs and correct the underlying
permission, configuration, or limit issue before submitting another request to re-arm coalescing.

## Storage and retention

Capture Mode controls detailed history volume:

- use **Fail** for typical exception-oriented operations;
- use **Both** during controlled validation or when full detail is a firm requirement;
- use **Pass** only when passing evidence is specifically needed.

Run Manager does not silently delete history. Establish an organization-approved retention process
for Batch Runs, Runs, Results, and submitted Requests. Preserve lookup order when deleting: Results
before Runs, Runs before Batch Runs; do not delete active configuration referenced by schedules.

For package uninstall, export required history first. The package lifecycle handler aborts only
Run Manager-owned active Batch, coalescer, and named scheduled jobs so those jobs do not block
uninstall. Verify customer-owned scheduled and asynchronous work independently; it is intentionally
outside the handler's scope.

## Installation and access

| Symptom | Resolution |
| --- | --- |
| App not in App Launcher | Assign Admin or Viewer; refresh session; verify package install |
| Definition picker empty | Assign core access; activate core metadata; select correct Selection Type |
| Target fields missing | Verify target-object and field read permissions |
| Save access error | Assign Run Manager Admin and appropriate core permissions |
| Flow action missing | Assign Executor; confirm package version and action label |
| Monitoring empty | Confirm a run was launched and user has Viewer/Admin record access |

## Platform queue checks

In Setup:

1. Enter `Apex Jobs` in Quick Find.
2. Open **Apex Jobs**.
3. Find the Async Apex Job ID shown on the Batch Run record if available.
4. Review Status, Job Type, Apex Class, Total Job Items, Job Items Processed, and Errors.

For schedules:

1. Enter `Scheduled Jobs` in Quick Find.
2. Open **Scheduled Jobs**.
3. Look for names beginning `RHC Run Manager`.
4. Use the Run Manager UI to edit/pause; do not manually replace the packaged job with custom CRON.

## Escalation packet

Provide these facts to a developer/support engineer:

- org ID and package versions;
- affected Run Definition ID and Name;
- Batch Run ID, source, status, counts, and Async Apex Job ID;
- affected scope Run ID and error summary;
- Capture Mode and Batch Size;
- selected Check Set/Check Qualified API Name as displayed in records;
- whether the source was Run Now, Scheduled, or Supplied IDs;
- Flow interview/debug evidence for supplied IDs;
- timestamps and user who launched/owns the schedule.

Do not include access tokens or unrelated customer data.
