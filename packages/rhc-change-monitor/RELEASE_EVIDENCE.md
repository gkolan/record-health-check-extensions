# RHC Change Monitor release evidence

Status: **implementation preview; not release-ready**.

Current-source note (2026-09-20): Gate 3 is passed. Gates 1, 2, and 4 plus package lifecycle remain
open. Local validation for the current diff is recorded in the suite verification document; the
org IDs below are historical evidence and must not be described as verification of later source.

## Implemented contract surface

- Nine-package repository project pinned to API `66.0` and core `2.0.4-2`.
- Policy and minimal Change Evaluation ledger metadata.
- Actual ChangeEvent sObject intake boundary with header-only extraction.
- Versioned SHA-256 event-policy-record claims.
- CREATE, UPDATE, UNDELETE, DELETE, gap, and unknown routing.
- One policy query per intake batch and partial-success duplicate claim insertion.
- Queueable dispatch with policy revalidation, 200-record scope, three-attempt retry cap, and
  ten-job chain cap.
- Admin and Viewer permission sets with no business-object access.
- Unit and 251-record bulk contract tests.
- Tested subscriber-adapter generator for standard and custom CDC entity naming; generated source
  remains subscriber-owned and requires an object-specific contract test. Read-only check mode
  detects missing or drifted generated files in subscriber CI.
- Immediate dispatch-event publication results are checked. Synchronous rejection rolls back both
  intake claims and administrator retry transitions, with focused negative tests for each path.
- Administrators can publish one additional data-free wake-up signal for visible pending claims
  when no dispatcher is active; the operation never edits or duplicates claims.

## Open feasibility gates

| Gate                     | Required evidence                                                                                                                  | Status                                            |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| Adapter packaging        | Namespaced and no-namespace subscriber-style trigger compile/deploy matrix, including CDC not selected                             | Open                                              |
| Stable replay identity   | Real CREATE/UPDATE/UNDELETE/DELETE, duplicate redelivery, bulk, and gap capture proving transaction key + sequence stability       | Open                                              |
| Effective principal      | CDC claim signal handed to a configured least-privilege platform-event subscriber, followed by core execution and historical retry | Passed 2026-09-18; reverify for release candidate |
| Limits and amplification | Measured event batch shapes, 10-policy amplification, queue backlog, and gap/overflow behavior                                     | Open; executable 10 × 251 = 2,510 claim scenario added, org measurement pending |

## Package-creation lock

Do not create a 2GP package container or package version merely because the source compiles. The
current maintainer decision requires every pre-registration feasibility, security, namespace,
no-namespace, limits, and operational gate to have objective passing evidence and an explicit
release-worthiness decision first.

Actual managed-package install, upgrade, and uninstall evidence necessarily depends on a package
candidate. Under the current lock that evidence remains unexecuted, so neither package creation nor
release is authorized. Any later exception must explicitly authorize creation of a release
candidate for lifecycle validation; it must not be treated as release approval.

## Historical org validation evidence

Populate only from actual command or org output:

| Check                           | Result                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Repository validation           | Passed at the time of the shared-org run: 8 packages, 179 Markdown files, 634 local links; API 66.0 and core 2.0.4-2 contract. Superseded by the current nine-package local validation.                                                                                                                                                                                                                                                          |
| XML/source validation           | Passed: generated metadata XML parsed successfully; final 11-class dry-run succeeded (`0AfO500000eNhBhKAK`)                                                                                                                                                                                                                                                                                                                                      |
| Salesforce Code Analyzer        | Passed: complete Recommended scan of package and subscriber source found 0 violations after remediation; repeated after the final Queueable correction with 0 violations (`code-analyzer-results-20260830-zero-posttest.json`)                                                                                                                                                                                                                   |
| Apex contract tests             | Passed after final no-namespace deployment: 19/19, 100% pass rate (`707RL00001eHWIZ`)                                                                                                                                                                                                                                                                                                                                                            |
| Namespaced build-org test       | Passed: 40-component initial deployment plus final class deployment (`0AfO500000eNhGXKA0`) and focused tests                                                                                                                                                                                                                                                                                                                                     |
| No-namespace build-org test     | Passed in canonical shared org `rhc-change-monitor-nons-shared-20260830`: exact core 2.0.4-2 source deployed (`0AfRL00000hD9zB0AS`); analyzer-refactored Change Monitor and adapter deployed (`0AfRL00000hD5vd0AC`, correction `0AfRL00000hD8v70AC`); focused tests 19/19 (`707RL00001eHWIZ`); final `RunLocalTests` 959/959 with 0 failures, 95% org-wide and 96% run coverage (`707RL00001eHQQq`); entry classes have `NamespacePrefix = null` |
| Subscriber-owned adapter test   | Passed in no-namespace org: 7/7, including CREATE, 251-record bulk CREATE, matching/nonmatching UPDATE, UNDELETE, and DELETE (`707RL00001eHNA3`, 85% run coverage)                                                                                                                                                                                                                                                                               |
| Clean install/upgrade/uninstall | Pending                                                                                                                                                                                                                                                                                                                                                                                                                                          |

No 2GP package container or version is authorized while any pre-registration gate remains open or
before an explicit release-worthiness decision is recorded.

The no-namespace source and adapter results clear compilation, deployment, test, and regression
questions for this source topology. They do not close the release gates for stable redelivery
identity, measured event amplification and backlog behavior, namespaced adapter packaging, or
package lifecycle. Gate 3's effective-principal design passed later and is documented in
`GAP_ANALYSIS.md`; it still needs release-candidate revalidation. The target
contains core and Change Monitor as unmanaged no-namespace source (`sf package installed list`
returned no installed packages), so this is source-compatibility evidence rather than a managed
package installation result.
