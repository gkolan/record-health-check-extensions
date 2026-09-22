# Extension suite verification — 2026-09-20

This ledger describes the current working-tree verification. Historical deployment IDs in package
release-evidence documents remain evidence for the source that was deployed on their stated dates;
they are not automatically evidence for this later diff.

No namespace, package container, package version, installation, quick deploy, or production deploy
was created during this work.

## Scope and repository contracts

| Check | Result |
| --- | --- |
| Package inventory | 9 independent package projects |
| Source inventory | 146 Apex classes, 10 Apex triggers, 11 LWC bundles, 31 object definitions, 0 Flows |
| Test inventory | 54 Apex test classes; 128 Jest tests and 6 adapter-generator tests executed locally |
| Shared contract | API 66.0; `Record Health Check@2.0.4-2`; namespace declaration `rhc` |
| Repository validator | Passed; 9 packages, 156 Markdown files, 403 local links |
| Documentation roles | Administrator, security, operations, and release guidance mapped for all 9 packages |
| Diff hygiene | `git diff --check` passed |

The Builder verification record was reconciled with the current monorepo on 2026-09-20. Its former
claim that the workspace had no commits, tracked files, or remote is obsolete: Builder has 109
tracked paths, `origin` is configured, and the current branch's committed HEAD matches its upstream.
The exact working-tree candidate still lacks durable CI evidence because the suite-wide diff is
uncommitted.

## Local package verification

All eight npm-backed packages passed `npm test` and `npm run test:coverage`. All eight dependency
audits reported zero vulnerabilities at high-or-greater severity after clean installs for the four
changed packages.

| Package | Tests | LWC statement / branch / function / line coverage |
| --- | ---: | --- |
| RHC Actions | 11 Jest | 91.58% / 70.83% / 92.3% / 92.85% |
| RHC Alerts | 19 Jest | 96.35% / 81.57% / 97.43% / 99.16% |
| RHC Builder | 33 Jest | 88.09% / 66.79% / 94% / 88.8% |
| RHC Change Monitor | 6 generator + 11 Jest | 100% / 90% / 100% / 100% for the LWC |
| RHC Integrations | 15 Jest | 100% / 100% / 100% / 100% |
| RHC Logs | 17 Jest | 100% / 96.42% / 100% / 100% |
| RHC Reports | 6 Jest | 90.56% / 53.33% / 93.75% / 88.88% |
| RHC Run Manager | 16 Jest | 92.2% / 80.32% / 100% / 100% |

Package source validators passed for Actions, Alerts, Integrations, Logs, and Reports. Alerts'
generated-metadata, formatting, core-contract, and XML checks passed after formatting seven files
with its configured formatter. Run Manager generated metadata is current. Source-to-Metadata-API
conversion passed for Alerts, Change Monitor, Integrations, Run Manager, and Agent Actions.

## CI coverage

The validation workflow now includes all eight npm-backed packages in its test-coverage and
high-severity dependency-audit matrix. Change Monitor additionally runs its six adapter-generator
tests and generated-metadata drift check. Package-specific jobs plus the new Change Monitor/Agent
Actions static matrix provide source-conversion and analyzer gates for all nine package projects.
The repository validator now enforces those package-to-job mappings, the eight-package npm matrix,
coverage and audit commands, Change Monitor adapter tests, and its metadata-drift check. The
workflow YAML parsed successfully locally, and all five workflows passed official Actionlint
1.7.12 after its macOS arm64 archive matched published SHA-256
`aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f`. The repository job now
repeats Actionlint with the pinned Linux amd64 checksum. Because these changes are still an
uncommitted working-tree candidate, no GitHub Actions run is claimed for this exact diff.

Org-backed validation workflows are now configured for all nine projects. The existing Actions,
Builder, and Reports workflows are joined by a serial matrix for Agent Actions, Alerts, Change
Monitor, Integrations, Logs, and Run Manager. Each new package path runs in both namespaced and
no-namespace modes, installs the pinned core dependency, performs a server-side dry run with local
tests, deploys only to a disposable one-day scratch org, verifies the expected namespace mode,
reruns local Apex tests with coverage, retains JSON evidence, and attempts scratch-org cleanup even
on failure. The root validator enforces these mappings, both modes, and required lifecycle steps,
and rejects package-container creation, package-version creation, or promotion commands in
validation workflows. This is workflow
coverage, not execution evidence: the configured `rhc-dev-hub` alias is not present in the current
authenticated-org inventory, so no scratch org was created and the new matrix has not run locally.

## Static analysis

The full Recommended scan produced `code-analyzer-results-20260920-150229.json`:

- 0 critical and 0 high findings;
- 360 moderate, 307 low, and 11 informational findings;
- the largest existing categories are ApexDoc, test `runAs`, naming, brace, parameter-count, and
  complexity rules; and
- CPD could not lex the pre-existing Change Monitor `generate_metadata.mjs`, so duplicate-code
  coverage for that one file is incomplete.

The new subscriber-adapter generator and its tests have zero Recommended findings in
`code-analyzer-results-20260920-150800.json`. The changed Apex scan has 0 critical/high, 27 moderate,
and 29 low findings; the remaining items are primarily Run Manager documentation/braces/complexity
debt recorded in the improvement plan.

A fresh Reports package scan initially found 132 findings: 0 critical, 0 high, 48 moderate, and 84
low (`/tmp/rhc-reports-recommended-20260920-205249.json`). Decomposing the coverage controller
removed its method-size and complexity findings and documented its Aura DTO; normalizing all 25
test-method names and all 33 `@IsTest` annotations then reduced the full result to 51 findings: 0
critical, 0 high, 19 moderate, and 32 low
(`/tmp/rhc-reports-recommended-20260920-205626.json`). The four remaining controller findings are
two generated Boolean-setter heuristics on its public DTO and two warnings on intentionally complete
aggregate queries. No analyzer suppression or generated autofix was added.

The subsequent Reports aggregation pass replaced positional window/dimension values with internal
typed boundaries, split selection/accumulation/persistence stages, preserved the public aggregation
API and deterministic snapshot identity, and completed the package's seven remaining ApexDoc
contracts. `RHCReportsAggregationService` fell from nine findings to one class-total complexity
heuristic. The final full Reports result contains 36 findings: 0 critical, 0 high, 12 moderate, and
24 low (`/tmp/rhc-reports-recommended-20260920-210324.json`). Twenty-two low findings are the
existing explicit-`runAs` test guidance; the remaining findings are bounded public-contract,
aggregate-query, and async/batch design heuristics.

The Reports Queueable follow-up replaced its Boolean catch-up argument and parallel serialized
fields with an enum-backed request, then separated finalizer outcome recording from continuation.
All repository call sites now use the typed contract; the two-argument manual-recompute constructor
and operational behavior are unchanged. The Queueable has zero findings and the full Reports result
now contains 33 findings: 0 critical, 0 high, 9 moderate, and 24 low
(`/tmp/rhc-reports-recommended-20260920-210558.json`).

Replacing the retention Batch's test-only four-argument constructor with a named no-continuation
factory and the five-value Result-fact test helper with `ResultFactRequest` removed both remaining
non-controller positional findings. The final Reports result now contains 31 findings: 0 critical,
0 high, 7 moderate, and 24 low
(`/tmp/rhc-reports-recommended-20260920-210838.json`).

Replacing `RHCReportsSetupController.saveSettings`' six positional Aura parameters with one typed
`SaveSettingsInput` removed its excessive-parameter finding and three Boolean-parameter findings.
The LWC and direct Apex callers use the same named contract, and a focused scan of the controller,
test, and component is clean (`/tmp/rhc-reports-settings-request-20260920-212803.json`). The full
Reports result now contains 27 findings: 0 critical, 0 high, 3 moderate, and 24 low
(`/tmp/rhc-reports-recommended-20260920-213038.json`). Six Jest tests, coverage, source and
minimum-core validation, XML parsing, zero-vulnerability audit, and Metadata API conversion pass;
current org-side Apex compilation and execution remain pending authorization.

Extracting bounded fact reads and atomic snapshot-partition replacement into
`RHCReportsAggregationRepository` removed the aggregation service's remaining class-total complexity
finding while preserving its public API, system-mode access, safety limits, transaction semantics,
and deterministic snapshot keys. The focused service/repository/test result contains five existing
low-severity `runAs` recommendations and no production-code findings
(`/tmp/rhc-reports-aggregation-repository-20260920-213452.json`). The full Reports result now contains
26 findings: 0 critical, 0 high, 2 moderate, and 24 low
(`/tmp/rhc-reports-recommended-20260920-2205.json`). Six Jest tests and coverage, source and
minimum-core validation, XML parsing, zero-vulnerability audit, and Metadata API conversion pass.
The focused Apex test could not start because no default or target org is configured.

The four non-controller Reports test suites now run all 22 scenarios under an explicit Standard
User created by the shared test factory. The focused factory/test scan is clean
(`/tmp/rhc-reports-explicit-principals-20260920-2245.json`). The full Reports result now contains
four findings at that stage: 0 critical, 0 high, 2 moderate, and 2 low
(`/tmp/rhc-reports-recommended-principals-20260920-2248.json`). Those items were the public
coverage DTO's two generated Boolean-setter heuristics and two intentionally complete aggregate
coverage queries. Six Jest tests and coverage, source and minimum-core validation, XML parsing,
zero-vulnerability audit, and Metadata API conversion pass. The four-class Apex run could not start
because no default or target org is configured.

The four coverage-controller heuristics are now captured as narrow, source-validator-enforced
exceptions rather than public-contract or query changes. The current full Reports package scan
reports zero findings (`/tmp/rhc-reports-recommended-20260921-0240.json`). Six Jest tests pass with
90.56% statement, 53.33% branch, 93.75% function, and 88.88% line coverage; source,
minimum-core, XML, dependency-audit, and Metadata API conversion gates pass. A focused Apex run was
requested but stopped before submission because no default or target org is configured.

The same documentation audit corrected the RHC Logs authoritative ingestion contract: it now states
the implemented three-retry bound and `RETRY_EXHAUSTED` terminal evidence instead of describing
unbounded platform retry behavior. This was a documentation-only reconciliation with the existing
service, tests, improvement record, and operations guide.

A focused Recommended scan of the new Alerts notification-type diagnostic, its Apex test, the
Alerts admin LWC, and the Change Monitor adapter tooling found 0 violations
(`/tmp/rhc-code-analyzer-results-20260920-153952.json`).

After adding Alerts retention, a focused Recommended scan of the admin controller, its Apex test,
the policy/retention services, and the admin LWC found 0 violations
(`code-analyzer-results-20260920-155851.json`). The first scan exposed class-level complexity in the
controller; extracting the two cohesive services removed that finding without changing the
Aura-enabled contract.

After adding Change Monitor retention, a focused Recommended scan of the retention service,
controller, controller test, and console found 0 violations
(`code-analyzer-results-20260920-161510.json`). Preceding scans exposed a hard-coded test ID,
an oversized test helper, incomplete ApexDoc, and the missing explicit admin test principal; all
were remediated before recording this result.

The current Integrations dedicated security scan is not yet a complete pass. Its first run reported
one high `ApexFlsViolation` at `saveRetentionSettings`; explicit setting-field capability checks and
`Security.stripInaccessible` before user-mode DML removed the finding. The follow-up Code Analyzer
5.15.0 result has zero violations, but SFGE still analyzed only 30 of 32 entry points because of
internal execution errors at `RHCIntegrationDeadLetterController.replay` and `replayAll`. The strict
log validator rejected the incomplete run. Evidence:
`/tmp/rhc-integrations-security-20260920-202747.json` and
`/tmp/rhc-integrations-security-20260920-202747.log`. Explicit replay-state sanitization with
fail-closed removed-field handling did not change the two engine errors; the controller's focused
Recommended scan is nevertheless clean (`/tmp/rhc-integrations-replay-20260920-202728.json`). No
generated autofix or analyzer suppression was applied.
The current rerun reproduced the same zero-violation but incomplete 30/32 result in
`/tmp/rhc-integrations-security-current.log`. Next-line and stack directives using both the v5
display name and legacy internal rule name, plus an explicit sanitized-list local, were tested and
did not change the engine result. Those ineffective experiments were removed; the release gate
remains open and the strict log validator continues to fail closed.
The hardened retention service's focused Recommended scan is clean
(`/tmp/rhc-integrations-retention-20260920-201811.json`).

After adding Integrations retention, a focused Recommended scan of the retention service,
dead-letter controller and test, and operations LWC found 0 violations
(`packages/rhc-integrations/code-analyzer-results-20260920-162714.json`). Earlier focused scans
exposed controller complexity, declaration placement, and documentation/style findings; the
controller was decomposed and the touched surface brought to a clean result.

After adding Run Manager retention, the first focused scan found two hard-coded test IDs. Replacing
them with inserted Account IDs produced a clean focused Recommended scan of the retention service,
tests, controller, and LWC (`/tmp/rhc-run-manager-code-analyzer-results-20260920-170500.json`): 0
violations.

A stricter root-policy scan of the full Run Manager source initially found 247 findings: 0
critical, 0 high, 179 moderate, and 68 low. Refactoring `RHCRunManagerCaptureService` reduced its
focused result from 17 moderate findings to the single accepted four-parameter-contract heuristic;
the full package result then fell to 231 findings: 0 critical, 0 high, 163 moderate, and 68 low
(`/tmp/rhc-run-manager-root-config-20260920-182100.json`). The removed findings were 14 brace
findings plus cyclomatic and cognitive complexity in `capture`; atomic rollback and user-mode
upsert behavior were preserved.

Extracting Batch cancellation from the Admin controller into a focused service reduced the full
Run Manager result again to 226 findings: 0 critical, 0 high, 158 moderate, and 68 low
(`/tmp/rhc-run-manager-root-config-20260920-182600.json`). The new cancellation service and its
dedicated active/terminal/null-input test have zero strict-policy findings; the controller fell
from 50 to 45 findings while retaining the same Aura-enabled method and sanitized messages.

Decomposing `RHCRunManagerScheduleService.save` reduced that file from 12 moderate findings to its
two unchanged public-signature heuristics. The full Run Manager result fell again to 216 findings:
0 critical, 0 high, 148 moderate, and 68 low
(`/tmp/rhc-run-manager-root-config-20260920-183000.json`).

Decomposing `RHCRunManagerSubmitIdsAction` reduced that file from 16 findings (14 moderate and 2
low) to two moderate complexity heuristics. The full Run Manager result fell again to 202
findings: 0 critical, 0 high, 136 moderate, and 66 low
(`/tmp/rhc-run-manager-root-config-20260920-183518.json`). The invocable request/response contract,
user-mode upsert, atomic rollback, idempotent request key, and coalescer ownership are unchanged.

Decomposing `RHCRunManagerCoalescerQueueable.execute`, documenting its implemented 9,000-row
governor-safe drain and bounded finalizer retry, adding malformed durable-ID coverage, and
normalizing the touched async-test method names produced a clean focused scan
(`/tmp/rhc-run-manager-coalescer-20260920-184012.json`).
The full Run Manager result fell again to 179 findings: 0 critical, 0 high, 118 moderate, and 61 low
(`/tmp/rhc-run-manager-root-config-20260920-184033.json`).

Decomposing `RHCRunManagerFilterService` and expanding its negative security-boundary tests reduced
the focused service/test surface from 16 findings to two moderate service heuristics
(`/tmp/rhc-run-manager-filter-20260920-184841.json`). The full Run Manager result fell again to 165
findings: 0 critical, 0 high, 105 moderate, and 60 low
(`/tmp/rhc-run-manager-root-config-20260920-184841.json`).

Completing ApexDoc and explicit control flow for the retention service, its test, and the scheduled
adapter produced a zero-finding focused scan
(`/tmp/rhc-run-manager-retention-scheduled-20260920-185500.json`). The Batch contract/control-flow
pass reduced its focused scan from 22 findings to the two accepted stateful-orchestration heuristics
(`/tmp/rhc-run-manager-batch-20260920-185700.json`). The full Run Manager result fell again to 118
findings: 0 critical, 0 high, 69 moderate, and 49 low
(`/tmp/rhc-run-manager-root-config-20260920-185800.json`).

Completing the Admin controller contracts reduced its focused scan from 45 findings to three design
heuristics (`/tmp/rhc-run-manager-admin-controller-20260920-190300.json`). Normalizing legacy test
names, bracing remaining test/support control flow, completing gateway/execution/test contract docs,
removing the test factory's unused Boolean option, and excluding drift-checked metadata generators
from misapplied LWC runtime rules reduced the full Run Manager result to 13 moderate design heuristics:
0 critical, 0 high, 0 low, and 0 informational
(`/tmp/rhc-run-manager-root-config-20260920-191500.json`).

Extracting Run Definition validation, canonicalization, and persistence into a dedicated service
produced a focused result with only the controller's remaining aggregate cyclomatic heuristic; the
new service and its nine-scenario test are clean
(`/tmp/rhc-run-manager-definition-20260920-193500.json`). The full Run Manager result fell to 12
moderate design heuristics: 0 critical, 0 high, 0 low, and 0 informational
(`/tmp/rhc-run-manager-root-config-20260920-194000.json`).

Replacing the eight-argument schedule-service call with one typed recurrence request and adding
direct null-request coverage produced a focused result containing only the controller's existing
aggregate cyclomatic heuristic
(`/tmp/rhc-run-manager-schedule-request-20260920-195000.json`). The full Run Manager result fell to
10 moderate design heuristics: 0 critical, 0 high, 0 low, and 0 informational
(`/tmp/rhc-run-manager-root-config-20260920-195100.json`).

Isolating supplied-ID validation behind a focused private validator removed both remaining action
complexity findings (`/tmp/rhc-run-manager-submit-validator-20260920.json`). Moving scalar
conversion behind the filter boundary and replacing its four positional values with a typed query
request produced a clean focused filter service/test result apart from the Batch's two unchanged
stateful findings (`/tmp/rhc-run-manager-filter-request-20260920.json`). Type-specific core metadata
mapping is clean (`/tmp/rhc-run-manager-core-info-20260920.json`), and typed execution/capture
requests plus their null guards are clean across the service, adapters, and tests
(`/tmp/rhc-run-manager-execution-capture-request-20260920.json`). The full strict scan now contains
three moderate design heuristics and no critical, high, low, or informational findings: the thin
Aura facade's aggregate cyclomatic total and the stateful Batch's serialized field-set and
constructor shape (`/tmp/rhc-run-manager-root-config-20260920-202000.json`).

Replacing the Batch's five positional launch values with `LaunchRequest` and grouping serialized
configuration and counters into execution/progress envelopes removed both Batch findings. A focused
negative test now rejects an incomplete launch request. The final full strict scan contains one
moderate finding—the Admin controller's aggregate cyclomatic total—and nothing else
(`/tmp/rhc-run-manager-state-envelope-final3.json`). Sixteen Jest tests pass with 92.2% statements,
80.32% branches, 100% functions, and 100% lines; metadata drift, dependency audit, and Metadata API
conversion pass. `sf org display --json` returned `NoDefaultEnvError`, so current Apex compilation
and execution remain unverified.

Agent Actions initially had eight strict-policy findings: one flat-response field-count heuristic,
one helper parameter-count heuristic, one missing test `runAs`, and five ApexDoc findings. The
response heuristic is now narrowly suppressed because that flat type is the public Agentforce
invocable contract; a typed internal accumulation request, explicit test principal, and completed
method contracts removed the rest. The full package now reports zero findings
(`/tmp/rhc-agent-actions-ci-clean2-20260920.json`). Metadata API conversion also passed. A current
`RHCAgentActionsTest` run was attempted but stopped before submission because the selected org
authorization was unavailable.

## Salesforce org verification boundary

`sf org list` still displays the historical shared no-namespace scratch-org alias, but
`sf org display --target-org rhc-change-monitor-nons-shared-20260830` cannot load its authorization,
and a validation-only attempt against `rhc-205-ns-release-20260828` fails at the same authorization
boundary before any metadata is submitted.
Consequently the current diff has not received a fresh server-side dry run or Apex test execution.
Do not promote the historical August/September deployment and test IDs into current-source claims.

Before release, restore or create an approved test-org authorization and rerun:

1. namespaced and no-namespace check-only source deployment;
2. affected Apex suites and `RunLocalTests` with coverage;
3. Change Monitor real CDC delivery and runtime-principal evidence; and
4. Alerts Custom Notification acceptance in a clean subscriber installation.

## Integrations delivery-retention readiness

Integrations now includes a package-owned settings singleton and manual cleanup path:

- retention is validated from 1 through 3,650 days;
- the displayed 90-day recommendation cannot authorize deletion until it is saved;
- one explicit run selects at most 1,000 oldest completed `SUCCEEDED` or `DEAD_LETTER` deliveries
  outside the saved window;
- `PENDING` and `RETRY_WAIT` are excluded regardless of timestamp;
- explicit setting-field capability checks, field sanitization, user-mode query/DML/delete,
  Admin-only settings CRUD, and hidden Operator/Viewer controls preserve least privilege;
- the UI requires a permanent-deletion acknowledgment, disables purge after unsaved changes, and
  clears the acknowledgment after a run; and
- no scheduled or automatic deletion is included.

The 15 LWC tests pass with 100% statement/branch/function/line coverage. Dependency audit, XML
parsing, source validation, local source conversion, repository/link validation, LWS rule review,
and the focused Recommended scan also pass. Clean install, Apex tests, and server-side compilation
of the new settings metadata, service, controller endpoints, and permission changes still require a
freshly authorized org.

## Run Manager operational-retention readiness

Run Manager now includes a package-owned settings singleton and Admin-only, manually confirmed
cleanup path:

- retention is validated from 1 through 3,650 whole days; the displayed 365-day recommendation
  cannot authorize deletion until it is saved;
- each request deletes at most 1,000 explicit rows, draining eligible Results before empty terminal
  scope Runs and Batch Runs, then old submitted Requests;
- `QUEUED`/`PROCESSING` Batch Runs, `IN_PROGRESS` scope Runs, and `PENDING` Requests are excluded;
- definitions and schedules are never part of cleanup;
- `RHC_Run_Manager_Manage_Retention`, settings CRUD, and the internal settings object are limited to
  Admin; Viewer and Executor receive neither the capability nor direct settings access; and
- cleanup is never scheduled, unsaved changes disable purge, and every run requires a fresh
  permanent-deletion acknowledgment.

The 16 Jest tests pass with 100% line/function coverage, 92.2% statement coverage, and 80.32%
branch coverage. Generated-metadata drift, XML parsing, Metadata API conversion, dependency audit,
root repository/link validation, diff hygiene, LWS review, and the focused Recommended scan pass.
The capture-service refactor also passed the stricter root-policy scan with only its accepted
parameter-count heuristic. The cancellation service and its test have zero strict-policy findings,
and the package-configured full scan remains clean. The schedule, supplied-ID staging, and
coalescer refactors further reduced the strict-policy debt without changing their public contracts.
The retention service/test and scheduled adapter are now strict-policy clean, and Batch retains only
its stateful field-set and constructor-parameter heuristics. The latest full strict scan contains
only three moderate design heuristics across the Aura facade and stateful Batch; test and support-code
naming, bracing, documentation noise, and non-stateful positional-request debt have been removed.
The final package-policy scan is clean
(`/tmp/rhc-run-manager-package-config-20260920-202300.json`), and the latest Metadata API conversion
succeeded (`/tmp/rhc-run-manager-convert-20260920-2021`). Focused Apex-test invocations covering
the controller, retention, Batch/schedule execution, supplied-ID staging, coalescer async behavior,
capture, core metadata resolution, guided-filter validation, and uninstall cleanup were attempted, but the saved
target-org authorization could not be loaded before any test submission; Apex execution and
server-side compilation still require a freshly authorized org.

The final strict-policy follow-up preserved every Aura-enabled controller method and DTO while
moving definition save, Run Now, cancellation, schedule save, and schedule pause mapping/error
translation into `RHCRunManagerAdminCommandService`. The focused controller/command/test scan is
clean (`/tmp/rhc-run-manager-admin-command-strict-20260920-2222.json`), and the full Run Manager
strict-policy scan now contains zero findings
(`/tmp/rhc-run-manager-strict-clean-final-20260920-2230.json`). Sixteen Jest tests pass with 92.2%
statements, 80.32% branches, and 100% functions/lines; generated-metadata drift, dependency audit,
and Metadata API conversion pass. The focused Apex run could not start because no default or target
org is configured.

## CDC readiness

CDC is built as an implementation preview, not as a releasable package.

The September 20 source re-audit confirmed that the package owns header-only parsing, policy
routing, idempotent claim persistence, data-free dispatch signaling, bounded Queueable evaluation,
retry/purge operations, and the subscriber-adapter generator. It also confirmed that object-specific
CDC triggers and channel membership remain deliberately subscriber-owned and that no package
container or version exists for Change Monitor.

| Capability | Current state |
| --- | --- |
| Header-only ChangeEvent parsing | Implemented and Apex-tested historically |
| Policy routing and field-change matching | Implemented |
| Versioned idempotent claim keys | Implemented; genuine redelivery stability remains a release gate |
| Bounded claim persistence and dispatch | Implemented |
| Least-privilege runtime principal | Gate 3 passed on 2026-09-18 through the package dispatch event and subscriber-owned `PlatformEventSubscriberConfig` |
| Operations console, bounded retry, bounded purge | Implemented and Jest-tested |
| Object-specific subscriber adapter | Account fixture exists; the CLI generates channel membership and a thin trigger for standard or custom objects, and read-only check mode detects drift |
| Namespaced/no-namespace adapter matrix | Open release gate |
| Real duplicate replay, gap, overflow, and 10-policy amplification | Open release gates |
| Clean install/upgrade/uninstall | Not run; no package or version was created |

Generate subscriber-owned source with:

```bash
cd packages/rhc-change-monitor
npm run adapter:generate -- \
  --object Account \
  --output /path/to/subscriber-repo/force-app/main/default

npm run adapter:check -- \
  --object Account \
  --output /path/to/subscriber-repo/force-app/main/default
```

The default references `rhc.RHCChangeMonitorIntake`. `--namespace none` is only for source-mode
verification. The generator does not invent object-specific test data, deploy metadata, enable a
policy, or create packaging artifacts.

## Salesforce notification-bell readiness

The bell feature is built in RHC Alerts:

- packaged `RHC_Alert` Custom Notification Type enables desktop and mobile delivery;
- `Messaging.CustomNotification` resolves that type, assigns the safe title/body, targets an
  accessible checked record or the fixed Delivery History navigation item, and sends to a bounded
  active-user audience;
- policy, duplicate, cooldown, retry, recipient, disclosure, and target rules are implemented;
- the administrator can send a test alert to the current user before policy activation; and
- the setup assistant reports `NOTIFICATION_TYPE_UNAVAILABLE` for an active bell policy when the
  packaged notification type cannot be resolved; and
- the UI labels the channel **Salesforce notification (bell)** without claiming control of the
  platform's global bell or proving that a recipient read the notification.

The remaining bell-specific release gaps are clean-subscriber installation, current org-side Apex
execution, platform-rejection acceptance, and end-to-end platform acceptance on desktop and mobile.
RHC Alerts still has no installable `04t` documented by the repository.

The September 20 source re-audit verified the packaged `RHC_Alert` notification type, sender,
coverage analyzer, administrator test-send path, accessible channel label, operational guidance,
and desktop/mobile contract. No source claims control of Salesforce's global bell badge or a
delivery/read receipt.

## Suite analyzer and Integrations principal follow-up

A fresh root Recommended scan initially reported 266 findings. Of those, 113 moderate findings
were LWC-runtime rules applied to Node CLI modules. Narrow file-local annotations now identify only
those two inapplicable rules while preserving every other ESLint and CPD check. Completing the
Integrations principal and ApexDoc pass, simplifying Logs cleanup control flow, and removing a
redundant Builder publication branch first brought the scan to 61 findings. Completing Actions and
recording the narrow Reports coverage exceptions brought the current scan to eight informational
findings across four files, with zero critical, high, moderate, or low findings. The current
artifact is `/tmp/rhc-suite-recommended-20260921-0300.json`; all eight notices are cross-package
duplication in independent Node validation scripts.

The full Integrations package Recommended scan
(`/tmp/rhc-integrations-recommended-20260921-0030.json`) reports zero findings. Fifteen Jest tests
pass with 100% coverage in every reported dimension, and source validation, minimum-core
validation, XML parsing, dependency audit, and Metadata API conversion pass. Apex execution was
attempted for all five test classes but could not start because no default or target org is
configured.

Logs now also reports zero package findings
(`/tmp/rhc-logs-recommended-20260921-0055.json`) after cleanup initialization and stop conditions
were isolated into focused helpers. Its continuation recovery model is captured by one narrow,
machine-checked `QueueableWithoutFinalizer` suppression. Seventeen Jest tests pass with 100%
statement/function/line and 96.42% branch coverage; source, core-contract, XML, dependency-audit,
and Metadata API conversion gates pass. Apex execution remains unavailable without an authorized
target org.

Builder now reports zero package findings
(`/tmp/rhc-builder-recommended-20260921-0130.json`) after removing redundant empty-list control flow
and applying the existing explicit-principal test convention. Thirty-three Jest tests pass, the
dependency audit and Metadata API conversion pass, and coverage is 88.09% statements, 66.79%
branches, 94% functions, and 88.8% lines. Its focused Apex run likewise stopped before submission
because no default or target org is configured.

## Change Monitor dispatch-signal atomicity

The current source checks the immediate `EventBus.publish` result for the package-owned,
data-free dispatch event. If Salesforce rejects that signal, intake rolls back the newly inserted
claims and administrator retry rolls back the failed-to-pending transition. Focused negative tests
cover both paths. Administrators can also publish one additional wake-up signal for visible pending
claims when no dispatcher is active, without editing or duplicating claims. The changed controller,
intake, dispatch helper, tests, and LWC have zero findings in the Recommended scan retained at
`/tmp/rhc-change-monitor-recovery-20260920-204909.json`; the dedicated LWS catalog review also has
zero findings. Metadata API conversion succeeds. Eleven LWC tests and six adapter-generator tests
pass, coverage is 100% statements/functions/lines and 90% branches, and the dependency audit
reports zero vulnerabilities. Apex execution remains pending because no default or explicitly
authorized target org is available. The Apex suite now also contains the Gate 4 amplification
scenario (ten policies × 251 record IDs = 2,510 exact policy-record claims); it is executable
scaffolding, not claimed load evidence until an org run captures limits and timings.

## Change Monitor retention readiness

Change Monitor now includes a package-owned settings singleton and manual cleanup path:

- retention is validated from 1 through 3,650 days;
- the displayed 90-day recommendation cannot authorize deletion until it is saved;
- one explicit run selects at most 1,000 oldest terminal evaluations outside the saved window;
- `PENDING` is excluded;
- the admin UI requires a permanent-deletion acknowledgment, disables purge while a changed window
  is unsaved, and clears the acknowledgment after a run; and
- no scheduled or automatic deletion is included.

The six adapter-generator tests and eleven LWC tests pass locally with 100% statement/function/line
coverage and 90% branch coverage. The dependency audit, XML parsing, source-to-Metadata-API
conversion, and focused Recommended scan also pass. Apex tests and deployment of the new settings
object, fields, validation rules, permissions, service, and controller surface still require a
freshly authorized org before release.

## Alerts delivery-retention readiness

Alerts now includes a package-owned settings singleton and manual cleanup path:

- retention is validated from 1 through 3,650 days;
- the displayed 90-day recommendation cannot authorize deletion until it is saved;
- one explicit run selects at most 1,000 oldest `DELIVERED`, `SUPPRESSED`, `FAILED`, or `DUPLICATE`
  rows outside the window;
- `PENDING` is excluded;
- the admin UI requires a permanent-deletion acknowledgment and clears it after a run; and
- no scheduled or automatic deletion is included.

The generator drift check, package contract validator, XML parser, SLDS linter, formatter, and 19
Jest tests pass locally. Apex tests and deployment of the new object, field, validation rules,
permissions, and controller surface still require a freshly authorized org before release.

Alerts release evidence is synchronized with the current suite: its pre-package lock now requires
at least 55 Apex methods in each org shape and all 19 current Jest tests locally. The lock integration
test covers both under-counted cases. The current Jest run passes 19/19 with 96.35% statements,
81.57% branches, 97.43% functions, and 99.16% lines. The aggregate local preflight also passes with
zero dependency vulnerabilities, successful source conversion, and zero Recommended findings;
raw evidence is retained at `/tmp/rhc-alerts-preflight-evidence-203406`.

## Actions audit-retention readiness

Actions now includes a package-owned settings singleton and a manually confirmed cleanup path that
preserves its no-direct-delete security model:

- retention is validated from 1 through 3,650 days, and the displayed 365-day recommendation cannot
  authorize deletion until saved;
- `RHC_Actions_Manage_Retention` is assigned only by the Admin Permission Set;
- no packaged role receives direct delete CRUD on Pending Action or Action History;
- each request deletes at most 1,000 combined rows, oldest completed History first and then old
  terminal Pending Actions in `SUCCEEDED`, `FAILED`, `SUPPRESSED`, or `REJECTED`;
- `PENDING_REVIEW`, `QUEUED`, `RUNNING`, and `RETRY_WAIT` are excluded; and
- cleanup is never scheduled and requires a fresh permanent-deletion acknowledgment.

Eleven Jest tests pass with 92.85% line coverage. The source/least-privilege validator, XML parser,
Metadata API conversion, dependency audit, root repository validator, diff check, and Recommended
Code Analyzer pass; the current package-source scan reports zero findings
(`/tmp/rhc-actions-recommended-20260921-0220.json`). Apex methods have complete contracts, all test
scenarios use explicit principals, and shared fixtures removed test duplication. Apex execution was
requested for all five test classes but stopped before submission because no default or target org
is configured. No package container, package version, namespace, deploy, or release artifact was
created.

## Well-Architected observable review

| Pillar | Verdict | Observable basis |
| --- | --- | --- |
| Trusted | Warning | No critical/high Recommended findings and no hard-coded HTTP endpoint, future method, or `SeeAllData=true` signal; org-side CRUD/FLS, OWD, and runtime-principal checks are not current. Several ReadWrite objects and one hierarchy setting require package-specific justification rather than a blanket pass. |
| Easy | Warning | No Workflow Rule, Process Builder, or Flow metadata was found, and tests/documentation are extensive. Existing moderate analyzer debt and one production `System.debug` path remain. |
| Adaptable | Warning | The suite is source-controlled, independently packaged by directory, and has meaningful tests. Static/local and org-backed CI paths now cover all nine projects, but the new org matrix lacks execution evidence because Dev Hub authorization is unavailable; several packages also still lack installable lifecycle evidence. |

### Manual review — not auto-graded; assess with the team

- [ ] Maintain a persona/integration security matrix, MFA and unique integration-user policy,
  capability-based permission assignments, session controls, credential ownership, and encryption
  requirements.
- [ ] Maintain the data dictionary, residency decisions, sensitivity owners, accessibility and
  assistive-technology evidence, translation requirements, and any applicable AI-governance record.
- [ ] Define risk, monitoring, scale/endurance, archiving, purging, skew, and allocation plans for
  each operational extension.
- [ ] Attach measurable value, accountable owners, maintained roadmaps, standard-versus-custom
  decisions, technical-debt dates, diagrams, and decision records to the suite.
- [ ] Define automation KPIs and fatal-versus-recoverable semantics; notify users before committing
  user-triggered changes where appropriate.
- [ ] Validate primary-persona journeys and guided experiences with users.
- [ ] Define SLOs, release cadence, environment and hot-fix paths, recovery drills, incident
  ownership, backup/restore tests, and business-continuity dependencies.
- [ ] Maintain functional-unit naming, state-management and rollback rules, versioned API/event
  contracts, dependency monitoring, and reproducible scratch-org builds.
