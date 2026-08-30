# RHC Actions packaging and release

## Package identity

| Property                   | Value                         |
| -------------------------- | ----------------------------- |
| Package name               | RHC Actions                   |
| Package type               | Unlocked 2GP                  |
| Namespace                  | `rhc`                         |
| Package container          | `0Hoak0000005M6LCAU`          |
| Version line               | `0.1.0.NEXT`                  |
| Source API version         | `66.0`                        |
| Only dependency            | `Record Health Check@2.0.4-2` |
| Core subscriber version ID | `04tak000000cZBFAA2`          |

No RHC Actions subscriber package version has been created yet. Do not publish an install link until
Salesforce returns and validates an `04t`.

## Pre-release checklist

- [ ] Product requirements and threat model are current.
- [ ] `sfdx-project.json` contains only the promoted core dependency.
- [ ] No core or sibling-extension source was modified without an approved gap decision.
- [ ] XML validation, source conversion, Jest, Apex tests, and Code Analyzer completed.
- [ ] `npm run validate` and the pinned saved-core contract check pass.
- [ ] The `validate.yml` RHC Actions static job and `rhc-actions-salesforce-validate.yml` org job pass.
- [ ] Package-only Apex coverage is at least Salesforce's required threshold.
- [ ] All Custom Permissions and Permission Sets match `SECURITY_AND_AUTHORIZATION.md`.
- [ ] Administrator labels and click paths match package metadata.
- [ ] Installation key is stored and distributed through the approved secret channel.
- [ ] A clean scratch-org definition and test users are ready.

## Create a beta

From `packages/rhc-actions`:

```sh
SF_DISABLE_LOG_FILE=true sf package version create \
  --package "RHC Actions" \
  --installation-key "<installation-key>" \
  --code-coverage \
  --wait 30 \
  --target-dev-hub rhc-dev-hub
```

Do not use `--installation-key-bypass` without an explicit security decision. Do not use
`--skip-validation` for release evidence.

If Salesforce reports a daily package-version limit, stop. Retrying the same day does not prove the
package and can consume operator time. Record the quota blocker and rerun after reset.

## Inspect the build

```sh
SF_DISABLE_LOG_FILE=true sf package version list \
  --packages "RHC Actions" \
  --target-dev-hub rhc-dev-hub
```

Record:

- package version ID (`05i`);
- subscriber package version ID (`04t`);
- semantic version and build number;
- validation status;
- code coverage; and
- dependency version.

Add a stable alias such as `RHC Actions@0.1.0-1` to `sfdx-project.json` only after Salesforce returns
the real ID.

## Install in a clean verification org

Install core first, then Actions:

```sh
SF_DISABLE_LOG_FILE=true sf package install \
  --package 04tak000000cZBFAA2 \
  --target-org <clean-org> \
  --wait 20 \
  --publish-wait 20

SF_DISABLE_LOG_FILE=true sf package install \
  --package <rhc-actions-04t> \
  --installation-key "<installation-key>" \
  --target-org <clean-org> \
  --wait 20 \
  --publish-wait 20
```

Confirm no Builder, Run Manager, Alerts, Reports, or Integrations package is needed.

## Promotion decision

Promote only after:

- clean-org installation, upgrade from the previous supported version, and uninstall succeed;
- the manual administrator acceptance test succeeds;
- automatic-mode security configuration is tested when included in the release scope;
- release notes list the minimum core version and known limits;
- an owner accepts residual analyzer findings; and
- the package key and install link have approved distribution handling.

Promotion is an external irreversible release action and must follow the repository's release
approval process.

## Release notes template

Each release note must state:

- Actions version and `04t`;
- required core version and `04t`;
- install order;
- new or changed metadata;
- Flow contract versions;
- permission changes;
- administrator actions required after install;
- tests and analyzer evidence;
- known limits and non-atomic behavior; and
- rollback or uninstall instructions.
