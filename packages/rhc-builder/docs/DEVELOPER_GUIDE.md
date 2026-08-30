# Developer guide

This guide explains how to work on RHC Builder without violating its Day-1 package boundary.

## Non-negotiable architecture

- Builder depends only on the pinned Record Health Check core package.
- Core must work when Builder is absent.
- Core contains no Builder-specific class, permission, object, tab, or UI.
- Builder does not create a second runtime definition schema.
- Builder draft and version records contain exact allow-listed snapshots of core fields.
- A Check is a child snapshot within a complete Check Set Version. There is no Check Version API.
- Qualified API Names are exact, namespace-aware identifiers and must never be rewritten.
- Publication, activation, and rollback always deploy a complete version.

Read [SPEC.md](../SPEC.md) before changing behavior. Read the core repository's `AGENTS.md` before
inspecting or proposing any core change.

## Source tree

| Path                                                      | Purpose                                                           |
| --------------------------------------------------------- | ----------------------------------------------------------------- |
| `force-app/main/default/lwc/recordHealthCheckBuilder`     | Three-step guided authoring UI and Jest tests                     |
| `RHCBuilderController.cls`                                | With-sharing, permission-checked LWC boundary                     |
| `RecordHealthCheckBuilderContract.cls`                    | Builder-owned choices, validation rules, and publication plan     |
| `RHCBuilderContractGateway.cls`                           | Narrow callable boundary to the Builder contract                  |
| `RHCBuilderFieldMapping.cls`                              | Exact allow-list and canonicalization of core fields              |
| `RHCBuilderVersionValidator.cls`                          | Complete-version structure, limit, and required-field validation  |
| `RHCBuilderCoreValidator.cls`                             | Builder mirror of the pinned core metadata validation contract    |
| `RHCBuilderMetadataService.cls`                           | Asynchronous Metadata API worker and callback                     |
| `RHCBuilderTestDataFactory.cls`                           | Test-only canonical versions and publication plans                |
| `objects/Record_Health_Check_Set_Draft__c`                | Stable Builder project identity                                   |
| `objects/Record_Health_Check_Set_Version__c`              | Immutable complete-version snapshot                               |
| `objects/Record_Health_Check_Draft__c`                    | Ordered child Check snapshot, not a separately versioned entity   |
| `objects/Record_Health_Check_Set_Deployment__c`           | Idempotent save/publication ledger                                |
| `permissionsets/RHC_Builder_Admin.permissionset-meta.xml` | Author permission, UI/controller access, read-only ledger access  |
| `sfdx-project.json`                                       | Namespaced unlocked 2GP definition and the single core dependency |

## Request flow

1. LWC loads the Builder-owned authoring contract and describe-backed readable objects.
2. LWC builds a canonical complete-version envelope in memory.
3. `RHCBuilderFieldMapping` removes no supported meaning but rejects unknown envelope or core fields.
4. `RHCBuilderVersionValidator` validates the complete version and applies the pinned core Check Set
   and Check rules through `RHCBuilderCoreValidator`. The installed core does not expose its
   candidate-record validators across package boundaries, so this mirror must be diffed against the
   pinned core source on every dependency change.
5. Saving creates one immutable version, ordered Check children, a SHA-256 fingerprint, and a
   terminal idempotent ledger entry.
6. Publication revalidates the saved fingerprint and builds an allow-listed Metadata API plan.
7. `RHCBuilderMetadataService` submits the plan asynchronously and records its request ID and result.
8. Successful activation or rollback marks the selected version deployed and supersedes the prior
   active version.

No runtime Check evaluation occurs in this package.

## Current guided-UI scope

- The contract permits at most 25 Checks in one complete version.
- The object picker returns readable and queryable objects.
- The guided Formula picker narrows readable fields to text, text area, email, phone, and URL because
  the guided rule is specifically “has a value” or “is blank.”
- The guided Query picker returns safe readable/queryable child relationships and generates a
  one-row existence query.
- Advanced Query and Compare Two Queries expose the primary SOQL, result-field, and operator inputs;
  remaining behavior comes from contract defaults or the canonical type-specific model.
- Apex authoring accepts an existing plugin class name and parameters but does not inspect or create
  plugin code.

## Public LWC controller endpoints

| Endpoint                    | Mutation | Purpose                                                                  |
| --------------------------- | -------- | ------------------------------------------------------------------------ |
| `getAuthoringContract`      | No       | Return supported choices, defaults, fields, and limits                   |
| `getBuilderHome`            | No       | Return up to 100 recent versions and 20 recent operations                |
| `getCheckSetVersion`        | No       | Return one immutable canonical snapshot and fingerprint                  |
| `listReadableObjects`       | No       | Return readable and queryable objects                                    |
| `listReadableFields`        | No       | Return readable fields for guided Formula authoring                      |
| `listReadableRelationships` | No       | Return readable/queryable child relationships for guided Query authoring |
| `validateCheckSetVersion`   | No       | Validate one complete canonical version                                  |
| `saveCheckSetVersion`       | Yes      | Idempotently save one complete immutable version                         |
| `publishCheckSetVersion`    | Yes      | Publish a saved complete version inactive                                |
| `activateCheckSetVersion`   | Yes      | Publish and activate a saved complete version                            |
| `rollbackToCheckSetVersion` | Yes      | Republish an older saved complete version                                |
| `getSetDeployment`          | No       | Return one operation by its idempotency token                            |

These endpoints are an internal UI boundary, not a deprecated prototype compatibility surface.

## Security model

- Every controller endpoint calls the `RHC_Builder_Author` Custom Permission check.
- The LWC controller is `with sharing`.
- Queries that return UI data use user mode.
- Builder-owned records are read-only to authors through the Permission Set.
- Controlled system-mode writes occur only after permission checks, canonicalization, and validation.
- The metadata worker is the narrow `without sharing` class because Metadata API publication cannot
  be implemented as ordinary user-mode record DML.
- User-facing operation summaries are sanitized; detailed deployment diagnostics remain in
  Salesforce Deployment Status.
- Describe-backed pickers filter inaccessible objects, fields, and relationships.

## Local setup

From `packages/rhc-builder`:

```bash
npm install
npm run test:ci
npm run test:coverage
```

Useful validation commands:

```bash
find force-app -name '*.xml' -print0 | xargs -0 xmllint --noout
sf project convert source --source-dir force-app --output-dir /tmp/rhc-builder-mdapi
npx @salesforce-ux/slds-linter@latest lint force-app/main/default/lwc/recordHealthCheckBuilder
```

Do not run generic HTML Prettier against an LWC template unless the Salesforce LWC parser is
configured. A generic HTML parser can quote template expressions and produce invalid LWC syntax.

## Testing expectations

Every behavior change should cover the applicable layers:

- `builderModel.test.js`: canonical shape, type-specific field selection, exact API-name behavior,
  defaults, cloning, and local validation.
- `recordHealthCheckBuilder.test.js`: user interactions, conditional controls, generated Formula or
  SOQL, confirmations, status refresh, retries, errors, and step navigation.
- Apex contract tests: supported values, validation failures, exact Qualified API Names, and plans.
- Apex controller tests: permission boundary, describe results, saves, idempotency, publication, and
  rollback rules.
- Metadata service tests: complete plans, asynchronous callbacks, status changes, and supersession.
- Field mapping tests: every core field and rejection of any second-schema field.

Run Code Analyzer on `force-app`, not generated Jest coverage HTML. Run the official SLDS linter on
the LWC bundle. A package version is not release-ready unless Salesforce's isolated packaging
validation passes its Apex coverage check.

## Changing the core contract

First determine whether Builder can proceed by reading the installed core metadata schema and using
an extension-owned contract. If it cannot:

1. Document the missing public contract and why describe or Metadata API is insufficient.
2. Explain why the extension cannot proceed independently.
3. Read the core repository `AGENTS.md`.
4. Propose the smallest general-purpose core API, with core remaining Builder-agnostic.
5. Obtain explicit approval before modifying the sibling core repository.
