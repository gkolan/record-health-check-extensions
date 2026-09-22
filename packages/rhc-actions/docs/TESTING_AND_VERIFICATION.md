# RHC Actions testing and verification

## Verification layers

No single test proves the package boundary. Complete all applicable layers before creating a 2GP
version.

| Layer                 | Proves                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------- |
| XML validation        | Metadata files are well-formed                                                                    |
| Metadata conversion   | Source can be converted to Metadata API format                                                    |
| Source deployment     | Salesforce compiles every component against promoted core                                         |
| Apex tests            | Authorization, bulk behavior, event capture, Flow contract, retries, cooldown, audit, and bounded retention behavior |
| Jest tests            | Review UI loading, approval, rejection, retention confirmation, and safe failure behavior                   |
| Code Analyzer         | Recommended static rules have no unreviewed critical/high findings                                |
| Source policy gates   | Permissions, execution authorization, event resilience, dependency, and core-contract invariants |
| 2GP version creation  | Dependency and package metadata resolve in the Dev Hub                                            |
| Clean-org install     | Only core plus Actions is sufficient                                                              |
| Admin acceptance test | A real matching event produces exactly one approved Flow result                                   |
| Demo scenario kit     | Installed-package behavior is visible with marked, reproducible sandbox data                      |

## Local metadata checks

From `packages/rhc-actions`:

```sh
npm run validate
npm run validate:core-contract -- --core-root /path/to/record-health-check
npm run validate:xml
SF_DISABLE_LOG_FILE=true sf project convert source \
  --source-dir force-app \
  --output-dir /tmp/rhc-actions-mdapi
```

Expected result: XML emits no error and source conversion reports success.

## LWC Jest

```sh
npm ci
npm test
```

The suite must cover:

- queue load and row rendering;
- Maya's validate-and-queue path;
- fail-closed invalid contract behavior; and
- rejection without Flow execution.
- retention controls hidden without capability, settings validation, explicit confirmation, and
  surfaced save/purge failures.

Run coverage when changing the component:

```sh
npm run test:coverage
```

## Apex tests

Deploy source to an org that already contains promoted core and assign `RHC_Actions_Admin` to the
test/deployment user when user-mode field access is required.

```sh
SF_DISABLE_LOG_FILE=true sf project deploy start \
  --source-dir force-app \
  --target-org <actions-test-org> \
  --wait 30

SF_DISABLE_LOG_FILE=true sf apex run test \
  --class-names RHCActionPolicyServiceTest,RHCActionCaptureServiceTest,RHCActionExecutionServiceTest,RHCActionReviewControllerTest,RHCActionRetentionServiceTest \
  --target-org <actions-test-org> \
  --result-format human \
  --code-coverage \
  --wait 30
```

Minimum behavioral coverage:

- direct Platform Event trigger delivery;
- duplicate Event ID for one policy;
- at least 251 Result events in one capture call;
- unsupported core contract ignored;
- active autolaunched Flow accepted;
- inactive, wrong type, arbitrary input, wrong variable type, and missing output rejected;
- approval permission denied and granted;
- approval permission revoked after queueing;
- automatic permission revoked after queueing;
- policy deactivated or automatic opt-in removed after queueing;
- duplicate manual approval denied under state control;
- Flow starts once with only selected inputs;
- success stores interview GUID and audit user;
- policy-specific cooldown suppression when policies have different windows;
- retry waits and stops at the configured limit; and
- transient capture classification, checkpoint behavior, and finalizer recovery;
- missing Flow interview output fails closed; and
- empty Queueable input is harmless.
- retention rejects missing permission, invalid/unsaved settings, and deletes only old completed
  evidence; nonterminal and recent records survive; one request is capped at 1,000 rows.

The Apex test suite creates its records with `RHCActionTestDataFactory`. That factory is test-only
and is deliberately unavailable to administrators. For reusable subscriber-org demonstration data,
use the separate sandbox kit below.

## Reproducible sandbox demo data

The [demo kit](../scripts/demo/README.md) creates one synthetic Account and one isolated policy,
then publishes deterministic events for manual success, rejection, duplicate delivery,
nonmatching status, unsupported contract, cooldown, Flow validation, retry exhaustion, optional
automatic execution, and a 251-event bulk exercise.

Use the [junior-admin click guide](admin/DEMO_DATA_AND_FULL_TEST.md) as the source of truth. It
includes expected UI state, evidence collection, stop conditions, a read-only verification script,
cleanup preview, and exact-scope cleanup. Synthetic event tests isolate RHC Actions; the release
gate still requires one real core evaluation with publication enabled.

Package-only Apex coverage must meet Salesforce's package-version requirement. Do not quote org-wide
coverage as package coverage.

## Salesforce Code Analyzer

Preserve timestamped evidence:

```sh
SF_DISABLE_LOG_FILE=true sf code-analyzer run \
  --rule-selector Recommended \
  --workspace force-app \
  --output-file "./code-analyzer-results-YYYYMMDD-HHMMSS.json" \
  --view detail
```

Critical and high findings require resolution or explicit approved disposition. Do not silently
apply engine-proposed fixes. Re-run tests and analysis after any change.

## Independent-install test

Use a fresh subscriber-style scratch org:

1. Create the scratch org without another RHC extension.
2. Install promoted core `04tak000000cZBFAA2`.
3. Install the new RHC Actions `04t` with its securely supplied installation key.
4. Assign Admin, Approver, Runtime, and Viewer to separate test users as appropriate.
5. Complete the [manual acceptance test](admin/TEST_MANUAL_APPROVAL.md).
6. Query installed package dependencies and confirm no other extension is present or required.
7. Uninstall Actions and confirm core remains operational.

The current package container is `0Hoak0000005M6LCAU`. A package container is not an installable
version; a successful version build must return a subscriber package version ID beginning `04t`.

## Last completed implementation evidence

On August 25, 2026:

- 25 of 25 Apex tests passed;
- package-only Apex coverage was 80.7%;
- 4 of 4 Jest tests passed;
- source deployment and LWC compilation succeeded;
- XML validation and Metadata API conversion succeeded; and
- Salesforce Code Analyzer reported zero critical and zero high findings.

A later Recommended rerun preserved at
`code-analyzer-results-20260825-180500.json` also reported zero critical and zero high findings; it
reported 115 moderate, 40 low, and 1 informational finding in existing package code/tests. The
Analyzer did not recognize the sandbox operator `.apex` files as scannable source. Execute the
read-only demo preflight and the controlled subscriber-org scenarios before release; do not claim
those scripts were PMD-scanned.

The Dev Hub created container `0Hoak0000005M6LCAU`, but its daily package-version quota prevented
creation of the first installable `04t`. Repeat packaging and the clean-org install after the quota
resets; do not describe the container alone as an installable release.

## August 30 source-only evidence

On August 30, 2026, after the authorization, permission, event-resilience, and recovery changes:

- source policy/permission validation, XML parsing, core-contract validation against saved core
  `2.0.4.2`, and Metadata API conversion passed locally;
- 4 of 4 Jest tests passed with 86.27% statement and 88.63% line coverage;
- `npm audit --audit-level=high` reported zero vulnerabilities;
- Recommended Code Analyzer reported 0 critical, 0 high, 0 moderate, 37 low, and 2 informational
  findings in `code-analyzer-results-20260830-063000.json`; the low findings are primarily ApexDoc
  and the analyzer's test-method `runAs` recommendation; and
- repository documentation/link validation passed after the documentation updates (8 packages,
  135 Markdown files, and 388 local links).

## Non-namespaced scratch-org evidence

On August 30, 2026, source was installed into the non-namespaced Developer scratch org
`rhc-change-monitor-nons-shared-20260830` after a local-only preflight:

- org namespace was null, no package versions were installed, and the source-deployed core
  `Record_Health_Check_Result__e` contract was present;
- all 86 Actions components compiled and deployed successfully without creating a package version;
- 44 of 44 Actions Apex tests passed (`707RL00001eHNX9`);
- aggregate Actions production coverage was 86.37% (659 of 763 lines), and org-wide coverage was
  95%;
- the previously weak infrastructure classes now have 100% coverage for `RHCActionAsyncGateway`,
  91.23% for `RHCActionExecutionFinalizer`, 87.23% for `RHCActionFlowGateway`, and 86.11% for
  `RHCActionResultSubscriberHandler`; and
- the installation exposed and corrected an Apex enum-shadowing compile defect, an invalid
  Modify-All-without-Delete permission combination, and test permission-context isolation.

On a clean org, validate component compilation with `NoTestRun`, persist the schema, and then run
the Actions tests. Dynamic USER_MODE SOQL cannot see newly introduced fields inside the same
check-only transaction before those fields are persisted.

The Change Monitor CDC test contamination was corrected by draining setup events before each
scenario policy is created and by aligning stale assertions with the bounded
`CHANGED_FIELDS_NOT_MATCHED` reason contract. The focused Change Monitor deployment passed 6 of 6
tests (`0AfRL00000hD9Kw0AK`). The org-wide `RunLocalTests` regression produced 959 passing
Apex results and zero non-passing results (`707RL00001eHG23YAG`).

A targeted Recommended Code Analyzer rerun over all updated Apex files reported zero critical,
high, or moderate findings; 21 low test-method `runAs` recommendations and one informational
copy/paste finding remain.

Real subscriber identity configuration, production Flow execution, package creation, clean package
install, upgrade, and uninstall remain release gates.

## Current retention-change evidence

On September 20, 2026, for the current source diff:

- 11 of 11 Jest tests passed;
- Jest coverage is 91.58% statements, 70.83% branches, 92.30% functions, and 92.85% lines;
- source/least-privilege validation, XML parsing, Metadata API conversion, dependency audit, root
  documentation/link validation, and diff whitespace validation passed;
- the validator proves Admin alone receives Manage Retention, Admin still lacks direct delete CRUD
  on Pending Action and Action History, and the service retains its terminal-state/system-mode cap;
- Apex tests were added for settings authorization, eligibility, preservation, and the 1,000-row
  limit; and
- the current package-source Recommended scan reports zero findings
  (`/tmp/rhc-actions-recommended-20260921-0220.json`); all test scenarios use explicit principals,
  public and virtual methods have complete contracts, and duplicated Flow/test assertions use
  shared fixtures; and
- an Apex run covering all five test classes stopped before submission because no default or target
  org is configured, so current Salesforce compilation and execution remain unverified. No package
  container, package version, namespace, deploy, or release artifact was created by this change.
