# Contributing

Each extension is an independent Salesforce 2GP project. Keep changes inside the package that owns
the capability unless the change updates a suite-wide contract or documentation.

## Before opening a pull request

1. Run the repository contract and local-link checks from the repository root:

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
   namespaced scratch org.
4. Update the package README, administrator guidance, security/operations documentation, and release
   evidence when behavior or installation steps change.

Do not commit org authentication, installation keys, environment files, dependencies, coverage,
logs, generated analyzer results, or package-version artifacts. See the
[release guide](docs/RELEASING.md) for the complete promotion gates.
