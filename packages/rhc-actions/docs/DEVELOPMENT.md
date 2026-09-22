# RHC Actions development guide

## Project layout

`packages/rhc-actions` is a standalone Salesforce DX project and unlocked 2GP package boundary.

```text
rhc-actions/
├── force-app/main/default/
│   ├── applications/       Lightning application
│   ├── classes/            Apex runtime, controller, gateways, and tests
│   ├── customPermissions/  approval and automatic-execution gates
│   ├── lwc/                manual review UI and Jest tests
│   ├── objects/            policy, queue, history, and retention-setting schema
│   ├── permissionsets/     Admin, Approver, Runtime, and Viewer personas
│   ├── tabs/               review and object tabs
│   └── triggers/           direct core Result event subscriber
├── manifest/               source deployment manifest
├── docs/                   maintainer and administrator documentation
├── sfdx-project.json       namespace, package, version, and core dependency
└── package.json            LWC Jest toolchain
```

Do not place Actions source in the core repository. A proposed core change requires a documented
public-contract gap first; the current gap analysis concludes no core change is needed.

## Prerequisites

- Salesforce CLI with packaging support
- access to the namespace-owning Dev Hub when creating a package version
- a scratch or development org with promoted core `2.0.4.2`
- Node.js compatible with `@salesforce/sfdx-lwc-jest`
- npm dependencies installed from `package-lock.json`

From this directory:

```sh
npm ci
sf --version
```

## Implementation rules

- Day 1 means no aliases, compatibility shims, migrations, or deprecated APIs.
- The only package dependency is the pinned core package.
- Consume `Record_Health_Check_Result__e` directly.
- Use `with sharing`, user-mode SOQL, and user-mode DML for package records.
- Keep the Platform Event trigger logicless.
- Bulkify event capture; never query or DML once per event.
- Use stable external-ID claims for idempotency.
- Lock stateful Pending Actions with `FOR UPDATE`.
- Revalidate Flow at the last responsible moment.
- Pass only contract allow-listed scalar Text values.
- Never store raw payloads, exception messages, arbitrary JSON, or Flow fault text.
- Never send human alerts or perform external callouts.
- Update the documentation index and relevant runbook in the same change.

## Class dependency map

```text
RHCActionResultSubscriber
└── RHCActionCaptureService
    ├── RHCActionConstants
    └── RHCActionExecutionQueueable
        └── RHCActionExecutionService
            ├── RHCActionPolicyService
            │   └── RHCActionFlowGateway
            └── RHCActionFlowGateway

rhcActionReview
└── RHCActionReviewController
    ├── RHCActionPolicyService
    └── RHCActionExecutionQueueable
```

`RHCActionFlowGateway` is replaceable in tests through the package-private `@TestVisible` gateway
seam. Tests must not depend on a subscriber org's real customer Flow.

## Adding or changing a policy field

1. Add or update field metadata under `RHC_Action_Policy__c/fields`.
2. Add field access intentionally to all four Permission Sets.
3. Add the field to every relevant SOQL projection.
4. Add server-side validation when the field affects safety.
5. Update capture, execution, and test-factory builders.
6. Add positive, negative, bulk, and authorization tests.
7. Update `DATA_MODEL.md`, admin field tables, and troubleshooting instructions.
8. Run the complete verification sequence.

## Changing the Flow contract

Do not reinterpret `1.0`. A breaking or additive public interface change needs a new explicit
contract version and coordinated changes to:

- constants and allow-list;
- policy mapping metadata;
- Flow metadata validation;
- execution input construction;
- permission fields and layouts;
- positive and negative contract tests;
- `FLOW_CONTRACT.md` and administrator Flow walkthrough; and
- release notes and compatibility statement.

No alias variables or automatic contract migration are allowed on Day 1.

## Documentation standard

Every UI step must name:

1. starting page;
2. exact control to click;
3. exact value to enter or select;
4. expected result; and
5. stop/recovery action when the result differs.

Repository docs must explain why a behavior exists, the owning component, transaction boundary,
authorization point, failure semantics, tests, and operational consequence.
