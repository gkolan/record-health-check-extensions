# Core compatibility and dependency policy

The extension projects declare `Record Health Check@2.0.4-2`
(`04tak000000cZBFAA2`) as their common minimum 2GP dependency. Keep that real, promoted
subscriber version in `sfdx-project.json` and installation documentation until a newer core
version is promoted and the extension release process deliberately raises the minimum.

A source-compatibility result is not an installable package release. In particular, do not add a
`2.0.11` dependency alias, package-install command, or installation URL until Salesforce has
produced and promoted the corresponding `04t` subscriber package version.

## Current source-compatibility evidence

On 2026-09-25, the suite was validated against the local `record-health-check` branch `2.0.11`.
That core working tree was not clean, so this is current development evidence rather than an
immutable release record. The release owner must repeat the same checks against the eventual
2.0.11 release-candidate commit and promoted subscriber package.

The validation used a clean, non-namespaced disposable scratch org and did not create any package
container or package version:

- current core source: 576/576 components passed dry-run validation and deployment;
- all nine extension projects: 650/650 components passed dry-run validation and deployment on top
  of that core source;
- package-owned Apex regression: 357/357 test methods passed across 54 test classes;
- local JavaScript and generator tests: 134/134 distinct test cases passed across the eight
  npm-backed projects;
- Salesforce Code Analyzer Recommended rules: zero findings across extension source, with 20
  documented inline suppressions honored;
- all nine projects converted successfully to Metadata API format;
- all eight npm dependency audits reported zero vulnerabilities;
- repository contracts, 159 Markdown files, 442 local links, and all GitHub Actions workflows
  passed their local validators.

The run found and fixed three release-readiness defects: invalid sharing-model values in the Alerts
and Change Monitor metadata generators, ineffective Change Monitor generator drift checking, and
an Actions retention test that depended on stale permission caching for the running test user.

## Release-owner checklist for a newer core

1. Confirm the core release candidate has a clean, immutable commit and a promoted `04t` version.
2. Re-run every extension's local gates, source conversion, Code Analyzer policy, scratch-org
   validation, Apex tests, and documented acceptance scenario against that exact core version.
3. Test subscriber install, upgrade, and uninstall behavior using promoted `04t` versions; source
   deployment alone does not prove the 2GP lifecycle.
4. Raise the shared dependency alias only when the extensions actually require the newer core as
   their minimum. Otherwise preserve the oldest explicitly supported promoted version.
5. Update package READMEs, admin/install guides, release evidence, CI install IDs, and the suite
   availability table together. Never publish a `0Ho` container ID as an installation target.
