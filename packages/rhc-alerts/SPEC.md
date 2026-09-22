# RHC Alerts specification

## Why this project exists

Core can publish finalized outcomes, but it does not decide who should be interrupted or retain a
notification history. Without an extension, an administrator must build and maintain Platform
Event-triggered Flows or Apex, deduplication, recipient rules, cooldowns, and error handling.

RHC Alerts converts selected core outcomes into human notifications through administrator-approved
Salesforce Custom Notifications and Email Alerts.

The Salesforce bell channel follows the dedicated
[Custom Notification contract](CUSTOM_NOTIFICATIONS_SPEC.md). A bell-shaped core Run button icon is
visual configuration only and is not an Alerts delivery mechanism.

## User value

A junior administrator can choose a Check Set or Check, statuses, minimum severity, recipients,
channel, and cooldown. The package validates exact Qualified API Names, prevents repeated delivery
of one Event ID, and provides a delivery history without exposing restricted result content.

## Dependency on core

RHC Alerts depends only on core and subscribes directly to:

- `Record_Health_Check_Result__e` for Check outcomes; and
- terminal `Record_Health_Check_Set_Run__e` events for run-level conditions.

It uses core identities, status/severity vocabulary, timestamps, Event IDs, and contract versions.
It does not call Run Manager or read Run Manager result objects. Therefore it works for card, Flow,
Apex, or scheduled outcomes whenever the originating core request publishes the required events.

## Owned data and behavior

- Alert Policy: identity/status/severity filters, human recipients, channel, cooldown, active state.
- Alert Delivery: Event ID, policy, recipient count, attempt time, outcome, and bounded error code.
- Alert Setting: one validated administrator-approved retention window for explicit bounded cleanup.
- Deduplication and cooldown state.
- The packaged `RHC_Alert` Custom Notification Type and its safe message/target contract.

It stores no general result history, raw payload, stack trace, or unrestricted found/expected value.

## Example

Maya configures an alert policy:

- Selection Type: **Check**
- Qualified API Name: `Opportunity_Has_Primary_Contact`
- Statuses: `FAIL`, `UNABLE_TO_EVALUATE`, `ERROR`
- Minimum Severity: `CRITICAL`
- Channel: **Salesforce Custom Notification**
- Recipient: **Sales Operations** public group
- Cooldown: 24 hours per Opportunity

When core publishes a matching finalized result, the group receives one notification. Duplicate
delivery of the same event does not notify again, and another matching outcome for the same record
during the cooldown is recorded as suppressed. Maya can explain who was notified and why without
building a Flow.

## Constraints it cannot escape

- No core event means no alert. `NONE` publication is invisible to this package.
- It cannot reconstruct outcomes from before installation.
- Platform Event delivery is asynchronous, at least once, and not a synchronous user guarantee.
- Email, Custom Notification, and Platform Event allocations still apply.
- Recipient access and email deliverability can prevent a successful human delivery.
- A cooldown reduces noise but cannot retract a message already delivered.
- Event ordering across transactions is not guaranteed; policies must use timestamps and idempotency.
- It cannot safely include restricted details that the event does not expose or the recipient should
  not see.

## Boundaries

Alerts serves humans. It does not schedule runs, retain analytical facts, change business records,
or deliver system-to-system webhook payloads. External delivery belongs to RHC Integrations.

## Acceptance criteria

1. It installs with core and without another extension.
2. One core Event ID produces at most one successful delivery per policy and recipient target.
3. Exact namespaced identities and every actionable status are supported.
4. The setup assistant identifies event-publication coverage gaps.
5. Removing Alerts does not change core execution or another extension.
6. Salesforce notification delivery satisfies the Custom Notification contract, including the
   global-bell boundary, safe target fallback, recipient caps, and no-read-receipt semantics.
7. Manual retention cleanup deletes no `PENDING` work and no more than 1,000 oldest eligible
   terminal deliveries per explicit administrator action.
