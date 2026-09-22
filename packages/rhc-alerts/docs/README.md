# RHC Alerts documentation

RHC Alerts documentation is split by audience so administrators do not have to read implementation
material and maintainers can find the package contract without reverse-engineering Apex.

## Administrator and operator documentation

| Document                                               | Use it when                                                                                                     |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| [Junior administrator guide](../ADMIN_GUIDE.md)        | Installing access, enabling publication, creating the first policy, testing, and troubleshooting click by click |
| [Sandbox demo and acceptance guide](../demo/README.md) | Creating demo-like data, running canonical events, checking each screen, and cleaning up                        |
| [Complete demo test matrix](../demo/TEST_MATRIX.md)    | Confirming manual and automated coverage for every product capability and constraint                            |
| [Operations runbook](OPERATIONS.md)                    | Monitoring delivery, interpreting outcomes and error codes, responding to limits, and handling incidents        |

## Maintainer and release documentation

| Document                                                            | Contents                                                                                                             |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| [Architecture](ARCHITECTURE.md)                                     | Package boundary, event-to-delivery sequence, components, transactions, bulk behavior, and extension independence    |
| [Data model](DATA_MODEL.md)                                         | Policy, delivery, and setting fields, keys, relationships, state vocabulary, and retention boundary                  |
| [Security and threat model](SECURITY.md)                            | Trust boundaries, access model, data minimization, threats, controls, and residual risks                             |
| [Development and package validation](DEVELOPMENT_AND_VALIDATION.md) | Local setup, metadata generation, tests, analyzer workflow, clean-org validation, 2GP creation, and acceptance gates |
| [Release gate ledger](RELEASE-GATES.md)                             | Executable pre-package lock, evidence schema, current blockers, and candidate-only gates                             |
| [Core gap analysis](../GAP_ANALYSIS.md)                             | Minimum compatible promoted core version and Set Run contract limitation                                             |
| [Specification](../SPEC.md)                                         | Authoritative product scope and acceptance criteria                                                                  |

## Release status

- Package: `RHC Alerts`
- Package container ID: `0Hoak0000005LtRCAU`
- Planned first version: `0.1.0.NEXT`
- Namespace: `rhc`
- Source API version: `66.0`
- Sole dependency: `Record Health Check@2.0.4-2` (`04tak000000cZBFAA2`)
- Installable `04t` version: pending; package creation is prohibited until the executable pre-package
  lock passes for one exact commit and creation is separately authorized

No other RHC extension is a dependency or runtime integration point.
