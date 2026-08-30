# RHC Actions

> **Turn selected health-check findings into governed Salesforce Flow actions.**

RHC Actions is an optional Salesforce extension that maps finalized Record Health Check outcomes to
administrator-approved autolaunched Flows in the same org. It creates a reviewable boundary between
finding a problem and changing data or starting a business process.

Manual approval is the default. Automatic execution requires an automatic policy, an explicit
policy opt-in, and a dedicated custom permission on the Platform Event subscriber identity. Those
facts are checked again by the execution job, so revoking a policy or permission also contains
already-queued work.

Actions is independently installable after Record Health Check core. It does not require any other
RHC extension.

## How Actions helps

Use Actions when an outcome should lead to a known, repeatable Salesforce process, such as:

- creating a task for a data steward;
- opening a governed remediation request;
- updating approved fields through a purpose-built Flow;
- routing a record for review; or
- recording that an authorized person accepted or rejected a proposed action.

Administrators choose the exact Check, status, Flow, and execution mode in a policy. Users can review
the source record and proposed action before selecting **Run Action**.

## How it works

1. Record Health Check core publishes a finalized Result event.
2. Actions matches the event to an active policy and creates an idempotent Pending Action.
3. In manual mode, an authorized approver reviews the item and chooses whether to run it.
4. Immediately before execution, Actions revalidates the policy, permission, Flow, and request.
5. The Flow starts asynchronously, and Actions records the actor, interview, attempt, and outcome.

Automatic mode uses the same controlled execution path, but only after all automatic-execution
controls are present. Core publication mode `NONE` produces no Result event and therefore no
Pending Action.

## What installation adds

- the **RHC Actions** Lightning app and Action Review experience;
- Action Policy, Pending Action, and Action History objects;
- Admin, Approver, Runtime, and Viewer permission sets;
- Approve and Automatic Execution custom permissions;
- the canonical Result Platform Event subscriber; and
- asynchronous validation, locking, Flow execution, idempotency, and history services.

The package does not select arbitrary Apex, execute another extension, or silently turn every
failure into a record update.

## Get started

1. Install the required Record Health Check core version.
2. Install an approved RHC Actions subscriber package version in a sandbox.
3. Assign the packaged permission sets according to administrator, approver, runtime, and viewer
   responsibilities.
4. Build an active autolaunched Flow that follows the [Flow contract](FLOW_CONTRACT.md).
5. Create an active policy and keep **Manual Approval** until automatic remediation has been
   separately reviewed and approved.
6. Publish a controlled matching Result, open **RHC Actions Review**, inspect the source record, and
   select **Run Action**.
7. Confirm Flow behavior and Action History before production activation.

Start with the [Administrator Guide](ADMIN_GUIDE.md), or follow the modular
[admin runbooks](docs/admin/README.md) and [full sandbox test](docs/admin/DEMO_DATA_AND_FULL_TEST.md).

### Current availability

The package project and registered 2GP container exist, but creation of the first installable
subscriber package version is still pending. There is currently no documented RHC Actions `04t`.
Do not treat container `0Hoak0000005M6LCAU` as an installation ID.

See [testing and verification](docs/TESTING_AND_VERIFICATION.md) for authoritative evidence and the
remaining release gate.

## Security and boundaries

- Manual approval is the default policy mode.
- Approval and automatic execution use separate custom permissions.
- Policy and Flow validation occurs at approval and again immediately before execution.
- Pending Actions are locked and processed asynchronously to prevent duplicate execution.
- Unexpected Queueable failures are reconciled by a finalizer into a bounded retry or terminal,
  operator-visible state.
- Platform Event batches are processed in bounded chunks with resume checkpoints and limited
  transient retries; permanent capture failures receive sanitized package audit records.
- Policies can invoke only the explicitly configured active autolaunched Flow.
- History records who initiated the action and its bounded outcome.
- Actions depends only on Record Health Check core and never reads another extension's objects.
- The administrator-owned Flow determines the business data changes, so it must enforce its own
  sharing, CRUD, field access, limits, and error-handling requirements.

## Documentation

| Need | Start here |
| --- | --- |
| Understand installation and setup | [Administrator Guide](ADMIN_GUIDE.md) |
| Follow task-specific admin runbooks | [Admin documentation](docs/admin/README.md) |
| Build a compatible Flow | [Flow contract](FLOW_CONTRACT.md) |
| Test the complete experience | [Demo data and full functional test](docs/admin/DEMO_DATA_AND_FULL_TEST.md) |
| Monitor and troubleshoot | [Operations](docs/OPERATIONS.md) |
| Understand components and lifecycle | [Architecture](docs/ARCHITECTURE.md) |
| Review package-owned records | [Data model](docs/DATA_MODEL.md) |
| Review permissions and threats | [Security and authorization](docs/SECURITY_AND_AUTHORIZATION.md) |
| Review the authoritative scope | [Product specification](SPEC.md) |
| Review release readiness | [Testing and verification](docs/TESTING_AND_VERIFICATION.md) |

<details>
<summary><strong>For contributors and release maintainers</strong></summary>

<br />

```bash
npm ci
npm run validate
npm run validate:core-contract -- --core-root /path/to/record-health-check
npm run validate:xml
npm run test:coverage
npm audit --audit-level=high
```

Follow the [development guide](docs/DEVELOPMENT.md) and
[packaging and release guide](docs/PACKAGING_AND_RELEASE.md) for Apex, security, metadata, Code
Analyzer, 2GP, and clean-subscriber validation.

Package identity:

- Package: RHC Actions
- Container: `0Hoak0000005M6LCAU`
- Namespace: `rhc`
- Source line: `0.1.0.NEXT`
- Pinned core dependency: `Record Health Check@2.0.4-2`

</details>
