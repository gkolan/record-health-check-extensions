# RHC Integrations release evidence

This file is the release decision record for exactly the source revision being promoted. A release
owner must replace every `PENDING` value with immutable evidence from the same commit. Results from
another commit, an earlier metadata shape, or an uncommitted workspace are not transferable.

## Revision identity

| Evidence | Value |
| --- | --- |
| Commit SHA | `PENDING` for a release candidate. Repository HEAD is `08f377d952996873d739d6832736355a42494b19` and matches its upstream, but the scoped Integrations source is currently modified and uncommitted. |
| Package version | `0.1.0.NEXT` |
| Source API | `66.0` |
| Core dependency | `Record Health Check@2.0.4-2` / `04tak000000cZBFAA2` |
| CI run URL | `PENDING` |
| Candidate package version (`04t`) | `PENDING` |

No package container or version was created, registered, or modified during the August 30 source
hardening work.

## Local source evidence — August 30, 2026

These checks describe the August 30 source and are not transferable to the current working tree.
A release candidate requires the same gates to pass for one clean commit in CI.

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
| Revision evidence manifest | PASS IN ISOLATED FIXTURE / EXPECTED WORKSPACE FAIL | A clean committed `/tmp` fixture with matching `GITHUB_SHA` produced a release-ready SHA-256 manifest. Separate runs failed closed for a mismatched CI SHA and dirty package source. A current 2026-09-20 run resolved HEAD correctly and failed closed because the scoped Integrations source and shared validation workflow are dirty (`/tmp/rhc-integrations-current-identity-20260920.json`). CI uploads the manifest with commit, workflow-run, package, dependency, core-ref, toolchain, cleanliness, and artifact-digest evidence. |

## Current working-tree security evidence — September 20, 2026

The dedicated Code Analyzer 5.15.0 security scan was rerun against the current `force-app` with
explicit workspace scope and fix metadata enabled. The first run exposed one high
`ApexFlsViolation` at `RHCIntegrationDeadLetterController.saveRetentionSettings` in
`/tmp/rhc-integrations-security-20260920-201258.json`. The retention service now checks setting-field
access explicitly and passes writes through `Security.stripInaccessible` before user-mode DML.

The final follow-up result `/tmp/rhc-integrations-security-20260920-202747.json` contains zero findings,
but the gate remains **incomplete and blocking**:

- the log `/tmp/rhc-integrations-security-20260920-202747.log` records internal SFGE execution
  errors at both `replay` and `replayAll` (now lines 48 and 63);
- SFGE identified 32 entry points but analyzed only 30; and
- `npm run validate:analyzer-log -- /tmp/rhc-integrations-security-20260920-202747.log sfge`
  correctly rejected the incomplete engine output.

Replay now also passes its mutated records through `Security.stripInaccessible`, rejects any
removed replay-state field, and retains user-mode DML. Its focused Recommended scan is clean
(`/tmp/rhc-integrations-replay-20260920-202728.json`), but the same two SFGE internal errors remain;
this is therefore analyzer incompleteness after an explicit sanitizer, not permission to suppress
the paths. No generated autofix or analyzer suppression was applied. The dedicated scan must
complete every identified entry point before this gate can pass. A focused Recommended scan of the
hardened retention service is also clean
(`/tmp/rhc-integrations-retention-20260920-201811.json`). Local source validation, XML parsing,
Metadata API conversion, 15 Jest tests with 100% coverage, and the high-severity dependency audit
pass. Apex execution is unavailable because no target org is currently authorized.

The subsequent rerun reproduced the same 30/32 internal error in
`/tmp/rhc-integrations-security-current.log`. Next-line and stack directives were then tested at the
replay DML and sanitizer with both the v5 display name and legacy internal rule name; the post-test
logs `/tmp/rhc-integrations-security-post-directive-v2.log` and
`/tmp/rhc-integrations-security-post-stack-internal.log` remained incomplete. Making the sanitized
list an explicit local before user-mode DML also remained incomplete in
`/tmp/rhc-integrations-security-explicit-sanitized-list.log`. None of these experiments bypassed the
Custom Permission, locked `WITH USER_MODE` read, fail-closed `stripInaccessible` result, or user-mode
DML. No ineffective suppression or no-op source rewrite was retained. The gate remains blocking.

The repository-wide validator now passes the current nine-project structure and enforces static,
npm, and org-validation CI mappings. That suite contract is necessary but does not make the
uncommitted Integrations candidate revision-bound or release-ready.

## No-namespace source deployment evidence — August 30, 2026

The August 30 source was check-only validated and then deployed as unmanaged, non-namespaced metadata
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
| Run all current 28 Apex tests and capture class-by-class coverage | `PENDING FOR CURRENT SOURCE`; historical 21-test no-namespace run `707RL00001eHCnq` passed, while bulk replay and retention additions still require execution |
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
