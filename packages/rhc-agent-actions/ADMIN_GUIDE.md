# RHC Agent Actions administrator guide

> [!WARNING]
> RHC Agent Actions is source-only. No package container or installable subscriber version exists.
> Use the current source only in an approved development or sandbox org. Do not construct an
> installation URL or present this extension as released.

## Prerequisites

- Record Health Check core `2.0.4.2` or a later explicitly validated version is present.
- The target user is the actual runtime user for the Agentforce agent.
- The runtime user can access every business record and display value that the agent is expected to
  explain. The extension does not elevate record or field access.
- Before acceptance, require evidence that the exact revision passed repository, conversion,
  analyzer, scratch-org compilation, and Apex test gates. The current working tree has only local
  repository, conversion, and analyzer evidence; org compilation and Apex execution remain open.

## Configure access

1. Assign **RHC Agent Actions User** to the agent runtime user. This grants access only to the two
   invocable actions and their support class.
2. Assign core **Record Health Check User** to the same user. Without core
   `Record_Health_Check_Run`, the explain action returns `AUTHORIZATION` and does not evaluate.
3. Grant ordinary object, record, and field access appropriate for that user. Do not compensate for
   missing access with an administrator profile.

## Add the actions to an agent

Follow [Adding the actions to an Agentforce agent](docs/AGENT_SETUP.md). Add both actions to one
record-health topic: use **List Record Health Check Sets for Agentforce** for discovery and
**Explain Record Health for Agentforce** for the bounded explanation. Keep the supplied topic
instructions that distinguish a business `FAIL` from an `ATTENTION` evaluation problem.

## Acceptance check

In a sandbox, test with the actual runtime user and one record the user may access:

1. List applicable Check Sets and confirm only active sets for the record's object are returned.
2. Explain the record without naming a Check Set and confirm no more than five sets are evaluated.
3. Confirm the response contains no more than the requested 1–25 findings and exposes no
   administrator-only detail.
4. Remove core run permission temporarily and confirm the action fails closed with
   `AUTHORIZATION`; restore the approved assignment afterward.
5. Test a record or field the user cannot access and confirm core's user-mode behavior is preserved.
6. Review conversational latency with the intended Check Sets before enabling the topic broadly.

## Operations and removal

The actions are synchronous and create no package-owned records, schedules, or event subscribers.
Use the correlation ID with core diagnostics when an execution returns `ATTENTION` or `EXECUTION`.
See [operations](docs/OPERATIONS.md) and [security](docs/SECURITY.md). To disable the capability,
remove the actions from the topic and revoke **RHC Agent Actions User**. Source removal must follow
the owning org's normal metadata change process.
