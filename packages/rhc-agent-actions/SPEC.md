# RHC Agent Actions — specification

## Problem

Core's `RecordHealthCheckRunSetAgentAction` returns `passed/failed/skipped/unable/systemError`
for one record. An Agentforce agent asked "why is this account unhealthy?" cannot answer from
counts, and it cannot discover which Check Set names are valid for the record. Custom Metadata is
not a natural agent data source.

## Actions

### Explain Record Health for Agentforce (`RHCAgentExplainRecordHealthAction.explain`)

Input (exactly one request):

| Field | Required | Rule |
| --- | --- | --- |
| Record ID | yes | any object; the object is derived from the ID |
| Check Set Qualified API Name | no | exact, opaque; must be an active Check Set for that object. When omitted, every active Check Set for the object is evaluated, bounded to 5 in `QualifiedApiName` order |
| Maximum Findings | no | 1–25, default 10 |
| Correlation ID | no | ≤ 120 chars of `[A-Za-z0-9._:-]`, passed to core as run ID |

Output: `contractVersion 1.0`, `success`, `overallStatus` (`PASS` when nothing failed and
nothing was unevaluable; `ATTENTION` when only unevaluable/system-error results exist; `FAIL`
otherwise), `objectApiName`, `checkSetsEvaluated`, five counts, `findings` (each: Check Set and
Check Qualified API Names, status, severity, message, fix, found, expected, action label/URL),
`omittedFindings`, `summaryText` (the lead sentence plus one line per finding with `Fix:`),
`errorType` ∈ {`VALIDATION`, `AUTHORIZATION`, `LIMIT`, `EXECUTION`}, `errorMessage`.

Findings include only `FAIL`, `UNABLE_TO_EVALUATE`, and `ERROR` results; passed and skipped
checks are counted, not listed. Display fields come from core's `EVALUATION_WITH_DISPLAY` result
mode for the running user; `adminDetail` is never copied.

### List Record Health Check Sets for Agentforce (`RHCAgentListCheckSetsAction.listCheckSets`)

Input: `Record ID` or `Object API Name` (record wins). Output: `objectApiName`, `checkSets`
(qualified API name, label, object, description from `CardSubtitle__c`), `summaryText`.
Bulk-safe: one response per request.

## Failure behavior

| Condition | Result |
| --- | --- |
| More than one explain request | one `LIMIT` response per request, nothing evaluated |
| Missing record ID | `VALIDATION` |
| User lacks `Record_Health_Check_Run` | `AUTHORIZATION` |
| Unknown or inactive Check Set / none applicable | `VALIDATION` with the object name |
| Core throws | `EXECUTION` with a fixed sentence; core's own diagnostics carry the detail |

## Boundaries

- No writes. No objects. No dependency on any sibling extension.
- Core public API only: `RecordHealthCheckRequest`, `RecordHealthCheck.evaluate`,
  `RecordHealthCheckResponse`, and the two public Custom Metadata types.
- Agent topic and instructions are org-owned (see `docs/AGENT_SETUP.md`); the package ships
  actions, not an agent.

## Tests

`RHCAgentActionsTest`: findings bounded with fix text and correlation round-trip; unknown Check
Set and multiple requests rejected; authorization denied without core permission; discovery by
record and by object agrees; correlation and status classification.

## Verification

The package converts to Metadata API format and has zero findings under the repository's strict
Code Analyzer policy. The flat explain-response shape is intentionally retained as the public
Agentforce invocable contract; its field-count suppression is scoped to that response type. The
historical five-test org run remains release evidence for its recorded source only. A current Apex
test attempt on 2026-09-20 stopped before submission because the selected scratch-org authorization
was unavailable, so fresh server-side compilation and execution remain required before release.
