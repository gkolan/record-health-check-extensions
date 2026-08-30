# Core lifecycle-event gap analysis

## Decision

Promoted **Record Health Check 2.0.4.2** (`04tak000000cZBFAA2`) is the minimum compatible core
version. Both required high-volume, Publish After Commit Platform Events are present with contract
version `1.0`. The public contract is sufficient, so RHC Reports makes no core repository change.

## Field sufficiency

| Analytical need | Set Run event | Result event | RHC Reports use |
| --- | --- | --- | --- |
| At-least-once deduplication | `EventId__c` | `EventId__c` | Unique external IDs on both fact objects |
| Run correlation | `RunId__c` | `RunId__c` | Exact opaque core Run ID |
| Check Set identity | `CheckSetQualifiedApiName__c` | same | Exact Qualified API Name, never prefix-normalized |
| Check identity | — | `CheckQualifiedApiName__c` | Exact Check Qualified API Name |
| Former source record | `RecordId__c` | `RecordId__c` | Text(18), so deletion of the business record does not delete history |
| Occurrence and source | `OccurredAt__c`, `Source__c` | same | Explicit local-date assignment and canonical execution-source reporting |
| Contract provenance | `ContractVersion__c`, `FrameworkVersion__c` | same | Accept only contract `1.0`; preserve framework version |
| Run status measures | five status counts plus eligible/evaluated | — | Run Fact and RUN-grain daily snapshot |
| Result dimensions | — | `Status__c`, `Severity__c`, `ReasonCode__c` | Result Fact and RESULT-grain snapshot |

Canonical status values are `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, and `ERROR`.
Canonical result severities are `CRITICAL`, `WARNING`, and `INFO`. Canonical sources are
`APEX_API`, `FLOW`, `USER_INITIATED`, `SCHEDULED`, `BATCH`, `QUEUEABLE`, `FUTURE`,
and `AGENT`. Set Run phase is `COMPLETED` for record summaries and `COMPLETED` or `FAILED`
for asynchronous terminal envelopes.

## Deliberate inference boundary

The publication request value (`NONE`, `ACTIONABLE`, or `ALL`) is not an event field. Adding it
is not necessary for facts or aggregates, and changing core would not solve history that was never
published. The coverage page therefore:

- shows configured interactive publication flags separately;
- infers **full ALL coverage** only when received detail has caught up with evaluated counts;
- infers **partial ACTIONABLE coverage** from actionable-only received detail;
- calls zero actionable counts **No failures** only when a Set Run fact exists; and
- never equates missing events with a clean run.

Programmatic callers choose publication per request, so their configuration cannot be reconstructed
afterward. Run summaries and result details can arrive in either order and coverage can temporarily
show as converging.

## Excluded contract content

Core events already exclude found/expected values, messages, raw payloads, fix instructions, and
stack traces. RHC Reports has no fields for those values and rejects any Result event whose reserved
`ContainsRestrictedDetail__c` flag is true.
