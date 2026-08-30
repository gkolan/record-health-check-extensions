# RHC Integrations specification

## Why this project exists

Organizations may need critical health outcomes in service management, governance, observability,
or data-quality platforms. Core does not own customer endpoints, authentication, retries, payload
mapping, or delivery history. Building a secure event subscriber and callout pipeline otherwise
requires Apex and operational support.

RHC Integrations routes allow-listed core outcomes to external systems through administrator-owned
Named Credentials and versioned payload profiles.

## User value

An administrator can select a Check Set or Check, statuses, minimum severity, Named Credential,
relative endpoint, packaged payload profile, and retry policy. Authentication stays in Salesforce
Named Credentials. Failed deliveries appear in a controlled dead-letter view with guarded replay.

## Dependency on core

RHC Integrations depends only on core and subscribes directly to finalized Run, Result, and approved
Log events. It uses core Event IDs, Qualified API Names, statuses, severity, timestamps, source, and
contract versions. It never reads Run Manager, Reports, Alerts, or Actions objects.

Only published core events can be delivered. The package cannot observe publication `NONE` or
reconstruct earlier outcomes.

## Owned data and behavior

- Outbound Route: identity/status filters, Named Credential, relative endpoint, payload profile,
  retry policy, and active state.
- Delivery: route, Event ID, payload contract version, attempt count, timestamps, outcome, HTTP
  classification, and bounded error details.
- Queue/retry/dead-letter state and guarded replay.

The package never stores credentials, arbitrary Apex class names, arbitrary templates, unrestricted
response bodies, or raw diagnostic payloads.

## Example

An integration administrator creates the Named Credential `Service_Management`. Maya creates a
route for `Opportunity_Close_Readiness`, status `ERROR`, minimum severity `CRITICAL`, relative
endpoint `/api/incidents`, and payload profile **RHC Error v1**.

When core publishes a matching error, RHC Integrations queues a post-commit callout. The Event ID is
sent as the external idempotency key. A temporary 503 response retries within policy; a permanent
400 response enters the dead-letter view. Maya can inspect the classification and request an
authorized replay after the external configuration is corrected.

## Constraints it cannot escape

- No core event means no outbound delivery.
- Network availability, DNS, TLS, endpoint behavior, and external rate limits are outside Salesforce.
- Exactly-once delivery cannot be guaranteed across two systems. The receiver must honor the Event
  ID idempotency key.
- Named Credential access, Remote Site/security policy, callout, Queueable, Platform Event, and
  asynchronous execution limits apply.
- A successful HTTP response does not prove that the external system completed its downstream work.
- Payload contracts cannot include data absent from the core event or restricted from the route.
- Secrets and endpoint authentication must remain in Named Credentials; package records cannot
  provide a fallback secret store.
- Retry and dead-letter retention consume Salesforce storage and require operational ownership.

## Boundaries

Integrations serves systems, not humans. It does not send Salesforce/email alerts, change checked
records, schedule runs, or own reporting facts. Human notification belongs to RHC Alerts; same-org
corrective Flow execution belongs to RHC Actions.

## Acceptance criteria

1. It installs with core and without another extension.
2. Exact qualified identity and status filters are enforced.
3. One route and Event ID produce at most one externally accepted logical delivery.
4. Authentication is available only through Named Credentials.
5. Restricted content is absent from standard payload profiles.
6. Removing Integrations does not affect core execution or another extension.
