# Development, testing, and 2GP release

## Repository and package layout

```text
packages/rhc-integrations/
├── config/project-scratch-def.json
├── docs/                         implementation and operating contract
├── force-app/main/default/
│   ├── applications/             RHC Integrations Lightning app
│   ├── classes/                  routing, payload, Queueable, replay, tests/mocks
│   ├── customPermissions/        replay gate
│   ├── lwc/                      dead-letter UI and Jest tests
│   ├── objects/                  route and delivery ledger
│   ├── permissionsets/           Admin, Operator, Runtime, Viewer
│   ├── tabs/                     route and dead-letter tabs
│   └── triggers/                 direct core Run/Result/Log subscribers
├── package.json
├── scripts/demo/                  repeatable subscriber-org demo seed, publishers, cleanup
├── sfdx-project.json
└── SPEC.md
```

Run commands from `packages/rhc-integrations` unless stated otherwise.

The local source gates include an executable compatibility check against the immutable minimum-core
revision used by CI:

```sh
npm run validate
npm run validate:core-contract -- --core-root /path/to/record-health-check
npm run validate:xml
```

The core-contract gate verifies namespace/API parity, the sole pinned package dependency, all three
consumed Platform Event field contracts, their distinct publish behaviors, and exclusion of the
restricted Log detail fields from extension Apex.

## Dependency and version policy

- Namespace: `rhc`
- Source API: 66.0
- Package version: `0.1.0.NEXT`
- Only package dependency: `Record Health Check@2.0.4-2`
- Immutable core 04t: `04tak000000cZBFAA2`
- Extension container: `0Hoak0000005Lv3CAE`

Day 1 means no aliases, migrations, compatibility shims, deprecated APIs, or fallback secrets.
Never add a dependency on Run Manager, Reports, Alerts, Actions, or any future extension.

## Local LWC tests

```sh
npm install
npm run test:unit
npm run test:unit:coverage
npm audit --audit-level=high
```

Current suite expectations: two suites and eight tests covering render, replay/refresh, structured
and unstructured load errors, manual refresh, rejected replay, unknown actions, and suppression of
the Replay action when the custom permission is absent. The enforced coverage floor is 100% for
statements, functions, and lines and 90% for branches; the August 30 local result was 100% in all
four categories.

## Apex validation

Validate against an org containing only promoted core plus this source:

```sh
sf project deploy start \
  --dry-run \
  --source-dir force-app \
  --target-org <CORE_ONLY_ORG_ALIAS> \
  --wait 30 \
  --test-level RunSpecifiedTests \
  --tests RHCIntegrationPayloadBuilderTest \
  --tests RHCIntegrationEventHandlerTest \
  --tests RHCIntegrationDeliveryQueueableTest \
  --tests RHCIntegrationDeadLetterControllerTest \
  --tests RHCIntegrationSubscriberTest
```

The current source test contract contains 21 Apex test methods covering exact matching, 251-event
bulk handling, the 50-event subscriber checkpoint boundary, bounded fan-out rejection, transient
versus permanent ingestion classification, non-duplicate ingestion failure, duplicate Event ID,
publication NONE/no event, direct three-event subscription, allow-listed payloads, incompatible
profiles, 202 success, 503 retry, 400 dead-letter, retry exhaustion, allowed replay, and denied
replay, stale-state and inactive-route replay rejection, Finalizer dead-letter recovery, and
authority-style endpoint rejection. The previous baseline dry-run completed 57/57 components and
13/13 Apex tests with 92.03% aggregate coverage under job `0AfRK00000szolb0AA`; that job predates
the hardening tests and is not evidence for the current source. The current no-namespace shared-org
check-only deployment is job `0AfRL00000hD8wg0AC`: 61/61 components and 21/21 test methods passed.
The persisted deployment is `0AfRL00000hCpXT0A0`; focused run `707RL00001eHCnq` passed with 89%
test-run coverage, and shared-org `RunLocalTests` run `707RL00001eHCzP` completed 907 test/setup
executions with zero failures and 95% test-run coverage. These results replace the obsolete source
baseline but do not replace the clean subscriber `04t` acceptance gate.

The subscriber demo helpers are namespaced anonymous Apex and require both managed packages to be
installed. They are not compile-validated by the local analyzer. Execute every scenario in the
[demo guide](DEMO-TESTING.md) in the clean install-check org before promotion; an `04t` must not be
promoted based only on the production unit-test dry-run.

## Salesforce Code Analyzer v5

Use the current `code-analyzer` topic; v4 `scanner` commands are retired.

```sh
sf code-analyzer run \
  --workspace force-app \
  --rule-selector Recommended \
  --output-file code-analyzer-results.json

sf code-analyzer run \
  --workspace force-app \
  --rule-selector 'all:Security:1' \
  --rule-selector 'all:Security:2' \
  --output-file code-analyzer-security-results.json
```

Preserve results as CI/release evidence. The final August 30 isolated CLI 2.149.9 / Code Analyzer
5.15.0 Recommended scan artifact `code-analyzer-results-20260830-071600-v515.json` reported zero
severity-1, severity-2, and severity-3
findings and 100 low findings. That run executed PMD, ESLint, CPD, RetireJS, and Regex; SFGE was
eligible but did not execute. A dedicated security scan artifact,
`code-analyzer-security-results-20260830-071300-v515.json` with captured log
`code-analyzer-security-20260830-071300-v515.log`, reported no violations but analyzed only 27
of 28 entry points because SFGE raised an internal execution error on
`RHCIntegrationDeadLetterController.replay`. Isolated scans proved that the controller's one-query
user-mode lock analyzes at 28/28 and that adding replay DML triggers the defect. Code Analyzer 5.15.0
reproduces the same failure observed in 5.14.0.
No analyzer suppression is committed. Salesforce documents an internal execution error as an
incomplete entry-point analysis, so this is **not** a security pass. The strict analyzer-log gate
rejects engine errors and independently requires analyzed entry-point counts to equal identified
entry-point counts. The source remains blocked from promotion until a complete SFGE run is captured.
CI pins the CLI-supported Code Analyzer 5.15.0. The CI workflow blocks severity
1–3 findings, rejects incomplete SFGE output, and uploads 90-day artifacts named with the commit
SHA. It also emits a JSON evidence manifest that fails closed unless Git `HEAD` matches the CI SHA,
the Integrations package and workflow are clean, and every analyzer artifact exists; the manifest
records SHA-256 digests, package/dependency metadata, the pinned core ref, and workflow-run identity.
Re-run after Apex, LWC, permission, or security-relevant metadata changes and record the result
in [release evidence](RELEASE-EVIDENCE.md).

## Create and promote a 2GP version

1. Confirm the Dev Hub and namespace owner.
2. Confirm the core dependency alias resolves to the promoted immutable 04t.
3. Run Jest, analyzer, XML validation, and core-only dry-run.
4. Create the package version without `--skip-validation`:

```sh
sf package version create \
  --package "RHC Integrations" \
  --installation-key-bypass \
  --code-coverage \
  --wait 120 \
  --target-dev-hub rhc-dev-hub
```

5. Inspect the version report and its dependency list.
6. Install the beta 04t in a new scratch org containing promoted core and no other RHC extension:

```sh
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias rhc-integrations-install-check \
  --duration-days 1 \
  --target-dev-hub rhc-dev-hub \
  --wait 30

sf package install \
  --package 04tak000000cZBFAA2 \
  --target-org rhc-integrations-install-check \
  --wait 30 \
  --publish-wait 30 \
  --no-prompt

sf package install \
  --package <RHC_INTEGRATIONS_04T> \
  --target-org rhc-integrations-install-check \
  --wait 30 \
  --publish-wait 30 \
  --no-prompt

sf package installed list --target-org rhc-integrations-install-check
```
7. Run the complete Apex and administrator acceptance suite.
   Seed and execute the [complete demo-data and functional test guide](DEMO-TESTING.md), record each
   scenario in the [implementation worksheet](ADMIN-IMPLEMENTATION-WORKSHEET.md), and run cleanup.
8. Promote only after those gates pass:

```sh
sf package version promote --package <RHC_INTEGRATIONS_04T> --target-dev-hub rhc-dev-hub --no-prompt
```

9. Update every release-status reference with the promoted 04t and installation URL.

Do not delete the verification org until its installed-package list, Apex results, subscriber names,
and admin acceptance evidence have been captured. Delete it afterward according to Dev Hub policy.

## Independent-install acceptance gate

The release fails if any of these are false:

- Clean org installs core, then Integrations, with no other extension.
- Dependency report lists core only.
- All three packaged subscribers are present.
- Subscriber user configuration can reference the namespaced triggers.
- Named Credential and External Credential remain subscriber-created.
- Example route produces the documented payload and headers.
- Duplicate Event ID produces one logical route delivery.
- 503 retries and 400 dead-letters.
- Admin can replay; Operator/Viewer cannot.
- Uninstalling Integrations does not affect core execution.

## Official developer references

- [Create a package version](https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_package_version_create.html)
- [Code Analyzer v5 migration](https://developer.salesforce.com/docs/platform/salesforce-code-analyzer/guide/migrate.html)
- [Code Analyzer CI/CD integration](https://developer.salesforce.com/docs/platform/salesforce-code-analyzer/guide/ci-cd.html)
- [Work with Salesforce Graph Engine](https://developer.salesforce.com/docs/platform/salesforce-code-analyzer/guide/engine-sfge-work-with.html)
- [Run Jest tests for LWC](https://developer.salesforce.com/docs/platform/lwc/guide/unit-testing-using-jest-run-tests)
