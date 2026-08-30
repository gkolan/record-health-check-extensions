# Demo script index

These anonymous Apex scripts target a subscriber org where the managed core and RHC Integrations
packages are installed with namespace `rhc`. They intentionally use namespaced API names.

Run from the `packages/rhc-integrations` directory:

```sh
sf apex run --file scripts/demo/seed-demo.apex --target-org <ALIAS>
```

| Script | Purpose |
| --- | --- |
| `seed-demo.apex` | Idempotently create seven inactive routes, one Opportunity, and one sanitized dead letter |
| `publish-result-critical-error.apex` | RHC Error v1, exact Check Set, ERROR/CRITICAL |
| `publish-result-warning-fail.apex` | RHC Outcome v1, exact Check, FAIL/WARNING |
| `publish-run-error.apex` | RHC Run v1 with derived ERROR from System Error Count |
| `publish-log-error.apex` | RHC Log v1 and prohibited diagnostic exclusion |
| `publish-duplicate-result.apex` | Publish two events with one Event ID to test route/Event idempotency |
| `publish-nonmatching-result.apex` | Prove exact identity/status/severity filters reject an event |
| `publish-unsupported-contract.apex` | Prove event contract 2.0 fails closed to dead letter |
| `run-core-actionable.apex` | Run the packaged core Opportunity example with ACTIONABLE publication |
| `run-core-publication-none.apex` | Run the same Check Set with NONE and prove no delivery |
| `cleanup-demo.apex` | Delete only `[RHC Demo]`, `RHC-DEMO-*`, and the named demo Opportunity data |

All routes start inactive. Scripts do not create credentials, principals, subscriber configurations,
or secrets. Follow [the complete demo guide](../../docs/DEMO-TESTING.md).

