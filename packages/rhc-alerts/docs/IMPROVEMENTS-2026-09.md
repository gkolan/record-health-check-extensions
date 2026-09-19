# RHC Alerts — improvement specification (2026-09)

Baseline: 74 components deploy, 50 Apex tests pass, 11 Jest tests pass, zero analyzer findings.
Source reviewed: event service, candidate builder, delivery service/queueable, notification
sender, recipient resolver, admin and viewer controllers, both LWCs.

## A1 — Cross-suite X1: stale policy list and delivery history after writes

**Problem.** `RHCAlertsAdminController.listPolicies` and `RHCAlertsViewerController.listDeliveries`
are `cacheable=true`; `rhcAlertsAdmin` re-reads `listPolicies` after `savePolicy`, and
`rhcAlertsDeliveryHistory` has a Refresh button that calls `listDeliveries` imperatively. Both
return the cached pre-write result.

**Change.** Remove `cacheable=true` from `listPolicies` (admin), `listDeliveries` (admin and
viewer). Keep it on `listSelections`, `listRecipients`, `getLimitInfo`, `analyzeCoverage` — these
are describe/limit reads whose arguments change when the user changes the search.

**Acceptance.** Save a policy → it appears in the table without reload. Refresh → newest delivery
rows appear.

## A2 — Direct record link in email alerts: **rejected during implementation**

The candidate change was to append the org record URL to the email body. `docs/SECURITY.md`
"Message contract" states that the body deliberately does not expose the checked record ID, and
`RHCAlertsNotificationSenderTest` enforces it. Bell notifications navigate through
`setTargetId`, which is subject to the recipient's record access; an email URL would put the ID in
a channel the package does not control. The contract stands; no change was made.

## A3 — Close the remaining gaps against `CUSTOM_NOTIFICATIONS_SPEC.md`

Audit of the bell-notification spec against source: packaged `RHC_Alert` type, sender, direct
group expansion, 500-recipient cap, cooldown, duplicate, and finalizer tests all exist. Two items
were missing and are now done:

- Required test 7 (valid record ID becomes the target; otherwise the packaged Delivery History
  item): `resolveTarget` extracted and covered by
  `shouldTargetRecordWhenIdIsWellFormedOtherwiseDeliveryHistory`.
- Administrator UX: the channel is labelled **Salesforce notification (bell)** with field-level
  help explaining it is an asynchronous Custom Notification; `ADMIN_GUIDE.md` updated.

Still open from that spec: test 10 (notification type absent) cannot be simulated while the type
is packaged metadata; test 11 (clean subscriber install) needs a `04t`.

## A4 — Send a test alert (added in the second pass)

`RHCAlertsAdminController.sendTestAlert(policyId)` builds an in-memory delivery with
`Status__c = 'TEST'` for the visible policy and sends it through the policy's real channel to the
**current user only**, via the same `RHCAlertsNotificationSender` path production uses. Nothing is
written to Delivery History and no configured recipient is contacted. The policy table gains
**Send test alert to me**, so an administrator can confirm the channel, packaged notification
type, and message shape before activating a policy. Tests:
`shouldSendTestAlertToCurrentUserWithoutLedgerRow`, Jest "sends a test alert for a policy row".

## Backlog

- Delivery-ledger retention (unbounded growth today; see suite plan).
- Set Run alerts remain `SUPPRESSED / RUN_CONTRACT_INSUFFICIENT` until core publishes an
  aggregate status/severity (see `GAP_ANALYSIS.md`).
