# RHC Alerts Salesforce Custom Notification contract

## Purpose

This contract defines the Salesforce bell-notification channel owned by RHC Alerts. It supplements
the package-wide [Alerts specification](SPEC.md); it does not create a separate extension.

The channel sends selected finalized core outcomes to active Salesforce users through Salesforce
Custom Notifications. The notification appears in Salesforce's notification experience, including
the global bell where supported by the recipient's client and org configuration.

## Terminology and icon boundary

Three distinct concepts must not be conflated:

| Concept                              | Owner                    | Contract                                                                                                                  |
| ------------------------------------ | ------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| Salesforce global notification bell  | Salesforce platform      | Alerts can send a Custom Notification but cannot replace, recolor, badge, or otherwise control the global bell UI         |
| `RHC Alert` Custom Notification Type | RHC Alerts               | Packaged metadata enables desktop and mobile delivery                                                                     |
| Core Run/Rerun button glyph          | Record Health Check core | Administrators may set `RunButtonIcon__c` to `utility:notification`; that changes only the action glyph and sends nothing |

RHC Alerts must never imply that selecting a bell-shaped Run button icon activates notification
delivery. Delivery requires an active Alert Policy, matching published core event, valid recipients,
and successful Salesforce platform acceptance.

## Packaged metadata contract

The package owns one `CustomNotificationType`:

| Property       | Required value |
| -------------- | -------------- |
| Developer Name | `RHC_Alert`    |
| Master Label   | `RHC Alert`    |
| Desktop        | Enabled        |
| Mobile         | Enabled        |

Changing the Developer Name is a breaking package change because Apex resolves it at runtime.
Metadata does not grant recipient access, ensure mobile push settings, or guarantee that a recipient
reads the message.

## Policy contract

`NotificationChannel__c = CUSTOM_NOTIFICATION` selects this channel. The policy must already pass
the package-wide exact identity, status, severity, active-state, duplicate, and cooldown rules.

Supported recipient targets are:

- one active Salesforce User; or
- direct active User members of one Regular public Group.

Nested groups, roles, role-and-subordinate groups, queues, territories, inactive users, external
addresses, arbitrary ID text, and user-provided Apex recipient resolvers are not supported in the
initial contract.

## Message contract

The initial title is:

```text
Record health check alert
```

The body is:

```text
Health check <exact identity> reported <status> (<severity>). Open Salesforce to review the record if you have access.
```

Severity parentheses are omitted when the canonical event has no severity. The title and body are
plain text. Implementation must verify current platform title/body limits and truncate only at safe,
documented boundaries; it must never split a surrogate pair, invent a status, or omit the identity
to make an oversized message fit.

Messages exclude:

- record IDs in visible text;
- Found and Expected values;
- display messages and Action URLs;
- diagnostics, exception messages, or stack traces;
- recipient email addresses; and
- raw Platform Event payloads.

## Navigation target

When `RecordId__c` is a syntactically valid 15- or 18-character Salesforce ID, Alerts sets it as the
Custom Notification target. Salesforce still enforces the recipient's record access when the target
is opened. Delivery acceptance must not be described as proof of target access.

When no valid record target exists, the notification points to the packaged Alerts Delivery History
navigation item. The target must never be an administrator-entered URL, JavaScript URI, arbitrary
page reference, or core event Action URL.

## Delivery semantics

1. A unique Event ID + Policy claim is inserted before asynchronous delivery.
2. Policy active state and cooldown are rechecked at delivery time.
3. Recipients are resolved again at delivery time so inactive users are excluded.
4. The package creates `Messaging.CustomNotification`, assigns the packaged type, safe title/body,
   and approved target, then sends to the bounded recipient-ID set.
5. `DELIVERED` means Salesforce accepted the send request. It does not mean that a push notification
   reached a device, that the bell displayed a badge, that the recipient opened it, or that the
   recipient acted.
6. Duplicate, suppressed, failed, and retry states follow the package-wide delivery ledger contract.

The package cap is 500 Custom Notification recipients per attempt. Before release, tests must also
confirm current Salesforce limits for the pinned API version and choose the lower of the platform
limit and the package cap.

## Failure classification

| Condition                                    | Required outcome                                                                                                              |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Notification type missing or renamed         | Terminal configuration failure                                                                                                |
| No eligible active recipients                | Suppressed or configuration failure according to the package-wide normalized contract; one behavior must be used consistently |
| Recipient count exceeds package/platform cap | Terminal limit failure; never silently truncate recipients                                                                    |
| Invalid checked-record target                | Use the approved Delivery History fallback, not an arbitrary target                                                           |
| Salesforce rejects the send                  | Bounded platform failure; raw exception text is not stored                                                                    |
| Transient row-lock conflict before send      | Retry within the package-wide bounded policy                                                                                  |
| Uncertain failure after send                 | Do not claim exactly-once human delivery; idempotency prevents a new event claim but operations must see the uncertainty      |

No automatic fallback to email occurs unless the policy explicitly supports a future separately
specified multi-channel mode. Silent fallback changes audience expectations and allocation use.

## Security and privacy constraints

- Recipient access is independent from policy-admin access.
- Permission sets do not grant access to checked business records.
- A notification target never bypasses Salesforce sharing, CRUD, or FLS.
- Group expansion is direct, bounded, and restricted to active users.
- Message contents use canonical minimal event facts only.
- No read receipt or engagement tracking is claimed or inferred.
- A sender-visible Delivery ledger row contains recipient count, not the full resolved recipient list.
- Mobile and desktop delivery remain subject to Salesforce, device, browser, and user settings.

## Accessibility and administrator UX

- The policy UI labels the channel **Salesforce notification (bell)** and explains that it is an
  asynchronous Custom Notification.
- Preview text must match the safe production formatter.
- The UI must not use the bell glyph as the only channel label; visible text and an accessible name
  are required.
- Setup diagnostics distinguish notification-type availability, recipient validity, event
  publication coverage, and platform acceptance.
- Documentation explains that core's `utility:notification` Run-button icon is unrelated.

## Required tests

1. Packaged `RHC_Alert` type resolves in a clean subscriber installation.
2. One active User receives one accepted send for one unique event-policy claim.
3. A Regular public Group expands only direct active User members.
4. Inactive, nested-group, role, queue, and malformed recipients are rejected or ignored according
   to the recipient contract.
5. Duplicate delivery cannot produce a second send.
6. Cooldown suppresses a later matching event for the same policy and record.
7. A valid record ID becomes the target; a missing/invalid ID uses the fixed Delivery History target.
8. Titles and bodies contain no restricted values or record ID text and stay within verified limits.
9. Recipient overflow fails without truncation.
10. Notification-type absence, platform rejection, row lock, and unknown exception use bounded codes.
11. Desktop and mobile metadata deploys and installs in a clean subscriber org.
12. Delivery history and UI never claim that `DELIVERED` means read.

## Official Salesforce reference

- [Messaging.CustomNotification Apex Reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Messaging_CustomNotification.htm)
  — official Apex reference for the class used to assign the notification type, title, body,
  target, and recipients. The public page is shell-rendered, so exact method and limit behavior must
  also be compile-tested against the package's pinned API version.
- [Lightning icon component](https://developer.salesforce.com/docs/platform/lightning-component-reference/guide/lightning-icon.html)
  — developer documentation for SLDS `icon-name` rendering. This supports the distinction between a
  configurable visual icon and Custom Notification delivery; it does not make an icon send a
  notification.

The implementation must recheck `Messaging.CustomNotification` methods and current limits during
release validation.

The setup assistant reports `NOTIFICATION_TYPE_UNAVAILABLE` when an active bell policy exists but
the packaged type cannot be resolved. Unit tests exercise that diagnostic through a pure availability
seam; clean-subscriber installation remains the authoritative proof that packaged metadata resolves.
