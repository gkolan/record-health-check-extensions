# Verification record

## Pre-version engineering verdict

The current `packages/rhc-builder` source cleared every applicable local gate and the requested
shared non-namespaced source-deployment gate on 2026-08-30. The backend candidate also has the
documented namespaced and clean non-namespaced evidence below; the later guided-UX delta is locally
namespace-neutral and was compiled in the shared non-namespaced org, but has not been redeployed to
the namespaced org. No package, package container, or package version was created or registered. No
production org was used. Runtime acceptance changed only the disposable scratch orgs described
below.

The engineering candidate is ready for source control and CI, but the repository itself is not yet a
releaseable source artifact: Git reports `No commits yet on main`, zero tracked files, and no remote.
Until the intended initial history is reviewed, committed, pushed, and both fail-closed workflows pass,
**do not create a package version**.

This is a pre-version engineering verdict, not a final release verdict. Clean non-namespaced installation,
upgrade, uninstall, package-version coverage readback, and artifact inspection require a new `04t`.
Creating that artifact remains prohibited until the release owner gives explicit approval.

## Local gates

| Check | Result |
| --- | --- |
| Salesforce Code Analyzer `Recommended` | 0 violations across PMD, CPD, ESLint, Regex, and retire-js (`/tmp/rhc-builder-code-analyzer-current.json`). |
| LWC Jest | 2 suites and 32 tests passed, including card selection, just-in-time guidance, all preview states, stale-validation invalidation, and publication confirmation identity. |
| Jest coverage | 88.01% statements, 67.75% branches, 94.11% functions, 88.95% lines; all configured floors passed. |
| Official SLDS linter | 0 violations. |
| Supplementary SLDS audit | 100/A theming, 100/A accessibility, 100/A code quality, and 97/A component usage. The only warning is the intentional native radio input required by the SLDS Visual Picker blueprint; its accessible label, description, checked state, and group semantics are covered by Jest. |
| Manual LWC gate | Pass: loading, actionable error, status, empty, disabled, semantic section/article, Lightning base-component states, responsive card selection, just-in-time help, example-result preview, readable review summary, stale-validation warning, and explicit publication confirmation are present. |
| npm audit | 0 known vulnerabilities across 574 dependencies. |
| Metadata XML | All package XML passed `xmllint --noout`. |
| Runtime verifier syntax | `bash -n scripts/verify-runtime-lifecycle.sh` passed; workflow YAML parsed successfully. |
| Repository diff hygiene | File formatting checks pass and temporary outputs were written outside the repository, but release governance is **blocked** because all files are untracked and the repository has no commit or remote. |
| Dependency | Exactly `Record Health Check@2.0.4-2` (`04tak000000cZBFAA2`); no extension dependency. |
| Mapping inventory | 18/18 Check Set fields and 44/44 Check fields, with deterministic allow-list serialization. |

## Namespaced Salesforce verification

- Scratch org: `rhc-builder-ready-20260830`, org `00Dcf00000G7wPWEAZ`, Enterprise, namespace
  `rhc`, expires 2026-08-31.
- Installed dependency: `Record Health Check@2.0.4-2` (`04tak000000cZBFAA2`).
- Final check-only deployment: `0Afcf00000B6Q6LCAV`; 57/57 components, 40/40 tests,
  zero component/test/coverage errors.
- Final deployment: `0Afcf00000B6QCnCAN`; 57/57 components, 40/40 tests, zero errors.
- Independent isolated Apex run: `707cf00001C4fOj`; 40/40 passed, 88% test-run coverage,
  97% org-wide coverage.
- Post-portability-fix check-only deployment: `0Afcf00000B6ScoCAF`; 57/57 components and
  40/40 tests, zero errors.
- Post-portability-fix deployment: `0Afcf00000B6SxlCAF`; 57/57 components and 40/40 tests,
  zero errors.
- Post-portability-fix isolated Apex run: `707cf00001C4RDU`; 40/40 passed and 97% org-wide
  coverage. Every Builder production class remained above 75%.

| Production class | Coverage |
| --- | ---: |
| `RHCBuilderContractGateway` | 100% |
| `RHCBuilderController` | 94% |
| `RHCBuilderCoreValidator` | 87% |
| `RHCBuilderFieldMapping` | 96% |
| `RHCBuilderMetadataService` | 81% |
| `RHCBuilderQueryValidator` | 89% |
| `RHCBuilderVersionValidator` | 94% |
| `RecordHealthCheckBuilderContract` | 95% |

## Non-namespaced source-deployment verification

### Clean managed-core topology

A fresh one-day Enterprise scratch org, `rhc-builder-nons-clean-20260830`
(`00DRL00000UjuuP2AR`), was created with `--no-namespace`. `Organization.NamespacePrefix` was
`null`, and its only installed package was the managed core dependency `Record Health
Check@2.0.4-2` (`04tak000000cZBFAA2`). No unpackaged core source was present.

- Initial check-only deployment `0AfRL00000hD6Bi0AK` failed before tests because
  `RHCBuilderCoreValidator` had a compile-time `RecordHealthCheckPlugin` reference. The earlier
  shared-org check had masked this because that org also contained unpackaged core source.
- The validator now resolves subscriber/local and managed-core plugin types dynamically, falls back
  to namespace `rhc` for packaged implementations, and verifies the interface with
  `System.Type.isAssignableFrom`. Constructor side-effect counters and rollback fencing remain in
  place.
- Final check-only deployment `0AfRL00000hD7Sl0AK` succeeded with 57/57 components and 40/40 tests.
- Final source deployment `0AfRL00000hDEM90AO` succeeded with 57/57 components and 40/40 tests.
- Independent Apex run `707RL00001eHHVTYA4` passed 40/40 tests with 92% test-run and 92% org-wide
  coverage. Builder production classes ranged from 81% through 100%.
- The complete lifecycle passed against subscriber-owned records on the installed managed core
  metadata types. Terminal Metadata requests were `0AfRL00000hCr4d0AC` (inactive publish),
  `0AfRL00000hDAKA0A4` (activate version 2), `0AfRL00000hCyan0AC` (activate version 3 and omit one
  Check), and `0AfRL00000hD4zX0AS` (rollback version 2).
- Final readback showed version 2 deployed and active, version 3 superseded and inactive, and both
  restored managed-core Checks active with subscriber-owned `NamespacePrefix = null` records.
- The lifecycle verifier now recognizes and validates an already completed run instead of replaying
  intermediate-state assertions after rollback.

The Salesforce workflow now runs an explicit matrix for `namespaced` and `non-namespaced` scratch
orgs. Each branch asserts the actual org namespace, installs the pinned core package, performs the
same dry run, deployment, isolated coverage run, permission assignment, lifecycle acceptance, and
cleanup. A missing Dev Hub secret still fails closed.

### Shared dual-core topology

The current source was also deployed and exercised in `rhc-change-monitor-nons-shared-20260830`
(`00DRL00000UKhkO2AT`) on 2026-08-30. `Organization.NamespacePrefix` was `null`. This was a
source deployment, not a package-version installation, and it did not create a package or package
version.

- The target contained the managed core dependency `Record Health Check@2.0.4-2`
  (`04tak000000cZBFAA2`) and an unpackaged, non-namespaced core source copy. Builder correctly
  selected the local core metadata types in that development topology.
- The first check-only deployment (`0AfRL00000hDCyf0AG`) exposed 11 namespace-specific test
  failures: ten from a hard-coded `PermissionSet.NamespacePrefix = 'rhc'` lookup and one from a
  hard-coded `rhc__IsActive__c` assertion. Both test assumptions were made namespace-neutral.
- The final check-only deployment (`0AfRL00000hD9r80AC`) succeeded with 57/57 components and
  40/40 tests.
- The final source deployment (`0AfRL00000hD4El0AK`) succeeded with 57/57 components and
  40/40 tests.
- After the managed-core plugin-boundary fix, exact-final-source check-only deployment
  `0AfRL00000hDCqc0AG` and deployment `0AfRL00000hCt9i0AC` both succeeded with 57/57 components
  and 40/40 tests. The resume-aware lifecycle verifier also passed against the completed run.
- Independent Apex run `707RL00001eH5Dz` passed 40/40 tests with 92% test-run coverage and
  96% org-wide coverage.
- The runtime verifier initially assumed namespaced Builder and core object names. It now discovers
  Builder and core namespaces independently and uses dynamic Builder schema references in anonymous
  Apex. The complete idempotent lifecycle then passed.
- Terminal Metadata requests were `0AfRL00000hDD6j0AG` (inactive publish),
  `0AfRL00000hD9rA0AS` (activate version 2), `0AfRL00000hDDI10AO` (activate version 3 and omit one
  Check), and `0AfRL00000hD7Sk0AK` (rollback version 2). Every ledger row succeeded and retained its
  request ID.
- Final readback showed version 2 deployed and active, version 3 superseded and inactive, and both
  restored local-core Checks active with `NamespacePrefix = null`.

This proves current-source behavior in the requested no-namespace development topology. It does not
replace the clean non-namespaced subscriber installation gate for a future `04t`, because the target
contains unpackaged core source and Builder was deployed from source.

#### Guided-UX current-source revalidation

After the guided card selection, just-in-time help, example-result preview, review summary,
stale-validation protection, and publication-confirmation work, the exact current source was
revalidated in the same requested shared no-namespace org on 2026-08-30. No package, package
container, or package version was created.

- Deployment preview reported 24 deployable logical members, zero conflicts, zero ignored members,
  zero retrievals, and zero deletions.
- Check-only deployment `0AfRL00000hDJIc0AO` succeeded with 57/57 components and 40/40 tests;
  component and test errors were both zero.
- Source deployment `0AfRL00000hD4uj0AC` succeeded with 57/57 components and 40/40 tests;
  component and test errors were both zero.
- Independent Apex run `707RL00001eHbuSYAS` passed 40/40 tests with 88% test-run coverage and 95%
  org-wide coverage. Builder production-class coverage ranged from 81% through 100%.
- The documented lifecycle verifier passed against the completed run and reconfirmed the final
  rollback state, active restored Check, and version-state invariants.
- Org preflight reconfirmed `Organization.NamespacePrefix = null`, managed core
  `Record Health Check@2.0.4-2` as the only installed package, and both local and managed core
  metadata types in the shared development topology.

The isolated suite verifies authorized and unauthorized controller boundaries, USER_MODE reads,
system-mode package-owned writes, idempotency conflicts, malformed contract responses, immutable
versions, fail-closed validation, async state transitions, and callback observability.

## Runtime lifecycle acceptance

The final source was exercised through real Apex Metadata API callbacks in the disposable org:

- immutable save and identical-key retry returned one version;
- inactive publication succeeded and recorded deployment `0Afcf00000B6MlvCAF`;
- activation of a two-Check version succeeded (`0Afcf00000B6OaoCAF`);
- publishing a later version that omitted one Check explicitly deactivated that Check
  (`0Afcf00000B6LWWCA3`);
- rollback to the two-Check version succeeded and reactivated the omitted Check
  (`0Afcf00000B6AWHCA3`);
- the exact final candidate then rolled back to the one-Check version successfully
  (`0Afcf00000B6PrpCAF`), superseded the prior active version, and left the omitted Check inactive;
- every terminal ledger row recorded `SUCCEEDED`, a completion timestamp, result summary, and
  Salesforce Metadata deployment request ID.

The repository verifier then repeated the complete sequence successfully with fresh CI-owned names
and tokens. Its four terminal Metadata requests were `0Afcf00000B6QXlCAN` (inactive publish),
`0Afcf00000B6GlPCAV` (activate version 2), `0Afcf00000B6MadCAF` (activate version 3 and omit one
Check), and `0Afcf00000B6Kk6CAF` (rollback version 2). Readback showed version 2 active and deployed,
version 3 inactive and superseded, and both restored Checks active.

Two defects were discovered and fixed before the successful run: mixed setup/non-setup DML after
`Metadata.Operations.enqueueDeployment`, and the invalid pseudo-namespace `subscriber__`. Request-ID
persistence now occurs in the callback transaction, and Builder accepts only unprefixed
subscriber-owned Developer Names for metadata it authors.

## Dependency-health probe

An exploratory org-wide `RunLocalTests` executed 699 tests: 694 passed and five installed-core tests
failed in this Enterprise scratch-org shape. No Builder test failed. The failures were in packaged
core classes (`RecordHealthCheckBulkQuerySupportTest`, `RecordHealthCheckFieldPlannerTest`, and
`RHCQueryClassificationRedTest`) and included org-schema/readability assumptions. Builder CI therefore
runs its seven package-owned test classes explicitly; dependency health remains a separate core gate
rather than allowing an installed dependency's packaged tests to make Builder results nondeterministic.

## Remaining pre-version repository gate

The workspace is an uncommitted repository (`main` has no commits, no tracked files, and no remote).
The source and workflow files therefore have not been reviewed as a commit and neither GitHub Actions
workflow has produced durable CI evidence. The Salesforce workflow now fails closed when its Dev Hub
secret is absent and runs `scripts/verify-runtime-lifecycle.sh` after isolated coverage, but it still
must run successfully after the intended initial commit is pushed.

This gate does not require a package version. Clear it before requesting permission to create one.

## Gates that cannot run before a new package version

The following are intentionally **unverified**, not silently passed:

- current-source package-version creation and `HasPassedCodeCoverageCheck` readback;
- clean non-namespaced subscriber installation of the current source;
- upgrade from beta `0.2.0.1`;
- uninstall cleanup and confirmation that core remains functional;
- installed-package UI acceptance in a clean subscriber org; and
- promotion and release-note/install-link checks.

These gates require the candidate `04t`. Do not create it without explicit release-owner approval.

## Historical beta evidence

Beta `0.2.0.1` (`04tak000000ckt3AAA`, request `08cak000000Gp9pAAC`) had 76% isolated
package coverage and was not promoted. It does not verify the current source and must not be used as
the current release artifact.

A final read-only Dev Hub audit confirmed the existing package container was created on 2026-08-23
and its newest `Package2Version` remains build `0.2.0.1`, also created on 2026-08-23. No package or
package version was created during the 2026-08-30 readiness work.
