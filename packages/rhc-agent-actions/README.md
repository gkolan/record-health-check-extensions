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

## First run

1. After an approved subscriber version exists, install Record Health Check core `2.0.4.2` or
   later, then this package. For current development, deploy source only to an approved test org.
2. Assign **RHC Agent Actions User** and core **Record Health Check User** to the agent's user.
3. Add the two actions to an agent topic; see [docs/AGENT_SETUP.md](docs/AGENT_SETUP.md).
4. Ask the agent "what's wrong with this account?" — see the sample dialogue in the same guide.

Confirm the agent returns a bounded explanation and does not change the record. The suite
[install, first-run, and uninstall checklist](../../docs/FIRST_RUN.md) covers lifecycle verification.

## Security and boundaries

- Requires core's `Record_Health_Check_Run` custom permission; the action returns an
  `AUTHORIZATION` error without it.
- Display text comes from core's `EVALUATION_WITH_DISPLAY` rendering for the running user;
  administrator-only detail (`adminDetail`) is never copied into the response.
- At most one record per request, at most five Check Sets per record, at most 25 findings.
- Correlation IDs are restricted to 120 characters of `[A-Za-z0-9._:-]`.
- Depends only on core; reads no other extension's objects.

See the [administrator guide](ADMIN_GUIDE.md), [specification](SPEC.md),
[security guidance](docs/SECURITY.md), and [operations guidance](docs/OPERATIONS.md).
Release status and remaining gates are tracked in [release evidence](RELEASE_EVIDENCE.md).

## Local verification

```bash
npm ci
npm test            # source contracts plus XML well-formedness
npm run validate    # source contracts only
npm run validate:xml
npm audit --audit-level=high
```

`npm run validate` asserts the pinned core dependency, API version 66.0, the `rhc` namespace,
explicit sharing and metadata companions on every Apex class, and that
`RHC_Agent_Actions_User` grants Apex access only. There is no `test:coverage` script: the
package ships no JavaScript, so there is nothing for Jest to cover. Apex tests need a
namespaced scratch org with core installed, as described in
[release evidence](RELEASE_EVIDENCE.md):

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias rhc-aa --duration-days 1
sf package install --package 04tak000000nGjZAAU --target-org rhc-aa --wait 30 --publish-wait 10 --no-prompt
sf project deploy start --source-dir force-app --target-org rhc-aa --test-level NoTestRun --wait 30
sf apex run test --target-org rhc-aa --test-level RunLocalTests --code-coverage --result-format human --wait 30
```

`RHCAgentActionsTest` covers the behavioural contract. `RHCAgentActionsAdversarialTest`
covers hostile input: an Agentforce planner is an LLM, so every invocable input is treated as
untrusted. It asserts null and empty request lists, over-sized planner batches, missing and
mismatched record IDs, quoted and wildcard Check Set names, out-of-range finding caps, unsafe
correlation IDs, permission denial, and that every error path returns a typed classification
carrying no org ID, username, record ID or Apex diagnostic.

## Current availability

Source only; no `0Ho` container is registered. The five-test shared no-namespace run from
2026-09-18 is historical evidence for the source recorded then, not the current working tree.
Current Metadata API conversion and strict static analysis pass with zero findings; fresh
server-side compilation and Apex execution require a newly authorized test org.
