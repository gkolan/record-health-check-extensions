# RHC Alerts development and package validation

## Project contract

Run commands from `packages/rhc-alerts`. The project is a namespaced Salesforce DX project at API
`66.0`, package version `0.1.0.NEXT`, with one dependency:

```json
"dependencies": [{ "package": "Record Health Check@2.0.4-2" }]
```

Do not add another extension as a package dependency, source reference, test fixture, or runtime
fallback.

## Local setup

```bash
cd packages/rhc-alerts
npm ci --ignore-scripts
npm run generate
npm run generate:check
npm run format:check
npm run validate
npm run validate:core-contract
npm run validate:xml
npm test
```

Release maintainers can run the complete local-only set, including repository contracts, coverage,
dependency audit, source conversion, and a zero-finding Recommended scan, with:

```bash
npm run preflight:local
```

The aggregate preflight writes only to a unique operating-system temporary directory and removes it
on exit. It never authenticates to Salesforce and does not satisfy the separate Git, CI, org, or
package-candidate gates.

`generate_metadata.mjs` is the source for repetitive object, field, tab, application, permission-set,
notification-type, and class/trigger metadata. Update the generator and regenerate; do not make a
generated XML edit that the next `npm run generate` will erase.

`npm run generate:check` compares every generated artifact in memory without modifying files.
`npm run validate` enforces the pinned core/API/namespace contract, Viewer field allow list, policy
validation rules, fan-out cap, Finalizer recovery, inspected ledger updates, and atomic email send.
The locked install intentionally disables dependency lifecycle scripts; the current test and linter
toolchain passes without the optional `fsevents` install script.

## Source layout

| Path                                       | Contents                                                                                                   |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `force-app/main/default/classes`           | Administration, core metadata gateway, subscriber orchestration, delivery, recipient resolution, and tests |
| `force-app/main/default/triggers`          | Direct canonical Result and Set Run Platform Event subscribers                                             |
| `force-app/main/default/lwc`               | Administration and delivery-history Lightning Web Components plus Jest tests                               |
| `force-app/main/default/objects`           | Alert Policy and Alert Delivery metadata                                                                   |
| `force-app/main/default/permissionsets`    | Admin and read-only Viewer Runtime access                                                                  |
| `force-app/main/default/notificationtypes` | Packaged desktop/mobile Custom Notification type                                                           |
| `docs`                                     | Architecture, data model, operations, security, and validation references                                  |
| `demo/apex`                                | Sandbox-only idempotent seed, canonical event, negative-control, and cleanup scripts                       |

## Repeatable sandbox demo

The [sandbox demo and acceptance guide](../demo/README.md) is the release-team source of truth for
demo data and manual acceptance. It seeds recognizable records and policies, then exercises the
actual core Platform Event triggers rather than calling package services directly.

The safe initial run is:

```bash
sf apex run --file demo/apex/01_seed_recipient_groups.apex --target-org <sandbox-alias>
sf apex run --file demo/apex/02_seed_records_and_policies.apex --target-org <sandbox-alias>
sf apex run --file demo/apex/03_publish_success_and_duplicate.apex --target-org <sandbox-alias>
```

Email stays inactive until `06_activate_and_publish_email.apex` is explicitly run. Validate exact
expected rows and automated-only cases against the [complete test matrix](../demo/TEST_MATRIX.md).
Run `98_cleanup_demo_data.apex` before `99_cleanup_recipient_groups.apex` when resetting the org.

## Required tests

### LWC Jest

```bash
npm test -- --runInBand
```

The current suite covers initialization/coverage rendering and delivery-history rendering/error
behavior. Add Jest cases when UI labels, field behavior, loading, empty, or error states change.

### Apex

Deploy to a namespace-enabled scratch org containing promoted core source or install promoted core,
then run:

```bash
sf apex run test \
  --class-names RHCAlertsAdminControllerTest,RHCAlertsCoverageAnalyzerTest,RHCAlertsDeliveryFailureTest,RHCAlertsDeliveryServiceTest,RHCAlertsEventCandidateBuilderTest,RHCAlertsEventServiceTest,RHCAlertsNotificationSenderTest,RHCAlertsPolicyValidatorTest,RHCAlertsResultPolicyMatcherTest,RHCAlertsViewerControllerTest \
  --target-org <alias> --result-format human --code-coverage --wait 60
```

Acceptance coverage must include:

- exact namespaced identity preservation;
- repeated Event ID creates one successful claim plus duplicate evidence;
- Set Run contract gap is suppressed and never sent;
- policy and checked-record cooldown;
- inactive-policy suppression after claim;
- recipient User and direct public-group resolution;
- invalid or unavailable recipient failure classification;
- both event triggers;
- administration, setup assistant, limit information, and least-privilege history endpoints;
- bulk Queueable behavior and empty input;
- 2,000-claim fan-out truncation with one durable overflow row;
- Finalizer recovery of rows left pending by an unhandled Queueable failure; and
- generic-edit rejection by packaged policy validation rules.

## Metadata and source checks

```bash
env LC_ALL=C find force-app/main/default -type f -name '*.xml' -print0 \
  | xargs -0 -n1 xmllint --noout

rg -n "Run_Manager|RHC Reports|RHC Actions|RHC Integrations|RHC Builder|webhook|HttpRequest" \
  force-app/main/default --glob '!**/__tests__/**'
```

Review every production DML target. Only Alert Policy and Alert Delivery may be updated. User, Group,
and GroupMember are read-only recipient directories. Checked business records must never be queried
or updated by runtime services.

## Salesforce Code Analyzer

Run the Recommended selector and retain the timestamped JSON evidence:

```bash
sf code-analyzer run --rule-selector Recommended \
  --target force-app/main/default \
  --output-file ./code-analyzer-results-YYYYMMDD-HHMMSS.json
```

Parse results using the repository-approved Code Analyzer skill scripts. Release acceptance is zero
Recommended findings at every severity. Suppressions require narrow comments explaining platform-context access to
package-owned objects; do not use blanket suppressions to hide administrator CRUD/FLS problems.

The repository CI installs reviewed CLI/analyzer pins, enforces the zero-finding gate against only
`packages/rhc-alerts/force-app`, and retains the JSON result for 90 days. This gate is local and does
not authenticate to or mutate an org.

## Clean-org source validation

Use a namespace-enabled scratch org with core `2.0.4-2` and no other extension:

```bash
sf project deploy start --source-dir force-app --target-org <alias> \
  --test-level RunLocalTests --dry-run --wait 60 --json
```

After a successful check-only deployment, perform an actual sandbox/scratch deployment when testing
permission-set and user-mode behavior that depends on committed metadata.

## 2GP creation and independent installation

**Hard stop:** do not create a package version until the exact commit has passed every local/CI gate,
current-source namespaced and non-namespaced org tests, coverage, permission checks, and clean-org
source validation. Package creation is evidence collection after those prerequisites, never a way to
discover whether unfinished source is viable.

The machine-enforced source of truth is the [release gate ledger](RELEASE-GATES.md). Before even
considering the command below, `npm run verify:prepackage` must exit successfully against the exact,
clean release commit. A successful verifier run does not itself authorize package creation.

The package container already exists:

```text
RHC Alerts = 0Hoak0000005LtRCAU
```

Create a beta version:

```bash
sf package version create --package "RHC Alerts" \
  --installation-key-bypass --code-coverage --wait 120 \
  --target-dev-hub rhc-dev-hub
```

Then install it into a clean subscriber org that contains only promoted core:

```bash
sf package install --package <RHC_ALERTS_04T> \
  --target-org <clean-subscriber-alias> --security-type AdminsOnly \
  --wait 30 --publish-wait 10 --no-prompt
```

Post-install acceptance:

1. `sf package installed list` shows core and Alerts, with no other extension required.
2. Assign `RHC Alerts Admin` and confirm the RHC Alerts app is visible.
3. Assign `RHC Alerts Viewer Runtime` to a separate user and confirm read-only history visibility.
4. Create one Custom Notification policy and one Email policy in a sandbox.
5. Publish a matching Result event and confirm terminal ledger outcomes.
6. Redeliver the same Event ID and confirm no second successful message.
7. Publish a later event for the same policy and record inside cooldown and confirm `SUPPRESSED`.
8. Confirm exact namespace mismatch produces no claim.
9. Confirm publication `NONE` produces no Alerts row.
10. Uninstall Alerts and verify core behavior is unchanged.

Run the complete demo kit between steps 4 and 9. It detects source versus installed namespace and
therefore also validates exact Qualified API Name behavior in a subscriber org.

## Latest verification evidence

Local-only remediation verification on August 30, 2026 (no org authentication or mutation):

- `npm run preflight:local` passed as an aggregate gate. It ran the repository validator, generated
  metadata drift check, exact-pinned formatting check, package and minimum-core contracts, XML,
  LWC coverage, SLDS, live dependency audit, temporary Metadata API conversion, and a zero-finding
  Recommended scan. Its temporary directory was removed on exit.
- `npm run test:prepackage-lock` passed. It proves missing evidence, missing option values, and a
  counterfeit all-`PASSED` ledger cannot bypass the exact-commit lock.
- `npm run generate:check` and `npm run validate` passed. The latter enforces the package/dependency
  contract, history-only Viewer surface and field allow list, policy validation rules, 2,000-claim
  cap, durable dispatch/Finalizer outcomes, deleted-policy disposition, inspected ledger updates,
  and atomic email submission.
- All generated/source XML passed `xmllint`, and `sf project convert source` successfully converted
  the full `force-app` tree to Metadata API format in `/tmp` without contacting an org.
- The pinned minimum-core contract validator passed against core commit `74fe1d6`, API 66.0,
  `Record Health Check@2.0.4-2`, and subscriber version `04tak000000cZBFAA2`. It verifies both event
  schemas and the Custom Metadata fields read by the setup assistant.
- LWC Jest: 2 suites and 11 tests passed. Enforced global coverage is 95.09% statements, 80.64%
  branches, 93.93% functions, and 96.59% lines against thresholds of 90/80/90/90.
- The official SLDS linter and supplementary quality analyzer reported zero findings across both
  components (automated grade A, 100/100). Manual loading, error, empty, disabled, semantic, and
  blueprint review passed after async actions were disabled during work and explicit clean states
  were added.
- Code Analyzer Recommended evidence: `code-analyzer-results-20260830-060451.json`, zero findings at
  every severity against the complete package `force-app` tree.
- `npm audit --audit-level=high` returned zero vulnerabilities in the final local verification.
- The 40 Apex test methods and four test setup methods parse successfully and now cover focused
  policy matching, candidate construction, failure classification, safe message formatting,
  bounded fan-out, durable claim and queue
  failures, Finalizer recovery, deleted-policy disposition, direct policy validation, generic-edit
  validation, unsupported contract isolation, and the Viewer user-mode projection. They have not been executed in this
  remediation pass because doing so requires an org, which remains outside the current authorization.

Current-source environment evidence is intentionally explicit:

| Gate                                             | Current source status | Why                                                                                     |
| ------------------------------------------------ | --------------------- | --------------------------------------------------------------------------------------- |
| Local namespaced source/static gates             | Verified              | All commands above passed locally without org access                                    |
| Non-namespaced org compile and Apex execution    | **Not verified**      | The older `rhc-summary-nons-20260820` demo predates the changed source                  |
| Namespace-enabled org dry-run and Apex execution | **Not verified**      | August 25 deployment/tests predate the changed source                                   |
| Namespaced subscriber install/upgrade/uninstall  | **Not verified**      | No Alerts `04t` exists and package creation remains prohibited until prerequisites pass |

Neither prior org evidence nor successful local conversion is a substitute for compiling and running
the current source in both org shapes. No package or package version was created during this pass.

The following older org-backed evidence predates the remediation and must not be treated as proof
for the changed source until the required org gates are rerun:

Verified August 25, 2026:

- Clean namespace-enabled source deployment: job `0AfOv00000hXG8VKAW`, 56/56 components, zero
  component errors.
- Focused Apex run `707Ov00006Zdavt`: 20/20 tests passed, including transient retry exhaustion;
  both Platform Event triggers at 100%, event/idempotency service at 98%, and delivery service at
  77%.
- LWC Jest: 2 suites and 4 tests passed.
- Code Analyzer Recommended evidence: `code-analyzer-results-20260825-180539.json`, 198 findings,
  zero severity 1 and zero severity 2 findings. The scan includes package source and demo scripts.
- Live demo validation in `rhc-summary-nons-20260820`: scripts 01 through 05 and 07 compiled and
  executed; success, configuration failure, duplicate, cooldown, exact-match negative controls, and
  Set Run contract-gap outcomes matched `demo/README.md`. Email script 06 remained intentionally
  inactive because it requires explicit approval for a real email attempt.
- Demo-driven ledger correction deployment: job `0AfOv00000hXSETKA4`; optional Suppression Reason
  and Failure Class fields now have no misleading defaults, and runtime transitions explicitly clear
  irrelevant classification fields.
- Corrected Admin and Viewer permission metadata deployment: job `0AfOv00000hX3rDKAS`, 2/2
  components, zero errors; Viewer effective permissions verified read/View All true and all mutation
  privileges false on both package objects.
- Package container registered as `0Hoak0000005LtRCAU`.

The Dev Hub returned `REQUEST_LIMIT_EXCEEDED` after the daily version-create allowance was exhausted.
No installable `04t` version exists yet, so final independent subscriber installation remains pending.
After the allowance resets, rerun version creation and all post-install acceptance steps without
changing source.

## Release gate

Do not promote a package version unless all of these are true:

- core dependency is the documented minimum promoted version;
- Apex and Jest tests pass;
- package aggregate Apex coverage is at least 75% and both triggers meet platform coverage rules;
- Code Analyzer has zero Recommended findings at every severity;
- exact matching, duplicate, cooldown, privacy, permissions, and bulk tests pass;
- source validation and actual clean-org permission behavior pass;
- the exact commit is tracked, clean, and has passing required CI checks;
- a 2GP version installs with core and no other extension; and
- administrator and operations documentation matches the shipped UI and error vocabulary.
