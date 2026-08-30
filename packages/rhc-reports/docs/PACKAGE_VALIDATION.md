# Package validation

## Required environment

- promoted Record Health Check 2.0.4.2 installed;
- Salesforce API 66.0 or newer;
- no other extension package required.

## Source validation

From `packages/rhc-reports`:

```bash
npm ci
npm run validate
npm run validate:core-contract -- --core-root /path/to/record-health-check
npm run validate:xml
npm run test:coverage
npm audit --audit-level=high
sf project convert source --source-dir force-app --output-dir <temporary-output-directory>
```

Pull requests also run `.github/workflows/rhc-reports-salesforce-validate.yml` when the repository
Dev Hub secret is available. That gate creates a disposable one-day scratch org, installs the
pinned promoted core dependency, validates and deploys source, runs all local Apex tests with
coverage, and deletes the scratch org in an `always()` cleanup step. It never creates a package
container or package version.

```bash
sf project deploy start --dry-run --source-dir force-app \
  --target-org <namespaced-scratch-alias> \
  --test-level RunLocalTests --wait 60 --json
```

Run focused tests after deployment or package installation:

```bash
sf apex run test \
  --class-names RHCReportsIngestionServiceTest,RHCReportsAggregationServiceTest,RHCReportsRetentionBatchTest \
  --target-org <alias> --result-format human --code-coverage --wait 60
```

## 2GP creation and independent install

```bash
sf package create --name "RHC Reports" --package-type Unlocked \
  --path force-app --target-dev-hub rhc-dev-hub

sf package version create --package "RHC Reports" \
  --target-dev-hub rhc-dev-hub --installation-key-bypass \
  --code-coverage --wait 120

sf package install --package <RHC_REPORTS_04T> \
  --target-org <clean-subscriber-with-core-2.0.4.2> \
  --security-type AdminsOnly --wait 30 --publish-wait 10 --no-prompt
```

Confirm `sf package installed list` shows only Record Health Check as the dependency and then RHC
Reports. Assign `RHC_Reports_Admin`, save 90-day settings, publish duplicate test Event IDs, and
verify only one fact per Event ID. Recompute the same date twice and verify snapshot row counts and
values do not change. Then complete the sandbox-only
[demo data and functional acceptance test](DEMO_TEST_DATA.md) and retain its acceptance record.

## Metadata acceptance

- all XML is well formed and deploys at API 66.0;
- all LWC Jest tests pass and satisfy the package coverage thresholds;
- custom report types, all six reports, both folders, and Data Quality Trend deploy together;
- Admin and Viewer have read access only to intentionally minimal analytical fields;
- package tests pass with at least 75% package Apex coverage;
- Salesforce Code Analyzer Recommended has no unresolved severity 1 or 2 findings;
- installation succeeds in a subscriber org containing core 2.0.4.2 and no extension package.

## Latest verification record

On 2026-08-30, the remediated source passed the package source-contract validator, XML parsing,
the pinned core 2.0.4.2 event-contract validator, Salesforce source conversion, dependency audit,
both LWC Jest suites (5 tests), and the configured coverage gates (89.47% lines, 93.33% functions,
53.33% branches). Repository validation also passed across all 8 packages, 134 Markdown files, and
383 local links. A fresh Recommended Code Analyzer scan reported zero severity 1 or 2 findings.
The non-namespaced source was then deployed successfully to scratch org
`rhc-change-monitor-nons-shared-20260830` in deployment `0AfRL00000hCwdq0AC`: 100 of 100
components deployed, 695 of 695 local tests passed, and there were no component or test errors.
A focused post-deploy run passed all 25 Reports tests with 93% org-wide coverage; both Platform
Event triggers reported 100% coverage and the ingestion service reported 98%. All six reports and
the Data Quality Trend dashboard were queryable in the RHC Reports folder. Packaged
install/upgrade/uninstall acceptance remains pending because this verification deliberately used
non-namespaced source deployment rather than creating or installing a package version.

Previous evidence:

On 2026-08-25, isolated source validation job `0AfVA00000Kyk9J0AR` succeeded in a namespaced
scratch org containing promoted core 2.0.4.2: 97 of 97 components deployed in check-only mode,
35 of 35 local tests completed, and there were no component, test, or coverage errors.

Salesforce Code Analyzer Recommended results are retained as
`code-analyzer-results-20260825-171213.json` and its matching log. The scan found no severity 1 or
2 findings; remaining findings are severity 3 design guidance and severity 4 style/documentation.

The unlocked 2GP package container was created as `0Hoak0000005M7xCAE`. Package-version creation
was attempted after validation, but the Dev Hub returned `REQUEST_LIMIT_EXCEEDED` because its daily
2GP version-create allowance was exhausted. No `04t` version was created, so the independent
subscriber installation acceptance item remains pending. After the daily allowance resets, rerun
the version-create and install commands above without changing source.
