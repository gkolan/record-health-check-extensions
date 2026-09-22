# Contributing

Each extension is an independent Salesforce 2GP project. Keep changes inside the package that owns
the capability unless the change updates a suite-wide contract or documentation.

## Before opening a pull request

1. Run the repository contract, CI-coverage contract, and local-link checks from the repository
   root:

   ```bash
   node scripts/validate-repository.mjs
   ```

2. From every changed package directory, install exactly from the lockfile and run its checks:

   ```bash
   npm ci
   npm test
   npm run test:coverage
   npm audit --audit-level=high
   ```

3. Run the package's documented Salesforce source validation and focused Apex tests in a compatible
   namespaced scratch org. The repository workflows define an org-validation path for every package;
   local execution still requires a valid Dev Hub authorization and must not create package artifacts.
4. Update the package README, administrator guidance, security/operations documentation, and release
   evidence when behavior or installation steps change.

For a suite-level static review, run from the repository root so `code-analyzer.yml` excludes only
generated and dependency content, then target deployable package source explicitly:

```bash
SF_DISABLE_LOG_FILE=true sf code-analyzer run \
  --workspace packages \
  --target 'packages/*/force-app/**' \
  --rule-selector Recommended \
  --include-fixes \
  --output-file code-analyzer-results-<timestamp>.json
```

Keep Node repository utilities under their package validation scripts; do not broaden the
Salesforce source scan to generated coverage reports or dependency trees.

Do not commit org authentication, installation keys, environment files, dependencies, coverage,
logs, generated analyzer results, or package-version artifacts. See the
[release guide](docs/RELEASING.md) for the complete promotion gates.
