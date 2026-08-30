# RHC Reports specification

## Why this project exists

Core deliberately stores no durable Run or Result records. A response helps the immediate caller,
and a Platform Event helps subscribers, but neither creates a reporting dataset. Administrators
otherwise need to design objects, event subscribers, retention, aggregates, report types, reports,
and dashboards.

RHC Reports turns published core lifecycle events into a minimal, durable analytical model and
ships native Salesforce reports and dashboards.

## User value

A junior administrator can enable retention, confirm event coverage, and use packaged dashboards to
answer:

- Is data quality improving?
- Which Checks fail most often?
- Where are `UNABLE_TO_EVALUATE` and `ERROR` increasing?
- Which records repeatedly fail and later recover?
- Are failures concentrated in interactive, Flow, Apex, or scheduled runs?

No custom Platform Event Flow, report type, or dashboard construction is required.

## Dependency on core

RHC Reports depends only on core. It subscribes directly to
`Record_Health_Check_Set_Run__e` and `Record_Health_Check_Result__e`, validates their contract
versions, and writes its own facts. It never reads Run Manager objects.

Coverage depends on the originating request:

| Core publication | Reporting coverage |
| --- | --- |
| `NONE` | No reporting data |
| `ACTIONABLE` | Run summaries and actionable result detail |
| `ALL` | Run summaries and all published Check-result detail |

Core stays stateless; RHC Reports performs the durable writes.

## Owned data and behavior

- Run Fact: exact run/set identity, source, occurrence time, record totals, and five status counts.
- Result Fact: record, Check Set, Check, status, severity, reason, source, and occurrence time.
- Daily Snapshot: bounded aggregates by date, identity, status, severity, and source.
- Custom Report Types, packaged reports, dashboards, retention, and aggregation jobs.

Analytical facts exclude found/expected values, messages, raw payloads, fix instructions, and stack
traces. Operational troubleshooting detail belongs to the immediate caller or Run Manager.

## Example

Maya installs RHC Reports, chooses 90-day detailed retention, and enables daily snapshots. The setup
assistant shows that `Opportunity_Close_Readiness` publishes `ALL`, while two Account Check Sets
publish no events and therefore have no coverage.

After enabling the intended core publication settings, Maya opens the packaged **Data Quality
Trend** dashboard. She filters to Opportunity readiness and sees weekly failure rate, recurring
failures, error hotspots, recovery rate, and volume by source. She shares the dashboard folder with
Sales Operations without granting access to restricted diagnostic values.

## Constraints it cannot escape

- It cannot report unpublished outcomes or reconstruct history from before installation.
- `ACTIONABLE` cannot produce per-Check PASS or SKIPPED detail that core did not publish.
- Platform Event delivery is asynchronous and at least once; facts require idempotent Event IDs.
- Cross-transaction event order is not guaranteed, so summaries and details can become consistent
  at different times.
- Salesforce data storage, Platform Event allocation, report-row, dashboard, and scheduled-job
  limits apply.
- Deleted source business records can leave historical facts containing only their former record ID.
- Retention deletion is irreversible unless the customer exports or backs up facts.
- Reports reflect the running identities and publication choices that produced events; they are not
  proof that every org record was evaluated.

## Boundaries

Reports owns minimal analytics, not operational Batch monitoring. It does not schedule evaluations,
send alerts, execute Flows, or deliver external payloads.

## Acceptance criteria

1. It installs with core and without another extension.
2. Duplicate Event IDs do not create duplicate facts or aggregates.
3. Dashboards distinguish missing coverage from zero failures.
4. Retention and aggregation are retry-safe and time-zone explicit.
5. Viewer permissions exclude restricted result content by design.
