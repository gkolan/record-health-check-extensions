# Repository and development guide

## Repository location

RHC Run Manager is intentionally isolated under:

```text
packages/rhc-run-manager/
```

Do not place feature code in the Observability prototype or Record Health Check core. A core change
requires a separately documented public-API need and review of the core repository's `AGENTS.md`.

## Directory layout

```text
rhc-run-manager/
├── force-app/main/default/
│   ├── applications/       Lightning application
│   ├── classes/            Apex runtime and tests
│   ├── lwc/rhcRunManager/  Administration/monitoring UI and Jest tests
│   ├── objects/            Six owned operational/configuration objects
│   ├── permissionsets/     Admin, Viewer, Executor personas
│   └── tabs/               App and operational object tabs
├── docs/                   Audience-focused documentation
├── scripts/demo/           Idempotent demo loader and scoped cleanup
├── ADMIN_GUIDE.md          Junior-admin product walkthrough
├── GAP_ANALYSIS.md         Core/prototype/API analysis
├── RELEASE_EVIDENCE.md     Current release verification ledger
├── SPEC.md                 Authoritative product specification
├── code-analyzer.yml       Analyzer policy and documented exceptions
├── jest.config.js          LWC Jest configuration
├── package.json            Local JavaScript tooling
└── sfdx-project.json       2GP identity, version, namespace, dependency
```

## Dependency rule

`sfdx-project.json` must declare exactly one package dependency:

```json
"dependencies": [{ "package": "Record Health Check@2.0.4-2" }]
```

Do not add Builder, Alerts, Reports, Actions, Integrations, the Observability prototype, or an
unpackaged Apex dependency.

## Prerequisites

- Salesforce CLI v2 with authenticated Dev Hub
- Salesforce Code Analyzer plugin
- Node.js compatible with the committed lockfile
- npm
- a namespace-enabled development scratch org with core `2.0.4-2` installed

From this directory, install JavaScript dependencies:

```bash
npm install
```

## Important implementation rules

- Use canonical core types and terminology.
- Keep `SelectionType__c` explicit: `CHECK_SET` or `CHECK`.
- Derive target objects through `RHCRunManagerCoreMetadataGateway`.
- Keep all entry points on `RHCRunManagerExecutionService.start`.
- Keep record population and operational DML in user mode.
- Never accept raw SOQL, CRON, Batch class names, event modes, or target objects from administrators.
- Treat `SKIPPED` as summary-only.
- Preserve independent per-scope Run envelopes and partial-failure monitoring.
- Publish through core request settings; do not create extension-specific evaluation events.

## Local verification

### Jest

```bash
npm test -- --runInBand
```

The suite covers initial data loading, guided-filter construction, supplied-ID guidance, Run Now,
schedule pause, and monitoring drilldown.

### Dependency audit

```bash
npm audit --json
```

Release expectation: zero known vulnerabilities.

### Metadata XML

```bash
rg --files force-app | rg '\.xml$' | xargs xmllint --noout
```

### SLDS

```bash
npx @salesforce-ux/slds-linter@latest lint force-app/main/default/lwc/rhcRunManager
```

### Salesforce Code Analyzer

```bash
sf code-analyzer run \
  --rule-selector Recommended \
  --target force-app/main/default \
  --output-file code-analyzer-results.json
```

Review `code-analyzer.yml` before changing exclusions. Exceptions must explain a product or platform
constraint; they are not a substitute for fixing a violation.

## Scratch deployment and Apex tests

The target org must already contain Record Health Check core `2.0.4-2`. Assign the core and Run
Manager admin permission sets to the development user.

Deploy and run the package tests:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org rhc-run-manager-day1 \
  --test-level RunSpecifiedTests \
  --tests RHCRunManagerAdminControllerTest \
  --tests RHCRunManagerAsyncTest \
  --tests RHCRunManagerCaptureServiceTest \
  --tests RHCRunManagerCoreMetadataGatewayTest \
  --tests RHCRunManagerExecutionTest \
  --tests RHCRunManagerFilterServiceTest \
  --tests RHCRunManagerSubmitIdsActionTest \
  --tests RHCRunManagerUninstallHandlerTest \
  --wait 30 \
  --json
```

The test factory creates dedicated users, assigns the Admin, Viewer, or Executor permission set,
and executes security-sensitive test bodies inside `System.runAs`. Minimum-access Viewer and
Executor tests prove cross-owner reads and denied writes rather than inheriting the upload user's
profile access.

## Test coverage expectations

Do not rely only on org-wide coverage when core is installed. Inspect Run Manager production classes
individually. Each class must meet Salesforce's 75% threshold, and tests must prove behavior rather
than merely execute lines.

High-risk required cases include:

- 251 Flow inputs;
- duplicate current/prior IDs;
- separate supplied-ID requests converging on one coalescer/Batch;
- invalid object/filter injection;
- Check and Check Set resolution;
- schedule date windows and owned CronTrigger checks;
- earlier scope persistence after a later scope exception;
- capture group exactness and Result idempotency;
- Viewer/Executor cross-owner access with denied configuration/monitoring writes;
- atomic launch/staging/capture failure behavior and bounded coalescer pages;
- uninstall cleanup that leaves customer-owned jobs untouched.

## Creating a beta

Confirm the manifest and aliases first:

```bash
sf package version create \
  --package "RHC Run Manager" \
  --target-dev-hub rhc-dev-hub \
  --code-coverage \
  --installation-key-bypass \
  --wait 10 \
  --json
```

Record the request ID (`08c`), package version ID (`05i`), subscriber version ID (`04t`), version
number, and package-calculated coverage in `RELEASE_EVIDENCE.md`. Do not promote a Day 1 beta.

The shared Dev Hub has a daily Package2 request limit. Before retrying a rejected request, inspect
recent requests and avoid submitting duplicates.

## Clean subscriber verification

Create the subscriber scratch org with `--no-namespace`. Install only core and the exact Run Manager
beta. Verify the installed-package list contains no other extension. Follow
[Installation](INSTALLATION.md) and [Operations](OPERATIONS.md) for functional validation.

## Definition of done

A source deployment is not a release. Completion requires direct evidence for:

- Apex and per-class coverage;
- Jest;
- SLDS;
- Code Analyzer;
- valid XML and dependency audit;
- successful 2GP beta creation;
- clean namespace-free install;
- permission assignment;
- Flow action discovery;
- supplied-ID consolidation;
- Run Manager monitoring drilldown.
