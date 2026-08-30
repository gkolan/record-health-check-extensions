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

