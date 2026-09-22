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

Current working-tree additions include Run Manager RM5 bounded manual operational retention, the
Agent Actions analyzer cleanup, and complete static/local CI coverage across the nine projects.
Sixteen Run Manager Jest tests pass, generated metadata is current, and focused Recommended/LWS
reviews are clean. New or changed Apex and metadata still require fresh server-side validation
before release.

The current Integrations SFGE security gate remains open. The September 20 Code Analyzer 5.15.0
first rerun reported one high `ApexFlsViolation` at the retention-settings entry point. Explicit
setting-field checks and field sanitization before user-mode DML removed that finding, and the
follow-up result contains zero violations. Internal engine errors at both replay entry points remain
(30 of 32 entry points analyzed) even after explicit replay-state sanitization and fail-closed
removed-field handling. A current rerun reproduced the result; supported directive placements and
an explicit sanitized local were also tested without changing the engine failure, so no ineffective
suppression or no-op source rewrite was retained. Obtain a complete SFGE run and retain the
strict-log evidence before treating Integrations as releasable.

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

## Suite-wide backlog

- **Ledger retention.** Alerts, Change Monitor, Integrations, Actions, and Run Manager now each own a
  validated settings singleton and an explicitly confirmed, manual 1,000-row purge; scheduling
  remains deliberately unimplemented. Integrations excludes `PENDING` and `RETRY_WAIT`. Actions
  preserves its no-direct-delete model through a separate Admin custom permission and deletes
  completed History before terminal Pending Actions. Run Manager deletes Results before empty
  terminal scope Runs and Batch Runs, then submitted Requests, while preserving active work and
  `PENDING` Requests. Logs and Reports already own retention policies.
- **Run Manager remaining analyzer debt.** The 2026-09-20 follow-up adopted one root analyzer
  configuration and decomposed the highest-signal controller and execution-service methods. A
  later capture-service refactor reduced that package's root-policy scan from 247 findings (179
  moderate, 68 low) to 231 (163 moderate, 68 low), eliminating 14 brace findings and both capture
  complexity findings. Extracting cancellation behavior from the Admin controller then reduced the
  result to 226 (158 moderate, 68 low); the new service and test are clean under the root policy.
  Decomposing schedule persistence and owned-job replacement then reduced it to 216 (148 moderate,
  68 low), leaving only the schedule method's unchanged public-signature heuristics. Separating
  supplied-ID validation, row construction, user-mode upsert, and coalescer enqueueing then reduced
  the result to 202 (136 moderate, 66 low). Decomposing the coalescer execution path, documenting its
  actual governor-safe 9,000-row drain, and normalizing the touched async tests then reduced the
  result to 179 (118 moderate, 61 low). Decomposing the guided-filter security boundary and adding
  five focused negative scenarios then reduced it to 165 (105 moderate, 60 low). Completing the
  retention and scheduled-adapter contracts, simplifying retention test helpers, and making Batch
  control flow explicit then reduced it to 118 (69 moderate, 49 low); the touched retention and
  scheduled files are clean, while Batch retains only two stateful-orchestration heuristics. Completing
  controller contracts, normalizing the test harness, and excluding build-time metadata generators
  from misapplied LWC runtime rules then reduced the result to 13 moderate design heuristics and zero
  lower-severity noise. Extracting Run Definition validation, canonicalization, and user-mode
  persistence from the Aura controller then removed its cognitive-complexity finding and reduced the
  result to 12 moderate design heuristics. Replacing the schedule service's eight positional values
  and Boolean flag with one typed recurrence request then reduced the result to 10. Isolating
  supplied-ID validation, scalar filter conversion, type-specific core metadata mapping, and typed
  filter/execution/capture requests reduced the result to three. The remaining findings describe
  aggregate Aura-facade branching and the intentional stateful Batch serialization envelope; they
  remain documented for org-validated redesign rather than mechanical suppression.
  A subsequent typed Batch launch request and separate execution/progress envelopes removed both
  Batch findings without changing execution behavior. Finally, a focused administrator command
  boundary preserved every Aura method and DTO while moving input mapping and safe error translation
  out of the facade. The full strict-policy result now contains zero findings.

## Follow-up — 2026-09-20

- Re-ran the suite-wide Recommended policy and distinguished Node CLI modules from LWC runtime
  source with narrow, file-local rule annotations. This retained all other ESLint and CPD analysis
  while removing 117 inapplicable LWC-runtime findings. Completing Integrations principals and
  contracts, simplifying Logs cleanup control flow, and removing Builder's redundant empty-list
  branch reduced the fresh suite result from 266 to 61 findings. Completing Actions contracts,
  explicit principals, and shared test fixtures, then recording the three narrow Reports coverage
  exceptions, reduced the current result to eight informational findings and no critical, high,
  moderate, or low findings. Actions, Integrations, Logs, Builder, and Reports now each have a
  zero-finding package-source scan; the remaining suite notices are cross-package duplication in
  independent Node validation scripts.
- Added a root Code Analyzer configuration and remediated the targeted Run Manager complexity and
  Change Monitor sharing findings without changing their public contracts.
- Corrected the Integrations source validator so it recognizes the deployed user-mode DML syntax.
- Added a tested Change Monitor subscriber-adapter generator for standard and custom CDC entities.
- Made Change Monitor intake and administrator retry fail closed when Salesforce immediately
  rejects the package dispatch event: the associated claims/state transition roll back, bounded
  errors replace stranded `PENDING` work, and both paths have focused negative tests.
- Added an idempotent administrator wake-up action for visible Change Monitor pending claims when no
  dispatcher is active, covering the operational gap between initial event acceptance and final
  asynchronous delivery without changing claim state or carrying record data.
- Added package-owned Alerts retention settings and an administrator-confirmed bounded manual purge;
  automated deletion remains outside the approved scope.
- Added the same package-owned, administrator-confirmed retention contract to Change Monitor while
  preserving pending claims and withholding scheduled deletion.
- Added a package-owned Integration Delivery retention window and administrator-confirmed,
  terminal-only 1,000-row purge while preserving pending/retry work and withholding scheduling.
- Added package-owned Actions audit retention with a saved 1–3,650-day window, separate Admin
  permission, explicit confirmation, History-first combined 1,000-row cap, terminal-only Pending
  Action eligibility, and no direct object delete grant or scheduler.
- Added package-owned Run Manager operational retention with a saved 1–3,650-day window, separate
  Admin permission, explicit confirmation, child-first combined 1,000-row cap, terminal-only
  Batch/Run eligibility, submitted-Request cleanup, and no scheduler.
- Reduced Run Manager capture complexity while preserving atomic rollback and user-mode upsert,
  then replaced its positional Batch-facing values with one typed capture request.
- Moved Run Manager Batch cancellation into a focused sharing-enforced service with dedicated
  active, terminal, and null-input tests while preserving the Aura contract.
- Decomposed Run Manager schedule persistence and exact owned-job replacement without changing the
  existing controller/service signature or human recurrence contract.
- Decomposed Run Manager's bulk supplied-ID Flow action while preserving its invocable contract,
  atomic rollback, user-mode upsert, idempotent request key, and one-coalescer-per-definition model.
- Decomposed the Run Manager coalescer, added malformed durable-ID regression coverage, and corrected
  its documented per-execution drain from an impossible 50,000 rows to the implemented governor-safe
  9,000 rows plus its stale denial of the existing bounded finalizer retry.
- Decomposed Run Manager's guided-filter security boundary and added focused rejection coverage for
  operator injection, field/operator incompatibility, typed-value errors, null clauses, and the
  ten-condition cap without changing the public builder contract.
- Replaced positional filter, execution, and capture calls with typed request contracts, isolated
  supplied-ID validation and scalar conversion, and reduced the full Run Manager strict-policy
  result to three moderate stateful/facade design heuristics with no lower-severity noise.
- Replaced the stateful Batch's five positional launch values and parallel serialized fields with a
  typed launch request plus execution/progress envelopes, reducing the full strict-policy result to
  one moderate facade-level heuristic with no other findings.
- Moved administrator mutations behind a focused command boundary without changing the Aura/LWC
  contract, removing Run Manager's final strict-policy finding.
- Removed all eight Agent Actions strict-policy findings while preserving the flat Agentforce
  response contract, bulk behavior, core-only dependency, and existing invocable signatures; added
  a source-only administrator guide with least-privilege setup, acceptance, and removal checks plus
  an explicit release-evidence ledger and pre-package lock.
- Extended pull-request and main-branch CI so all nine package projects have source-conversion and
  analyzer gates, and all eight npm-backed packages have test, coverage, and dependency-audit
  coverage. Change Monitor's generated-metadata and adapter-generator checks are included explicitly,
  and the root repository validator now prevents those package-to-job contracts from silently drifting.
  The repository job also runs checksum-pinned Actionlint 1.7.12 over every workflow.
- Added scratch-org source-validation paths for the six projects that lacked them, completing the
  nine-project org-CI configuration without creating package artifacts. Each new path runs in both
  namespaced and no-namespace modes, installs the pinned core dependency, validates before deploying
  to a disposable org, runs local Apex tests with coverage, captures JSON evidence, and always
  attempts cleanup. Execution remains pending until a valid Dev Hub authorization is available.
- Reconciled current documentation with the nine-package repository and Gate 3 evidence. Historical
  deployment and test IDs remain date-scoped evidence; they are not claims about the current diff.
- Synchronized the Alerts executable pre-package lock and release ledger with the current suite:
  both org shapes must now report at least 55 Apex methods and local evidence must report all 19
  Jest tests. Lock integration coverage proves under-counted evidence remains rejected.
- Decomposed Reports coverage discovery and classification without changing its Aura response,
  documented the response fields, and normalized all 25 test-method names and 33 test annotations.
  A follow-up replaced daily aggregation's positional window/dimension values with typed internal
  boundaries, completed the remaining Apex contracts, and replaced the daily Queueable's Boolean
  catch-up/parallel state with an enum-backed request plus focused finalizer stages. The Queueable
  is now clean; a named test-only retention factory and typed Result-fact request removed the last
  non-controller positional findings. Replacing the setup controller's six positional save values
  with one typed request then removed its four remaining parameter findings. A dedicated aggregation
  repository now owns bounded reads and atomic partition replacement, removing the aggregation
  service's final class-total complexity finding. Running all non-controller service tests under an
  explicit Standard User then removed the 22 remaining test-principal recommendations. The four
  remaining coverage-controller heuristics are now narrow, documented, machine-checked exceptions:
  two generated Aura Boolean setters and two deliberately complete grouped aggregate queries. The
  full Reports package-source scan now reports zero findings; current org-side Apex execution
  remains pending authorization.
