# RHC Change Monitor administrator guide

> [!WARNING]
> This workflow describes the current implementation preview and its acceptance testing. There is
> no installable RHC Change Monitor package yet, and the remaining release gates still prohibit
> production use.

## Roles

| Role | Responsibility |
| --- | --- |
| Salesforce administrator | Reviews CDC eligibility, enables selected entities, and manages package permissions |
| Record Health Check administrator | Activates and validates the selected Check or Check Set |
| Change Monitor administrator | Creates policies, validates adapters and runtime identity, and monitors claims |
| Salesforce developer | Reviews and deploys subscriber-owned change-event triggers when required |
| Operations owner | Monitors gaps, failures, allocation pressure, and event amplification |

One person can hold multiple roles, but the setup screens and permission sets must not assume that
every Record Health Check user can enable CDC or author Apex.

## Before enabling a source entity

1. Confirm CDC is appropriate instead of a scheduled scan or ordinary record-triggered automation.
2. Estimate daily creates, updates, deletes, undeletes, batch loads, and ETL changes for the entity.
3. Review the org's CDC and Platform Event allocations and all existing subscribers.
4. Confirm that automatic reruns after every matching change will not create unacceptable Check,
   query, Queueable, result-event, alert, report, action, or integration volume.
5. Test the exact core Check or Check Set manually under the proposed runtime principal.
6. Decide whether result publication should be `NONE`, `ACTIONABLE`, or `ALL`.
7. Name the operations owner who will respond to gaps and terminal failures.

## Setup workflow for source and subscriber-adapter testing

### 1. Enable Salesforce CDC deliberately

In Setup, open **Change Data Capture**, select only the approved source entity, and save. Do not
select every available entity for convenience. Record the approval, estimated volume, and rollback
plan outside the package.

### 2. Install or deploy the intake adapter

The package intentionally has no object-specific adapter. A developer can generate the exact CDC
channel member and thin trigger in the subscriber repository:

```bash
cd packages/rhc-change-monitor
npm run adapter:generate -- \
  --object Account \
  --output /path/to/subscriber-repo/force-app/main/default
```

The generator uses the installed `rhc` namespace by default. `--namespace none` exists only for
source-deployment verification. Review the generated source, add the object-specific contract test,
and deploy it through the organization's normal lifecycle. The command refuses to overwrite existing
files unless `--force` is explicit. An administrator cannot manufacture or deploy this Apex from a
text field.

### 3. Establish the runtime principal

Change-event triggers, and any Queueable they start, always run as **Automated Process**. Assigning
permission sets to that user does not grant it custom permissions (verified 2026-09-18), so the
intake trigger only records claims and publishes the package's `Record Health Check Change
Dispatch` event. The dispatch event's trigger, `RHCChangeMonitorDispatchSubscriber`, is where the
principal is chosen:

1. Create a dedicated integration user (no interactive login needed) and assign
   **RHC Change Monitor Runtime** plus core **Record Health Check User**.
2. Deploy a `PlatformEventSubscriberConfig` for `RHCChangeMonitorDispatchSubscriber` naming that
   user (template: `subscriber-app/main/default/platformEventSubscriberConfigs/`). Never put a
   username in package metadata.
3. If the trigger was already active before the config existed, deactivate and reactivate it once
   so the subscription restarts under the configured user.
4. Open the **RHC Change Monitor** app. The console shows a warning while claims fail with
   `RUNTIME_PERMISSION_MISSING`; after the config is in place, use **Retry failed claims**.

Intake and retry treat immediate rejection of the package dispatch event as a failed transaction.
New claims are rolled back, and retried claims keep their prior failed state, so the console never
reports work as pending solely because Salesforce rejected the wake-up signal synchronously.
If pending claims later remain while no dispatcher is queued, use **Dispatch pending claims** to
publish another data-free wake-up signal. This is an idempotent recovery request; it does not edit
claims and is not a substitute for reconciling a CDC gap.

Then confirm in the console or the setup identity probe:

- effective User ID and user type;
- core Apex access;
- Record Health Check Run custom-permission outcome;
- source object and required field access; and
- one controlled positive and one controlled negative access result.

Do not activate a policy when the principal is unknown, excessively privileged, or lacks required
access. Never solve this by granting broad administrator access without a security review.

### 4. Create the policy

Choose:

1. a source object;
2. **Check** or **Check Set**;
3. the exact Qualified API Name from the core picker;
4. CREATE, UPDATE, and/or UNDELETE;
5. optional UPDATE field names from the schema-backed picker; and
6. an explicit event-publication mode.

The setup assistant must prevent free-form identities when an authoritative picker is available.
It must reject a Check Set targeted at a different object.

### 5. Review the activation analysis

Activation stays unavailable until all errors are resolved. Warnings require explicit review:

- CDC or result-event allocation pressure;
- `ALL` publication amplification;
- more than five policies for one source object;
- no UPDATE field filter on a high-volume entity;
- subscriber-owned adapter requiring lifecycle ownership;
- unsupported DELETE behavior; and
- manual retention cleanup only; no automated ledger deletion job.

### 6. Test in a sandbox

Exercise this matrix before production:

| Test | Expected evidence |
| --- | --- |
| CREATE | One accepted claim and one core run |
| UPDATE matching a selected field | One accepted claim and one core run |
| UPDATE changing only an unselected field | Terminal ignored claim or documented no-claim metric; no core run |
| UNDELETE | One accepted claim and one core run |
| DELETE | `IGNORED / RECORD_DELETED`; no core run |
| Duplicate event delivery | Duplicate evidence; no second core run |
| Inaccessible record/field | Core's documented user-mode outcome; no privilege escalation |
| Policy deactivated before dispatch | Terminal policy-inactive outcome; no core run |
| Invalid selection after metadata change | Bounded configuration failure visible to operations |
| Gap or overflow signal | High-priority incident and automatic dispatch stopped for affected scope |

Verify resulting RHC Alerts or other event consumers separately; Change Monitor does not prove that
downstream automation completed.

## Production operations

- Review terminal failures and gaps every business day while the feature is new.
- Trend accepted changes, evaluated records, duplicates, ignored deletes, and actionable results.
- Re-run setup analysis after permission, CDC entity, Check metadata, adapter, package, or API-version
  changes.
- Pause policies before large data loads unless the load is an intentional evaluation source.
- Do not purge active incident evidence until the operations owner has reconciled missed records.
- In **Change Evaluation retention**, save the approved 1–3,650-day window before cleanup. The
  displayed 90-day recommendation does not authorize deletion until it is saved.
- Review the cutoff and acknowledge permanent deletion for each purge. One run deletes at most
  1,000 oldest terminal evaluations; repeat only after reviewing the remaining evidence. `PENDING`
  claims are never eligible.
- Use a scheduled portfolio run when recovery requires proving the current state of every record;
  CDC replay alone is not a permanent audit or reconciliation mechanism.

## Disable and uninstall

1. Deactivate Change Monitor policies.
2. Wait for or deliberately cancel bounded pending work according to the operations runbook.
3. Preserve required operational evidence.
4. Remove subscriber-owned change-event triggers through the subscriber repository.
5. Disable CDC for the entity only when no other subscriber depends on it.
6. Uninstalling Change Monitor must not disable CDC automatically and must not modify core metadata.
