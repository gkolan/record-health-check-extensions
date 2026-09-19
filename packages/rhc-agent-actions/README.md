# RHC Agent Actions

> **Let an Agentforce agent explain a record's health and how to fix it.**

> [!WARNING]
> **Active development:** this package is a pre-release extension. No package container or
> subscriber version exists. Use it only in development or sandbox environments.

Record Health Check core ships two native Agentforce actions that run a Check or Check Set for one
record and return its status and counts. An agent can say *how many* checks failed, but not
*which* ones or *what to do*. RHC Agent Actions adds the missing layer on top of core's public API:

| Action | What the agent gets |
| --- | --- |
| **Explain Record Health for Agentforce** | Overall `PASS` / `FAIL` / `ATTENTION`, counts, and a bounded list of failed or unevaluable checks with the same message, fix guidance, found/expected display values, and action link the running user would see on the record page — plus a plain-language summary ready to speak. |
| **List Record Health Check Sets for Agentforce** | The active Check Sets that apply to a record or object, with exact Qualified API Names to pass to the explain action. |

Both actions run in user mode under the agent user's permissions, evaluate through
`RecordHealthCheck.evaluate`, and never modify the checked record.

## What installation adds

- Apex classes `RHCAgentExplainRecordHealthAction`, `RHCAgentListCheckSetsAction`,
  `RHCAgentSupport`, and their tests;
- permission set **RHC Agent Actions User** (Apex access only).

No objects, triggers, scheduled jobs, or Platform Event subscribers.

## Get started

1. Install Record Health Check core `2.0.4.2` or later, then this package.
2. Assign **RHC Agent Actions User** and core **Record Health Check User** to the agent's user.
3. Add the two actions to an agent topic; see [docs/AGENT_SETUP.md](docs/AGENT_SETUP.md).
4. Ask the agent "what's wrong with this account?" — see the sample dialogue in the same guide.

## Security and boundaries

- Requires core's `Record_Health_Check_Run` custom permission; the action returns an
  `AUTHORIZATION` error without it.
- Display text comes from core's `EVALUATION_WITH_DISPLAY` rendering for the running user;
  administrator-only detail (`adminDetail`) is never copied into the response.
- At most one record per request, at most five Check Sets per record, at most 25 findings.
- Correlation IDs are restricted to 120 characters of `[A-Za-z0-9._:-]`.
- Depends only on core; reads no other extension's objects.

See [SPEC.md](SPEC.md), [docs/SECURITY.md](docs/SECURITY.md), and
[docs/OPERATIONS.md](docs/OPERATIONS.md).

## Current availability

Source only. Deployed and tested in the shared no-namespace org on 2026-09-18 (5 Apex tests);
no `0Ho` container is registered.
