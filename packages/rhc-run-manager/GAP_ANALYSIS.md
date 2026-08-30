# RHC Run Manager gap analysis

## Sources reviewed

- `SPEC.md` in this package.
- The former Day-1 Observability prototype, whose relevant decisions were reconciled into this
  package before the prototype directory was removed.
- Record Health Check core `2.0.4-2` source and global Apex contracts in the sibling repository.

## Contract comparison

| Capability | Specification | Observability prototype | Core public contract | Run Manager decision |
| --- | --- | --- | --- | --- |
| Check Set execution | Required | Direct capture, Queueable, and Batch wrappers | `RecordHealthCheckRequest.forCheckSet` and `RecordHealthCheck.evaluate` | Use the core request/evaluate path in every Batch scope. |
| Check execution | Required | Missing | `RecordHealthCheckRequest.forCheck` | Store explicit `SelectionType__c` and use the same Batch implementation. |
| Target-object derivation | Required | Caller supplies record IDs | Public Custom Metadata contains `ObjectApiName__c`, but no global resolver exists | Isolate a read-only metadata lookup in `RHCRunManagerCoreMetadataGateway`; never call internal core classes. |
| All accessible records | Required | Missing | Core accepts IDs only | Run Manager owns a user-mode `QueryLocator` and supplies IDs to core by scope. |
| Guided filters | Required | Missing | Not a core responsibility | Store structured filter JSON produced by packaged UI. Validate fields and operators; never accept SOQL. |
| Supplied IDs / related changes | Required | Explicit-ID wrappers, but no coalescing | Core accepts bounded ID lists | A bulk Flow action stages deduplicated IDs and a duplicate-signature Queueable drains them into one Batch request. |
| Schedules | Required | Missing | Core Scheduled adapter captures fixed IDs and Check Sets only | Run Manager owns `CronTrigger` identity and launches the same saved-definition execution path as Run Now and supplied IDs. |
| Capture policy | PASS / FAIL / BOTH | Actionable outcomes only | Response exposes all canonical statuses | Persist only the documented status groups; count but never retain `SKIPPED`. |
| Canonical event publication | ALL / ACTIONABLE derived from capture | Prototype subscribes to events | `withEventPublication` publishes canonical core events | Request publication on the direct core call. Do not create or re-publish extension events. |
| Durable model | Definition, Schedule, Batch Run, Run, Result, staged requests | Run and Observation | Core persists no operational history | Use canonical Run/Result/Check terminology and correlate every scope to the owned Batch Run and platform job. |
| Idempotency | Required | Event capture keys | Event delivery is at least once | Direct capture uses unique result keys. Run Manager does not subscribe to events emitted by its own calls. |
| Security | User-mode discovery and persistence | Prototype system DML | Core enforces its run permission and evaluation model | Use `with sharing`, user-mode query/DML, describe allowlists, and separate Admin/Viewer permissions. |

## Prototype reuse and rejection

Reusable ideas are the durable run envelope, partial-success result DML, asynchronous correlation,
least-privilege viewer permissions, and an external idempotency key. Prototype API names,
`Observation`/`Rule` terminology, Check-Set-only wrappers, subscriber triggers, raw payload storage,
and independently generated metadata are intentionally not copied. Day 1 has no aliases,
migrations, deprecated facades, or dual-write paths.

## Necessary core API change

Core should add a global, read-only resolver suitable for every independent extension:

```apex
global class RecordHealthCheckDefinitionInfo {
  global String selectionType;
  global String selectionQualifiedApiName;
  global String checkSetQualifiedApiName;
  global String targetObjectApiName;
}

global static RecordHealthCheckDefinitionInfo resolveDefinition(
  RecordHealthCheckSelection selection
);
```

The implementation should reuse core's namespace-safe identity rules, active-definition checks,
and owning-Check-Set resolution. Until that contract ships in the pinned dependency,
`RHCRunManagerCoreMetadataGateway` performs the smallest possible read against the two **public**
Custom Metadata types. That gateway is the only location aware of their fields and is designed to
be replaced atomically. Run Manager does not reference core internal loaders, repositories,
constants, async adapters, lifecycle publishers, or access helpers.

Core's Batch and Scheduled adapters are not reused because their public APIs accept Check Sets only
and fixed caller-supplied populations. Run Manager retains ownership of discovery, both selection
types, correlation, capture, coalescing, and monitoring while calling only the global
request/evaluate/status/publication contracts.

## Former core monitoring proposals

The core-local Monitor v1 and result-history documents were reconciled on 2026-08-30. Their valid
requirements map as follows:

| Origin requirement | Disposition |
| --- | --- |
| Coverage accounting and durable minimum | Implemented by Batch Run, scope Run, captured Result, counts, and explicit capture mode |
| Scan identity versus viewer authorization | Implemented through user-mode execution and persona-specific permission sets; current access is not inferred from stored identity |
| Transition notifications | Owned by RHC Alerts through canonical core events; not a Run Manager dependency |
| Batch orchestration and partial failures | Implemented by the owned Batch, independently committed scope Runs, and bounded error summaries |
| Per-Check resource observations | Not promised because core exposes no stable per-Check governor-usage contract |
| Explorer and job correlation | Implemented by Batch Run → scope Run → Result drill-down and owned `AsyncApexJob` identity |
| Long-term trends | Owned by RHC Reports; Run Manager retains operational rather than analytical history |

The temporary extraction inputs can be deleted after this mapping and the package specification are
validated together.
