# RHC Actions core gap analysis

The minimum compatible promoted version is **Record Health Check 2.0.4.2**
(`Record Health Check@2.0.4-2`, `04tak000000cZBFAA2`).

It supplies Result contract `1.0` with Event ID, Run ID, record ID, Check Set and Check Qualified
API Names, status, severity, reason code, occurrence time, source, framework version, and the
restricted-detail marker. The event is `PublishAfterCommit`; publication `NONE` returns before
event construction.

No core change is required. This contract is sufficient for exact matching, allow-listed inputs,
idempotency, and cooldown. Actions does not need raw values, messages, stack traces, or extension
records.

The event lacks a correction-causation token. That could enrich tracing, but is not required for
safe Day-1 behavior because Actions mandates a positive policy-record cooldown and bounded
attempts. Expanding core's public contract is unjustified.
