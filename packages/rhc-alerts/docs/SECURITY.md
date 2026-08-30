# RHC Alerts security and threat model

## Trust boundary

The package trusts only promoted core contract `1.0` Platform Events and administrator-saved package
policies. Its boundary ends at Salesforce accepting a Custom Notification or email request. It does
not trust that an event is delivered exactly once, that a recipient still exists, that email reaches
an inbox, or that a notification recipient can access the checked record.

## Protected assets

- Exact health-check identities and record correlation from core events.
- Human recipient choices and public-group membership.
- Delivery and duplicate evidence.
- Salesforce messaging allocations.
- Restricted health-check details that must never enter this package's messages or ledger.

## Access model

| Permission set              | Policy object                                 | Delivery object                                        | Lightning access                                                | Intended user                                    |
| --------------------------- | --------------------------------------------- | ------------------------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------ |
| `RHC Alerts Admin`          | Create/read/edit/delete, View All, Modify All | Read and View All                                      | Administration, history, object tabs                            | Configuration owners and incident administrators |
| `RHC Alerts Viewer Runtime` | Read/View All for policy display name only    | Read/View All for the bounded history field allow list | History tab only; administration and generic object tabs hidden | Auditors and support viewers                     |

Neither permission set grants access to checked business objects. A recipient follows their existing
sharing, CRUD, and field-level security when opening a notification target.

Administrator-facing Apex is `with sharing` and uses `WITH USER_MODE` or user-mode DML. Event and
Queueable services operate in platform context because Platform Event subscribers must claim and
update package-owned ledger rows even when Automated Process cannot be assigned a permission set.
Those services do not query or update checked business records.

The Viewer permission set deliberately omits recipient IDs and labels, routing criteria, internal
delivery/cooldown digests, checked record IDs, run IDs, retry timestamps, and generic object tabs.
It grants only `RHCAlertsViewerController`, whose sole endpoint uses `WITH USER_MODE` and returns the
reviewed operational fields. Policy `DisplayName__c` remains readable so history can name its policy;
recipient-directory and policy-administration endpoints are not on the Viewer Apex surface.

## Threats and controls

| Threat                                                                   | Control                                                                                                                                                                  |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Duplicate Platform Event delivery creates duplicate messages             | Unique SHA-256 Event ID + Policy claim; duplicate insert becomes terminal `DUPLICATE` evidence and is never enqueued                                                     |
| Namespace normalization routes the wrong Check                           | Full Qualified API Name compared exactly and case-sensitively; picker reads core `QualifiedApiName` directly                                                             |
| Restricted result data reaches recipients                                | Message body is compiled from identity, status, and severity only; no payload/value/detail field exists in the ledger                                                    |
| Exception or stack-trace disclosure                                      | Recipient messages never include errors; ledger keeps only closed failure classes and bounded package error codes                                                        |
| Arbitrary recipient or channel injection                                 | Restricted picklists plus server validation permit only User/Regular Public Group and Custom Notification/email                                                          |
| Public Group expands into unintended principals                          | Resolver accepts only `Group.Type = 'Regular'` and only direct active User member IDs; nested groups, roles, queues, and inactive users are ignored                      |
| Recipient amplification exceeds platform limits                          | Package caps of 500 Custom Notification recipients and 10 email recipients; resolver and Queueable queries are bounded                                                   |
| One event matches an unbounded number of policies                        | Subscriber inserts at most 2,000 claims per trigger transaction and adds one `FAILED / LIMIT / EVENT_POLICY_FANOUT_LIMIT` evidence row when more work is dropped         |
| Alert storm across repeated events                                       | Per-policy and checked-record cooldown using canonical occurrence time plus policy row locking                                                                           |
| Queue dispatch or unhandled Queueable failure strands `PENDING` rows     | Dispatch failure is converted to `QUEUE_ENQUEUE_FAILED`; a Queueable Finalizer converts rows still pending after an unhandled exception to `QUEUEABLE_UNHANDLED_FAILURE` |
| Partial email audience succeeds while ledger says the attempt failed     | Email submission uses all-or-none platform acceptance for the policy audience                                                                                            |
| Checked record mutation                                                  | No business-object dynamic DML or update path; `RecordId__c` is text correlation and optional notification target only                                                   |
| Cross-extension privilege coupling                                       | Sole 2GP dependency is core; no Run Manager, Reports, Actions, Integrations, or Builder metadata/API reference                                                           |
| External exfiltration                                                    | No HTTP, Named Credential, webhook, callout, Slack, or system-to-system delivery path                                                                                    |
| Viewer cannot see platform-owned ledger rows, or receives edit privilege | Viewer gets View All only on the two private package objects; create/edit/delete/Modify All remain false                                                                 |

## Message contract

Custom Notification title and email subject are `Record health check alert`. The body format is:

```text
Health check <exact identity> reported <status> (<severity>). Open Salesforce to review the record if you have access.
```

The severity parentheses are omitted when no canonical severity is present. The body does not expose
the checked record ID. A Custom Notification can target the checked record for navigation; Salesforce
still enforces the recipient's access when they try to open it.

## Residual risks

- Salesforce Platform Event delivery is asynchronous and at least once.
- Email acceptance does not guarantee inbox placement; Custom Notification acceptance does not
  guarantee that a user reads it.
- Cross-transaction ordering is not guaranteed. Cooldown uses event time and idempotency uses Event
  ID, but a very late older event can still be evaluated after a newer event.
- Administrators with broader Salesforce privileges can query or change package data outside the
  packaged UI and permission sets.
- The platform validation rules enforce required values, canonical statuses, recipient-ID shape,
  and nonnegative cooldowns on generic edits, but only the packaged picker verifies that an exact
  current core definition and Regular public group were selected.
- The package does not provide a read receipt, escalation chain, acknowledgment workflow, or pager
  integration.
- The package has no automated ledger purge in `0.1.0`; storage retention is an org governance task.

## Security review checklist

Before release, verify:

1. Production classes expose no raw event or exception payload.
2. All administrator SOQL/DML remains user mode.
3. Runtime SOQL/DML targets only package objects and User/Group directories.
4. Recipient and channel values remain closed allow lists.
5. Permission sets grant no checked-record access.
6. Code Analyzer has zero Recommended findings at every severity.
7. Duplicate and exact-namespaced-identity tests pass.
8. Clean-org installation requires only promoted core.
