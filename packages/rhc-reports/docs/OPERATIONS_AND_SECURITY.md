# Operations and security

## Access model

### RHC Reports Admin

The packaged Admin Permission Set grants:

- the `Manage_RHC_Reports` Custom Permission;
- access to the setup, coverage, ingestion, aggregation, scheduling, and retention Apex classes;
- read, View All Records, and View All Fields on Run Facts, Result Facts, and Daily Snapshots;
- visible Setup and Coverage tabs;
- Run Reports and Create and Customize Reports.

It does not grant users create, edit, delete, or Modify All Records on the fact objects. It also does
not grant direct edit access to the hierarchy Custom Setting or broad Setup powers such as managing
users or editing core Custom Metadata. The permission-gated setup controller validates values and
writes settings in package system context so retention policy and scheduler identity commit
atomically. Other broad powers come from the administrator's existing Salesforce access.

### RHC Reports Viewer

The Viewer Permission Set grants the coverage controller, read/View All Records on the three
analytical objects, the Coverage tab, and Run Reports. Field access on raw Run and Result Facts is
limited to the aggregate fields required by Reporting Coverage. Viewer does not receive Record ID,
Run ID, Event ID, Reason Code, or contract/framework version fields. Daily Snapshot fields remain
available for packaged reports and dashboards. The Setup tab and management Custom Permission are
not granted.

Folder sharing and app visibility remain Salesforce administration responsibilities.

## Data minimization

RHC Reports retains exact IDs, qualified API names, statuses, severities, reason codes, counts,
source, occurrence time, and contract/framework versions. It does not retain:

- found or expected values;
- user-facing or technical messages;
- raw event payloads;
- fix instructions;
- stack traces; or
- a copied business-record name or field value.

Result events claiming restricted detail are rejected. Source Record ID is Text, not a relationship,
so a deleted source record can leave only its former ID in history.

## Ingestion evidence

Fact upserts are keyed by Event ID and use partial success. A delivery whose only failures are
transient (`UNABLE_TO_LOCK_ROW`, `SERVER_UNAVAILABLE`, `REQUEST_RUNNING_TOO_LONG`) is retried by
the platform at most three times; after that, and for any permanent failure, the successful facts
of that delivery are kept and the failure is recorded on the package setting as **Last Ingestion
Failure At** and sorted **Ingestion Error Codes** (for example `REQUIRED_FIELD_MISSING` or
`RETRY_EXHAUSTED`). The subscriber never throws a non-retryable exception, because that would move
the trigger into the error state and stop all reporting until an administrator resumed it. Both
values appear on the setup assistant under "Latest aggregation outcome".

## Scheduled processing

`RHC Reports Daily Maintenance` is registered with cron `0 15 2 * * ?` by the user who clicks
**Save and Apply**. Salesforce interprets 2:15 AM in that scheduling user's time zone.

At execution:

1. If Daily Aggregation is enabled, the scheduler calculates "today" in the configured aggregation
   time zone and queues the oldest missed local date, then exits.
2. Successful Queueable Finalizers continue catch-up in bounded chains. Retention waits until the
   latest completed local day succeeds, preventing cleanup from racing aggregation.
3. If Retention Cleanup is enabled after catch-up, a Result Fact Batch starts with scope 200.
4. The Result Batch chains Run Fact cleanup, then Daily Snapshot cleanup.
5. If Daily Aggregation is disabled, enabled retention starts directly from the scheduler.

## Aggregation behavior

The aggregator calculates exact UTC start and end instants for the requested date in the configured
Salesforce time zone, including daylight-saving offset changes, and queries only that half-open
window. It does not rely on the running user's locale.

Per aggregation, conservative fail-closed boundaries reserve the shared 50,000-row Apex query
budget for all queries in the transaction:

- 15,000 candidate Run Facts;
- 20,000 candidate Result Facts;
- 5,000 prior Result Facts used for recurrence/recovery comparison; and
- 5,001 rows for detecting an oversized existing snapshot partition.

Reaching any candidate or prior-result boundary raises an error before the partition is replaced;
the service never writes a knowingly partial snapshot. A day that exceeds these conservative
single-transaction boundaries requires a partitioned aggregation design before scheduling can be
considered production-ready at that volume.

Snapshot identity is SHA-256 of local date, time zone, and exact grouping dimensions. Repeating the
same date and time zone with the same facts upserts the same rows. Changing the aggregation time
zone changes the identity and can create a second set of snapshots for the same calendar date.
Choose the production time zone before enabling the schedule.

The Queueable Finalizer records the latest attempt time and a `SUCCESS`/`FAILED` status in a separate
transaction. Failures store only the Apex exception type. Successful historical recomputations do
not move `LastAggregatedDate__c` backward.

## Retention behavior

Detailed retention applies to Run and Result Facts by `OccurredAt__c`. Snapshot retention applies
to `SnapshotDate__c`. The comparison is exclusive: rows older than the calculated cutoff are
deleted. Batch deletion uses partial success.

Deletion is irreversible. Shortening retention and saving settings does not immediately delete
rows; the next successful maintenance run applies the new cutoff. Export required history before
the job runs.

Recommended Opportunity Close Readiness baseline:

| Setting | Value | Reason |
| --- | --- | --- |
| Detailed retention | 90 days | Supports recent record/Check investigations with bounded storage. |
| Snapshot retention | 730 days | Preserves two years of compact daily trends. |
| Daily aggregation | On | Produces trend rows for the prior completed local day. |
| Retention cleanup | On after approval | Enforces the chosen storage period. |
| Time zone | Business reporting zone | Keeps day boundaries stable and explicit. |
| Daily maintenance | On | Runs aggregation and cleanup without a separate scheduler. |

## Daily and weekly operating checklist

### Daily automated checks

- Scheduled Jobs contains one future `RHC Reports Daily Maintenance` execution.
- Apex Jobs shows successful Queueable and Batch work after the scheduled time.
- `LastAggregatedDate__c` advances to the prior completed local day.
- **Last Ingestion Failure At** on the setup assistant has not moved; if it has, review the error
  codes and the publishing Check Set before facts are lost for that day.
- Reporting Coverage's latest event time advances for active publishing Check Sets.

### Weekly administrator review

1. Open Reporting Coverage before the dashboard.
2. Investigate Publication disabled and No events received states.
3. Refresh Data Quality Trend and inspect its Last Refreshed time.
4. Review Weekly Failure Rate, Recurring Failures, Error/Unable Hotspots, Recovery Rate, and Source
   volume.
5. Compare data-storage growth and Platform Event publishing usage with the approved budget.
6. Review Scheduled Jobs and Apex Jobs for repeated failures.

### Monthly platform-owner review

- confirm retention still matches policy;
- confirm the aggregation time zone has not changed accidentally;
- review package/core versions and supported contract;
- confirm folder sharing and Permission Set assignments remain least privilege;
- confirm daily volume remains below the documented shared-transaction safety boundaries; and
- export evidence required by policy before it ages out.

## Capacity planning

Approximate daily Result Fact volume as:

```text
evaluated records × eligible Checks × publication fraction
```

For `ALL`, publication fraction is near 1. For `ACTIONABLE`, it is the proportion of FAIL,
UNABLE_TO_EVALUATE, and ERROR outcomes, while Set Run facts still provide one heartbeat per scanned
record. Card checkboxes can publish selected Check results regardless of status.

Monitor:

- Salesforce data storage;
- high-volume Platform Event publishing and delivery allocations;
- concurrent and daily async Apex capacity;
- Scheduled Jobs capacity;
- report row/chart and dashboard limits; and
- report/dashboard folder access.

RHC Reports does not automatically throttle core publication. Reduce publication at the caller or
shorten retention only through an approved change.

## Change controls

Treat these as production changes:

- `NONE` → `ACTIONABLE` or `ALL` publication changes;
- enabling more Check-level card publication boxes;
- aggregation time-zone changes;
- retention reductions;
- changing the user who owns the schedule;
- report clones with materially different filters; and
- permission/folder sharing changes.

Record the old value, new value, approver, expected volume, rollback decision, and whether data loss
can occur. A retention reduction cannot be rolled back after deletion.

## Backup and recovery boundary

RHC Reports has no internal undelete archive. Use an approved Salesforce export or backup product
before destructive retention changes. A backup should include all three analytical objects plus the
org setting needed to interpret time-zone and retention behavior.

Events that were never published, expired from the event bus, rejected as unsupported/restricted,
or deleted by retention cannot be recreated from core because core is stateless.

## Official Salesforce references

- [Monitoring Scheduled Jobs](https://help.salesforce.com/s/articleView?id=xcloud.data_monitoring_jobs.htm&language=en_US&type=5)
- [Define and Manage Platform Events](https://help.salesforce.com/s/articleView?id=platform.platform_events.htm&language=en_US)
- [Reports and Dashboards Limits and Allocations](https://help.salesforce.com/s/articleView?id=analytics.faq_reports_common_limits.htm&language=en_US&type=5)
