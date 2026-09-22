# RHC Alerts release gates

This ledger is the authority for deciding whether package-candidate creation is allowed. Local
success is necessary, but it does not prove that Apex compiles or runs in Salesforce.

## Executable candidate-creation lock

Copy the tracked
[`release-evidence/prepackage.template.json`](../release-evidence/prepackage.template.json) to the
ignored `.release-evidence/prepackage.json`, then run `npm run verify:prepackage`. The verifier is
read-only and never authenticates to Salesforce. It fails unless the run-specific ledger identifies
one clean, exact commit and records all local, CI, namespaced-source, and no-namespace-source
evidence.

Run `npm run preflight:local` first to execute the complete local-only gate set and a temporary
zero-finding analyzer scan. Passing it is necessary but cannot populate or waive Git, CI, or org
evidence.

For release evidence capture, run
`npm run preflight:local -- --evidence-dir .release-evidence/local`. This retains the raw analyzer and
Jest JSON plus a machine-generated `local-summary.json` under the ignored evidence directory. Copy
those exact values into the populated ledger; do not transcribe terminal output by hand.

Current working-tree evidence: the September 20 aggregate preflight passed with 19 Jest tests,
threshold coverage, zero dependency vulnerabilities, successful Metadata API conversion, and zero
Recommended findings. Raw local artifacts are retained at
`/tmp/rhc-alerts-preflight-evidence-203406`; they are not exact-commit or org evidence.

Do not create a package version while the verifier fails. A passing verifier allows a release owner
to consider separately authorizing candidate creation; it does not authorize promotion.

## Pre-package gates

| Gate                         | Required evidence                                                                   | Current state                                                                                                                                                                  |
| ---------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Exact source                 | Full Git SHA, clean tracked worktree                                                | **Pending for a release candidate**: repository HEAD is `08f377d952996873d739d6832736355a42494b19`, but Alerts source and shared validation workflows are modified/uncommitted |
| Repository/package contracts | Repository validator, generated metadata, package invariants                        | Passed locally; must be tied to the release SHA                                                                                                                                |
| Formatting                   | Exact-pinned Prettier and Apex plugin, zero drift                                   | Passed locally; must be tied to the release SHA                                                                                                                                |
| Minimum-core compatibility   | Core `74fe1d6022f819397fc879c076f4f4dd2093cfab`, API 66.0, `2.0.4-2`                | Passed locally; must be tied to the release SHA                                                                                                                                |
| XML and source conversion    | Valid XML and Metadata API conversion                                               | Passed locally; must be tied to the release SHA                                                                                                                                |
| LWC                          | 19 tests and thresholds 90/80/90/90                                                 | Passed locally: 96.35% statements, 81.57% branches, 97.43% functions, and 99.16% lines; must be tied to the release SHA                                                        |
| SLDS                         | Pinned linter, zero violations                                                      | Passed locally; must be tied to the release SHA                                                                                                                                |
| Dependency audit             | Zero high vulnerabilities                                                           | Passed locally; must be tied to the release SHA                                                                                                                                |
| Code Analyzer                | Recommended selector, zero severity 1–5 findings                                    | Passed locally; must be tied to the release SHA                                                                                                                                |
| Namespaced source behavior   | Dry-run deployment, all current 55 Apex test methods, coverage, events, permissions | **Pending; requires explicit org authorization**                                                                                                                               |
| No-namespace source behavior | Same current source/test/runtime matrix in a no-namespace org                       | **Pending; requires explicit org authorization**                                                                                                                               |
| Exact-commit CI              | Required Alerts jobs pass for the release SHA                                       | **Pending**                                                                                                                                                                    |

The two source-org gates use minimum-core source and the same Alerts source revision. Each record
must identify its org shape, completion time, distinct org, dry-run job, Apex test run, and HTTPS raw
evidence location. Together they prove portable unqualified type resolution before any `04t` is
created.

## Candidate-only gates

These begin only after `npm run verify:prepackage` passes and package creation is separately
authorized:

| Gate                             | Required evidence                                                                   | Current state                         |
| -------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------- |
| Validated beta                   | No `--skip-validation`; Salesforce coverage succeeds                                | Locked                                |
| Artifact inventory               | Intended metadata and dependency are present                                        | Locked                                |
| Clean subscriber install         | Core `04tak000000cZBFAA2` plus Alerts candidate only                                | Locked                                |
| Namespaced subscriber acceptance | Events, idempotency, cooldown, email/custom notification, Admin/Viewer              | Locked                                |
| Upgrade safety                   | Install designated prior baseline, then candidate, without contract/data regression | Locked until a baseline is designated |
| Uninstall safety                 | Core remains functional; package data-loss behavior is explicitly accepted          | Locked                                |
| Promotion                        | Every applicable candidate gate passed for the same `04t`                           | Locked                                |

## Evidence handling

- Retain raw CLI JSON and CI URLs outside the package source tree or in the approved release evidence
  store.
- Keep the populated ledger in ignored `.release-evidence/`; the tracked template must remain
  `PENDING`. This avoids an impossible self-reference between a commit and a file inside that commit.
- Retain the analyzer JSON beside the populated ledger or at another ignored/external path. The lock
  parses it, requires zero findings, and verifies its SHA-256 digest rather than trusting a reported
  count.
- Record only org IDs and job/test IDs in the populated ledger; never store authentication data.
- Never mark a gate passed from an older source revision.
- Never treat local source conversion as Apex compilation evidence.
