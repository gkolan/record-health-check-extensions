# RHC Integrations implementation worksheet

Copy this file into the organization's controlled change record. Do not enter passwords, tokens,
client secrets, authorization headers, session IDs, or response bodies.

## Change identification

| Item | Value |
| --- | --- |
| Change/ticket number | |
| Sandbox My Domain | |
| Production My Domain | |
| Implementing admin | |
| Reviewing admin | |
| Security approver | |
| External receiver owner | |
| Planned activation time/time zone | |
| Rollback owner | |

## Package evidence

| Package | Expected version/ID | Installed version | Evidence location | Pass |
| --- | --- | --- | --- | :---: |
| Record Health Check | 2.0.4.2 / `04tak000000cZBFAA2` | | | |
| RHC Integrations | promoted `04t` supplied by release owner | | | |

## Runtime and credential configuration

| Item | Approved value |
| --- | --- |
| Dedicated integration username | |
| RHC Integrations Runtime assigned | Yes / No |
| External Credential label/API name | |
| Authentication protocol | |
| Principal name | |
| Org-owned principal permission set | |
| Principal permission assigned to runtime user | Yes / No |
| Named Credential label | Service Management |
| Named Credential API name | `Service_Management` |
| Approved base URL (no secret) | |

## Subscriber evidence

| Event | Expected trigger | User | Batch | State | Evidence | Pass |
| --- | --- | --- | ---: | --- | --- | :---: |
| Result | `rhc__RHCIntegrationResultSubscriber` | | 100 | Running | | |
| Set Run | `rhc__RHCIntegrationRunSubscriber` | | 100 | Running | | |
| Log | `rhc__RHCIntegrationLogSubscriber` | | 100 | Running | | |

## Human assignments

| Role | Primary user | Backup user | Approved by |
| --- | --- | --- | --- |
| Admin | | | |
| Operator | | | |
| Viewer | | | |

## Route record

| Field | Approved value | Saved value | Reviewer initials |
| --- | --- | --- | --- |
| Route Name | Opportunity Critical Errors to Service Management | | |
| Active before test | false | | |
| Event Types | Result only | | |
| Selection Type | Check Set | | |
| Qualified API Name | `Opportunity_Close_Readiness` or exact namespaced value | | |
| Statuses | Error only | | |
| Minimum Severity | Critical | | |
| Named Credential | `Service_Management` | | |
| Relative Endpoint | `/api/incidents` | | |
| Payload Profile | RHC Error v1 | | |
| Retry Policy | Standard (3 attempts) | | |

## Acceptance evidence

For the complete repeatable procedure and scripts, use the
[demo-data and functional test guide](DEMO-TESTING.md). Do not substitute an `EventBus.publish()`
success message for ledger and receiver evidence.

| Test | Event ID | Expected | Evidence location | Pass |
| --- | --- | --- | --- | :---: |
| 2xx success | | One logical receiver acceptance | | |
| Wrong identity | | No request | | |
| Wrong status | | No request | | |
| Below severity | | No request | | |
| Publication NONE | | No event/no delivery | | |
| Inactive route | | No request | | |
| 503 | | Bounded Standard retries | | |
| 400 | | Immediate dead letter | | |
| Admin replay | | Original Event ID reused | | |
| Operator/Viewer | | No replay/payload exposure | | |
| Receiver dedupe | | Repeated Event ID causes no repeated external work | | |

## Demo scenario evidence

Use this table in a sandbox or disposable verification org. Enter `N/A` only with reviewer approval
and a written reason.

| Scenario | Route/script | Event or Run ID | Ledger evidence | Receiver/UI evidence | Pass |
| --- | --- | --- | --- | --- | :---: |
| A: sanitized UI and roles | seeded dead-letter fixture | `RHC-DEMO-DEAD-LETTER-FIXTURE` | | | |
| B: Error v1 success | Route 01 / `publish-result-critical-error.apex` | | | | |
| C: Outcome v1 exact Check | Route 02 / `publish-result-warning-fail.apex` | | | | |
| D: Run v1 derived ERROR | Route 03 / `publish-run-error.apex` | | | | |
| E: Log v1 minimization | Route 04 / `publish-log-error.apex` | | | | |
| F: reject nonmatch | Routes 01–02 / `publish-nonmatching-result.apex` | | No row | No request | |
| G: Event ID idempotency | Route 01 / `publish-duplicate-result.apex` | | One route/event row | One logical acceptance | |
| H: unsupported contract | Route 01 / `publish-unsupported-contract.apex` | | Terminal dead letter | No request | |
| I: bounded 503 retries | Route 05 / critical-error publisher | | Three attempts maximum | 503 evidence | |
| J: 400 and replay | Route 06 / critical-error publisher | | Dead letter then success | Original Event ID reused | |
| K: real core ACTIONABLE | Route 07 / `run-core-actionable.apex` | | | | |
| L: core Publication NONE | Route 07 / `run-core-publication-none.apex` | | No row | No request | |
| M: incompatible profile | sandbox clone / `publish-run-error.apex` | | No row | No request | |

Cleanup output/evidence location:  
Reviewer name and timestamp:  

## Go-live and rollback

| Gate | Owner | Complete |
| --- | --- | :---: |
| Receiver idempotency accepted in writing | | |
| Security/principal review complete | | |
| Sandbox evidence approved | | |
| Platform/async capacity reviewed | | |
| Dead-letter owner and response target agreed | | |
| Ledger retention period agreed | | |
| Rollback is clear Active on affected route(s) | | |
| Production route activation approved | | |

Final decision: **GO / NO-GO**  
Approver and timestamp:  
Post-activation Event ID and evidence:  
