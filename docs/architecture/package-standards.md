# Extension package standards

## Names

Use the same name at every layer, transformed only for platform syntax.

| Layer | Example for Run Manager |
| --- | --- |
| Product/package label | `RHC Run Manager` |
| Git project directory | `rhc-run-manager` |
| Salesforce project name | `RHCRunManager` |
| Package source root | `packages/rhc-run-manager/force-app` |
| Apex prefix where useful | `RHCRunManager` |
| Permission Set labels | `RHC Run Manager Admin`, `RHC Run Manager Viewer` |

Do not use `RHC_` at the beginning of object API names. Use the full product family so subscriber
Setup, reports, schema describe, and uninstall reviews remain understandable.

## Package rules

Every package project must declare namespace `rhc`, use the same Metadata API version as its pinned
core dependency, declare `Record Health Check@<version>` as a dependency, expose the least Apex
surface required, and include least-privilege permission sets. No extension modifies core Custom
Metadata types, events, or permission sets.

## Object and field vocabulary

Core event and Apex response names are canonical. Durable equivalents copy the exact semantic name:

| Meaning | Required field API name |
| --- | --- |
| Framework run identity | `RunId__c` |
| Check Set identity | `CheckSetQualifiedApiName__c` |
| Check identity | `CheckQualifiedApiName__c` |
| Checked record | `RecordId__c` |
| Framework event identity | `EventId__c` |
| Framework contract version | `ContractVersion__c` |
| Framework package version | `FrameworkVersion__c` |
| Occurrence/completion time | `OccurredAt__c`, `CompletedAt__c` |
| Asynchronous job/schedule | `AsyncApexJobId__c`, `CronTriggerId__c` |
| Result facts | `Status__c`, `Severity__c`, `ReasonCode__c` |
| System error total | `SystemErrorCount__c` |

Use UpperCamelCase field API names without word-separating underscores. Use `Check`, not `Rule`;
use `Result`, not `Observation`; use `QualifiedApiName` when a value can be namespaced.

## Durable operational objects

| Object | Responsibility |
| --- | --- |
| `Record_Health_Check_Schedule__c` | Scheduling configuration and current platform schedule identity |
| `Record_Health_Check_Batch_Run__c` | One scheduled or manually started Batch job envelope |
| `Record_Health_Check_Run__c` | One framework evaluation run/scope envelope |
| `Record_Health_Check_Result__c` | One retained Check result for one record |

## Builder objects

Builder uses the full product vocabulary and does not create a parallel runtime metadata schema:

| Object | Responsibility |
| --- | --- |
| `Record_Health_Check_Set_Draft__c` | Stable authoring record for one Check Set and target object |
| `Record_Health_Check_Set_Version__c` | Immutable versioned Check Set snapshot |
| `Record_Health_Check_Draft__c` | Ordered Check draft owned by one Check Set Version |
| `Record_Health_Check_Set_Deployment__c` | Check Set validation and metadata deployment ledger |

There is no Check Version object. Checks are ordered child snapshots within one immutable Check Set
Version. Version number, fingerprint, validation, publication, activation, and rollback belong to
the complete Check Set Version.

Use Setup labels **Record Health Check Set Draft**, **Record Health Check Set Version**, **Record
Health Check Draft**, and **Record Health Check Set Deployment**. In the Builder UI, shorten these
to the familiar nouns **Check Set**, **Version**, **Check**, and **Publish History** after context is
established.

Builder fields use names such as `DeveloperName__c`, `ObjectApiName__c`, `CheckSetDraft__c`,
`CheckSetVersion__c`, `EvaluationOrder__c`, `EvaluationType__c`, `SnapshotJson__c`,
`OperationToken__c`, and `MetadataRequestId__c`. Avoid the prototype's `RHC_Builder_*` objects,
generic `Project` terminology, and word-separating underscores.

## Status and capture vocabulary

Never collapse the five core statuses in stored Result records.

| Capture mode | Retained Result statuses |
| --- | --- |
| `PASS` | `PASS` |
| `FAIL` | `FAIL`, `UNABLE_TO_EVALUATE`, `ERROR` |
| `BOTH` | `PASS`, `FAIL`, `UNABLE_TO_EVALUATE`, `ERROR` |

`SKIPPED` is counted on Run records but is not retained as a detailed Result in these modes.

## Security and Day-1 evolution

Discover and evaluate business records in user mode under the schedule owner. Use `with sharing`
and `WITH USER_MODE`; restrict diagnostic detail from Viewer access; store Salesforce IDs in
Text(18) unless a stable owned relationship exists; and make ingestion/retries idempotent. Release 1
does not accept arbitrary administrator-entered SOQL.

There are no compatibility constraints. Rename or remove prototype metadata directly. Do not ship
aliases, duplicate objects, dual-read/write paths, prototype-data migrations, or deprecated facades.
