# Subscriber-owned CDC adapter contract

RHC Change Monitor deliberately does not package an object-specific change-event trigger. Salesforce
binds each trigger to one concrete `*ChangeEvent` type, while subscriber custom objects and CDC
selection differ by organization. A subscriber adapter is lifecycle-owned source that must be
reviewed and deployed by the subscribing organization.

## Generator

Generate the channel member and routing-only trigger directly into a subscriber repository:

```bash
cd packages/rhc-change-monitor
npm run adapter:generate -- \
  --object Shipment__c \
  --output /path/to/subscriber-repo/force-app/main/default
```

The default output references `rhc.RHCChangeMonitorIntake`, which is correct for an installed
namespaced package. Use `--namespace none` only when Change Monitor is source-deployed without a
namespace for verification. The generator creates no package or package version and does not deploy.
It refuses invalid source-object names and existing output files unless `--force` is explicit.

Keep generated adapters under source control and verify them in CI without rewriting files:

```bash
npm run adapter:check -- \
  --object Shipment__c \
  --output /path/to/subscriber-repo/force-app/main/default
```

The check fails if any of the three expected files is missing or differs from current generator
output. Pass the same `--namespace` and optional `--trigger-name` values used during generation.

## Required trigger shape

An Account adapter contains routing only:

```apex
trigger RHCAccountChangeMonitor on AccountChangeEvent (after insert) {
  rhc.RHCChangeMonitorIntake.accept(Trigger.new);
}
```

For a custom source object such as `Shipment__c`, bind the trigger to
`Shipment__ChangeEvent`. Do not copy fields, evaluate values, query records, perform DML, enqueue
additional work, catch and suppress package exceptions, or invoke core directly from the adapter.

## Deployment prerequisites

Before deploying an adapter:

1. Confirm the source object is supported by Salesforce CDC.
2. Select the source entity explicitly in Salesforce Setup under Change Data Capture.
3. Confirm the package has an active policy for the exact durable source API name.
4. Run the effective-principal probe and verify the core Run custom permission and expected source
   sharing, CRUD, and FLS behavior.
5. Deploy the trigger and its organization-owned CDC contract test through the normal lifecycle.

The generator does not invent the object-specific test data needed for required fields, validation
rules, or automation. Copy and adapt the Account contract fixture under `subscriber-app`, then keep
that test in the subscriber repository beside the generated trigger.

The package validates that every input is a ChangeEvent sObject, its serialized header entity
matches the concrete event type, stable transaction and sequence identity exist, and every record
ID is syntactically valid. It ignores all payload values.

## Adapter test expectations

Each subscriber adapter must prove CREATE, matching UPDATE, nonmatching UPDATE, UNDELETE, DELETE,
bulk delivery, and malformed/wrong-type rejection. Use `Test.enableChangeDataCapture()` and deliver
the event bus after the source DML. Duplicate replay and gap evidence require the feasibility harness
because ordinary Apex tests cannot manufacture a genuine redelivery guarantee.

Removing the adapter is a subscriber source change. Uninstalling Change Monitor does not remove the
trigger and does not disable CDC for the entity.
