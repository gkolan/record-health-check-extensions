# RHC Builder

> **Create and publish Record Health Check rules through a guided administrator experience.**

RHC Builder is an optional Salesforce extension for designing complete Check Sets without editing
individual Custom Metadata records by hand. It helps administrators make deliberate, reviewable
changes by validating a complete version before publication and preserving the history needed to
return to an earlier version.

Builder is independently installable after Record Health Check core. It does not require any other
RHC extension.

## How Builder helps

Core stores runtime Check Sets and Checks in Custom Metadata. That makes the rules deployable and
version-controlled, but direct record-by-record editing requires an administrator to understand
field compatibility, namespaces, ordering, and partial-deployment risk.

Builder provides one guided path to:

- design a Check Set and its ordered Checks together;
- use guided options for common field-presence and related-record checks;
- retain advanced Formula, Query, Compare Two Queries, and Apex choices for skilled authors;
- validate and save an immutable, complete Check Set version;
- publish and monitor the version as one operation;
- activate deliberately; and
- roll back by republishing an earlier validated version.

## How it works

1. **Design** — Choose the target, behavior, and ordered Checks in the Builder workspace.
2. **Validate and save** — Builder checks the complete definition and saves an immutable version.
3. **Publish and monitor** — Builder creates an exact Metadata API deployment plan, publishes the
   complete version to core, and records the outcome.

Builder owns the authoring drafts, immutable snapshots, and deployment history. Record Health Check
core continues to own the published Custom Metadata and all runtime evaluation. Uninstalling Builder
does not remove core metadata that Builder already published.

## What installation adds

- the Record Health Check Builder Lightning Web Component;
- draft, version, Check snapshot, and deployment-history objects;
- the **RHC Builder Admin** permission set;
- the **RHC Builder Author** custom permission; and
- the controlled Apex service that validates and publishes complete versions.

The package does not add a second evaluation engine and does not change records being checked.

## Get started

1. Install the required Record Health Check core version.
2. Install an approved RHC Builder subscriber package version in a sandbox.
3. Assign `RHC_Builder_Admin` to the administrators who will author Check Sets.
4. Follow the [click-by-click guide](docs/CLICK_BY_CLICK_GUIDE.md) to create, validate, publish, and
   verify a sample version.
5. Review [operations](docs/OPERATIONS.md) before introducing a production authoring process.

See [installation](docs/INSTALLATION.md) for exact prerequisites and package installation steps.

### Current availability

Builder beta `0.2.0.1` (`04tak000000ckt3AAA`) passed the isolated 2GP coverage check with 76%
coverage. It is a validated beta for testing and has **not** been promoted or released. The current
source also contains a later usability change, so confirm the exact package version and verification
record before testing.

See [verification evidence](docs/VERIFICATION.md) for the authoritative status.

## Security and boundaries

- Every Builder controller endpoint requires the `RHC_Builder_Author` custom permission.
- The controller runs with sharing and reads UI records in user mode.
- Object and field choices are filtered by Salesforce describe access.
- Authors receive read-only access to the Builder ledger; controlled writes happen through Apex.
- Unknown fields are rejected instead of creating an alternate runtime schema.
- Save and publication requests use idempotency tokens.
- Activation and rollback require explicit confirmation and always affect a complete version.
- Builder depends only on Record Health Check core and never reads another extension.

## Documentation

| Need | Start here |
| --- | --- |
| Understand the product | [Administrator guide](docs/ADMIN_GUIDE.md) |
| Follow every setup and authoring click | [Click-by-click guide](docs/CLICK_BY_CLICK_GUIDE.md) |
| Install the package | [Installation](docs/INSTALLATION.md) |
| Operate and troubleshoot Builder | [Operations](docs/OPERATIONS.md) |
| Understand validation and publication rules | [Builder contract](docs/BUILDER_CONTRACT.md) |
| Review exact core field mappings | [Field mapping](docs/FIELD_MAPPING.md) |
| Understand architecture or contribute | [Developer guide](docs/DEVELOPER_GUIDE.md) |
| Review package evidence | [Verification](docs/VERIFICATION.md) |
| Review the authoritative scope | [Product specification](SPEC.md) |

<details>
<summary><strong>For contributors and release maintainers</strong></summary>

<br />

Run commands from this package directory:

```bash
npm ci
npm run test:ci
npm run test:coverage
```

Before release, also validate metadata, SLDS, Apex, security, Code Analyzer results, source
deployment, package coverage, and clean-subscriber installation. Follow the
[release guide](docs/RELEASE_GUIDE.md); do not promote a package from local test results alone.

Package identity:

- Package: Record Health Check Builder
- Container: `0Hoak0000005Fb7CAE`
- Namespace: `rhc`
- Source line: `0.2.0.NEXT`
- Pinned core dependency: `Record Health Check@2.0.4-2`

</details>
