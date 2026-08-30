# RHC Alerts

> **Bring important Record Health Check outcomes to the people who need to respond.**

RHC Alerts is an optional Salesforce extension that converts selected finalized outcomes into
Salesforce Custom Notifications or plain-text email. Administrators decide which Checks or Check
Sets matter, which statuses and severities qualify, who receives the message, and how often repeated
findings may notify them.

Alerts is independently installable after Record Health Check core. It does not require Run Manager
or any other RHC extension.

## How Alerts helps

Record-page guidance works when a user is looking at the record. Alerts helps when a finding should
reach someone without relying on that person to open the record first.

Use it to:

- notify an active Salesforce user or the active user members of a public group;
- match an exact Check or Check Set identity, status, and minimum severity;
- deliver through Salesforce Custom Notification, email, or both;
- suppress repeated messages during a policy-and-record cooldown;
- see whether each delivery was pending, delivered, suppressed, failed, or a duplicate; and
- analyze whether core publication settings can produce the events the policy needs.

For example, a data steward group could receive one alert when an Account fails a critical ownership
Check, while repeated results for that Account remain quiet during the configured cooldown.

## How it works

1. Record Health Check core evaluates a record and publishes a canonical Result event.
2. Alerts matches active policies by exact identity, status, and severity.
3. A unique event-and-policy claim prevents the same event from being delivered twice.
4. An asynchronous worker applies cooldown, resolves active recipients, sends the message, and
   records a bounded delivery outcome.

Publication mode matters: if core publishes no Result event, Alerts has nothing to process. The
setup assistant helps administrators find interactive and programmatic publication gaps.

## What installation adds

- the **RHC Alerts** Lightning app;
- guided Alert Policy administration and a Delivery History experience;
- Alert Policy and Delivery ledger objects;
- Admin and least-privilege Viewer Runtime permission sets;
- a Salesforce Custom Notification type;
- Result and Set Run Platform Event subscribers; and
- asynchronous delivery, cooldown, idempotency, and retry services.

The package does not retain general health-check history, update checked business records, send
webhooks, or deliver to Slack or other external systems.

## Get started

1. Install the required Record Health Check core version.
2. Install an approved RHC Alerts subscriber package version in a sandbox.
3. Assign **RHC Alerts Admin** to configuration owners and **RHC Alerts Viewer Runtime** to
   read-only investigators.
4. Enable the required core Result-event publication.
5. Open **RHC Alerts Administration** and create a policy using the provided pickers.
6. Run **Analyze publication coverage** and resolve its errors and warnings.
7. Produce a controlled matching event and verify the message, history, cooldown, duplicate handling,
   and viewer experience before activation.

Follow the [junior administrator guide](ADMIN_GUIDE.md) for exact clicks and decisions, or use the
[sandbox demo](demo/README.md) for a repeatable acceptance exercise.

### Current availability

The package container is registered and source validation is documented, but the first installable
subscriber package version is still pending. There is currently no RHC Alerts `04t` to install.
Do not treat container `0Hoak0000005LtRCAU` as an installation ID.

See the executable [release gate ledger](docs/RELEASE-GATES.md) for the authoritative blockers and
[development and package validation](docs/DEVELOPMENT_AND_VALIDATION.md) for supporting evidence.

## Security and boundaries

- Policies use exact namespace-aware Qualified API Names.
- Delivery rows store bounded operational evidence rather than raw event payloads, stack traces,
  found values, expected values, or exception text.
- Package objects use private sharing; packaged permission sets grant access only by role.
- Recipient resolution includes active users and direct active user members of regular public
  groups.
- Cooldown and event-policy idempotency reduce repeated delivery.
- Salesforce messaging and platform limits still apply.
- Alerts depends only on Record Health Check core and never reads another extension's records.
- Custom Notification and email delivery is asynchronous and cannot guarantee that a recipient read
  the message.

## Documentation

| Need                                         | Start here                                                       |
| -------------------------------------------- | ---------------------------------------------------------------- |
| Configure a policy click by click            | [Junior administrator guide](ADMIN_GUIDE.md)                     |
| Load demo data and test behavior             | [Sandbox demo](demo/README.md)                                   |
| Review complete acceptance coverage          | [Demo test matrix](demo/TEST_MATRIX.md)                          |
| Monitor deliveries and troubleshoot          | [Operations runbook](docs/OPERATIONS.md)                         |
| Understand components and event flow         | [Architecture](docs/ARCHITECTURE.md)                             |
| Review package-owned records                 | [Data model](docs/DATA_MODEL.md)                                 |
| Review permissions and threats               | [Security](docs/SECURITY.md)                                     |
| Review the authoritative scope               | [Product specification](SPEC.md)                                 |
| Review Salesforce bell-notification behavior | [Custom Notification contract](CUSTOM_NOTIFICATIONS_SPEC.md)     |
| Review the executable pre-package lock       | [Release gate ledger](docs/RELEASE-GATES.md)                     |
| Review release readiness                     | [Development and validation](docs/DEVELOPMENT_AND_VALIDATION.md) |

<details>
<summary><strong>For contributors and release maintainers</strong></summary>

<br />

```bash
npm ci --ignore-scripts
npm run generate
npm test
npm run test:coverage
```

Generated metadata, Apex, Jest, XML, Code Analyzer, clean-org deployment, package creation, and
clean-subscriber installation must all be validated as documented in
[development and validation](docs/DEVELOPMENT_AND_VALIDATION.md).

Package identity:

- Package: RHC Alerts
- Container: `0Hoak0000005LtRCAU`
- Namespace: `rhc`
- Source line: `0.1.0.NEXT`
- Pinned core dependency: `Record Health Check@2.0.4-2`

</details>
