# Payload contracts

## Contract rules

Payloads are generated only by `RHCIntegrationPayloadBuilder`. Profile names and version `1.0` are
package-owned. There are no templates, merge expressions, class-name hooks, scripts, or customer
code. JSON serialization can include `null` for an allow-listed key when the canonical event lacks
that optional value; the builder never queries another source to fill it.

Every compatible profile contains:

| JSON key | Source |
| --- | --- |
| `payloadProfileVersion` | Packaged profile version, `1.0` |
| `eventContractVersion` | Core event contract |
| `frameworkVersion` | Core framework version |
| `eventType` | Normalized RUN, RESULT, or LOG |
| `eventId` | Canonical Event ID |
| `runId` | Canonical Run ID |
| `occurredAt` | Canonical occurrence time |
| `source` | Canonical source when supplied |

## Profile compatibility and additional keys

| Profile | Compatible input | Additional keys |
| --- | --- | --- |
| RHC Error v1 | Any normalized event with status ERROR | `checkSetQualifiedApiName`, `checkQualifiedApiName`, `status`, `severity`, `reasonCode`, `recordId` |
| RHC Outcome v1 | Result only | Same six outcome keys |
| RHC Run v1 | Run only | `checkSetQualifiedApiName`, `status`, `recordId`, `eligibleCount`, `evaluatedCount`, `passedCount`, `failedCount`, `skippedCount`, `unableCount`, `systemErrorCount` |
| RHC Log v1 | Log only | `code` only beyond common keys |

Incompatible combinations return no payload and therefore create no delivery row. Examples: Run
with RHC Outcome v1, Result with RHC Run v1, or a non-ERROR event with RHC Error v1.

## Example RHC Error v1 request

```json
{
  "payloadProfileVersion": "1.0",
  "eventContractVersion": "1.0",
  "frameworkVersion": "2.0.4",
  "eventType": "RESULT",
  "eventId": "evt-7f6b3",
  "runId": "run-91c2",
  "occurredAt": "2026-08-25T20:14:33.000Z",
  "source": "USER_INITIATED",
  "checkSetQualifiedApiName": "Opportunity_Close_Readiness",
  "checkQualifiedApiName": "Close_Date_Present",
  "status": "ERROR",
  "severity": "CRITICAL",
  "reasonCode": "EVALUATION_ERROR",
  "recordId": "006000000000001AAA"
}
```

JSON object property order is not a contract. Receivers must parse keys by name and tolerate
allow-listed null optional values.

## HTTP request contract

- Method: `POST`
- Endpoint: `callout:<NamedCredential><RelativeEndpoint>`
- Timeout: 20,000 ms
- `Content-Type: application/json`
- `Accept: application/json`
- `Idempotency-Key: <eventId>`
- `X-RHC-Event-ID: <eventId>`

The receiver must use Event ID—not Run ID or Salesforce Replay ID—as its logical idempotency key.

## Explicitly prohibited content

No profile may contain credentials, authorization headers, external response bodies, arbitrary
business-record enrichment, formulas, SOQL results, raw exception messages, stack traces, or
diagnostic JSON. RHC Log v1 specifically excludes Log Message, Exception Type, Stack Trace, Details
JSON, User ID, and Record ID.

Adding a key requires a new reviewed package change. Breaking meaning or removing a key requires a
new profile name/version; do not silently redefine an existing profile.

