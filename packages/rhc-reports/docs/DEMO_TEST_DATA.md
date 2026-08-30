# Demo data and complete functional test

**Audience:** A junior Salesforce administrator working with a release administrator.  
**Environment:** A sandbox, scratch org, or disposable demo org only.  
**Time required:** About 60 minutes, plus asynchronous event delivery and one overnight maintenance
run for the true daily-aggregation test.

This pack provides reusable demo data and an acceptance test for the subscriber experience. It is
not production data and it does not alter Record Health Check core metadata automatically.

## What the demo covers

| Capability | How it is tested |
| --- | --- |
| Real Opportunity evaluation | Four marked Opportunities with clean, failing, mixed, and recovery-ready values. |
| Canonical event subscriptions | Core Set Run and Result Platform Events are published in bulk. |
| At-least-once delivery | Duplicate Event IDs are deliberately published. |
| Run/Result ordering | A Result is published and verified before its Run summary. |
| Contract and privacy rejection | One unsupported-contract Run and one restricted-detail Result must be ignored. |
| Coverage UI | Synthetic rows demonstrate No failures, Partial ACTIONABLE, and Full ALL. Configured core sets demonstrate Publication disabled and No events received. |
| Reports and dashboard | Six weeks of clearly labeled synthetic snapshots populate every packaged chart. |
| Recurring failures and recovery | Stable record/Check pairs transition through repeated FAIL and later PASS patterns. |
| ERROR and UNABLE hotspots | Canonical statuses and reason codes are present without messages or raw detail. |
| Source volume | `USER_INITIATED`, `FLOW`, `BATCH`, `QUEUEABLE`, `SCHEDULED`, and `APEX_API`. |
| Daily aggregation | Yesterday's ingested facts are aggregated by the scheduled job, separate from seeded snapshots. |
| Retention | Optional destructive test uses only marked demo facts in a disposable org. |
| Deleted source record behavior | Optional cleanup removes Opportunities while facts retain former Record IDs. |
| Permissions | Admin and Viewer personas are tested separately. |

Automated Apex tests remain the authority for branch-level bulk limits, retry-safe snapshot keys,
time-zone rejection, controller permission gates, Batch chaining, and retention boundaries. The demo
pack complements those tests; it does not replace them.

## Safety rules

1. Never run these scripts in production.
2. Confirm the org name and sandbox indicator before every script.
3. Record current Platform Event and data-storage usage.
4. Keep Retention Cleanup off until the optional destructive test.
5. Do not edit the marker `RHC_REPORTS_DEMO_V1` or the `RHC-DEMO-` Event ID prefix.
6. Synthetic reporting rows are named `Opportunity_Close_Readiness` so the packaged example report
   works without cloning.
7. Real core evaluations use the Check Set actually installed in the org. Core currently ships the
   example **Example: Opportunity Deal Readiness**; copy its exact Qualified API Name rather than
   assuming the synthetic reporting name.
8. The scripts never populate found/expected values, messages, raw payloads, fix instructions, or
   stack traces.

## Files in the demo pack

| Script | Purpose | Safe to rerun? |
| --- | --- | --- |
| `create-opportunity-demo.apex` | Creates or resets four marked source Opportunities. | Yes |
| `repair-recovery-candidate.apex` | Changes the recovery candidate to passing values. | Yes |
| `publish-canonical-demo-events.apex` | Publishes six weeks of canonical events plus duplicate IDs. | Yes; fact counts must not increase |
| `publish-ingestion-edge-events.apex` | Publishes a Result-before-Run test and two rejected events. | Yes |
| `publish-late-run-event.apex` | Completes the Result-before-Run scenario. | Yes |
| `seed-reporting-snapshots.apex` | Upserts six weeks of synthetic report/dashboard aggregates. | Yes |
| `cleanup-opportunity-demo.apex` | Deletes only source records with the exact marker. | Destructive |
| `cleanup-reporting-demo.apex` | Deletes synthetic facts/snapshots with the demo identities. | Destructive |

All paths below are relative to `packages/rhc-reports`.

## Before starting

Complete these checkpoints:

- Record Health Check core 2.0.4.2 or a later explicitly compatible version is installed.
- RHC Reports is installed and **RHC Reports Admin** is assigned to the tester.
- Setup Assistant contains 90 detailed-retention days, 730 snapshot-retention days, the approved
  explicit time zone, Daily Snapshots on, Retention Cleanup off, and the schedule on.
- A second user has **RHC Reports Viewer** for the persona test.
- The core example Opportunity Check Set is active.
- The tester can create Account and Opportunity records and run Record Health Checks.

Use [Click-by-click setup](CLICK_BY_CLICK_SETUP.md) if any checkpoint is incomplete.

## How to run a demo script

### Salesforce CLI method

From the `packages/rhc-reports` directory:

```bash
sf apex run --file scripts/demo/create-opportunity-demo.apex --target-org <sandbox-alias>
```

Replace the filename for later procedures. A successful command ends with a compiled/successful
result. Read errors before continuing.

### Browser method

1. Log in to the sandbox.
2. Click the gear.
3. Click **Developer Console**.
4. In Developer Console, click **Debug**.
5. Click **Open Execute Anonymous Window**.
6. Open the requested `.apex` file locally.
7. Copy the entire file contents.
8. Paste into Enter Apex Code.
9. Leave **Open Log** selected for the first execution.
10. Click **Execute**.
11. Wait for the log to open.
12. Confirm the final message reports success. Stop on a fatal error or unhandled exception.

The CLI method is preferred because it records the exact file used.

## Test 1: Create realistic Opportunity source records

Run:

```bash
sf apex run --file scripts/demo/create-opportunity-demo.apex --target-org <sandbox-alias>
```

Then verify in Lightning:

1. Open App Launcher.
2. Open **Sales**.
3. Click **Opportunities**.
4. Select **All Opportunities**, or use Search this list.
5. Search for `[RHC DEMO]`.
6. Confirm exactly four records:
   - Ready Opportunity;
   - Recurring Failure;
   - Recovery Candidate; and
   - Mixed Readiness.
7. Open each record and confirm Description is `RHC_REPORTS_DEMO_V1`.

Expected core outcomes with the shipped Opportunity example:

| Record | Expected pattern |
| --- | --- |
| Ready Opportunity | Amount, Close Date, Next Step, and Probability pass. |
| Recurring Failure | The four readiness conditions fail. |
| Recovery Candidate | Starts failing and will later be repaired. |
| Mixed Readiness | Amount, Close Date, and Probability pass; Next Step fails. |

Actual status remains authoritative because subscriber org validation rules, field automation,
stage probability, currency configuration, or custom metadata may differ.

## Test 2: Run the real core Check Set with ALL

1. In Setup, open **Custom Metadata Types**.
2. Find **Record Health Check Set** and click **Manage Records**.
3. Open **Example: Opportunity Deal Readiness**, or the approved Opportunity readiness set.
4. Copy its exact **Qualified API Name**.
5. Follow Procedure 6B in [Click-by-click setup](CLICK_BY_CLICK_SETUP.md) to configure a sandbox Flow
   using **Run Record Health Check Set**.
6. Set Event Publication to **All (ALL)**.
7. Debug the Flow once for each of the four Opportunity IDs.
8. Confirm each Flow transaction succeeds and commits.
9. Wait for asynchronous delivery, then open **RHC Reporting Coverage**.
10. Confirm Run and Result fact counts increase for the exact Check Set identity.

This is the genuine end-to-end test. The following synthetic events test reporting edge cases that
would be unsafe or unreliable to manufacture through broken production-style Check metadata.

## Test 3: Publish the deterministic reporting event dataset

Run:

```bash
sf apex run --file scripts/demo/publish-canonical-demo-events.apex \
  --target-org <sandbox-alias>
```

The script asks the event bus to accept 27 Run events and 98 Result events. One of each is an exact
duplicate by Event ID. Delivery is asynchronous; acceptance is not proof that subscribers have
finished.

Wait briefly, then verify using Reports:

1. Open **Reports**.
2. Click **New Report**.
3. Choose **RHC Report Runs**.
4. Filter Run ID starts with `RHC-DEMO-`.
5. Run the report. Expect **26** unique Run Facts.
6. Repeat with **RHC Report Results**. Expect **97** unique Result Facts.

Rerun the same script. After delivery settles, the counts must remain 26 and 97. If either count
increases, duplicate Event IDs are not being handled idempotently.

## Test 4: Verify coverage classifications

Open **RHC Reporting Coverage** and refresh after delivery settles.

| Synthetic row | Expected state | Why |
| --- | --- | --- |
| `Opportunity_Close_Readiness` | Full ALL coverage | 24 Runs × 4 evaluated Checks and 96 Result details. |
| `RHC_Demo_Actionable` | Partial ACTIONABLE coverage | One failing detail exists, but PASS/SKIPPED details do not. |
| `RHC_Demo_No_Failures` | No failures | A Run summary exists and all actionable counts are zero. |

To demonstrate the two configuration-only states:

1. Find an active Check Set that has no facts and has **Publish User Run Event** off with every
   Check's **Publish User Result Event** off. Expect **Publication disabled**.
2. In the sandbox only, enable **Publish User Run Event** for a different unused active Check Set,
   but do not run it. Refresh Coverage. Expect **No events received**.
3. Revert that temporary metadata change immediately.

Do not manufacture these two states by deleting facts from a used Check Set.

## Test 5: Verify independent and late event arrival

Run:

```bash
sf apex run --file scripts/demo/publish-ingestion-edge-events.apex \
  --target-org <sandbox-alias>
```

After delivery settles:

1. Create or run an RHC Result Fact report filtered to Run ID
   `RHC-DEMO-LATE-RUN`. Expect one row.
2. Run an RHC Run Fact report filtered to Run ID `RHC-DEMO-LATE-RUN`. Expect zero rows.
3. Confirm Run ID `RHC-DEMO-RESTRICTED-RUN` created no Result Fact.
4. Confirm Run ID `RHC-DEMO-UNSUPPORTED-CONTRACT` created no Run Fact.

Now run:

```bash
sf apex run --file scripts/demo/publish-late-run-event.apex \
  --target-org <sandbox-alias>
```

After delivery, the same Run ID report must show one Run Fact while the earlier Result Fact remains.
This proves neither subscriber requires the other event to arrive first.

## Test 6: Populate and inspect reports immediately

Run:

```bash
sf apex run --file scripts/demo/seed-reporting-snapshots.apex \
  --target-org <sandbox-alias>
```

This upserts **23 synthetic snapshots** across six weeks. It deliberately seeds aggregates so a demo
does not need to wait six real weeks. It does not claim to test aggregation.

1. Open the public read-only **RHC Reports** folder.
2. Run **Opportunity Close Readiness**. Expect six dated groups for
   `Opportunity_Close_Readiness`.
3. Run **Weekly Failure Rate**. Expect six weeks and a generally improving failure rate.
4. Run **Recurring Failures**. Expect `Opportunity_Close_Date_Current` to lead recurring failures.
5. Run **Error and Unable Hotspots**. Expect ERROR and UNABLE_TO_EVALUATE columns on their configured
   weeks. The current packaged matrix can also display other statuses.
6. Run **Recovery Rate**. Expect recoveries for `Opportunity_Amount_Positive` in recent weeks.
7. Run **Volume by Execution Source**. Expect six canonical execution sources.
8. Run the seed script again. The snapshot count for the demo set must remain 23 because Snapshot
   Key is deterministic.

## Test 7: Verify the packaged dashboard

1. Click **Dashboards**.
2. Open the public read-only **RHC Reports** folder.
3. Open **Data Quality Trend**.
4. Click **Refresh**.
5. Confirm all five widgets render:
   - weekly trend;
   - recurring failures;
   - technical hotspots;
   - recovery; and
   - source distribution.
6. Record the Last Refreshed time.
7. Confirm no widget exposes messages, found/expected values, payloads, fixes, or stack traces.

## Test 8: Verify true daily aggregation

The reporting event script publishes one group dated yesterday. Seeded snapshots start two days ago,
so they do not collide with this test.

1. Confirm Setup Assistant has the intended explicit time zone, Daily Snapshots on, and schedule on.
2. After the next 2:15 a.m. scheduled execution, open Setup → **Apex Jobs**.
3. Confirm the scheduled job and aggregation Queueable completed.
4. Run an **RHC Daily Snapshots** report for yesterday.
5. Filter Check Set Qualified API Name to `Opportunity_Close_Readiness`.
6. Confirm RUN and RESULT grain rows exist and show the configured time zone.
7. Record the snapshot count and keys.
8. Allow the next approved retry/re-execution in a development org, then confirm the same keys were
   updated rather than duplicated. Branch-level Apex tests enforce this retry behavior directly.

## Test 9: Verify the recovery story with real source data

1. Run the real core Check Set with `ALL` for `[RHC DEMO] Recovery Candidate` while it is failing.
2. Confirm actionable Result Facts arrive.
3. Run:

```bash
sf apex run --file scripts/demo/repair-recovery-candidate.apex \
  --target-org <sandbox-alias>
```

4. Reopen the Opportunity and confirm Amount, Close Date, Probability, and Next Step are now ready.
5. Run the same core Check Set again with `ALL`.
6. Confirm PASS Result Facts arrive for the same Opportunity and Check identities.
7. After aggregation, verify Recovery Count/Rate. `ACTIONABLE` is insufficient because it does not
   publish the later PASS details.

## Test 10: Verify Viewer permissions

1. Log in as the Viewer test user.
2. Open App Launcher → **RHC Reports**.
3. Confirm Reporting Coverage, packaged reports, and dashboard are readable.
4. Confirm RHC Reports Setup is unavailable.
5. Confirm raw Record ID, Run/Event ID, Reason Code, and version fields are not available.
6. Confirm facts and snapshots are read-only.
7. Confirm the user cannot schedule maintenance or change retention.

## Optional destructive test: retention

Perform only in a disposable org after exporting evidence.

1. Record current demo Run/Result Fact counts and 23 seeded snapshots.
2. In Setup Assistant, change Detailed retention to **30** days.
3. Leave Snapshot retention at **730** days.
4. Turn Retention Cleanup on and keep the schedule on.
5. Re-read the irreversible warning and save.
6. After maintenance completes, verify demo facts older than 30 days were deleted.
7. Verify the older seeded Daily Snapshots remain.
8. Restore Detailed retention to 90 days. Deleted facts do not return.

This validates detail-versus-snapshot retention. It cannot reconstruct deleted or unpublished data.

## Optional deleted-source-record test

Run:

```bash
sf apex run --file scripts/demo/cleanup-opportunity-demo.apex \
  --target-org <sandbox-alias>
```

Confirm the four Opportunities disappear but historical facts still contain their former Record ID
as text. This is expected and is not a broken lookup.

## Full cleanup

Cleanup is irreversible. Preserve screenshots or exports first.

```bash
sf apex run --file scripts/demo/cleanup-reporting-demo.apex \
  --target-org <sandbox-alias>
sf apex run --file scripts/demo/cleanup-opportunity-demo.apex \
  --target-org <sandbox-alias>
```

The reporting cleanup removes only facts with `RHC-DEMO-` Event IDs and snapshots whose Check Set is
`Opportunity_Close_Readiness`. The source cleanup removes only records with the exact Description
marker. It does not remove custom metadata, packaged reports, dashboards, settings, or schedules.

## Acceptance record

Record these results in the release evidence:

| Check | Expected | Actual | Pass? |
| --- | --- | --- | --- |
| Four marked Opportunities | 4 | | |
| Initial unique synthetic Run Facts | 26 | | |
| Initial unique synthetic Result Facts | 97 | | |
| Counts after exact rerun | unchanged | | |
| Late Result before Run | Result 1, Run 0 | | |
| Late Run after second script | Result 1, Run 1 | | |
| Restricted Result retained | 0 | | |
| Unsupported contract Run retained | 0 | | |
| Synthetic snapshots | 23 | | |
| Snapshot count after rerun | 23 | | |
| Required coverage states | visible/verified | | |
| Six reports | render expected patterns | | |
| Five dashboard widgets | render | | |
| Overnight aggregation | completed | | |
| Viewer persona | read-only, no setup | | |
| Retention test | optional, disposable org only | | |

Attach package versions, org ID, explicit time zone, execution timestamps, report exports, and Apex
Job IDs. Never attach restricted diagnostic payloads.
