# RHC Logs release gates

This ledger is the authority for deciding whether package-candidate creation is allowed. A green
local gate is necessary but is not evidence that the source compiles or runs in Salesforce.

## Candidate-creation lock

Do not register a package container and do not create a package version until every pre-package gate
below is **Passed** for the exact committed source. A `0Ho` is only a container; a validated `04t` is
the first installable artifact.

`npm run release:check-candidate-unlock` must also pass. It binds the two org-shape results and exact
CI result to a deterministic digest of the current source. See the
[pre-package evidence format](PREPACKAGE-EVIDENCE.md).

| Pre-package gate | Required evidence | Current state |
| --- | --- | --- |
| Repository contracts and links | `node scripts/validate-repository.mjs` from suite root | Passed locally, 2026-10-13 |
| Package source and security invariants | `npm run validate` | Passed locally, 2026-10-13 |
| Minimum-core contract | `npm run validate:core-contract` against core commit `74fe1d6022f819397fc879c076f4f4dd2093cfab` | Passed locally, 2026-10-13 |
| Current-release source contract | `npm run validate:core-contract -- --core-ref 5905f999dfee391bd4ff029611023f157e60e8ee` (core 2.0.11.4) | Passed locally, 2026-10-13 |
| Current-release subscriber-source runtime | Namespace-adapted source dry run against installed core 2.0.11.4 | Passed, 2026-10-13: 56 components, 34/34 Apex tests, 95.15% coverage, job `0AfcU00000B5e6XSAR`; [scope and limits](RUNTIME-VERIFICATION.md) |
| Metadata XML | `npm run validate:xml` | Passed locally, 2026-10-13 |
| LWC tests and thresholds | 25 Jest tests; at least 98% lines/statements/functions and 75% branches | Passed locally, 2026-10-13: 100% lines/statements/functions, 93.47% branches |
| Dependency audit | `npm audit --audit-level=high` | Passed locally, 2026-10-13: full audit reports 0 vulnerabilities; four dependency-security tests and registry signature verification pass |
| Source conversion | source-to-Metadata-API conversion in an empty temporary directory | Passed locally, 2026-10-13 |
| Salesforce Code Analyzer | Recommended rules, zero severity 1–5 findings | Passed locally, 2026-10-13 |
| Namespaced source compile and tests | `rhc` scratch org; promoted minimum-core dependency plus extension source; all current 34 Apex tests; at least 95% package Apex coverage | **Pending; requires authorized org creation and source upload** |
| No-namespace source compile and tests | Namespace-null extension source in a no-namespace scratch org with promoted minimum-core dependency; all current 34 Apex tests and at least 95% package Apex coverage | **Pending for current source**; historical 2026-08-30 evidence passed 32/32 tests and 429/450 lines (95%), run `707RL00001eGvoZ` |
| Platform Event runtime | 251-event delivery, duplicate delivery, malformed event, unsupported contract, and retry classification in both source org shapes | No-namespace passed in run `707RL00001eGvoZ`; namespaced pending |
| Permission/runtime acceptance | unprivileged, Viewer, and Admin behavior; schedule create/disable; bounded cleanup | No-namespace passed in run `707RL00001eGvoZ`; namespaced pending |
| Exact-commit CI | GitHub Actions `Validate` succeeds for the release commit | **Pending** |

Both org-shape gates are bound to core commit
`74fe1d6022f819397fc879c076f4f4dd2093cfab` (`74fe1d6`), the source commit that
records promoted dependency `Record Health Check@2.0.4-2` as
`04tak000000cZBFAA2`. The no-namespace evidence uses that promoted managed dependency and
namespace-null extension source. The namespaced gate remains a combined core-source and
extension-source development check.

## Candidate-only gates

These gates begin only after every pre-package gate passes and package creation is separately
authorized:

| Candidate gate | Required evidence | Current state |
| --- | --- | --- |
| Validated 2GP version | no `--skip-validation`; package code coverage passes | Not started |
| Artifact inventory | intended metadata exists in the generated package artifact | Not started |
| Clean subscriber install | core 2.0.4.2 only, then the candidate `04t` | Not started |
| Subscriber acceptance | Admin/Viewer permissions, event ingestion, review, cleanup, schedule, disable flow | Not started |
| Upgrade safety | Not applicable to the first promoted release unless an earlier candidate is designated as an upgrade baseline | Not applicable currently |
| Uninstall safety | schedule disabled; restricted evidence export decision; package data-loss behavior exercised | Not started |
| Promotion | promote only after every applicable candidate gate passes | Locked |

## Namespace interpretation

The extension source never hard-codes `rhc__` in Apex or trigger code. Direct references to core
types are intentionally unqualified for the package's own namespace. Namespace-null validation
against a managed core install requires a temporary copy with core references qualified; unchanged
package source does not resolve them in that shape. The local core-contract validator confirms the namespace, API version, dependency alias,
canonical event fields, publish behavior, default-off control, and publisher permission against the
minimum-core source. Only the two scratch-org gates can prove compilation and runtime behavior.
