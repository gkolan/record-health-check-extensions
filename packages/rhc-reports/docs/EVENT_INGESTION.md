# Event ingestion contract

## Supported public contract

RHC Reports 0.1.0 accepts only Record Health Check lifecycle-event contract `1.0`. The minimum
promoted core version is 2.0.4.2 (`04tak000000cZBFAA2`). See the
[gap analysis](GAP_ANALYSIS.md) for the authoritative field-by-field sufficiency decision.

The subscribers bind directly to:

- `Record_Health_Check_Set_Run__e`; and
- `Record_Health_Check_Result__e`.

There is no RHC Run Manager dependency and no fallback, migration, alias, or deprecated schema.

## Acceptance rules

| Incoming event | Result |
| --- | --- |
| Contract version is `1.0` and Event ID is nonblank | Mapped to the corresponding minimal fact. |
| Contract version is not `1.0` | Ignored; no partially understood row is stored. |
| Event ID is blank | Ignored because it cannot be made idempotent. |
| Result says `ContainsRestrictedDetail__c = true` | Ignored; restricted detail never enters the analytical store. |
| Same Event ID appears more than once in one trigger batch | The in-memory map keeps one fact for that Event ID. |
| Same Event ID is delivered again later | Upsert on the unique external Event ID updates the same fact. |

The event's canonical Event ID is the business idempotency key. Salesforce Replay ID is not used
as a fact identity.

## Field mappings

### Set Run event to Run Fact

| Event field | Fact field |
| --- | --- |
| `EventId__c` | `EventId__c` |
| `RunId__c` | `RunId__c` |
| `CheckSetQualifiedApiName__c` | `CheckSetQualifiedApiName__c` |
| `RecordId__c` | `RecordId__c` |
| `OccurredAt__c` | `OccurredAt__c` |
| `Source__c` | `Source__c` |
| `ContractVersion__c` | `ContractVersion__c` |
| `FrameworkVersion__c` | `FrameworkVersion__c` |
| `Phase__c` | `Phase__c` |
| `SubmittedRecordCount__c` | `SubmittedRecordCount__c` |
| `ProcessedRecordCount__c` | `ProcessedRecordCount__c` |
| `EligibleCheckCount__c` | `EligibleCheckCount__c` |
| `EvaluatedCheckCount__c` | `EvaluatedCheckCount__c` |
| `PassedCount__c` | `PassedCount__c` |
| `FailedCount__c` | `FailedCount__c` |
| `SkippedCount__c` | `SkippedCount__c` |
| `UnableCount__c` | `UnableCount__c` |
| `SystemErrorCount__c` | `SystemErrorCount__c` |

### Result event to Result Fact

| Event field | Fact field |
| --- | --- |
| `EventId__c` | `EventId__c` |
| `RunId__c` | `RunId__c` |
| `CheckSetQualifiedApiName__c` | `CheckSetQualifiedApiName__c` |
| `CheckQualifiedApiName__c` | `CheckQualifiedApiName__c` |
| `RecordId__c` | `RecordId__c` |
| `Status__c` | `Status__c` |
| `Severity__c` | `Severity__c` |
| `ReasonCode__c` | `ReasonCode__c` |
| `OccurredAt__c` | `OccurredAt__c` |
| `Source__c` | `Source__c` |
| `ContractVersion__c` | `ContractVersion__c` |
| `FrameworkVersion__c` | `FrameworkVersion__c` |

`ContainsRestrictedDetail__c` is a gate, not a stored field.

## Asynchrony and ordering

Platform Events are asynchronous and at least once. A Set Run summary and its Result details can be
delivered in separate trigger transactions and in either observed order. The ingestion paths do not
require the related fact to exist first and do not use a parent-child relationship.

Consequences:

- Reporting Coverage can temporarily show a converging state.
- A Run Fact can exist without Result Facts under `ACTIONABLE` when all outcomes pass or skip.
- Result Facts can briefly appear before their Set Run fact.
- Event acceptance does not prove that every eligible source record in the org was evaluated.
- A publishing transaction that rolls back produces no durable reporting event.

## Bulk and partial-success behavior

Both Platform Event triggers pass `Trigger.new` to one bulk service call. The service performs one
upsert per fact type, outside loops, with `allOrNone=false`. Valid rows in a delivery can succeed
when another row fails. The package does not store raw failed event payloads or restricted error
detail for later replay.

Operational monitoring must therefore include subscriber state and Apex errors. See
[Troubleshooting](TROUBLESHOOTING.md).

## Publication coverage

| Originating caller | Control |
| --- | --- |
| Lightning card explicit Run/Rerun | Check Set `PublishUserRunEvent__c` and each Check's `PublishUserResultEvent__c`. |
| Automatic Lightning page load | Publication is off. |
| Flow, Apex, Batch, Queueable, Future, or Scheduled Apex | Required caller choice `NONE`, `ACTIONABLE`, or `ALL`. |
| Agent native actions and agent REST/MCP adapters | Core forces `NONE`; no RHC Reports coverage. |

`ACTIONABLE` publishes one completed Set Run heartbeat for every scanned record and Result details
only for `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR`. `ALL` adds `PASS` and `SKIPPED` Result details.

## Contract upgrade procedure

Do not silently accept a new contract version. For a future core contract:

1. Read the promoted core event metadata and public contract documentation.
2. Compare every required analytical field and canonical vocabulary.
3. Decide whether existing facts can represent the contract without aliases or lossy translation.
4. Add explicit version handling and tests.
5. Update the minimum compatible core dependency in `sfdx-project.json`.
6. Update the gap analysis, this mapping, package-validation evidence, and admin release notes.
7. Create and independently install a new 2GP version.

