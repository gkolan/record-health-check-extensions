# RHC Change Monitor development

## Source layout

- `RHCChangeMonitorEventEnvelope` accepts actual ChangeEvent sObjects and retains header facts only.
- `RHCChangeMonitorClaimKey` owns versioned, delimiter-safe SHA-256 identities.
- `RHCChangeMonitorRoutingService` owns closed change-type and changed-field decisions.
- `RHCChangeMonitorIntake` queries active policies once, creates partial-success unique claims, and
  enqueues at most one dispatcher from an intake transaction.
- `RHCChangeMonitorDispatcherQueueable` revalidates policies and invokes core in homogeneous scopes
  of at most 200 source IDs.
- `generate_metadata.mjs` is the canonical generator for the two objects and permission sets.

Regenerate metadata after changing the object declarations:

```bash
node generate_metadata.mjs
```

Do not hand-edit generated object fields or permission sets without updating the generator in the
same change.

## Contract rules

- API `66.0`, namespace `rhc`, and core dependency `Record Health Check@2.0.4-2` match the suite.
- No packaged `PlatformEventChannelMember` is emitted. Administrators enable the standard CDC
  entity deliberately; subscriber code owns concrete adapters.
- No class uses `without sharing`, user impersonation, dynamic Apex, administrator-authored SOQL,
  or unrestricted retry.
- Every dispatch rechecks policy active state and activation time.
- Core gets one exact Check or Check Set identity and no more than 200 same-object IDs.
- Tests use 251 records for the intake bulk boundary and exact assertions for routing behavior.

## Required validation

Run repository validation, Code Analyzer, source deployment validation, all Change Monitor Apex
tests, a namespaced build-org test, and a clean subscriber-style adapter test. Record results in
`RELEASE_EVIDENCE.md`; never convert a missing run into a passing claim.
