# RHC Integrations threat model

## Security boundary

RHC Integrations is an outbound, system-to-system subscriber to the three canonical Record Health
Check Platform Events. Its trust boundary starts at an accepted core event and ends at the HTTP
response classification. Authentication and secrets remain in administrator-owned Named
Credentials and External Credentials. The package never offers a fallback credential store.

## Protected assets

- Named Credential and External Credential material, which this package references only by name.
- Event identity and the minimal allow-listed payload derived from the core event.
- Route configuration, delivery state, and the replay permission.
- Salesforce record IDs present in approved event profiles.

## Threats and controls

| Threat | Control |
| --- | --- |
| Secret disclosure | No credential fields exist. Callouts use `callout:<NamedCredential>` only. Response bodies are never read or stored. |
| SSRF or endpoint escape | Named Credential names accept only Salesforce developer-name characters. Endpoints must begin with `/`, cannot contain a scheme, authority, backslash, query, fragment, or `..` segment. |
| Code or template injection | Payload profiles and retry policies are closed Apex allow lists backed by restricted picklists. There are no class-name, script, expression, or template fields. |
| Diagnostic exfiltration | Log payloads omit message, exception type, stack trace, details JSON, user ID, and record ID. Delivery errors contain only bounded package classifications. |
| Duplicate external work | The ledger has a unique route-plus-Event-ID key. Every request sends the canonical Event ID in `Idempotency-Key`. The receiver must enforce it. |
| Retry storm | Retryable classifications are explicit and retries have fixed maximum attempts and bounded delays. Permanent responses dead-letter immediately. |
| Unauthorized replay | Replay requires the packaged `RHC_Integration_Replay` Custom Permission and user-mode record access. Only the Admin permission set grants it. |
| Reporting-data accumulation | The ledger stores only delivery operations and the minimal allow-listed request needed for retry/replay. There are no report types, dashboards, event-history objects, or checked-record updates. |
| Cross-extension privilege | No other extension object or Apex API is referenced. The only package dependency is Record Health Check core. |
| Human-notification side effects | The package contains no email, notification, Chatter, Slack, or checked-record mutation path. |

## Residual risks

Salesforce and an external system cannot provide an atomic exactly-once transaction. Network, DNS,
TLS, Named Credential, endpoint, external rate-limit, Platform Event, Queueable, callout, and async
limits remain outside this package's control. An HTTP success proves only that the receiver returned
a success response; it does not prove downstream completion.

