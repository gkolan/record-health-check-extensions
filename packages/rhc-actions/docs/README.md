# RHC Actions documentation

This directory is the documentation home for RHC Actions. Choose the path that matches your role.

## Salesforce administrators

Start with the [administrator documentation index](admin/README.md). It separates first-time setup
into short runbooks with exact clicks, exact field values, expected results, stop conditions, and
recovery steps.

| Goal                                            | Guide                                                                     |
| ----------------------------------------------- | ------------------------------------------------------------------------- |
| Confirm prerequisites and install the packages  | [Install and verify](admin/INSTALL_AND_VERIFY.md)                         |
| Assign access without over-permissioning users  | [Assign permissions](admin/ASSIGN_PERMISSIONS.md)                         |
| Build the example corrective Flow               | [Build the Flow](admin/BUILD_CORRECTIVE_FLOW.md)                          |
| Create the example manual policy                | [Create the policy](admin/CREATE_MANUAL_POLICY.md)                        |
| Generate, approve, and verify the first action  | [Test manual approval](admin/TEST_MANUAL_APPROVAL.md)                     |
| Create synthetic data and exercise all controls | [Demo data and full test](admin/DEMO_DATA_AND_FULL_TEST.md)               |
| Monitor records and run governed retention      | [Monitor and troubleshoot](admin/MONITOR_AND_TROUBLESHOOT.md)             |
| Deliberately enable automatic execution         | [Automatic execution](admin/ENABLE_AUTOMATIC_EXECUTION.md)                |
| Pause or remove the package                     | [Disable and uninstall](admin/DISABLE_AND_UNINSTALL.md)                   |
| Recheck Salesforce navigation sources           | [Official Salesforce references](admin/OFFICIAL_SALESFORCE_REFERENCES.md) |

The legacy entry point [ADMIN_GUIDE.md](../ADMIN_GUIDE.md) now routes readers to this modular set.

## Maintainers and release engineers

Read these documents in order for a new-maintainer onboarding:

1. [Architecture and execution lifecycle](ARCHITECTURE.md)
2. [Data model and state machines](DATA_MODEL.md)
3. [Flow contract](../FLOW_CONTRACT.md)
4. [Security and authorization](SECURITY_AND_AUTHORIZATION.md)
5. [Development guide](DEVELOPMENT.md)
6. [Testing and verification](TESTING_AND_VERIFICATION.md)
7. [Packaging and release](PACKAGING_AND_RELEASE.md)
8. [Production operations](OPERATIONS.md)

Release engineers can run the documented subscriber-org demo assets from
[`scripts/demo`](../scripts/demo/README.md). They are sandbox operator scripts, not package
metadata, and include a read-only preflight and cleanup preview.

## Product and security reviewers

- [Authoritative specification](../SPEC.md)
- [Threat model](../THREAT_MODEL.md)
- [Core event gap analysis](../GAP_ANALYSIS.md)
- [Requirements traceability](REQUIREMENTS_TRACEABILITY.md)

## Documentation ownership

Update documentation in the same change as source when any of these items changes:

- an object, field, picklist value, label, tab, application, Permission Set, or Custom Permission;
- the core Result event or Flow input contract;
- queue state, retry, cooldown, idempotency, loop, or retention behavior;
- an administrator-visible message or navigation path;
- an Apex class responsibility or transaction boundary;
- package dependency, namespace, API version, package ID, or release command; or
- test commands, supported org type, or verification evidence.

`SPEC.md` remains the product requirement. These documents explain the implementation and its
operation; they must not quietly redefine the specification.
