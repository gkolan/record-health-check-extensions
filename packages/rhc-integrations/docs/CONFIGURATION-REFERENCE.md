# Configuration and data reference

## Record Health Check Integration Route (`Record_Health_Check_Integration_Route__c`)

Routes are administrator-authored configuration. The object has Read/Write sharing, field history
on the security-sensitive text fields and Active, no activities, no feeds, and no reporting.

| UI field | API name | Required/default | Exact behavior |
| --- | --- | --- | --- |
| Route Name | `Name` | Required | Human-readable operational name; never used for matching |
| Active | `Active__c` | Default false | Only active routes are queried; clear it to stop accepting new events |
| Event Types | `EventTypes__c` | Required; Result default | Multi-select of Run, Result, Log; event must match one selected API value |
| Selection Type | `SelectionType__c` | Required; Check Set default | Chooses which event identity is compared: Check Set or Check |
| Qualified API Name | `QualifiedApiName__c` | Required, Text(120) | Exact, case-sensitive equality including namespace when present |
| Statuses | `Statuses__c` | Required; Error default | Multi-select of Pass, Fail, Skipped, Unable to Evaluate, Error |
| Minimum Severity | `MinimumSeverity__c` | Optional | `INFO < WARNING < CRITICAL`; blank accepts any severity; configured minimum rejects missing severity |
| Named Credential | `NamedCredential__c` | Required, Text(80) | Developer/API name only; letters first, then letters/numbers/underscores |
| Relative Endpoint | `RelativeEndpoint__c` | Required, Text(255) | Appended to Named Credential base URL; must begin `/` |
| Payload Profile | `PayloadProfile__c` | Required; RHC Error v1 default | Closed packaged allow-list; incompatible event/profile produces no delivery |
| Retry Policy | `RetryPolicy__c` | Required; Standard default | Closed packaged retry schedule |

### Endpoint validation

Accepted: `/api/incidents`, `/v1/rhc/errors`.

Rejected: full URLs, `//host/path`, backslashes, query strings, fragments, and any `..` substring.
Runtime repeats these checks before each callout, so a bad route fails safely even if metadata or
data loading bypasses the UI validation rule.

The validation rule and runtime check both reject a leading double slash; an authority-style path
must never rely on receiver or Named Credential URL normalization.

### Matching truth table

Every condition is ANDed. Multi-select choices are ORed inside their field.

| Condition | Required result |
| --- | --- |
| Route active | true |
| Event type | selected in Event Types |
| Identity | exact selected Check Set/Check identity |
| Status | selected in Statuses |
| Severity | at least Minimum Severity, or minimum blank |
| Profile | compatible with event shape |

Result is the complete identity/status/severity routing event. Run has Check Set identity and a
derived status but no severity. Log has developer names rather than canonical qualified identities,
is mapped to status ERROR, and has no severity. See [core-event gaps](CORE-EVENT-GAP-ANALYSIS.md).

## Delivery ledger (`Record_Health_Check_Integration_Delivery__c`)

The ledger is private operational state, not a reporting dataset. Search and reports are disabled.
The parent Route lookup uses Restrict delete. The auto-number is `RHCD-{00000000}`.

| Field | API name | Purpose |
| --- | --- | --- |
| Delivery Number | `Name` | Immutable human reference |
| Route | `Route__c` | Required lookup to accepting route |
| Event ID | `EventId__c` | Canonical application event ID and outbound idempotency value |
| Route Event Key | `RouteEventKey__c` | Required unique external ID, `routeId:eventId` |
| Event Type | `EventType__c` | RUN, RESULT, or LOG |
| Event Contract Version | `ContractVersion__c` | Core event contract accepted at ingestion |
| Payload Profile | `PayloadProfile__c` | Profile name frozen for the attempt/replay |
| Payload Profile Version | `PayloadProfileVersion__c` | Currently `1.0` |
| Payload | `Payload__c` | Allow-listed JSON retained only for retry/replay; hidden from Viewer/Operator/LWC |
| Status | `Status__c` | Pending, Retry Wait, Succeeded, or Dead Letter in current runtime |
| Attempt Count | `AttemptCount__c` | Attempts in the current original/replay sequence |
| Replay Count | `ReplayCount__c` | Authorized manual replay count |
| Last Attempt At | `LastAttemptAt__c` | Most recent callout start time |
| Next Attempt At | `NextAttemptAt__c` | Earliest scheduled retry time |
| Completed At | `CompletedAt__c` | Success or terminal dead-letter time |
| HTTP Status | `HttpStatus__c` | Numeric status only; null for transport/configuration failures |
| HTTP Classification | `HttpClassification__c` | Bounded SUCCESS, RETRYABLE, TRANSPORT, or PERMANENT value |
| Error Code | `ErrorCode__c` | Package-owned bounded code such as `HTTP_400` |
| Error Detail | `ErrorDetail__c` | Package-owned guidance; never raw external or Apex diagnostic text |

`DELIVERING` exists in the restricted Status picklist but the current runtime does not persist that
value; callout and final ledger update occur in one Queueable transaction. Operators must not build
automation that expects `DELIVERING`.

## Integration setting (`Record_Health_Check_Integration_Setting__c`)

The package supports one administrator-managed record whose Name and Setting Key are both
`Default`. Only `RHC Integrations Admin` receives create/read/edit access; the setting cannot be
deleted through that permission set. Operator, Viewer, and Runtime receive no access.

| Field | API name | Purpose |
| --- | --- | --- |
| Setting Name | `Name` | Fixed singleton identity `Default` |
| Setting Key | `SettingKey__c` | Unique external key fixed to `Default` |
| Retention Days | `RetentionDays__c` | Whole days from 1 through 3,650 before completed terminal deliveries become eligible for manual cleanup |

The unsaved value of 90 days is a recommendation, not deletion authorization. Saving the setting
does not create a schedule. Each separately confirmed purge deletes at most 1,000 oldest rows whose
status is `SUCCEEDED` or `DEAD_LETTER` and whose Completed At precedes the cutoff.

## Complete example

| Field | Value |
| --- | --- |
| Route Name | Opportunity Critical Errors to Service Management |
| Active | true after sandbox acceptance |
| Event Types | Result |
| Selection Type | Check Set |
| Qualified API Name | `Opportunity_Close_Readiness` |
| Statuses | Error |
| Minimum Severity | Critical |
| Named Credential | `Service_Management` |
| Relative Endpoint | `/api/incidents` |
| Payload Profile | RHC Error v1 |
| Retry Policy | Standard (3 attempts) |
