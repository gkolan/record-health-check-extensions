# RHC Actions security and authorization

## Security model

RHC Actions uses layered authorization:

1. private object sharing;
2. packaged object, field, Apex, tab, and Custom Permission grants;
3. `with sharing` entry-point Apex;
4. user-mode visibility, policy selection, and customer-controlled input operations;
5. server-side Custom Permission checks;
6. row locks before manual state transitions and execution;
7. Flow metadata and input-contract revalidation; and
8. narrowly scoped system-mode writes only for package-owned lifecycle and audit fields; and
9. the execution identity's business-record, Flow, Apex, and license access.

The LWC is not a security boundary. It never decides whether a user is an approver.

## Permission Sets

| Permission Set       | Custom Permissions  | Package object access                                                                | Intended identity                     |
| -------------------- | ------------------- | ------------------------------------------------------------------------------------ | ------------------------------------- |
| RHC Actions Admin    | Approve             | Create/read/edit Policy; read Pending/History                                        | Package administrator                 |
| RHC Actions Approver | Approve             | Read-only Policy, Pending, and History; lifecycle transition occurs in guarded Apex | Human reviewer                        |
| RHC Actions Runtime  | Automatic Execution | Read Policy/History; create Pending; package services own later lifecycle writes     | Dedicated Platform Event runtime user |
| RHC Actions Viewer   | None                | Read-only Policy, Pending, and History                                               | Auditor or support viewer             |

All four roles receive object-scoped View All for the three private package objects so cross-owner
queue and audit records remain visible without `View All Data`. No role receives Modify All because
Salesforce couples that permission to object Delete. Admins can edit policies they own; cross-owner
policy reassignment or editing requires an explicitly governed administrative process. No
Permission Set grants delete access. Retention and deletion require an explicitly reviewed future
design, not casual record cleanup.

## Additional customer permissions

Packaged Permission Sets grant only package metadata. Administrators must separately grant the
execution identity the least privilege needed by the selected customer Flow, including:

- Flow execution access;
- read access to the checked record;
- CRUD and field-level access for every record the Flow reads or mutates;
- record type, queue, group, or ownership access;
- access to called subflows and Apex actions; and
- access required by downstream automation.

Do not solve a permission failure by assigning System Administrator unless that identity is already
approved for the business process.

## Manual approval authorization

`RHCActionReviewController` performs the authoritative check:

1. evaluate `FeatureManagement.checkPermission('RHC_Actions_Approve')`;
2. reject missing or null record IDs;
3. query the Pending Action in user mode;
4. lock it with `FOR UPDATE`;
5. require current state `PENDING_REVIEW`;
6. store approving user and time; and
7. enqueue execution.

The controller reads and locks in user mode. After authorization, it writes only package-owned
approval and queue lifecycle fields in system mode; it does not elevate access to customer data.

A stale browser tab, duplicate click, or crafted client request cannot approve the same Pending
Action twice because the row is locked and its state is checked after locking.

## Automatic execution authorization

Automatic execution requires a three-part AND condition:

- `Mode__c = AUTOMATIC`;
- `Auto_Execution_Enabled__c = true`; and
- the Platform Event subscriber identity has `RHC_Actions_Automatic_Execution`.

At capture time, a false condition creates `PENDING_REVIEW`. At execution time, the service checks
the active policy, mode, opt-in, and appropriate custom permission again. Revocation after enqueue
fails the action with `EXECUTION_AUTHORIZATION_REVOKED` before starting the Flow.

By default, Salesforce runs Platform Event Apex triggers as Automated Process. Production automatic
mode therefore requires a release administrator to deploy `PlatformEventSubscriberConfig` for the
installed trigger with an approved dedicated user. This configuration is subscriber-org metadata
because a package cannot safely embed a customer's user identity.

## Flow validation boundary

The package validates:

- an active version exists;
- process type is `AutoLaunchedFlow`;
- contract version is `1.0`;
- every exposed input is one of eight allow-listed names;
- every selected mapping resolves to scalar Text input; and
- scalar Text output `rhcInterviewGuidV1` exists.

The package cannot prove:

- which objects or fields the Flow changes;
- that a subflow or Apex action is safe;
- that downstream record-triggered automation is bounded;
- that a Flow is reversible or idempotent internally; or
- that the Flow performs no indirect external operation.

Security review must inspect the entire active Flow dependency tree.

## Asynchronous containment

The Platform Event trigger delegates to a handler that processes at most 50 events per chunk,
sets a resume checkpoint after every successful chunk, and uses bounded first-chunk retries only
for transient storage failures. Duplicate idempotency keys are successful no-ops. Permanent
capture failures create sanitized `FAILED_FINAL` history when capacity permits.

The execution Queueable attaches a finalizer. An unhandled job failure moves eligible package
records to a one-minute bounded retry or terminal failure based on the policy retry limit. If the
recovery job itself cannot be enqueued, the record becomes terminal with
`ASYNC_RECOVERY_ENQUEUE_FAILED`; it is never left silently `RUNNING`.

## Safe error handling

Runtime records contain fixed error codes and bounded package-authored summaries. Catch blocks must
not persist or return `Exception.getMessage()`, stack traces, raw payloads, or Flow fault messages.
Detailed diagnostics remain in Salesforce's protected Flow and Apex operational facilities under
the org's retention and access model.

## Review checklist

Before approving a new policy or Flow version, security reviewers confirm:

- [ ] exact Check and optional Check Set identities are approved;
- [ ] manual mode is used unless automatic execution has explicit governance approval;
- [ ] only necessary input mappings are selected;
- [ ] no Flow input exists outside contract `1.0`;
- [ ] Flow, subflows, Apex actions, and downstream automation contain no human notification or
      external callout for this use case;
- [ ] business-object CRUD, FLS, sharing, queue, and record-type access is least privilege;
- [ ] cooldown covers the expected reevaluation period;
- [ ] retry count reflects side-effect risk;
- [ ] a sandbox test proves one event creates one correction; and
- [ ] Flow monitoring and package audit records are accessible to the operational owners.
