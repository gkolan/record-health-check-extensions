# RHC Change Monitor threat model

## Trust boundary

The package accepts platform-generated CDC headers from explicitly supported change-event adapters
and administrator-approved package policies. It does not trust event delivery to be unique, ordered,
complete, or timely. It does not trust the user who caused a source change to be the user who later
evaluates the record.

Its boundary ends when core returns a response and optionally publishes canonical result events.
Downstream notification, reporting, action, or integration success belongs to those extensions.

## Protected assets

- Source-record identity and change timing.
- Exact Check and Check Set Qualified API Names.
- The effective evaluation principal and its access.
- CDC, Queueable, SOQL, Platform Event, and storage allocations.
- The invariant that core and Change Monitor do not mutate checked business records.
- Replay and gap evidence needed to detect missed or duplicate work.

## Threats and required controls

| Threat | Required control |
| --- | --- |
| Duplicate delivery runs a Check twice | Unique versioned event-policy-record claim before dispatch |
| Reordered older event causes misleading rerun | `ActiveAfter__c`, event-time evidence, idempotency, and no claim that results reflect historical payload state |
| CDC gap silently misses health changes | Treat gap/overflow as a high-priority incident; stop affected automatic dispatch and require reconciliation |
| A delete is evaluated as a live record | Closed change-type routing; DELETE is terminal ignored |
| Event payload bypasses record access | Never evaluate payload fields; core reloads the durable record in user mode |
| System context bypasses core Run permission | Release-blocking principal test; no privileged internal API or permission bypass |
| Admin routes Account changes to an Opportunity Check | Schema-backed source/selection compatibility validation before activation and again before dispatch |
| Changed-field filter is injected or ambiguous | Exact schema-resolved field API names; no expressions, wildcards, relationship paths, or payload values |
| Event storm exhausts limits | Policy caps, batch queries, unique claims, Queueable slicing, core 200-ID limit, explicit publication mode, volume warnings |
| Extension data creates a self-observation loop | Package-owned objects are permanently excluded as source entities |
| Raw CDC or health data leaks through operations records | Minimal ledger with bounded enums/codes; no raw payload, values, display messages, or exception text |
| Subscriber trigger passes arbitrary SObjects | Global handler verifies change-event type, entity, header shape, adapter allow-list, and package policy |
| Retry loop amplifies a permanent failure | Closed transient classification, maximum three attempts, terminal failure |
| Uninstall disables another CDC subscriber | Never disable selected entities automatically; document subscriber dependency review |

## Security invariants

1. No package method accepts administrator-authored SOQL, Apex, Flow name, or expression.
2. No CDC value becomes a core Found or Expected value.
3. No package code modifies a checked business record.
4. No hidden principal or privilege bypass is permitted.
5. Every core invocation identifies one exact selection and at most 200 same-object IDs.
6. Every dispatched record has a durable unique claim first.
7. A package exception stored for administrators is a bounded code, never raw exception text.
8. Package permission sets grant no source-object access; administrators grant business access
   separately according to the effective-principal design.

## Required negative tests

- Wrong sObject type passed to the intake handler.
- Missing or malformed change header.
- Unsupported change type and future additive value.
- Mixed source objects in one dispatch request.
- Namespaced and subscriber-owned selection identity collision.
- Field name with wrong case, relationship traversal, wildcard, and nonexistent field.
- Duplicate claim racing in two transactions.
- Policy deactivation between claim and dispatch.
- Source record deleted between UPDATE event and dispatch.
- Runtime principal loses Run custom permission.
- Runtime principal can see the record but not one required field.
- Queueable limit, row lock, and exhausted retry.
- Gap/overflow signal.
- Attempt to configure a package-owned object as the source.

## Residual risks

- A later evaluation observes current record state, not necessarily the exact state at CDC commit.
- Multiple changes can coalesce operationally into several events or several evaluations of the same
  current state.
- Salesforce allocations and asynchronous backlogs can delay work.
- A successful core run does not guarantee a downstream human or system acted on the result.
- CDC is not permanent history; reconciliation requires a current-state scan owned outside this
  package.

