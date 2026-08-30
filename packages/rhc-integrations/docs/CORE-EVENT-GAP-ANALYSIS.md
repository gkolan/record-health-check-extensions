# Core-event gap analysis

## Minimum compatible promoted core version

The minimum compatible promoted version is **Record Health Check 2.0.4.2**
(`04tak000000cZBFAA2`, dependency alias `Record Health Check@2.0.4-2`). It is the earliest promoted
version in the authoritative core catalog that supplies the canonical Run, Result, and Log event
shapes consumed here with event contract `1.0`. The extension package pins that immutable 04t
dependency and API version 66.0.

## Contract assessment

| Event | Sufficient fields | Gaps and safe behavior |
| --- | --- | --- |
| `Record_Health_Check_Result__e` | Event ID, Run ID, both qualified identities, status, severity, reason code, occurrence, source, event and framework versions | This is the complete routing contract. Restricted detail is rejected; profile payloads never include data absent from the event. |
| `Record_Health_Check_Set_Run__e` | Event ID, Run ID, Check Set qualified identity, counts, occurrence, source, versions | It has no overall status or severity. The subscriber derives status only from documented count precedence (`ERROR`, `UNABLE_TO_EVALUATE`, `FAIL`, `PASS`, `SKIPPED`). A route with a severity threshold cannot match a Run event. |
| `Record_Health_Check_Log__e` | Event ID, Run ID, occurrence, level, code, developer names, versions | It intentionally lacks qualified identities and canonical severity and contains prohibited diagnostics. The subscriber maps `ERROR` status, leaves severity blank, matches identity only by exact string equality, and emits only Event ID, Run ID, code, occurrence, and versions. Namespaced Check/Check Set routes therefore cannot safely match Log events. |

Publication `NONE` creates no core event, so the extension produces no ledger row and no callout.
The extension does not query core configuration or reconstruct unpublished results.

## Core-change decision

No core change is required for Day 1. Result events fully support the specified qualified-identity,
status, and severity use case, including the `Opportunity_Close_Readiness` / `ERROR` / `CRITICAL`
example. Run gaps are safely deterministic from documented counts. Log limitations fail closed and
are documented; weakening identity semantics or exporting diagnostic fields would be less safe.

If a future product requirement demands namespaced qualified-identity or severity filtering for Log
events, core would need additive, canonical `CheckSetQualifiedApiName__c`,
`CheckQualifiedApiName__c`, and severity fields in a promoted event contract. That is not necessary
for this implementation and no core files are modified.

