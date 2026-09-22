# RHC Integrations documentation

> Last source review: September 20, 2026 · API 66.0 · package 0.1.0

This documentation describes the implementation in this repository. `SPEC.md` remains the product
authority; source metadata and tests remain the executable authority.

## Choose your path

| Audience | Start here | Then read |
| --- | --- | --- |
| Junior Salesforce administrator | [Administrator setup guide](JUNIOR-ADMIN-GUIDE.md) | [Operations](OPERATIONS.md), [configuration reference](CONFIGURATION-REFERENCE.md) |
| Integration/security owner | [Security model](SECURITY.md) | [Payload contracts](PAYLOAD-CONTRACTS.md), [threat model](THREAT-MODEL.md) |
| Operator/on-call engineer | [Operations](OPERATIONS.md) | [Delivery lifecycle](DELIVERY-LIFECYCLE.md) |
| Apex/LWC maintainer | [Architecture](ARCHITECTURE.md) | [Development, testing, and release](DEVELOPMENT-TESTING-RELEASE.md) |
| Package/release owner | [Development, testing, and release](DEVELOPMENT-TESTING-RELEASE.md) | [Release evidence](RELEASE-EVIDENCE.md), [core-event gap analysis](CORE-EVENT-GAP-ANALYSIS.md) |

## Documentation map

- [Architecture](ARCHITECTURE.md): boundaries, components, execution sequence, and dependency rules.
- [Configuration reference](CONFIGURATION-REFERENCE.md): every route and ledger field, validation,
  filtering semantics, and examples.
- [Payload contracts](PAYLOAD-CONTRACTS.md): exact JSON keys, compatibility rules, headers, versions,
  and prohibited content.
- [Delivery lifecycle](DELIVERY-LIFECYCLE.md): state transitions, HTTP classification, retry timing,
  idempotency, replay, and failure interpretation.
- [Security](SECURITY.md): identities, credentials, sharing, permission sets, least privilege, and
  data exposure.
- [Administrator setup guide](JUNIOR-ADMIN-GUIDE.md): sandbox-first, screen-by-screen setup and
  acceptance testing.
- [Administrator implementation worksheet](ADMIN-IMPLEMENTATION-WORKSHEET.md): controlled values,
  evidence, role assignments, acceptance results, and go/no-go sign-off.
- [Complete demo and functional test guide](DEMO-TESTING.md): seeded routes/data, approved receiver
  contract, synthetic and real-core scenarios, expected evidence, and cleanup.
- [Operations](OPERATIONS.md): concise production runbook.
- [Development, testing, and release](DEVELOPMENT-TESTING-RELEASE.md): local setup, tests, analyzer,
  validation, 2GP version creation, and independent install gates.
- [Release evidence](RELEASE-EVIDENCE.md): revision identity, local gate results, required org
  evidence, and the release decision.
- [Threat model](THREAT-MODEL.md): threats, controls, and residual risks.
- [Core-event gap analysis](CORE-EVENT-GAP-ANALYSIS.md): minimum compatible promoted core and safe
  behavior for incomplete event shapes.

## Release status

The 2GP package container is `0Hoak0000005Lv3CAE`. A container ID is not installable. The first
promoted RHC Integrations `04t` was not available at the last review because the Dev Hub daily
package-version limit had been reached. Update this page, the root README, and the administrator
guide together when the promoted `04t` exists.

## Documentation maintenance rule

Any source change must update the corresponding documentation in the same change:

| Source change | Required documentation |
| --- | --- |
| Route, ledger, or setting field | Configuration reference and administrator guide |
| Payload key/profile/version | Payload contracts and receiver acceptance tests |
| HTTP/retry classification | Delivery lifecycle and operations |
| Permission/FLS/custom permission | Security model and assignment steps |
| Core event field or minimum dependency | Core-event gap analysis and architecture |
| Package version/dependency | Release status and install steps |
