# Contributor guide

## Scope rules

Keep changes inside `packages/rhc-reports` unless a documented public core-contract gap makes a core
change unavoidable. Read the core repository `AGENTS.md` before inspecting or proposing core
changes. Never add a Run Manager object dependency.

Day-1 constraints:

- no compatibility layers, migrations, aliases, or deprecated APIs;
- core stays stateless;
- RHC Reports owns durable analytics;
- exact canonical status, severity, reason, source, Event ID, and contract vocabulary;
- no restricted details, raw payloads, or stack traces; and
- no evaluations, notifications, corrective Flows, or callouts.

## Project layout

| Path | Contents |
| --- | --- |
| `force-app/main/default/classes` | Ingestion, coverage, setup, aggregation, retention, scheduling, and tests. |
| `force-app/main/default/triggers` | Two canonical Platform Event subscribers. |
| `force-app/main/default/objects` | Three analytical objects and one hierarchy Custom Setting. |
| `force-app/main/default/lwc` | Setup Assistant and Reporting Coverage. |
| `force-app/main/default/reportTypes` | Run, Result, and Snapshot custom report types. |
| `force-app/main/default/reports` | Six packaged reports and folder. |
| `force-app/main/default/dashboards` | Data Quality Trend and folder. |
| `force-app/main/default/permissionsets` | Admin and Viewer access. |
| `docs` | User, operator, security, architecture, reporting, and validation references. |

## Dependency declaration

`sfdx-project.json` declares:

- package: `RHC Reports`, unlocked 2GP;
- version: `0.1.0.NEXT`;
- namespace: `rhc`;
- API version: 66.0; and
- sole dependency: `Record Health Check@2.0.4-2`.

## Design invariants

1. `EventId__c` stays unique and external on both fact objects.
2. Result Facts never gain fields capable of storing restricted diagnostic content.
3. New event-contract versions are rejected until explicitly implemented and tested.
4. Event triggers remain bulk; no SOQL or DML inside per-event loops.
5. Aggregation date assignment always takes an explicit time-zone ID.
6. Snapshot identity remains deterministic for date, time zone, grain, and dimensions.
7. Retention remains bounded Batch Apex and clearly irreversible.
8. Users receive read-only fact access; scheduled package processing performs analytical writes.
9. Coverage distinguishes missing events from received zero-failure runs.
10. Reports never imply unpublished outcomes exist.

## Test inventory

| Test class | Required behaviors |
| --- | --- |
| `RHCReportsIngestionServiceTest` | 251-event bulk handling, same-batch and redelivery deduplication, trigger delivery, unsupported/restricted rejection, null safety. |
| `RHCReportsAggregationServiceTest` | deterministic upsert, recurrence, recovery, invalid time zone, null date. |
| `RHCReportsRetentionBatchTest` | expired Result, Run, and Snapshot deletion. |
| `RHCReportsControllerTest` | permission-gated 90-day settings, invalid retention, observed ACTIONABLE coverage. |
| `RHCReportsMaintenanceTest` | Queueable completion date, disabled scheduler branch, invalid retention target. |

## Local metadata checks

From `packages/rhc-reports`:

```bash
rg --files force-app | rg '\.xml$' | xargs xmllint --noout
```

Search implementation metadata for prohibited storage/dependencies:

```bash
rg -n -i 'found.?value|expected.?value|stack.?trace|fix.?instruction|raw.?payload|run.?manager' force-app
```

Review every match; documentation can name prohibited concepts, implementation must not store or
query them.

## Salesforce validation

Use an isolated namespaced org that contains only promoted core 2.0.4.2 as the dependency:

```bash
sf project deploy start --dry-run --source-dir force-app \
  --target-org <isolated-org> --test-level RunLocalTests --wait 60 --json
```

The latest recorded validation completed 97/97 components and 35/35 tests with no component, test,
or coverage error. Update [Package validation](PACKAGE_VALIDATION.md) after every release candidate.

## Code Analyzer

Run Salesforce Code Analyzer Recommended with timestamped JSON and log files:

```bash
sf code-analyzer run --rule-selector Recommended --target force-app \
  --output-file ./code-analyzer-results-YYYYMMDD-HHMMSS.json \
  --include-fixes 2>&1 | tee ./code-analyzer-results-YYYYMMDD-HHMMSS.log
```

Release acceptance requires no unresolved severity 1 or 2 finding. Document remaining findings and
their rationale; do not hide them by changing rule configuration without an approved repository
policy.

## 2GP version and independent install

```bash
sf package version create --package "RHC Reports" \
  --target-dev-hub rhc-dev-hub --installation-key-bypass \
  --code-coverage --wait 120
```

Install the resulting `04t` into a clean subscriber containing core 2.0.4.2 and no extension
package, then execute the acceptance checklist in Package validation. Package container:
`0Hoak0000005M7xCAE`.

## Documentation completion checklist

- [ ] README and docs index route each audience correctly.
- [ ] Architecture/data dictionary matches metadata.
- [ ] Event mappings and supported contract match Apex.
- [ ] Setup clicks, labels, defaults, and validation match LWC/Apex.
- [ ] Report catalog matches exact filters/groupings/dashboard sources.
- [ ] Operations documents schedule, time zones, query bounds, retention, and recovery boundary.
- [ ] Validation evidence has actual job IDs/counts and truthful pending gates.
- [ ] Demo scripts remain sandbox-scoped, idempotent where documented, and use exact canonical
      event vocabulary.
- [ ] Demo expected counts and cleanup filters match the scripts.
