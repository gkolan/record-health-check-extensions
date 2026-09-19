# Extension suite improvement plan — September 2026

Review date: 2026-09-18. Scope: every package under `packages/rhc-*`, reviewed as source, by
Salesforce Code Analyzer (`Recommended` selector, 513 findings, none at severity 1 or 2), by Jest,
and by deploying every package to the shared no-namespace org and running its Apex tests.

## Baseline before this work

| Package | Deploy (components) | Apex tests | Jest | Analyzer sev 3 |
| --- | ---: | ---: | ---: | ---: |
| rhc-logs | 56/56 | 32 pass | 16 pass | 0 |
| rhc-builder | 57/57 | 40 pass | 32 pass | 0 |
| rhc-alerts | 74/74 | 50 pass | 11 pass | 0 |
| rhc-actions | 86/86 | 44 pass | 4 pass | 0 |
| rhc-integrations | 61/61 | 23 pass | 8 pass | 0 |
| rhc-reports | 100/100 | 25 pass | 5 pass | 58 |
| rhc-run-manager | 110/110 | 47 pass | 12 pass | 170 (all disabled by its `code-analyzer.yml`) |
| rhc-change-monitor | 44/44 | 19 pass | n/a | 0 |

Build org: `rhc-change-monitor-nons-shared-20260830` (no namespace, core deployed as unmanaged
source, expires 2026-09-29). It is the only authenticated non-namespace org that still contains
core; `rhc-specs-nons-20260904` expires today and holds no core source.

## Cross-suite finding X1 — stale client cache after writes

Every package exposes list/status Apex methods as `@AuraEnabled(cacheable=true)` and then calls
them **imperatively** again immediately after a write (approve, reject, save, replay, run now,
cleanup). Imperative calls to cacheable methods are served from the Lightning client cache for
identical arguments, so the refreshed table shows the pre-write state until the page is reloaded.
Reproduction: approve a Pending Action in RHC Actions, observe it is still listed after the
"Action queued" toast.

Resolution (per package, no shared code): remove `cacheable=true` from read methods that a
component re-fetches after a write. Keep it on describe-style reads whose result cannot change
during a session (object/field lists, authoring contract, limit info, selections).

## Result after this work (2026-09-18, same org)

| Package | Deploy | Apex tests (run ID) | Jest | Change |
| --- | ---: | --- | ---: | --- |
| rhc-logs | 56/56 | 34 pass (`707RL00001hfQBm`) | 16 | L1 retry cap, L2 cleanup continuation, X1 |
| rhc-builder | 57/57 | 41 pass (`707RL00001hfNPH`) | 32 | B1 component failures on ledger, X1 |
| rhc-alerts | 74/74 | 50 pass (`707RL00001hfPUI`) | 11 | X1 (A2 rejected, see spec) |
| rhc-actions | 86/86 | 44 pass (`707RL00001hfCtz`) | 5 | X1, AC2 busy table |
| rhc-integrations | 61/61 | 26 pass (`707RL00001hfHVj`) | 8 | I1 sliced delivery, X1 |
| rhc-reports | 102/102 | 26 pass (`707RL00001hfIg9`) | 5 | R1 subscriber resilience, R2 test debt, X1 |
| rhc-run-manager | 110/110 | 49 pass (`707RL00001heww7`) | 13 | RM1 overlap guard, RM2 cancel, X1 |
| rhc-change-monitor | 44/44 | 19 pass (`707RL00001hfJ97`) | n/a | none (blocked on Gate 3) |

Code Analyzer after the change: 0 findings at severity 1 or 2 across all packages;
`AvoidHardcodingId` and `@lwc/lwc/no-async-operation` are gone. `npm audit --audit-level=high` is
clean in every package after a lockfile-only bump of the transitive `js-yaml` 3.15.1 → 3.15.2
(pre-existing high finding in `sfdx-lwc-jest`'s dependency tree).

Deploying source to the shared org is source-compatibility evidence only; it is not package
install, upgrade, or release evidence (see each package's release documentation).

## Second pass (same day, at the maintainer's request)

| Package | Added | Apex tests (run ID) | Jest |
| --- | --- | --- | ---: |
| rhc-change-monitor | Gate 3 passed: dispatch event + `PlatformEventSubscriberConfig` runtime user; console app with retry and purge | 21 pass (`707RL00001hk0DS`) | 3 |
| rhc-actions | Bulk approve / reject | 45 pass (`707RL00001hjLDU`) | 6 |
| rhc-integrations | Bulk replay of dead letters | 27 pass (`707RL00001hjyos`) | 9 |
| rhc-run-manager | Pass/Fail/Unable/Error totals on the Batch Run | 49 pass (`707RL00001hjfFy`) | 13 |
| rhc-reports | Run aggregation now | 27 pass (`707RL00001hjr9M`) | 6 |
| rhc-alerts | Send test alert to me; bell label + target test | 52 pass (`707RL00001hjMyt`) | 12 |
| rhc-logs | Inline log details | 34 pass (`707RL00001hjYZo`) | 17 |
| rhc-builder | Version diff against the active version | 41 pass (`707RL00001hjyIh`) | 33 |
| **rhc-agent-actions (new)** | Explain Record Health + List Check Sets actions for Agentforce | 5 pass (`707RL00001hjHpU`) | n/a |

Shared-org change: the duplicate managed core package was uninstalled to free platform-event
definitions (recorded in `packages/rhc-change-monitor/docs/SHARED_NO_NAMESPACE_ORG.md`).

## Per-package specifications

| Package | Specification |
| --- | --- |
| rhc-logs | [docs/IMPROVEMENTS-2026-09.md](../packages/rhc-logs/docs/IMPROVEMENTS-2026-09.md) |
| rhc-builder | [docs/IMPROVEMENTS-2026-09.md](../packages/rhc-builder/docs/IMPROVEMENTS-2026-09.md) |
| rhc-alerts | [docs/IMPROVEMENTS-2026-09.md](../packages/rhc-alerts/docs/IMPROVEMENTS-2026-09.md) |
| rhc-actions | [docs/IMPROVEMENTS-2026-09.md](../packages/rhc-actions/docs/IMPROVEMENTS-2026-09.md) |
| rhc-integrations | [docs/IMPROVEMENTS-2026-09.md](../packages/rhc-integrations/docs/IMPROVEMENTS-2026-09.md) |
| rhc-reports | [docs/IMPROVEMENTS-2026-09.md](../packages/rhc-reports/docs/IMPROVEMENTS-2026-09.md) |
| rhc-run-manager | [docs/IMPROVEMENTS-2026-09.md](../packages/rhc-run-manager/docs/IMPROVEMENTS-2026-09.md) |
| rhc-change-monitor | [docs/IMPROVEMENTS-2026-09.md](../packages/rhc-change-monitor/docs/IMPROVEMENTS-2026-09.md) |
| rhc-agent-actions | [SPEC.md](../packages/rhc-agent-actions/SPEC.md) |

## Suite-wide backlog (not implemented in this pass)

- **Ledger retention** for Alerts deliveries, Actions pending/history, Integrations deliveries,
  Run Manager batch/run/result rows, and Change Monitor evaluations. Only Logs and Reports own a
  retention policy today. Each remaining package needs its own settings record, bounded delete,
  and documented approval before deletion is automated; that is a per-package design decision, not
  a mechanical change.
- **Run Manager Apex formatting.** 170 analyzer findings are brace/complexity/naming rules that the
  package deliberately disables in `code-analyzer.yml`. Reformatting would be churn without a
  behavioral gain; revisit only if the suite adopts one analyzer configuration.
