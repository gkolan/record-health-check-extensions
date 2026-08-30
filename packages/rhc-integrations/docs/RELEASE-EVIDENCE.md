# RHC Integrations release evidence

This file is the release decision record for exactly the source revision being promoted. A release
owner must replace every `PENDING` value with immutable evidence from the same commit. Results from
another commit, an earlier metadata shape, or an uncommitted workspace are not transferable.

## Revision identity

| Evidence | Value |
| --- | --- |
| Commit SHA | `PENDING` — this workspace does not currently resolve a Git `HEAD` |
| Package version | `0.1.0.NEXT` |
| Source API | `66.0` |
| Core dependency | `Record Health Check@2.0.4-2` / `04tak000000cZBFAA2` |
| CI run URL | `PENDING` |
| Candidate package version (`04t`) | `PENDING` |

No package container or version was created, registered, or modified during the August 30 source
hardening work.

## Local source evidence — August 30, 2026

These checks validate the current workspace but are not revision-bound until the source has a
commit SHA and the same gates pass in CI.

| Gate | Result | Evidence |
| --- | --- | --- |
| Package source contracts | PASS | `npm run validate`: 2 objects, 28 fields, 17 Apex classes |
| Pinned minimum-core event contract | PASS | `npm run validate:core-contract -- --core-root /Users/gkolan/Documents/GitHub/record-health-check`: core `74fe1d6022f819397fc879c076f4f4dd2093cfab`, all three event schemas/publication modes, API/namespace, dependency pin, and restricted Log-field exclusion |
| Metadata XML | PASS | `npm run validate:xml` |
| Salesforce source conversion | PASS | Isolated Salesforce CLI 2.149.9 `sf project convert source`; no org contacted |
| LWC tests and coverage | PASS | 2 suites, 8 tests; 100% statements/branches/functions/lines |
| Dependency audit | PASS | `npm audit --audit-level=high`: 0 vulnerabilities |
| Recommended analyzer | PASS WITH SCOPE LIMIT | Isolated CLI 2.149.9 / Code Analyzer 5.15.0 artifact `code-analyzer-results-20260830-071600-v515.json`: 0 severity 1–3, 100 low; executed PMD, ESLint, CPD, RetireJS, and Regex |
| Dedicated SFGE security analyzer | INCOMPLETE / BLOCKING | Isolated CLI 2.149.9 / Code Analyzer 5.15.0 artifacts `code-analyzer-security-results-20260830-071300-v515.json` and `code-analyzer-security-20260830-071300-v515.log`: 0 reported violations, but only 27/28 entry points completed; internal execution error on `RHCIntegrationDeadLetterController.replay`; strict log gate correctly failed. The supported 5.15.0 version reproduces 5.14.0. Isolated scans proved the one-query user-mode lock completes at 28/28 and that adding replay DML triggers the engine defect. No suppression is committed. |
| Revision evidence manifest | PASS IN ISOLATED FIXTURE / EXPECTED WORKSPACE FAIL | A clean committed `/tmp` fixture with matching `GITHUB_SHA` produced a release-ready SHA-256 manifest. Separate runs failed closed for a mismatched CI SHA and dirty package source. The real workspace run hashed all three analyzer artifacts but failed as designed because this workspace has no Git `HEAD`. CI uploads the manifest with commit, workflow-run, package, dependency, core-ref, toolchain, cleanliness, and artifact-digest evidence. |

The repository-wide validator is not a package pass/fail signal at this time: it stops on four
missing Apex metadata companions under `packages/rhc-alerts`, outside this package.

## No-namespace source deployment evidence — August 30, 2026

The current source was check-only validated and then deployed as unmanaged, non-namespaced metadata
to shared Developer scratch org `rhc-change-monitor-nons-shared-20260830` (`00DRL00000UKhkO2AT`).
This org is useful for source compatibility and cross-extension regression, but it is not a clean
core-only subscriber: its installed-package list contains Record Health Check 2.0.4.2
(`04tak000000cZBFAA2`) and it also contains other source-deployed extension metadata. No RHC
Integrations package container or version was created or installed.

| Gate | Result | Evidence |
| --- | --- | --- |
| Initial check-only deployment | FAIL, then fixed | Job `0AfRL00000hCxeg0AC` exposed an incorrect `Long` checkpoint parameter in `RHCIntegrationSubscriberCoordinator`; Platform Event `ReplayId` and `setResumeCheckpoint` require the string-compatible contract. The helper now accepts `String`, and the local validator pins that signature. |
| Corrected check-only deployment | PASS | Job `0AfRL00000hD8wg0AC`: 61/61 components, 21/21 test methods, zero component or test errors. |
| Persisted no-namespace source deployment | PASS | Job `0AfRL00000hCpXT0A0`: 61/61 components, zero errors. All 17 deployed `RHCIntegration*` Apex classes report `NamespacePrefix = null`. |
| Focused persisted-org Apex suite | PASS | Run `707RL00001eHCnq`: 21 test methods plus two `@TestSetup` executions, zero failures, 89% test-run coverage, 95% org-wide coverage. Production-class coverage ranges from 80% to 100%. |
| Shared-org `RunLocalTests` regression | PASS | Run `707RL00001eHCzP`: Salesforce reported 907 test/setup executions, zero failures, 95% test-run coverage, 94% org-wide coverage. |

The source deployment does not clear clean-subscriber package installation, package dependency,
upgrade, uninstall, real Named Credential callout, subscriber-principal, or package-version coverage
gates. Those still require a validated RHC Integrations `04t` and purpose-built org evidence.

## Required org and packaging evidence

The table distinguishes the no-namespace source result from gates that still require separately
authorized packaging or purpose-built org work.

| Gate | Status |
| --- | --- |
| Compile all metadata against promoted core only | `PENDING` |
| Run all 21 Apex tests and capture class-by-class coverage | `VERIFIED FOR NO-NAMESPACE SOURCE` — run `707RL00001eHCnq`; package-version isolation remains pending |
| Exercise Platform Event subscribers at realistic batch and route fan-out | `PENDING` |
| Verify Finalizer recovery and concurrent replay/worker row locking | `PENDING` |
| Verify Named Credential callouts, retries, and receiver idempotency | `PENDING` |
| Complete dedicated SFGE security analysis | `PENDING` |
| Create a fully validated beta package version | `PENDING` |
| Install core then Integrations in a clean subscriber org | `PENDING` |
| Run administrator/demo acceptance and uninstall isolation | `PENDING` |
| Capture package dependency report and upgrade/uninstall evidence | `PENDING` |

## Release decision

**NOT READY FOR PROMOTION.** Local and shared-org no-namespace source gates pass at the scope
recorded above, but there is no commit-bound CI run and the required complete SFGE, clean-install,
package-isolated Apex, packaging, upgrade, and uninstall evidence remains pending.
