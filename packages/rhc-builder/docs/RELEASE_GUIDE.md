# Release guide

This guide is for maintainers creating a new independently installable RHC Builder 2GP version.

## Release invariants

- Package: `Record Health Check Builder` (`0Hoak0000005Fb7CAE`).
- Namespace: `rhc`.
- Type: unlocked, non-org-dependent 2GP.
- Dependency: exactly `Record Health Check@2.0.4-2` (`04tak000000cZBFAA2`) for the current line.
- No other extension dependency.
- Do not use `--skip-validation`.
- Do not promote a version until clean-subscriber installation and UX acceptance testing pass.
- Use an installation key for betas unless the release owner explicitly approves key bypass.

## 1. Prepare the source

1. Review [SPEC.md](../SPEC.md) and the package boundary.
2. Confirm every intended change is inside `packages/rhc-builder` unless a repository-level change is
   explicitly justified.
3. Confirm `sfdx-project.json` has one package directory, namespace `rhc`, and one dependency.
4. Increment `versionName`, `versionNumber`, `package.json`, and lockfile consistently when required.
5. Confirm no prototype aliases, deprecated endpoints, migrations, or Check Version APIs were added.
6. Diff `RHCBuilderFieldMapping` against the pinned core metadata fields.
7. Diff Builder's validation mirror against the pinned core validators, including query bulk shape,
   applicability COUNT, Apex-plugin, text-operator, limit, empty-value, and identity rules.

## 2. Run local gates

```bash
npm install
npm audit
npm run test:ci
npm run test:coverage
find force-app -name '*.xml' -print0 | xargs -0 xmllint --noout
sf project convert source --source-dir force-app --output-dir /tmp/rhc-builder-mdapi
npx @salesforce-ux/slds-linter@latest lint force-app/main/default/lwc/recordHealthCheckBuilder
```

Run Salesforce Code Analyzer's Recommended rules against `force-app`. Record the report filename and
all severity counts in [VERIFICATION.md](VERIFICATION.md). Do not scan generated coverage HTML as
product source.

## 3. Verify in a package-development scratch org

Use dedicated namespaced and `--no-namespace` orgs with the pinned core package and no other
extension dependency. The non-namespaced org must contain only the installed managed core package;
do not use a shared org with an unpackaged core source copy as the clean portability gate.

```bash
sf project deploy preview --source-dir force-app --target-org <builder-scratch-alias> --json
sf project deploy start --dry-run --source-dir force-app --target-org <builder-scratch-alias> --test-level RunSpecifiedTests --tests RHCBuilderControllerTest --tests RHCBuilderContractGatewayTest --tests RecordHealthCheckBuilderContractTest --tests RHCBuilderFieldMappingTest --tests RHCBuilderMetadataServiceTest --tests RHCBuilderQueryValidatorTest --tests RHCBuilderValidationRulesTest --wait 30 --json
sf project deploy start --source-dir force-app --target-org <builder-scratch-alias> --test-level RunSpecifiedTests --tests RHCBuilderControllerTest --tests RHCBuilderContractGatewayTest --tests RecordHealthCheckBuilderContractTest --tests RHCBuilderFieldMappingTest --tests RHCBuilderMetadataServiceTest --tests RHCBuilderQueryValidatorTest --tests RHCBuilderValidationRulesTest --wait 30 --json
sf apex run test --tests RHCBuilderControllerTest --tests RHCBuilderContractGatewayTest --tests RecordHealthCheckBuilderContractTest --tests RHCBuilderFieldMappingTest --tests RHCBuilderMetadataServiceTest --tests RHCBuilderQueryValidatorTest --tests RHCBuilderValidationRulesTest --target-org <builder-scratch-alias> --code-coverage --wait 30
```

Record the preview result, deploy IDs, Apex run ID, pass count, and class coverage.

Run the complete sequence in both namespace modes. The repository Salesforce workflow enforces this
as a two-entry matrix and verifies `Organization.NamespacePrefix` before deployment.

Before creating a version, exercise the exact deployed source through save retry, inactive
publication, activation, omitted-Check deactivation, callback request-ID capture, publication retry,
and rollback. Query both the Builder ledger and core Custom Metadata after each callback.

The repository automation performs that sequence against a disposable namespaced org:

```bash
sf org assign permset --name RHC_Builder_Admin --target-org <builder-scratch-alias>
scripts/verify-runtime-lifecycle.sh <builder-scratch-alias>
```

## 4. Stop for explicit package-version approval

Do not create a package version merely because source gates pass. Confirm the verification record has
no unresolved pre-version blocker and obtain explicit release-owner approval for the artifact needed
by the clean-subscriber, upgrade, and uninstall gates.

## 5. Create a validated package version

Generate and securely store a new installation key. Do not commit it or write it into documentation.

```bash
sf package version create --package "Record Health Check Builder" --installation-key <secure-key> --code-coverage --target-dev-hub <dev-hub-alias> --wait 60 --json
```

If the command times out, poll the returned request rather than creating a duplicate version.

```bash
sf package version create report --package-create-request-id <08c-id> --target-dev-hub <dev-hub-alias> --json
sf package version report --package <04t-id> --target-dev-hub <dev-hub-alias> --json
```

Required readback:

- `ValidationSkipped` is `false`;
- `HasPassedCodeCoverageCheck` is `true`;
- package coverage is at least 75%;
- `IsOrgDependent` is `No`;
- the version and dependency are correct; and
- no unexpected metadata was removed.

## 6. Clean-subscriber acceptance

1. Use a clean, non-namespaced subscriber scratch org.
2. Install the core package first.
3. Install the new Builder `04t` with its installation key.
4. Assign **Record Health Check Builder Admin**.
5. Load the [sandbox demo kit](../demo/README.md) and execute the complete
   [end-to-end demo test plan](../demo/DEMO_TEST_PLAN.md).
6. Test Formula and Query guided authoring.
7. Test validation failure, immutable save, inactive publication, activation, status refresh, copy as
   new draft, and rollback.
8. Verify core still runs after Builder is uninstalled in a disposable org.
9. Record tester, org, date, version, results, and defects.

## 7. Promote only after approval

Promotion changes the release state and is separate from creating a validated beta. Obtain explicit
release-owner approval, then promote the exact reviewed `04t`. Publish the installation URL, supported
core version, secure key-distribution process if applicable, release notes, and rollback plan.
