# RHC Change Monitor administrator guide

> [!WARNING]
> This is a proposed workflow for implementation and acceptance testing. There is no installable RHC
> Change Monitor package yet.

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

## Proposed setup workflow

### 1. Enable Salesforce CDC deliberately

In Setup, open **Change Data Capture**, select only the approved source entity, and save. Do not
select every available entity for convenience. Record the approval, estimated volume, and rollback
plan outside the package.

### 2. Install or deploy the intake adapter

The setup assistant must state whether the entity has a packaged adapter. If Release 1 uses the
preferred subscriber-owned model, a developer copies the package's exact trigger template, binds it
to the entity's change-event type, adds the contract test, and deploys it through the organization's
normal lifecycle. An administrator cannot manufacture this Apex from a text field.

### 3. Establish the runtime principal

Run the setup identity probe. It must show:

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
- no automated ledger retention job.

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
- Use a scheduled portfolio run when recovery requires proving the current state of every record;
  CDC replay alone is not a permanent audit or reconciliation mechanism.

## Disable and uninstall

1. Deactivate Change Monitor policies.
2. Wait for or deliberately cancel bounded pending work according to the operations runbook.
3. Preserve required operational evidence.
4. Remove subscriber-owned change-event triggers through the subscriber repository.
5. Disable CDC for the entity only when no other subscriber depends on it.
6. Uninstalling Change Monitor must not disable CDC automatically and must not modify core metadata.

