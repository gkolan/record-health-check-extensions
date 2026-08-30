# Reporting reference

## Coverage before charts

Always open **RHC Reporting Coverage** before interpreting a zero or empty chart. An empty report can
mean no failures, no published events, disabled publication, missing daily aggregation, a report
filter mismatch, or lack of folder/object access.

Coverage states are observational:

| State | Classification |
| --- | --- |
| Publication disabled | No facts, interactive Set Run publication off, and no active Check has interactive Result publication on. |
| No events received | No Run or Result facts, but interactive configuration is not fully off. |
| Full ALL coverage | Observed Result Fact count is at least the summed evaluated Check count. |
| No failures | At least one Run Fact and summed FAIL + UNABLE + ERROR counts equal zero. |
| Partial ACTIONABLE coverage | Result Facts exist but no PASS or SKIPPED detail was observed. |
| Events received; coverage still converging | Events exist but no stronger classification currently applies. |

Programmatic publication configuration is not stored in the event. The page can infer observed
coverage but cannot prove which enum a historical caller selected.

## Custom Report Types

| Label | Base object | Intended use |
| --- | --- | --- |
| RHC Report Runs | Run Fact | Immediate Set Run completion volume and five-status summary reporting. |
| RHC Report Results | Result Fact | Immediate per-Check status, severity, reason, and recurrence investigation. |
| RHC Daily Snapshots | Daily Snapshot | Daily/weekly trends, source distribution, recovery, and recurring failure aggregates. |

All three are deployed in the **Other Reports** category. Users need object read access, field
access, **Run Reports**, and access to the report folder.

## Packaged reports

All packaged reports are stored in the **RHC Reports** folder.

### Weekly Failure Rate

- Source: RHC Daily Snapshots.
- Filter: `Grain__c = RUN`.
- Grouping: Snapshot Date by week.
- Metric: weighted custom summary formula: total FAIL + UNABLE_TO_EVALUATE + ERROR divided by all
  five summarized status counts.
- Use: direction-of-travel from received Set Run summaries.
- Caveat: it represents published runs, not every record in the org.

### Recurring Failures

- Source: RHC Daily Snapshots.
- Filter: `Grain__c = RESULT` and Status is `ERROR` or `UNABLE_TO_EVALUATE`.
- Grouping: Check Qualified API Name.
- Metric: sum of Recurring Failure Count; Record Count is also shown.
- Use: identify Checks whose same record/Check pair remained actionable after a prior actionable
  observation.
- Caveat: multiple events during a day can contribute transitions; this is observed event history,
  not a unique-case workflow count.

### Error and Unable Hotspots

- Source: RHC Daily Snapshots.
- Filter: `Grain__c = RESULT`.
- Matrix grouping: Check by Status.
- Metric: sum of Result Count.
- Use: compare `ERROR` and `UNABLE_TO_EVALUATE` columns by Check.
- Caveat: status comparison reflects published Result events only.

### Recovery Rate

- Source: RHC Daily Snapshots.
- Filter: `Grain__c = RESULT`.
- Grouping: Check Qualified API Name.
- Metrics: Recovery Count, Recurring Failure Count, and weighted Recovery / (Recovery + Recurring
  Failure).
- Use: compare actionable-to-PASS transitions with continued actionable outcomes.
- Caveat: reliable recovery requires `ALL`; `ACTIONABLE` does not publish PASS details.

### Volume by Execution Source

- Source: RHC Daily Snapshots.
- Grouping: canonical Source.
- Metric: sum of Run Count, with Result and Record Count columns.
- Use: determine whether received reporting activity comes from users, Flow, Apex, Batch, or other
  canonical callers.
- Caveat: RESULT-grain rows have Run Count zero; the donut's Run Count therefore represents RUN
  grain without a separate grain filter.

### Opportunity Close Readiness

- Source: RHC Daily Snapshots.
- Filter: `CheckSetQualifiedApiName__c = Opportunity_Close_Readiness` and `Grain__c = RUN`.
- Grouping: Snapshot Date by day.
- Metrics: Result Count and weighted Failure Rate across summarized run outcomes.
- Use: the packaged junior-admin example.
- Caveat: if the Check Set's exact qualified API name differs, clone the report and replace the
  filter with the value copied from Custom Metadata.

## Data Quality Trend dashboard

The dashboard runs as the logged-in user and contains five widgets:

| Widget | Source report | Display |
| --- | --- | --- |
| Weekly trend | Weekly Failure Rate | Line |
| Recurring failures | Recurring Failures | Bar |
| Technical hotspots | Error and Unable Hotspots | Stacked column |
| Recovery | Recovery Rate | Column |
| Source distribution | Volume by Execution Source | Donut |

The dashboard does not include the Opportunity-specific report and has no packaged dashboard
filter. Clone it when a team needs a separately filtered or curated view.

## Metric interpretation

| Metric | Correct interpretation | Do not claim |
| --- | --- | --- |
| Failure Rate | Share of observed status counts that are FAIL, UNABLE, or ERROR. | Percentage of all org records that are unhealthy. |
| Record Count | Distinct nonblank Record IDs inside one snapshot group. | A deduplicated count across groups or dates. |
| Recurring Failure Count | Current actionable result followed a prior actionable result for the same record and Check. | Number of unresolved business cases. |
| Recovery Count | Current PASS followed a prior actionable result for the same record and Check. | Complete recovery under ACTIONABLE publication. |
| Run/Result Count | Accepted event facts represented in the group. | Proof that event publication never failed. |

Salesforce reports display a bounded number of rows and dashboards can cache prior results. Use
**Refresh**, inspect **Last Refreshed**, narrow filters, or export when analysis exceeds UI limits.
