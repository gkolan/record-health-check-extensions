# Releasing the extension suite

Repository publication and Salesforce package release are separate decisions. Passing repository
checks means the source is suitable for review; it does not make a `0Ho` package container
installable. Only a validated `04t` subscriber package version can be installed, and only a promoted
version may be described as released.

## Repository publication gate

- [ ] Confirm `LICENSE`, `NOTICE`, README attribution, and package manifest identifiers remain
      consistent with Apache License 2.0.
- [ ] `node scripts/validate-repository.mjs` passes from the repository root.
- [ ] GitHub Actions `Validate` passes for the exact commit being published.
- [ ] No credentials, tokens, private keys, installation keys, populated environment files, org
      state, generated reports, dependencies, or build artifacts are tracked.
- [ ] README availability statements match each package's authoritative release evidence.
- [ ] The release notes describe user-visible behavior, security implications, prerequisites,
      upgrade impact, and known limitations.

## Package source gate

From each npm-backed package directory that will be released:

```bash
npm ci
npm test
npm run test:coverage
npm audit --audit-level=high
```

RHC Agent Actions currently contains Apex and metadata only, so it has no npm install or Jest gate.
Its source conversion, XML parsing, Code Analyzer, scratch-org compilation, and Apex tests still
apply. Do not add an empty npm project merely to make the command list uniform.

Convert the source to Metadata API format as an offline structure check:

```bash
SF_DISABLE_LOG_FILE=true sf project convert source \
  --root-dir force-app \
  --output-dir <empty-temporary-directory>
```

Run Salesforce Code Analyzer against package source. Severity 1 and 2 findings block release;
record reviewed severity 3 findings and their disposition in the package's release evidence.

```bash
SF_DISABLE_LOG_FILE=true sf code-analyzer run \
  --rule-selector Recommended \
  --target 'force-app/**' \
  --output-file code-analyzer-results-<timestamp>.json \
  --include-fixes
```

Run the package's documented check-only deployment and Apex tests in its required scratch-org
matrix, containing only the pinned Record Health Check core dependency. This includes no-namespace
source validation where the package's release ledger requires it. Retain job IDs, component/test
counts, package Apex coverage, and analyzer summary as release evidence.

## 2GP and subscriber acceptance gate

This section describes the release procedure after a release owner separately authorizes package
artifact creation. A green source or CI gate is not authorization to create a container, version,
or promotion artifact.

- [ ] Create the package version with validation and code coverage; never use `--skip-validation`
      for a release candidate.
- [ ] Record the package-version create request ID and resulting `04t` ID.
- [ ] Install the `04t` in a clean subscriber org that contains the pinned core version and no other
      extension package.
- [ ] Assign only the documented permission sets and complete the package's acceptance scenario.
- [ ] Verify install, upgrade where applicable, and uninstall behavior, scheduled work, permissions,
      data retention, idempotency, and failure handling.
- [ ] Distribute any installation key only through an approved secret channel.
- [ ] Promote only after every package-specific acceptance item passes.

After promotion, update the package README and suite README with the exact version, promoted `04t`,
installation command or URL, dependency version, evidence date, and known limitations. Never publish
an installation URL built from a `0Ho` container ID.
