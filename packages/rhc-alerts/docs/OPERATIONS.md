# RHC Alerts operations runbook

For first-time setup, follow the [junior administrator guide](../ADMIN_GUIDE.md). This runbook is for
ongoing monitoring, incident response, limits, and support handoff.

## What to monitor

| Signal                                  | Where                                                    | Healthy interpretation                                                                                                         |
| --------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Recent delivery outcomes                | RHC Alerts → RHC Alerts Delivery History                 | Expected mix of `DELIVERED`, deliberate `SUPPRESSED`, and rare `DUPLICATE`; no unexplained `PENDING` or growing `FAILED` count |
| Queueable execution                     | Setup → Apex Jobs                                        | RHC Alerts delivery jobs complete and backlog does not grow                                                                    |
| Email configuration                     | Setup → Deliverability                                   | Access level supports the intended environment; sandbox restrictions are understood                                            |
| Platform Event and messaging allocation | Setup → Company Information and org monitoring           | Allocations have headroom for expected event and recipient volume                                                              |
| Policy publication coverage             | RHC Alerts Administration → Analyze publication coverage | No unresolved ERROR or WARNING for policies expected to receive interactive runs                                               |
| Salesforce storage                      | Setup storage pages and package object row counts        | Delivery ledger growth remains inside the organization's approved operational retention plan                                   |

The history component returns the newest 500 rows. Use the package object tab, a report, or authorized
data tooling when an investigation needs older rows.

## Outcome response

### PENDING

`PENDING` normally means a newly claimed row or a bounded retry scheduled at `NextRetryAt__c`.

1. Click **Refresh** after the retry time.
2. Open **Setup → Apex Jobs** and find recent `RHCAlertsDeliveryQueueable` jobs.
3. Confirm the selected policy still exists and is active.
4. If the row remains PENDING after jobs stop, capture the delivery number, timestamps, attempts,
   policy, and bounded error fields for engineering. Do not copy restricted business data into the
   support ticket.

### DELIVERED but the person saw nothing

`DELIVERED` means Salesforce accepted the send request, not that it was read.

For Custom Notification:

1. Confirm the intended active User was selected or was a direct active member of the public group at
   delivery time.
2. Ask the user to check the Salesforce notification bell and mobile notification settings.
3. Confirm the user can access the target record; record access is not granted by Alerts.

For Email:

1. Confirm the User record has the intended email address.
2. Check **Setup → Deliverability**.
3. Check sandbox email rewriting, spam quarantine, corporate mail gateway rules, and daily email
   limits.

### SUPPRESSED

| Suppression                 | Explanation                                                                      | Response                                                                   |
| --------------------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `COOLDOWN`                  | Same policy and checked record had a successful delivery inside Cooldown Minutes | Expected noise control; reduce cooldown only with business-owner approval  |
| `POLICY_INACTIVE`           | Policy was deactivated after the event claim but before delivery                 | Expected; no message was sent                                              |
| `RUN_CONTRACT_INSUFFICIENT` | Matching Set Run event lacks canonical aggregate severity/status                 | Informational evidence; Check Set alerts come from Result events           |
| `NO_RECIPIENTS`             | Reserved package value                                                           | In 0.1.0, recipient-resolution problems are configuration failures instead |

### DUPLICATE

No action is normally required. It proves at-least-once redelivery was blocked by the unique Event ID
and Policy claim. Investigate only if duplicate volume rises sharply, which can indicate upstream
replay or Platform Event delivery behavior worth correlating with core event IDs.

### FAILED

Use `FailureClass__c` first, then `ErrorCode__c`. Codes are deliberately safe to place in support
cases.

| Failure class   | Error code                            | Meaning                                                                                                     | Administrator response                                                                                                    |
| --------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `CONFIGURATION` | `INVALID_RECIPIENT_ID`                | Stored target is blank, malformed, or no longer a Salesforce ID                                             | Edit the policy and reselect a recipient                                                                                  |
| `CONFIGURATION` | `RECIPIENT_USER_UNAVAILABLE`          | User is missing or inactive                                                                                 | Select an active User                                                                                                     |
| `CONFIGURATION` | `UNSUPPORTED_RECIPIENT_TYPE`          | Policy contains a value outside the closed allow list                                                       | Recreate or correct the policy through the packaged UI                                                                    |
| `CONFIGURATION` | `PUBLIC_GROUP_UNAVAILABLE`            | Group is missing or is not a Regular public group                                                           | Select an available Public Group                                                                                          |
| `CONFIGURATION` | `NO_DIRECT_ACTIVE_USERS`              | Group contains no direct active User members                                                                | Add direct active Users or select a User                                                                                  |
| `CONFIGURATION` | `POLICY_UNAVAILABLE`                  | The policy was deleted after the event claim and before delivery                                            | No retry occurs; create a replacement policy and publish only a new controlled Event ID if notification is still required |
| `LIMIT`         | `CUSTOM_NOTIFICATION_RECIPIENT_LIMIT` | More than 500 direct recipients resolved                                                                    | Split the audience across smaller public groups and policies                                                              |
| `LIMIT`         | `EMAIL_RECIPIENT_LIMIT`               | More than 10 direct recipients resolved                                                                     | Split the audience or use Custom Notification if appropriate                                                              |
| `LIMIT`         | `EVENT_POLICY_FANOUT_LIMIT`           | One trigger batch exceeded the 2,000 policy-claim safety cap; later matches in that batch were not claimed  | Reduce active policies per identity or upstream event batch size, then publish new controlled events for omitted work     |
| `LIMIT`         | `QUEUE_ENQUEUE_FAILED`                | The subscriber could not enqueue the delivery worker within the transaction's Queueable limit               | Correlate Apex Jobs and other automation in the event transaction; publish a new Event ID after capacity is restored      |
| `PERMANENT`     | `NOTIFICATION_TYPE_UNAVAILABLE`       | Packaged notification type cannot be found                                                                  | Verify package metadata/install integrity; escalate to release admin                                                      |
| `PERMANENT`     | `UNSUPPORTED_NOTIFICATION_CHANNEL`    | Policy contains a channel outside the allow list                                                            | Correct the policy through the packaged UI                                                                                |
| `PERMANENT`     | `EMAIL_PLATFORM_REJECTED`             | Salesforce rejected one or more email requests                                                              | Check deliverability, addresses, and email allocations                                                                    |
| `PERMANENT`     | `PLATFORM_DML_FAILURE`                | Salesforce rejected a platform delivery-related DML operation                                               | Correlate with Apex Jobs and Salesforce status; escalate if repeatable                                                    |
| `PERMANENT`     | `PLATFORM_DELIVERY_FAILURE`           | Unexpected delivery API failure was safely classified                                                       | Retry with a new controlled event after checking Salesforce status; escalate if repeatable                                |
| `PERMANENT`     | `CLAIM_INSERT_FAILED`                 | A policy/event claim failed for a reason other than duplicate and sanitized fallback evidence was retained  | Check field/package integrity and Apex Jobs; escalate with the bounded row fields                                         |
| `PERMANENT`     | `QUEUEABLE_UNHANDLED_FAILURE`         | A Queueable ended with an unhandled exception and its Finalizer terminally dispositioned rows still pending | Correlate the delivery and failed Apex Job; fix the underlying fault before publishing a new Event ID                     |
| `TRANSIENT`     | `UNABLE_TO_LOCK_ROW`                  | A retryable lock conflict occurred in a classified delivery operation                                       | Package retries up to three attempts; investigate sustained contention                                                    |

If claim evidence itself, Queueable-dispatch failure updates, ledger updates, or Finalizer recovery
cannot be persisted, the bounded internal codes `CLAIM_EVIDENCE_INSERT_FAILED`,
`QUEUE_FAILURE_UPDATE_FAILED`, `LEDGER_UPDATE_FAILED`, or
`QUEUEABLE_RECOVERY_UPDATE_FAILED` appear on the failed Apex job rather than a ledger row. Treat any
of these as a package-integrity incident; capture the Apex Job ID and do not replay the same Event ID.

## Publication incident: no delivery row exists

Absence of a ledger row is different from a failed delivery. Work in this order:

1. Confirm the policy was active before the event.
2. Confirm exact Check or Check Set identity, matching status, and minimum severity.
3. Run **Analyze publication coverage**.
4. For interactive runs, confirm **Publish User Result Event** on the relevant core Check metadata.
5. For programmatic runs, confirm the caller requested `ACTIONABLE` or `ALL`. `NONE` produces no
   event and no Alerts evidence.
6. Confirm the core Result event was published using approved core observability or test tooling.
7. Check Apex trigger and Queueable failures in Setup.

Do not “fix” missing publication by reading another extension's result tables. Alerts intentionally
subscribes to canonical core events only.

## Policy change procedure

The guided Administration card applies server validation and exact core/recipient pickers when
creating a policy. Platform validation rules also protect generic edit/API paths from missing
values, noncanonical status lists, mismatched recipient-ID shapes, and negative cooldowns. Generic
edits still cannot verify that a Qualified API Name exists in the current core metadata or that a
`00G` ID is a Regular public group, so use a replacement for routing or matching changes.

1. Create an inactive replacement through **RHC Alerts Administration** with the approved new
   identity, status, severity, recipient, channel, or cooldown.
2. During the change window, open the old policy through **Record Health Check Alert Policies** and
   change only **Active** to off.
3. Open the replacement and change only **Active** to on.
4. Run publication coverage analysis.
5. Perform a sandbox or controlled-record test.
6. Record the replacement and old-policy deactivation in the organization's normal change log.

Do not directly edit routing or matching fields on the generic object page. A future UI can add a
validated edit action; version `0.1.0` provides validated creation and generic Active toggling.

Existing claimed rows resolve the policy again at delivery time. Deactivating a policy can therefore
turn a queued claim into `SUPPRESSED / POLICY_INACTIVE`.

## Retention and uninstall

Delivery rows are operational evidence, not analytical history. Version `0.1.0` does not ship an
automated purge job and the packaged Admin permission set intentionally does not grant delivery-row
delete. Define an organization retention period before production. If deletion is required, use a
separately authorized data administrator and approved tooling; never delete PENDING rows during an
incident.

Uninstalling RHC Alerts removes its package metadata and package-owned data according to Salesforce
package uninstall behavior. It does not change core or another extension. Export only the bounded
ledger fields your audit policy permits before uninstall.

## Support evidence checklist

Provide these safe facts when escalating:

- Package version and core package version.
- Delivery number, Event ID, Run ID, Event Type, exact Check/Check Set identity.
- Outcome, suppression reason, failure class, error code, attempt count, and timestamps.
- Policy name, channel, recipient type, recipient count, cooldown, and active state.
- Related Apex Job status and time.
- Whether the run was interactive or programmatic and its requested publication mode.

Do not include raw result payloads, found/expected values, stack traces, unrestricted exception text,
or sensitive business-record fields.
