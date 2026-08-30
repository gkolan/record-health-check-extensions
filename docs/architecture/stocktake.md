# Architecture stocktake

## Decision summary

The extension portfolio is still Day 1. Existing source is useful prototype material, but none of
its object, field, package, or Apex names are compatibility constraints.

The first operational extension should be **RHC Run Manager**, combining durable observability
with configuration-driven scheduled Batch execution. These responsibilities share the same Run,
Result, schedule, correlation, permission, retention, and monitoring model. Keeping them together
also preserves the rule that every extension depends only on core.

## Core framework contract reviewed

The sibling `record-health-check` repository is the source of truth.

| Contract | Core standard |
| --- | --- |
| Namespace | `rhc` |
| Packaging | Namespaced second-generation package |
| Metadata API | `66.0` until core raises it |
| Check Set type | `Record_Health_Check_Set__mdt` |
| Check type | `Record_Health_Check__mdt` |
| Set selection | `RecordHealthCheckRequest.forCheckSet(qualifiedApiName, recordIds)` |
| Check selection | `RecordHealthCheckRequest.forCheck(qualifiedApiName, recordIds)` |
| Status values | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, `ERROR` |
| Publication values | `NONE`, `ACTIONABLE`, `ALL` |
| Set lifecycle event | `Record_Health_Check_Set_Run__e` |
| Result event | `Record_Health_Check_Result__e` |
| Error event | `Record_Health_Check_Log__e` |
| Canonical identity fields | `RunId__c`, `CheckSetQualifiedApiName__c`, `CheckQualifiedApiName__c`, `RecordId__c` |

Qualified API names are opaque, exact identities. Code trims and bounds them but never adds or
removes `rhc__`. Selection type must be stored separately because a name alone does not say whether
it belongs to the Check Set or Check metadata type.

## Historical extension source

### Builder prototype

The original Builder prototype contained a Lightning workspace, Apex controller and metadata service,
four draft/version/deployment objects, permissions, tests, and detailed UX specifications. The core
development tree also contains in-progress guided-authoring classes and LWCs, creating an unresolved
duplicate boundary.

**Day-1 disposition:** guided authoring is the independent **RHC Builder** extension.
Move Builder UI, draft/version persistence, orchestration, and deployment ownership out of core.
Core retains only generally reusable runtime validation and narrowly scoped public metadata APIs
that are appropriate for any external authoring client. There must be one Builder implementation
and one authoring persistence contract.

The prototype is not yet a release contract. Its `RHC_Builder_*` objects and underscore-separated
fields must be renamed to the full product vocabulary defined in package standards.

### Observability prototype

The original Observability prototype contained durable Run and Observation objects, synchronous Apex
and Flow capture, Queueable and Batch wrappers, subscribers for core events, permissions, and tests.
It is an implementation seed, not a releasable package contract. Current gaps are:

1. `sfdx-project.json` does not declare its required core package dependency.
2. It uses API version `67.0` while core currently declares `66.0`.
3. Its direct capture service and async wrappers support only Check Sets.
4. Its Batch wrapper accepts explicit IDs and a fixed scope of 50; it is not an administrator-configured schedule.
5. Object fields use underscore-separated API names that differ from core contract names.
6. `Observation` and `Rule` terminology diverges from core's `Result` and `Check` terminology.
7. It has no administrator scheduling UI or configurable capture policy.
8. It lacks one terminal model spanning schedule, `CronTrigger`, `AsyncApexJob`, and framework Run IDs.

**Day-1 disposition:** rename and reshape this source into RHC Run Manager. Rename
objects and fields directly; do not add aliases, deprecated fields, data migration, or dual-write.

The prototype directories were removed after their relevant decisions and capabilities were
reconciled into the independent projects under `packages/`. They are not package source and should
not be restored alongside the canonical implementations.

## Independently installable means

Each extension is a separate 2GP package and Salesforce project, declares a dependency on a tested
core version, does not require another extension, owns its persistent objects, and can be installed,
permissioned, upgraded, and uninstalled on its own.

Run Manager is intentionally cohesive. Extracting scheduling from monitoring would violate this
model unless Scheduler duplicated result persistence or required Observability.

## CDC-driven evaluation and Salesforce notifications

RHC Alerts already owns human delivery through Salesforce Custom Notifications and email. The
Salesforce global bell, the packaged Custom Notification Type, and core's configurable Run-button
glyph are separate concepts. Native human notification remains in Alerts; core does not acquire a
messaging dependency.

CDC-driven evaluation is a proposed independent **RHC Change Monitor** extension. It initiates a new
core evaluation for the durable source record after selected CDC changes. It does not evaluate a
transient `*ChangeEvent` payload and does not belong in Alerts, Run Manager, or core.

Change Monitor now has a local Salesforce DX implementation preview that makes object-specific
adapter intake, stable replay identity, least-privilege execution principal, and bulk-limit
hypotheses executable. It still has no package container, and none of those feasibility gates is
considered passed merely because source exists. The repository contains eight package projects.

## Delivery sequence

1. Freeze the core runtime, validation, and metadata API surfaces extensions may consume.
2. Extract/reconcile guided authoring into RHC Builder and remove the duplicate core UI/persistence path.
3. Rename Observability source to RHC Run Manager and align every API name with core vocabulary.
4. Implement the configuration-driven scheduler and QueryLocator Batch.
5. Package and subscriber-validate RHC Builder and RHC Run Manager independently.
6. Build RHC Alerts and RHC Reports against core events, each with its own storage where needed.
7. Build RHC Actions and RHC Integrations after security and idempotency contracts are proven.
8. Run the RHC Change Monitor feasibility project and close all four gates before registering its
   package container or creating a subscriber version.
