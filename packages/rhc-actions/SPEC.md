# RHC Actions specification

## Why this project exists

Core is intentionally read-only: it explains health but does not change the checked record. Some
outcomes have an organization-approved response, such as creating a stewardship Task, requesting
review, or applying a deterministic normalization Flow. Administrators otherwise need custom event
automation, idempotency, approvals, loop prevention, and audit storage.

RHC Actions maps selected finalized outcomes to approved same-org autolaunched Flows. It keeps
mutation outside core and makes every proposed and completed corrective action auditable.

## User value

A junior administrator can select one Check, choose matching statuses/severity, select an eligible
Flow, map allow-listed inputs, require manual approval, test the mapping, and activate the policy.
The default mode is `MANUAL_APPROVAL`; automatic execution requires an explicit setting and a
dedicated Custom Permission.

## Dependency on core

RHC Actions depends only on core and subscribes directly to finalized
`Record_Health_Check_Result__e` events. It uses the exact Check/Check Set Qualified API Names, record
ID, Run ID, status, severity, reason code, Event ID, and contract version supplied by core.

It does not read Run Manager results or require Reports. Any core caller can produce an actionable
event, but a caller using publication `NONE` is invisible to Actions.

## Owned data and behavior

- Corrective Action Policy: Check identity, statuses, severity, Flow API name, mode, cooldown,
  retry limit, active state, and allow-listed input mapping.
- Pending Action: one reviewable response for one policy and core Event ID.
- Action History: approver/initiator, Flow interview ID, times, outcome, and bounded error details.
- Idempotency, cooldown, approval, and loop-guard state.

Only active autolaunched Flows satisfying the versioned input contract are selectable.

## Example

The org has an autolaunched Flow named `Create_Data_Steward_Task`. It accepts record ID, Check
Qualified API Name, status, severity, and reason code and creates a Task for a stewardship queue.

Maya maps `Account_Has_Primary_Contact` failures to that Flow in `MANUAL_APPROVAL` mode. When core
publishes a matching event, one Pending Action appears. Maya reviews the Account and selects **Run
Action**. RHC Actions starts the approved Flow once and records the interview ID and outcome. It does
not invent a missing Contact or silently alter business data.

## Constraints it cannot escape

- No core Result event means no corrective action.
- A Flow can have broad side effects; the package can validate its declared interface but cannot
  prove all business behavior is safe.
- Flow execution uses a Salesforce identity whose CRUD, FLS, sharing, and Flow permissions apply.
- Platform Event and Flow execution are asynchronous; there is no atomic transaction spanning the
  original health check and later correction.
- External or downstream automation triggered by the Flow cannot be rolled back by RHC Actions.
- At-least-once event delivery and Flow retries require strict idempotency.
- A correction can cause another evaluation and event; loop guards and cooldowns are mandatory.
- Automatic correction is inappropriate when human judgment or irreversible changes are involved.

## Boundaries

Actions owns approved same-org Flow execution. It does not schedule Checks, send human alerts,
create analytical datasets, or perform outbound callouts. A Flow selected for corrective action
must not be used to bypass those package boundaries.

## Acceptance criteria

1. It installs with core and without another extension.
2. Duplicate Event IDs cannot execute one policy twice.
3. Manual approval is the default and records the approving user.
4. Input mapping rejects unapproved values and incompatible Flow variables.
5. Loop guards prevent unbounded evaluate-correct-evaluate behavior.
6. Removing Actions leaves core and other extensions operational.
