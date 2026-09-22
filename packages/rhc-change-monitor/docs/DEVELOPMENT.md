# RHC Change Monitor development

## Source layout

- `RHCChangeMonitorEventEnvelope` accepts actual ChangeEvent sObjects and retains header facts only.
- `RHCChangeMonitorClaimKey` owns versioned, delimiter-safe SHA-256 identities.
- `RHCChangeMonitorRoutingService` owns closed change-type and changed-field decisions.
- `RHCChangeMonitorIntake` queries active policies once, creates partial-success unique claims, and
  publishes one dispatch signal after an intake transaction persists pending work. Immediate
  publication rejection rolls the claims back.
- `RHCChangeMonitorDispatcherQueueable` revalidates policies and invokes core in homogeneous scopes
  of at most 200 source IDs.
- `RHCChangeMonitorRetentionService` owns persisted retention settings and bounded manual deletion.
- `generate_metadata.mjs` is the canonical generator for the three objects and permission sets.
- `scripts/generate-subscriber-adapter.mjs` generates subscriber-owned CDC channel membership and
  a routing-only trigger for one standard or custom source object.

Regenerate metadata after changing the object declarations:

```bash
node generate_metadata.mjs
npm run adapter:generate -- --help
npm run adapter:check -- --object Account --namespace none --output subscriber-app/main/default
```

Do not hand-edit generated object fields or permission sets without updating the generator in the
same change.

## Contract rules

- API `66.0`, namespace `rhc`, and core dependency `Record Health Check@2.0.4-2` match the suite.
- No packaged `PlatformEventChannelMember` is emitted. Administrators enable the standard CDC
  entity deliberately; subscriber code owns concrete adapters.
- No class uses `without sharing`, user impersonation, dynamic Apex, administrator-authored SOQL,
  or unrestricted retry.
- `RHCChangeMonitorDispatchSupport` declares `inherited sharing`; its dispatcher lookup therefore
  retains the explicit sharing context of the `with sharing` Queueable caller and still uses
  `WITH USER_MODE` for object and field access.
- Every dispatch rechecks policy active state and activation time.
- Both intake and administrator retry inspect the dispatch-event `SaveResult`; immediate rejection
  rolls back the associated state transition and surfaces only a bounded error.
- Retention cleanup requires the saved `Default` setting, excludes `PENDING`, and deletes at most
  1,000 evaluations in one user-mode transaction.
- Core gets one exact Check or Check Set identity and no more than 200 same-object IDs.
- Tests use 251 records for the intake bulk boundary and exact assertions for routing behavior.
- The adapter generator defaults to the installed package namespace, supports explicit
  no-namespace source verification, never overwrites existing adapter files implicitly, and has a
  read-only check mode for subscriber-repository CI.

## Required validation

Run repository validation, Code Analyzer, source deployment validation, all Change Monitor Apex
tests, a namespaced build-org test, and a clean subscriber-style adapter test. Record results in
`RELEASE_EVIDENCE.md`; never convert a missing run into a passing claim.
