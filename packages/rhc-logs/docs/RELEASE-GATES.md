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
| Repository contracts and links | `node scripts/validate-repository.mjs` from suite root | Passed locally, 2026-08-30 |
| Package source and security invariants | `npm run validate` | Passed locally, 2026-08-30 |
| Minimum-core contract | `npm run validate:core-contract` against core commit `74fe1d6022f819397fc879c076f4f4dd2093cfab` | Passed locally, 2026-08-30 |
| Metadata XML | `npm run validate:xml` | Passed locally, 2026-08-30 |
| LWC tests and thresholds | 16 Jest tests; at least 98% lines/statements/functions and 75% branches | Passed locally, 2026-08-30 |
| Dependency audit | `npm audit --audit-level=high` | Passed locally, 0 vulnerabilities, 2026-08-30 |
| Source conversion | source-to-Metadata-API conversion in an empty temporary directory | Passed locally, 2026-08-30 |
| Salesforce Code Analyzer | Recommended rules, zero severity 1–5 findings | Passed locally, 2026-08-30 |
| Namespaced source compile and tests | `rhc` scratch org; minimum-core source plus extension source; 29 Apex tests; at least 95% package Apex coverage | **Pending; requires authorized org creation and source upload** |
| No-namespace source compile and tests | Namespace-null extension source in a no-namespace scratch org with promoted minimum-core dependency; at least 29 Apex tests and 95% package Apex coverage | Passed, 2026-08-30: dry run `0AfRL00000hD2jD0AS`; deployment `0AfRL00000hDCH80AO`; 32/32 tests and 429/450 lines (95%), run `707RL00001eGvoZ` |
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
types are intentionally unqualified so Salesforce resolves them in both package and portable source
shapes. The local core-contract validator confirms the namespace, API version, dependency alias,
canonical event fields, publish behavior, default-off control, and publisher permission against the
minimum-core source. Only the two scratch-org gates can prove compilation and runtime behavior.
