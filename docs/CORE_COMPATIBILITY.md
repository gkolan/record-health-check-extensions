# Core compatibility and dependency policy

The extension projects declare `Record Health Check@2.0.11-4`
(`04tak000000nGjZAAU`) as their common minimum 2GP dependency. Keep that real, promoted
subscriber version in `sfdx-project.json` and installation documentation until a newer core
version is promoted and the extension release process deliberately raises the minimum.

Subscribers on core `2.0.4.2` through `2.0.10.1` can no longer install these extensions. That is
the intended consequence of raising the minimum, not an oversight. Earlier promoted core versions
remain listed in the core project's package aliases for historical reference only.

A source-compatibility result is not an installable package release. Do not add a dependency
alias, package-install command, or installation URL for any core version until Salesforce has
produced and promoted the corresponding `04t` subscriber package version.

## Current minimum-core evidence

The minimum was raised from `2.0.4-2` to `2.0.11-4` on 2026-10-19, after confirming with
`sf package version list --released` that `04tak000000nGjZAAU` (Record Health Check 2.0.11.4) is a
promoted subscriber version.

Every extension's source contract validator passes against the new minimum:

- all five `validate-core-contract.mjs` gates pass against core `2.0.11.4`;
- all nine extension projects pass their source and least-privilege validators;
- repository contracts, Markdown files, and local links pass their validators;
- all eight npm-backed packages report zero `npm audit --audit-level=high` findings.

### Benchmark commit

The validators and CI benchmark core at commit
`b839c4916315c5129812bbf401e3ea7e99c7a326` ("Release Record Health Check 2.0.11"), which is the
2.0.11 release commit on the core repository's `main` branch.

Earlier revisions of this document named `5905f999dfee391bd4ff029611023f157e60e8ee` as the
2.0.11.4 creation commit. **That commit is not pushed to the core remote** — it exists only on a
local `2.0.11` working branch — so it cannot be used as a benchmark ref. CI checks the core
repository out from GitHub and would fail to resolve it. Use the pushed release commit above, and
do not reintroduce an unpushed ref into a validator or workflow.

### Outstanding verification

Raising the dependency alias is a source and packaging change. It does not by itself prove the
2GP lifecycle against the new core. Still outstanding:

- subscriber install, upgrade, and uninstall behavior against promoted `04t` versions;
- namespaced scratch-org Apex validation against core `2.0.11.4` (the available 2.0.11 orgs are
  non-namespaced, so only the no-namespace path is covered);
- package version creation for any extension against the raised dependency.

## Release-owner checklist for a newer core

1. Confirm the core release candidate has a clean, immutable, **pushed** commit and a promoted
   `04t` version. Verify the promotion with `sf package version list --released`, and verify the
   commit is reachable on the remote with `git branch -r --contains <sha>`.
2. Re-run every extension's local gates, source conversion, Code Analyzer policy, scratch-org
   validation, Apex tests, and documented acceptance scenario against that exact core version.
3. Test subscriber install, upgrade, and uninstall behavior using promoted `04t` versions; source
   deployment alone does not prove the 2GP lifecycle.
4. Raise the shared dependency alias only when the extensions actually require the newer core as
   their minimum. Otherwise preserve the oldest explicitly supported promoted version.
5. Update package READMEs, admin/install guides, release evidence, CI install IDs, and the suite
   availability table together. Never publish a `0Ho` container ID as an installation target.
6. Note that the core project spells its own aliases with a branch suffix
   (`Record Health Check@2.0.11-4-2.0.11`) while the extensions spell theirs without it
   (`Record Health Check@2.0.11-4`). Core-side and extension-side alias lookups in the contract
   validators therefore use different keys.
