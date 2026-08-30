# Corrective Flow contract

Contract `1.0` supports active same-org autolaunched Flows only. Every exposed input must be a
scalar Text variable below. Policy checkboxes select supplied values.

## Contract ownership and compatibility

RHC Actions owns this contract. A Flow opts in by exposing exact variables; core has no Flow
dependency. Contract `1.0` is interpreted exactly and has no aliases. Adding, renaming, changing the
type of, or changing the direction of a public variable requires a future explicit contract
version rather than silently changing `1.0`.

| Flow variable                   | Core fact                    |
| ------------------------------- | ---------------------------- |
| `rhcRecordIdV1`                 | Record ID                    |
| `rhcRunIdV1`                    | Run ID                       |
| `rhcCheckSetQualifiedApiNameV1` | Check Set Qualified API Name |
| `rhcCheckQualifiedApiNameV1`    | Check Qualified API Name     |
| `rhcStatusV1`                   | Status                       |
| `rhcSeverityV1`                 | Severity                     |
| `rhcReasonCodeV1`               | Reason Code                  |
| `rhcEventIdV1`                  | Event ID                     |

Additional exposed inputs fail validation. Actions never passes raw payloads, diagnostics, stack
traces, unrestricted strings, or JSON. Internal variables not exposed for input are permitted.

An allow-listed input can exist in the Flow without being selected by a policy. RHC Actions supplies
only the inputs whose policy mapping checkboxes are selected. Flow logic must handle an allowed but
unmapped input being null if the Flow exposes it.

The Flow must also expose scalar Text output `rhcInterviewGuidV1`. Set it from
`$Flow.InterviewGuid` so Action History can retain the Salesforce Flow interview reference.

The input API names are case-sensitive. Select **Available for input** only on allowed inputs.
Select **Available for output**, but not input, on `rhcInterviewGuidV1`. Connect every successful
path through an Assignment that sets `rhcInterviewGuidV1` before the Flow ends. See the
[click-by-click administrator guide](ADMIN_GUIDE.md) for the exact Flow Builder steps.

## Validation moments

For manual execution, validation runs when the approver chooses **Run Action** and again in the
execution transaction. Automatic execution validates in the execution transaction. Revalidation is
required because an administrator can activate a different Flow version after policy creation or
after a Pending Action was captured.

Validation requires:

1. a nonblank Flow API name;
2. an active Flow version;
3. `ProcessType = AutoLaunchedFlow`;
4. policy contract version `1.0`;
5. every exposed input name to be in the allow-list;
6. every selected mapping to resolve to a non-collection Text input; and
7. `rhcInterviewGuidV1` to be a non-collection Text output.

An invalid contract fails closed with safe package-authored validation text. No Flow starts.

## Execution semantics

The package creates a dynamic Flow interview with the selected input map, calls `start()`, and reads
`rhcInterviewGuidV1` after the Flow finishes. Flow execution is asynchronous relative to the
original health-check transaction even though it runs inside the later Actions Queueable
transaction.

The Flow author must assign `$Flow.InterviewGuid` on every successful path. The administrator's
acceptance test must confirm Pending Action and Action History contain a real GUID, not blank output.

## Flow review checklist

- [ ] The intended no-trigger autolaunched version is active.
- [ ] API names and case exactly match contract `1.0`.
- [ ] Inputs are Text, input-only, and non-collection.
- [ ] Interview GUID is Text, output-only, and non-collection.
- [ ] Every success path assigns the interview GUID.
- [ ] Every selected policy mapping has a matching input.
- [ ] No exposed input is outside the allow-list.
- [ ] Subflows, Apex actions, and downstream automation were reviewed.
- [ ] The Flow sends no human alert and performs no external callout for this use case.
- [ ] Execution identities have least-privilege Flow and business-data access.
- [ ] Sandbox Debug and end-to-end Actions acceptance both passed.

Metadata validation cannot prove that a Flow is reversible or limited to one record. Review
subflows, Apex actions, scheduled paths, and downstream automation. External callouts and human
alerting are outside this extension's boundary.
