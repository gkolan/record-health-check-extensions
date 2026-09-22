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

The setup assistant now reports `NOTIFICATION_TYPE_UNAVAILABLE` for an active bell policy when the
packaged type cannot be resolved, with a pure unit-test seam for the unavailable branch. Platform
rejection remains an org-side acceptance case, and required test 11 (clean subscriber install)
needs an explicitly authorized `04t`.

## A4 — Send a test alert (added in the second pass)

`RHCAlertsAdminController.sendTestAlert(policyId)` builds an in-memory delivery with
`Status__c = 'TEST'` for the visible policy and sends it through the policy's real channel to the
**current user only**, via the same `RHCAlertsNotificationSender` path production uses. Nothing is
written to Delivery History and no configured recipient is contacted. The policy table gains
**Send test alert to me**, so an administrator can confirm the channel, packaged notification
type, and message shape before activating a policy. Tests:
`shouldSendTestAlertToCurrentUserWithoutLedgerRow`, Jest "sends a test alert for a policy row".

## A5 — Bounded manual delivery retention

Alerts now owns a singleton `Record_Health_Check_Alert_Setting__c` record with a validated 1–3,650
day window. The Administration page requires the window to be saved and permanent deletion to be
acknowledged before cleanup. One run deletes at most 1,000 oldest terminal Delivery rows and never
selects `PENDING`. The controller uses sharing plus user-mode SOQL/DML. No scheduler is included.

Retention and policy-administration behavior are isolated behind focused sharing-enforced services;
the Aura-enabled controller remains the stable thin UI boundary. A focused Recommended Code Analyzer
scan of the controller, services, test, and LWC reports zero findings.

Coverage includes the unsaved 90-day recommendation, saved settings, both range boundaries, the
missing-setting guard, preservation of old `PENDING` and recent terminal rows, and the LWC save and
confirmation paths.

## Backlog

- Automated delivery cleanup remains deferred until scheduling, legal-hold, audit, and operational
  approval requirements are designed. Manual bounded cleanup is implemented.
- Set Run alerts remain `SUPPRESSED / RUN_CONTRACT_INSUFFICIENT` until core publishes an
  aggregate status/severity (see `GAP_ANALYSIS.md`).
