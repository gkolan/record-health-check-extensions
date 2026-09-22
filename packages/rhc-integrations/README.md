# RHC Integrations

> **Deliver approved Record Health Check outcomes to external systems.**

RHC Integrations is an optional Salesforce extension for sending allow-listed run, result, and
diagnostic events through administrator-owned Named Credentials. It gives organizations a governed
outbound path to automation, monitoring, data, or integration platforms without putting endpoint
secrets in package records.

Integrations is independently installable after Record Health Check core. It does not require any
other RHC extension.

## How Integrations helps

Use Integrations when an external system needs to:

- receive completed run summaries or selected result outcomes;
- open or update work in an integration platform;
- add health-check signals to monitoring or analytics;
- receive only an approved, versioned payload profile;
- retry temporary delivery failures; or
- let an authorized operator inspect and replay a dead-lettered delivery.

Administrators control each route's exact event type, Check or Check Set selection, statuses,
minimum severity, payload profile, Named Credential, relative endpoint, and retry policy.

## How it works

1. Record Health Check core publishes a canonical Run, Result, or approved Log Platform Event.
2. Integrations matches active allow-listed routes.
3. It creates an idempotent delivery record using the route and canonical Event ID.
4. A post-commit Queueable builds the approved payload and calls the configured Named Credential.
5. The delivery becomes succeeded, waits for a bounded retry, or moves to the dead-letter queue.
6. An authorized operator can investigate and replay an eligible dead letter.

The receiver must enforce the supplied idempotency key. No package can guarantee exactly-once
delivery across Salesforce and an external system.

## What installation adds

- the **RHC Integrations** Lightning app;
- Route configuration and Dead Letter review experiences;
- Integration Route, Delivery ledger, and package-owned retention setting objects;
- Admin, Operator, Runtime, and Viewer permission sets;
- a Replay custom permission;
- Run, Result, and approved Log Platform Event subscribers; and
- payload, callout, retry, dead-letter, and replay services.

Subscriber administrators continue to own the Named Credentials and External Credentials. The
package does not contain destination authentication secrets.

## First run

1. Install the required Record Health Check core version.
2. Install an approved RHC Integrations subscriber package version in a sandbox.
3. Create and test the required Named Credential and External Credential.
4. Assign the Admin, Operator, Runtime, and Viewer permission sets by responsibility.
5. Create an inactive route using the [implementation worksheet](docs/ADMIN-IMPLEMENTATION-WORKSHEET.md).
6. Confirm its filters, payload profile, relative endpoint, authentication, and receiver idempotency.
7. Activate the route and run the documented controlled delivery tests.
8. Verify success, retry, dead-letter, and permission-gated replay before production use.

New administrators should follow the [junior administrator guide](docs/JUNIOR-ADMIN-GUIDE.md) and
[demo testing guide](docs/DEMO-TESTING.md).
The suite [install, first-run, and uninstall checklist](../../docs/FIRST_RUN.md) defines the common
package lifecycle and required delivery evidence.

### Current availability

The package project and registered 2GP container exist, but the first promoted installable subscriber
package version is still pending. There is currently no documented RHC Integrations `04t`. Do not
treat container `0Hoak0000005Lv3CAE` as an installation ID.

See the [documentation index release status](docs/README.md#release-status) and
[development, testing, and release guide](docs/DEVELOPMENT-TESTING-RELEASE.md) for authoritative
evidence.

## Security and boundaries

- Named Credentials and External Credentials own endpoint authentication.
- Relative endpoints are validated and routes are explicitly allow-listed.
- Payload profiles are versioned, bounded contracts rather than arbitrary event serialization.
- Delivery records retain operational evidence needed for retry and investigation.
- Replay requires the dedicated custom permission, applies only to eligible dead letters, and
  rejects a request if any replay-state field is removed by field-level security.
- Delivery cleanup is administrator-only, manual, explicitly confirmed, terminal-only, and capped
  at 1,000 oldest rows per transaction; setting writes are field-sanitized and run in user mode,
  and saving a policy never schedules deletion.
- Integrations depends only on Record Health Check core and never queries another extension.
- The receiver must validate authorization, schema version, and idempotency.
- Platform Event, Queueable, callout, storage, and downstream-service limits still apply.

## Documentation

| Need | Start here |
| --- | --- |
| Configure the package click by click | [Junior administrator guide](docs/JUNIOR-ADMIN-GUIDE.md) |
| Plan a route before configuration | [Implementation worksheet](docs/ADMIN-IMPLEMENTATION-WORKSHEET.md) |
| Test delivery and failure behavior | [Demo testing](docs/DEMO-TESTING.md) |
| Review every configuration choice | [Configuration reference](docs/CONFIGURATION-REFERENCE.md) |
| Understand payloads | [Payload contracts](docs/PAYLOAD-CONTRACTS.md) |
| Understand retry and dead letters | [Delivery lifecycle](docs/DELIVERY-LIFECYCLE.md) |
| Monitor and troubleshoot | [Operations](docs/OPERATIONS.md) |
| Understand components and transactions | [Architecture](docs/ARCHITECTURE.md) |
| Review security and threats | [Security](docs/SECURITY.md) and [threat model](docs/THREAT-MODEL.md) |
| Review the authoritative scope | [Product specification](SPEC.md) |

<details>
<summary><strong>For contributors and release maintainers</strong></summary>

<br />

```bash
npm ci
npm run test:unit
npm run test:unit:coverage
```

Follow [development, testing, and release](docs/DEVELOPMENT-TESTING-RELEASE.md) for Apex, metadata,
security, Code Analyzer, 2GP, receiver-contract, and clean-subscriber validation.

Package identity:

- Package: RHC Integrations
- Container: `0Hoak0000005Lv3CAE`
- Namespace: `rhc`
- Source line: `0.1.0.NEXT`
- Pinned core dependency: `Record Health Check@2.0.4-2`

</details>
