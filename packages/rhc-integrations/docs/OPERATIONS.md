# RHC Integrations operations

> Last reviewed: August 25, 2026. For installation and first-time setup, follow the
> [junior administrator click-by-click guide](JUNIOR-ADMIN-GUIDE.md).

## Install and authorize

1. Install promoted Record Health Check 2.0.4.2 (`04tak000000cZBFAA2`).
2. Install the independently created RHC Integrations 2GP version. No other extension is required.
3. Assign `RHC Integrations Admin` to configuration owners, `Operator` to delivery operators,
   `Viewer` to read-only observers, and `Runtime` to the dedicated integration user that owns the
   packaged Platform Event subscriber executions.
4. Create the Named Credential and External Credential in the subscriber org. Store authentication
   only there. Grant its principal access to the dedicated integration user using an
   administrator-owned permission set; this package cannot package access to a credential that does
   not exist until after installation.
5. Create `PlatformEventSubscriberConfig` records for `RHCIntegrationResultSubscriber`,
   `RHCIntegrationRunSubscriber`, and `RHCIntegrationLogSubscriber`, setting their subscriber user
   to that dedicated integration user. Salesforce delivers Apex Platform Event triggers as the
   Automated Process user unless this subscriber configuration is present; relying on that default
   can prevent External Credential principal authorization. Subscriber user IDs are org-specific
   and therefore cannot be packaged. Verify all three configurations before activating a route.
6. Keep delivery-ledger access restricted. The retained allow-listed request exists only for retry
   and replay and is intentionally absent from the Viewer and Operator field permissions and LWC.

## Create the example route

Create an **Record Health Check Integration Route** record with:

| Field | Value |
| --- | --- |
| Active | Off until validation is complete |
| Event Types | Result |
| Selection Type | Check Set |
| Qualified API Name | `Opportunity_Close_Readiness` |
| Statuses | Error |
| Minimum Severity | Critical |
| Named Credential | `Service_Management` |
| Relative Endpoint | `/api/incidents` |
| Payload Profile | RHC Error v1 |
| Retry Policy | Standard |

Confirm the Named Credential base URL, authentication principal, endpoint path, and receiver
idempotency behavior in a sandbox. Then activate the route. The package sends the core Event ID in
both `Idempotency-Key` and `X-RHC-Event-ID`.

`Qualified API Name` matching is case-sensitive and exact. Copy it from Record Health Check setup.
Statuses are exact API values. Severity is ordered `INFO` < `WARNING` < `CRITICAL`; an event without
canonical severity never matches a route that sets Minimum Severity.

## Payload profiles

Profiles are compiled, package-owned allow lists. There is no template interpreter or extension
point for customer code.

| Profile | Compatible input | Version | Contents |
| --- | --- | --- | --- |
| RHC Error v1 | Any canonical event whose derived status is `ERROR` | 1.0 | Common event fields plus public identity/status/severity/reason/record fields when present |
| RHC Outcome v1 | Result | 1.0 | Public Result event contract subset |
| RHC Run v1 | Run | 1.0 | Public Run identity, derived status, and counts |
| RHC Log v1 | Log | 1.0 | Event ID, Run ID, occurrence, event/framework versions, and code only |

Log Message, Exception Type, Stack Trace, Details JSON, User ID, and Record ID are never sent by the
Log profile. External response bodies are never read or retained.

## Retry and dead-letter behavior

| Policy | Maximum attempts | Delays after failed attempts |
| --- | ---: | --- |
| None | 1 | none |
| Standard | 3 | 1, 5 minutes |
| Aggressive | 5 | 1, 2, 5, 10 minutes |

HTTP `408`, `425`, `429`, and `5xx` plus transport failures are retryable. `2xx` is successful.
Other status codes are permanent and enter the dead-letter queue immediately. A `503` therefore
retries; a `400` dead-letters. The ledger stores only a status code and package-owned bounded
classification—not the response body, exception message, or stack trace.

`QUEUEABLE_UNHANDLED` means the Finalizer observed an unexpected worker failure. Preserve the Async
Apex job evidence, correct the cause, and use the guarded replay path; the ledger deliberately does
not retain the exception message or stack trace.

## Replay

1. Correct the Named Credential, External Credential principal, endpoint, network policy, or
   external receiver configuration.
2. Confirm the route is active.
3. Open **RHC Integrations → Dead Letters** as a user assigned `RHC Integrations Admin`.
4. Choose **Replay**. The server verifies `RHC_Integration_Replay`, resets the bounded attempt
   sequence, increments Replay Count, and reuses the original Event ID.

Replay is at-least-once. The receiver must make the Event ID idempotent because an earlier request
may have completed externally even when Salesforce observed a timeout.

## Retention and monitoring

The ledger is operational state, not a reporting warehouse. Monitor dead-letter count, age,
attempts, Platform Event allocations, Queueable backlog, callout limits, and Salesforce storage.
After the organization-defined audit window, an administrator may delete completed ledger rows.
Do not build health trend reports from this object; use an explicitly governed external platform or
the separate reporting extension for that purpose.

Publication `NONE` creates no event and therefore no delivery. Uninstalling RHC Integrations does
not affect core execution or any other extension, but removes its route and delivery data according
to Salesforce package uninstall behavior.

## Limits and interpretation

- Network, DNS, TLS, endpoint availability, external rate limits, and downstream execution are
  outside Salesforce.
- Named Credential, callout, Queueable, Platform Event, and async limits apply.
- HTTP success proves only that the receiver returned success, not that downstream work completed.
- The package cannot send data absent from the core event or prohibited by its security policy.
- Platform Event delivery and cross-system delivery are at-least-once; exactly-once is not
  guaranteed.
