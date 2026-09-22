# Security and access model

## Identities and trust boundaries

Three identities are distinct:

1. A human Admin configures routes and may replay dead letters.
2. A dedicated Salesforce runtime user owns all three Platform Event subscriber executions and the
   Queueables they enqueue.
3. An External Credential principal represents the external-system authentication identity.

Configure all three Apex subscribers with `PlatformEventSubscriberConfig`. Otherwise Salesforce's
default Automated Process user cannot use the runtime user's permission-set/principal assignment.

## Permission-set matrix

| Capability | Admin | Operator | Viewer | Runtime |
| --- | :---: | :---: | :---: | :---: |
| See RHC Integrations app | Yes | Yes | Yes | No |
| Read routes | All | All | All | All for runtime |
| Create/edit/delete routes | Yes | No | No | No |
| Read sanitized ledger/dead letters | Yes | Yes | Yes | Runtime access |
| Read retained Payload | Yes | No | No | Yes |
| Update delivery state | Yes | No | No | Yes |
| Replay custom permission | Yes | No | No | No |
| Configure and run bounded retention cleanup | Yes | No | No | No |
| Read Run/Result/Log events | Not granted here | No | No | Yes |
| External Credential principal | Separate org-owned assignment only | No | No | Required separately |

Admin's payload field access supports exceptional investigation/deletion, but the packaged LWC and
controller never return it. Limit Admin assignment and avoid copying payloads into tickets or chat.

## Object and execution security

- Route sharing is Read/Write; only Admin has create/edit/delete through packaged permissions.
- Delivery sharing is Private; Admin has Modify All, Operator/Viewer have View All, Runtime has
  View All plus create/edit.
- Dead-letter queries use `WITH USER_MODE` and a DTO projection that omits Payload.
- Replay checks the custom permission, sanitizes the replay-state fields, rejects any stripped
  field rather than performing a partial reset, and performs user-mode query/update.
- Retention management requires setting object and field create/read/edit access plus Delivery
  delete access. Setting writes pass through `Security.stripInaccessible` and user-mode DML;
  queries/deletes also use user mode, and controls are hidden from users without those capabilities.
- Runtime route query intentionally supports Platform Event background processing; route authorship
  remains restricted to admins.
- No permission set contains or can contain a subscriber-specific secret.

## Credential rules

- Use current extensible Named Credentials and External Credentials, not route fields, Custom
  Settings, Custom Metadata, Protected Custom Metadata, or Apex constants, for secrets.
- Store only the Named Credential developer name on the route.
- Assign the External Credential principal to the dedicated runtime user through an org-owned
  permission set.
- Rotate/revoke credentials in the credential facility without changing package records.
- Use a Named Principal for one system identity unless security explicitly requires per-user auth.

## Data minimization

The ledger retains the allow-listed request only because automated retry and authorized replay need
the original versioned request. Reports and search are disabled. Define and save an approved org
retention period, then use the administrator-confirmed, terminal-only, 1,000-row cleanup after the
audit window. Saving settings does not schedule deletion, and active delivery states are excluded.
Do not add report types, trend dashboards, checked-record snapshots, external bodies, or general
health history to this package.

Read the detailed [threat model](THREAT-MODEL.md) and [payload prohibitions](PAYLOAD-CONTRACTS.md).
