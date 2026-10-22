# Core Log-event gap analysis

The promoted Record_Health_Check_Log__e contract in core 2.0.4.2 is sufficient. It provides a
required canonical Event ID, run/time/version/error classification, restricted detail, optional
record/check/user context, default-off publication, and separate publisher permission. No core
modification is proposed.

Contract 1.0 does not publish Execution Source or Check/Check Set Qualified API Names. It publishes
developer-name strings. RHC Logs preserves those exact strings and does not infer source or
reconstruct namespaces. Stack Trace is excluded to minimize the Day 1 restricted surface. Details
JSON is retained only as a bounded opaque value, never parsed into a second contract.

Minimum promoted subscriber version: Record Health Check@2.0.4-2 / 04tak000000cZBFAA2.

Source compatibility was also checked against promoted core 2.0.11.4's creation commit
`5905f999dfee391bd4ff029611023f157e60e8ee` on October 13, 2026. The Log event schema, logger,
publication control, publisher permission, and settings provider are unchanged from the minimum
core baseline. Contract 1.0 still has no Execution Source field. The subsequent subscriber-source
dry run passed 34 Apex tests at 95.15% coverage; see [Runtime verification](RUNTIME-VERIFICATION.md).
Acceptance of an actual installable Logs artifact remains pending.

Reproduce the current-release check from this package:

```bash
npm run validate:core-contract -- --core-ref 5905f999dfee391bd4ff029611023f157e60e8ee
```

