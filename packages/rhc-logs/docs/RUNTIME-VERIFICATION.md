# RHC Logs runtime verification — October 13, 2026

The approved subscriber-source dry run passed against installed **Record Health Check 2.0.11.4**
(`04tak000000nGjZAAU`) in scratch org `rhc-2-0-11-lws-gautam-20260929`.

- Validation job: `0AfcU00000B5e6XSAR`, status `Succeeded`, `checkOnly: true`.
- Metadata: **56 of 56** components validated, **0** component errors.
- Apex: **34 of 34** test methods passed, **0** failures.
- Package Apex coverage: **471 of 495** executable lines, **95.15%**; no coverage warnings.
- All metadata and test changes were rolled back by Salesforce; Logs was not installed or deployed.

| Component | Covered lines | Executable lines |
| --- | ---: | ---: |
| RHCLogsAdminController | 119 | 128 |
| RHCLogsCleanupScheduler | 16 | 17 |
| RHCLogsCleanupService | 120 | 121 |
| RHCLogsIngestionService | 97 | 109 |
| RHCLogsReviewController | 118 | 119 |
| RHCLogsLogSubscriber | 1 | 1 |

The four test classes exercised 251-event delivery, duplicate suppression, malformed input,
unsupported contracts, restricted-field access, Admin/Viewer/unprivileged behavior, retention
boundaries, cleanup continuation limits, lease handling, scheduling, and review pagination.
Retry classification and exhaustion boundaries are unit-tested; this does not prove real platform
redelivery under persistent database lock contention.

## Subscriber source shape

Unchanged `rhc` package source cannot resolve unqualified core types when uploaded as unmanaged
source into a namespace-null subscriber org. The first dry run (`0AfcU00000B5dwrSAB`) confirmed
that compilation boundary; it ran no tests.

The successful run used a temporary copy of `force-app`, `sfdx-project.json`, and `.forceignore`:

1. Set the copied project's namespace to empty.
2. Qualify only core Log event and Check Set metadata references with `rhc__`, including event
   constructor fields, event-field reads/writes, the publication checkbox, and core references
   in the Admin permission set. Keep extension-owned object and field names unqualified.
3. Preserve `.forceignore`, which excludes Jest tests from the deployed LWC bundles.
4. Run `sf project deploy start --dry-run --source-dir force-app` against the named scratch org
   with `RunSpecifiedTests` and all four Logs test classes.

No application logic, expected assertions, field permissions, or metadata members were changed in
that copy. The package's canonical source retains unqualified references for its `rhc` namespace.

## Verification limits

This is current-source Apex validation against core 2.0.11.4, not a validated 2GP Logs artifact.
Namespaced source validation, the minimum-core current-source org gate, actual subscriber install,
browser acceptance, upgrade/uninstall acceptance, and exact-commit CI remain separate release gates.
The historical 2.0.4.2 evidence remains historical and is not replaced with this newer-core result.

See [Release gates](RELEASE-GATES.md) and [Metadata inventory](METADATA.md).

## Human-review deployment

After separate user authorization, the same namespace-adapted source was deployed to the above
scratch org for interactive review. Job `0AfcU00000B5dYgSAJ` succeeded with all 56 components and
34/34 Apex tests passing. The default scratch user received Logs Admin and core Error Log Publisher
permissions. Five explicitly synthetic logs were verified under Check Set `Demo_Log_Review`, with
one duplicate event suppressed and one unsupported-contract example retained. Retention is 30 days,
batch size 2,000, and automated cleanup remains disabled. This is unmanaged subscriber-source
deployment, not installation of a 2GP Logs artifact. No credentials are recorded in repository docs.
Demo records can be identified by the exact Check Set name; remove only those synthetic records
after review, or let the scratch org expire.
