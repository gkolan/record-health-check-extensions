# RHC Alerts core event gap analysis

## Sources reviewed

- `SPEC.md` in this package.
- Core repository `AGENTS.md` and the promoted `Record Health Check@2.0.4-2` source contract.
- `Record_Health_Check_Result__e`, `Record_Health_Check_Set_Run__e`, their publisher, publication controls, and platform-event documentation.

## Minimum compatible promoted core version

The minimum compatible promoted version is **Record Health Check 2.0.4-2** (`04tak000000cZBFAA2`).
It provides event contract `1.0`, exact Qualified API Names, stable Event IDs, record and run
correlation, canonical five-state Result status, Result severity, timestamps, source attribution, and
explicit `NONE` / `ACTIONABLE` / `ALL` publication behavior. `sfdx-project.json` pins this version.

No core change is required for Check alerts. No core files were modified.

## Contract comparison and decisions

| Need                     | Result event 1.0                                                             | Set Run event 1.0                                                                | Alerts decision                                                                                                                               |
| ------------------------ | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Exact Check identity     | `CheckQualifiedApiName__c`                                                   | Not applicable                                                                   | Compare the full opaque string exactly; never strip or add a namespace.                                                                       |
| Exact Check Set identity | `CheckSetQualifiedApiName__c`                                                | `CheckSetQualifiedApiName__c`                                                    | Compare exactly.                                                                                                                              |
| Matching status          | `PASS`, `FAIL`, `SKIPPED`, `UNABLE_TO_EVALUATE`, `ERROR`                     | `Phase__c` plus counts, not a canonical result status                            | Check Set policies evaluate Result events for exact status semantics.                                                                         |
| Minimum severity         | Canonical severity is present for failures where core defines one            | No severity                                                                      | Check Set policies evaluate Result events. Set Run events cannot send an alert under contract 1.0.                                            |
| Idempotency              | Stable `EventId__c`                                                          | Stable `EventId__c`                                                              | Unique SHA-256 Event ID + Policy claim; redelivery creates `DUPLICATE` evidence and never another successful send.                            |
| Per-record cooldown      | `RecordId__c`                                                                | `RecordId__c` when the envelope is per record                                    | Policy and record SHA-256 cooldown key; policy row lock serializes competing transactions.                                                    |
| Restricted content       | Minimal facts and `ContainsRestrictedDetail__c`; no values                   | Minimal counts                                                                   | Store and message only approved identity, status, and severity. Never store payloads, found/expected values, exception text, or stack traces. |
| Publication coverage     | Interactive Check checkbox; caller chooses publication for programmatic runs | Interactive Check Set checkbox; caller chooses publication for programmatic runs | Setup assistant checks interactive Result coverage and warns that programmatic `NONE` is invisible.                                           |

## Public-contract insufficiency

Set Run contract `1.0` has no canonical aggregate result status and no severity. Inferring severity
from failure counts would create an extension-specific vocabulary and violate the requirement to
consume canonical core facts. RHC Alerts therefore subscribes directly to Set Run events but records
matching policy evaluations as `SUPPRESSED / RUN_CONTRACT_INSUFFICIENT`; it sends Check Set alerts
from matching Result events instead.

A future core contract could add explicit aggregate `Status__c` and `Severity__c` fields with
documented ordering. Until a promoted version does so, this package does not require or propose a
core edit. The setup assistant makes the limitation and missing Result-publication coverage visible.

## Boundary confirmation

RHC Alerts references only core Platform Events and the two public core Custom Metadata types used
by its read-only setup assistant. It does not reference Run Manager, Reports, Actions, Integrations,
Builder, their objects, or their Apex. It does not call core internal publisher classes, retain
general result history, update checked records, or implement webhooks.
