# RHC Run Manager Day 1 Release Evidence

> **Current working-tree note (2026-09-20):** bounded manual operational-record retention, its
> internal Setting object, Admin capability, Apex service/test, LWC controls, cancellation-service
> separation, and documentation were added after the historical org evidence below. Local Jest (16
> tests), coverage, generated-metadata, XML, Metadata API conversion, dependency audit, LWS,
> repository, diff, and package-policy Recommended analysis checks pass. The stateful Batch uses a
> typed launch request plus explicit execution/progress envelopes, and administrator mutations now
> pass through a focused command boundary. The full strict root-policy scan has zero findings. No
> authorized org is available, so this diff has not yet received server-side compilation or Apex
> execution and is not release evidence.

Historical org evidence captured: 2026-08-30

Current-source note: the Apex source changed after these org runs. Local verification for the
current diff is recorded in the suite verification document, but fresh org-side compilation and
Apex execution are still required before this file can claim current-source deployment evidence.

This file records reproducible evidence for the Day 1 beta. It distinguishes completed verification
from packaging work that still requires an external Salesforce result.

## 2026-08-30 no-namespace source-deployment verification

Target scratch org: `rhc-change-monitor-nons-shared-20260830`

| Item | Evidence |
| --- | --- |
| Org ID | `00DRL00000UKhkO2AT` |
| Subscriber namespace | None |
| Core dependency | Record Health Check `2.0.4.2` / `04tak000000cZBFAA2` installed successfully; request `0HfRL000005wYWI0A2` |
| Final validation-only deployment | `0AfRL00000hD2D10AK`: succeeded, 39/39 deployment tests |
| Source deployment | `0AfRL00000hD6A70AK`: succeeded, 110/110 components, 39/39 deployment tests |
| Post-deployment Apex run | `707RL00001eGpTH`: 47/47 methods passed, 0 failed or skipped |
| Coverage | 93% test-run coverage; 94% org-wide coverage |
| Namespace readback | 20/20 `RHCRunManager*` Apex classes have `NamespacePrefix = null` |
| Admin permission assignment | Not applied; requires separate explicit approval for the persistent privilege grant |

Validation found and corrected three portability defects before the successful deployment: an Apex
`FOR UPDATE` query used unsupported `ORDER BY`; two direct Queueable test invocations passed an
ambiguous untyped `null`; and the test-user factory assigned only the extension permission set, so
the managed core correctly rejected shared execution. The factory now assigns both required
permission sets and tolerates any additional matching permission set returned across namespace
contexts.

This proves that the 2026-08-30 source compiled, deployed, and passed its Apex suite in a no-namespace
subscriber org with the pinned managed core dependency. It is **not** package-install evidence:
Run Manager was source-deployed, no Run Manager `04t` was created or installed, and package install,
upgrade, uninstall, package-calculated coverage, and packaged Flow-action discoverability remain
open gates.

## 2026-08-30 namespaced check-only verification

Target scratch org: `rhc-run-manager-goal-20260830` (`00DEc00000kGryjMAC`), with namespace `rhc`
and the pinned core dependency installed.

Check-only deployment `0AfEc00000nFxOYKA0` succeeded with 110/110 components, 39/39 Apex behavior
tests, and zero component or test errors. Production-class coverage ranged from 75.90% to 100%:

| Production class | Coverage |
| --- | ---: |
| `RHCRunManagerAdminController` | 87.39% |
| `RHCRunManagerBatch` | 98.45% |
| `RHCRunManagerCaptureService` | 97.73% |
| `RHCRunManagerCoalescerQueueable` | 88.68% |
| `RHCRunManagerCoreMetadataGateway` | 88.06% |
| `RHCRunManagerExecutionService` | 100% |
| `RHCRunManagerFilterService` | 75.90% |
| `RHCRunManagerScheduled` | 96.30% |
| `RHCRunManagerScheduleService` | 96.15% |
| `RHCRunManagerSubmitIdsAction` | 78.22% |
| `RHCRunManagerUninstallHandler` | 100% |

This independently confirms compilation and specified-test behavior for the 2026-08-30 source in the package
namespace. It does not create a beta version or replace the clean subscriber package-install gate.

## 2026-08-30 robustness hardening and local gates

The source now includes atomic supplied-ID staging/capture, target-object ID validation,
governor-safe coalescer paging with bounded finalizer retries, terminal Batch startup errors,
bounded stateful error summaries, Viewer/Executor cross-owner tests, and an owned-job uninstall
handler. Current local evidence:

- Code Analyzer targeted scan: 0 findings (`code-analyzer-results-20260830-065859.json`);
- LWC Jest: 12 passed, 0 failed; 92.52% statements, 80% branches, 100% functions/lines;
- dependency audit: 0 vulnerabilities;
- generated metadata drift check: passed;
- source-to-Metadata-API conversion at API 66.0: passed with no warnings;
- repository contracts and documentation links: passed.

The hardened source was subsequently validated, deployed, and tested in the no-namespace scratch
org recorded above. All production Run Manager classes met Salesforce's 75% per-class threshold;
the lowest observed rounded values were 76% for `RHCRunManagerFilterService` and 78% for
`RHCRunManagerSubmitIdsAction`. Raising those classes toward the suite's preferred 90% robustness
target remains worthwhile release hardening, but it did not block this source deployment.

Source review against saved core `2.0.6` confirms that every consumed global contract remains
present (`RecordHealthCheck.evaluate`, request factories/options, response/result DTO fields,
statuses, result modes, publication modes, and execution origins). The declared package dependency
remains the extension suite's shared pinned floor, `Record Health Check@2.0.4-2`; changing that pin
requires a coordinated suite release rather than a one-extension edit.

## Package identity and dependency boundary

| Item | Value | Status |
| --- | --- | --- |
| Package name | RHC Run Manager | Verified |
| Package ID | `0Hoak0000005FhZCAU` | Registered in `rhc-dev-hub` |
| Package type | Second-generation unlocked package | Verified |
| Namespace | `rhc` | Verified |
| Declared dependency | Record Health Check `2.0.4-2` / `04tak000000cZBFAA2` | Verified in `sfdx-project.json` |
| Other extension dependencies | None | Verified in `sfdx-project.json` |
| Beta subscriber version | Pending | Dev Hub daily version-create quota exhausted by other packages |

The package does not declare Builder, Alerts, Reports, Actions, or Integrations as dependencies.

## Source and Apex verification

Target scratch org: `rhc-run-manager-day1`

Latest deployment with the permission-aware package-upload harness:

- Deployment ID: `0AfRK00000szrBa0AI`
- Deployment status: `Succeeded`
- Apex tests: 29 passed, 0 failed
- Test harness: dedicated user assigned `RHC_Run_Manager_Admin`; each security-sensitive test runs
  inside `System.runAs`
- Production access mode: remains `USER_MODE`

Verified behaviors include:

- Check Set and individual Check selection
- target-object derivation from core metadata
- all-accessible, guided-filtered, and supplied-ID populations
- raw-query rejection and bind-based filtering
- 251 supplied-ID Flow inputs
- null and duplicate ID removal
- coalesced requests and one owned Batch launch
- shared Run Now, schedule, and supplied-ID execution path
- partial Batch failure with earlier scope persistence
- capture-mode retention and idempotent Result upsert
- safe schedule ownership, pause, and date windows

## Static and client-side gates

| Gate | Evidence | Result |
| --- | --- | --- |
| Salesforce Code Analyzer | `code-analyzer-results-20260825.json` | 0 violations |
| Jest | `npm test -- --runInBand` | 6 passed, 0 failed |
| Dependency audit | `npm audit --json` | 0 vulnerabilities |
| SLDS validation | SLDS linter/validator run | 100/A, 0 findings |
| Metadata XML | package metadata parse verification | Passed |
| Diff hygiene | `git diff --check -- packages/rhc-run-manager` | Passed |

## Documentation

- `README.md`: package overview and experienced-admin checklist
- `ADMIN_GUIDE.md`: junior-admin click-by-click setup, Flow, scheduling, monitoring, and troubleshooting
- `SPEC.md`: authoritative product contract
- `GAP_ANALYSIS.md`: prototype/core comparison and public API boundary

## Demo dataset verification

- Loader: `scripts/demo/create-demo-data.apex`
- Cleanup: `scripts/demo/remove-demo-data.apex`
- Functional guide: `docs/DEMO_GUIDE.md`
- Loader compiled and succeeded in `rhc-run-manager-day1`.
- A second loader execution succeeded without creating duplicate exact-name demo records.
- Cleanup compiled and removed only the scoped demo hierarchy; the loader then restored the dataset.
- Verified records: 4 Accounts, 3 Contacts, 3 Run Definitions, 1 inactive Schedule.
- Filtered demo Batch Run: `a00RK00000nnSGfYAM`
- Runtime result: `COMPLETED`, Submitted 4, Processed 4, Failed Scopes 0.
- Scope result: 2 completed Runs with 2 records each, proving Batch Size 2 and guided population.

## Prepared clean subscriber

| Item | Value |
| --- | --- |
| Alias | `rhc-run-manager-clean-20260823` |
| Org ID | `00DQL00000ZG0kg2AD` |
| Namespace | None |
| Expiration | 2026-08-30 |
| Installed packages | Record Health Check core `2.0.4.2` only |
| Assigned core access | `Record_Health_Check_Admin` |

The org was deliberately created with `--no-namespace`; this prevents a packaging namespace from
hiding subscriber-boundary defects.

## Remaining beta and clean-install proof

Do not mark the release complete until all items below have direct evidence:

- [ ] Create one coverage-enabled beta after the shared Dev Hub quota frees.
- [ ] Confirm the request succeeds and record its request ID, `05i` ID, `04t` ID, version number,
      and package-calculated coverage.
- [ ] Install the exact `04t` version into `rhc-run-manager-clean-20260823` while it remains active.
- [ ] Confirm installed packages are exactly Record Health Check core and RHC Run Manager.
- [ ] Assign `RHC_Run_Manager_Admin` to the clean-org administrator.
- [ ] Confirm the packaged Flow action **Submit Record IDs to RHC Run Manager** is discoverable.
- [ ] Submit current and prior Account IDs in separate committed requests.
- [ ] Confirm null/duplicate removal, consolidation, and one owned Batch Run.
- [ ] Confirm Monitoring drills Batch Run → scope Run → retained Results.
- [ ] Record final commands and results in this file.

If the prepared scratch org expires before the beta is available, create a new Developer scratch org
with sample data and `--no-namespace`, install only core, and repeat the subscriber checks.
