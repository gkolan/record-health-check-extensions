# RHC Builder — improvement specification (2026-09)

Baseline: 57 components deploy, 40 Apex tests pass, 32 Jest tests pass, zero analyzer findings.
Source reviewed: `RHCBuilderController`, `RHCBuilderMetadataService`, `RHCBuilderContractGateway`,
`RecordHealthCheckBuilderContract`, validators, `recordHealthCheckBuilder` LWC.

## B1 — Surface Metadata API component failures on the deployment ledger

**Problem.** `RHCBuilderMetadataService.DeploymentCallback.handleResult` records only a fixed
sentence ("Salesforce rejected the metadata publication…") when a deployment fails. The
administrator must leave Builder and open Setup → Deployment Status to learn which Check and which
field was rejected. `ResultSummary__c` is a 32,768-character long text area and already holds the
outcome, so the evidence has a home.

**Change.** Add `@TestVisible private static String failureSummary(Metadata.DeployResult result)`
that appends up to `MAX_REPORTED_FAILURES = 10` entries from
`result.details.componentFailures` as `"<fullName>: <problem>"`, each bounded to 255 characters,
plus a count of omitted failures. The callback stores the fixed sentence followed by that list.
Success text is unchanged. No stack traces, no request payloads.

**Acceptance.**
- A failed result with two component failures stores both `fullName: problem` lines.
- A failed result with twelve failures stores ten lines and "…and 2 more".
- A failed result without details stores only the fixed sentence.
- A succeeded result is unchanged.

**Tests.** `RHCBuilderMetadataServiceTest`: `failureSummary_listsBoundedComponentFailures`,
`failureSummary_withoutDetails_isFixedSentence`. `Metadata.DeployResult`, `DeployDetails`, and
`DeployMessage` are constructible in Apex tests.

**Docs.** `docs/OPERATIONS.md` (failed publication section) explains where the component list
appears.

## B2 — Cross-suite X1: stale Builder home after publish/save

**Problem.** `getBuilderHome` and `getSetDeployment` are `cacheable=true` but the component
re-reads them imperatively after save, publish, activate, and rollback. The version list and
deployment status can lag until reload.

**Change.** Remove `cacheable=true` from `getBuilderHome` and `getSetDeployment`. Keep it on
`getAuthoringContract`, `getCheckSetVersion` (versions are immutable), `listReadableObjects`,
`listReadableFields`, and `listReadableRelationships`.

**Acceptance.** After "Publish", the home list shows the new `DEPLOYING` ledger row without reload.

## B3 — Version diff against the active version (added in the second pass)

Reviewing a saved version now shows **Changes versus active version N** for the same Check Set:
Check Set fields that differ, added checks, removed checks (which publication deactivates), and
changed checks with the names of the changed fields. `diffVersions` in `builderModel.js` matches
checks by qualified API name; the raw JSON remains below for full inspection. No Apex change —
the active version is read through the existing immutable, cacheable `getCheckSetVersion`.
Test: builderModel "diffs two versions by check identity and changed field names".

## Not changed

- The publication plan already deactivates Checks omitted from the prior active version
  (`RHCBuilderContractGateway.buildDeploymentPlan`); no orphan-activation bug exists.
- Stale `DEPLOYING` rows when a callback never fires remain an operator procedure
  (`docs/OPERATIONS.md`); a timeout sweeper would add a scheduled job for a rare case.
