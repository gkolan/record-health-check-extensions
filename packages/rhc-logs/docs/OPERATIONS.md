# RHC Logs operations

The Setup page shows best-effort last-ingestion counts, duplicate suppression, ingestion status and
sanitized error categories, unsupported contract count, last cleanup status/counts and lease state,
schedule state, retained count, and oldest/newest event time. These are snapshots, not a complete
audit ledger. Monitor the core runner and event-triggered Apex separately.

Transient `UNABLE_TO_LOCK_ROW` and unknown platform database failures roll back the whole event
delivery and request Platform Event retry. Canonical Event ID uniqueness makes redelivery
idempotent. Malformed contracts and permanent database failures are not retried indefinitely; the
latest batch exposes a failure count, `PARTIAL_FAILURE`, and sanitized categories without retaining
the rejected payload. Redelivery is bounded: after three Platform Event retries the transient rows
are counted as failed with the `RETRY_EXHAUSTED` category instead of letting Salesforce suspend the
trigger, and the successful rows of that delivery are kept. Subscriber state and delivery behavior
must still be verified in an org before release.

Eligibility is strictly Occurred At < now - Retention Days. A record exactly on the boundary remains.
Each run deletes only the oldest eligible RHC Diagnostic Logs up to Cleanup Batch Size. When a run
deletes a full batch, it enqueues up to five bounded continuations under the same user and mode so
a backlog drains within one schedule instead of one batch per day. Partial failures remain for retry. Active overlap locks skip; locks older than 60 minutes are recoverable.
Cleanup is disabled until configured and deliberately enabled for the schedule.

Plan for daily Platform Event allocation, at-least-once delivery, temporary event retention,
Automated Process behavior, Apex CPU/heap/SOQL/DML, async and scheduled Apex quotas, query
selectivity, custom-object storage, delete/recycle-bin behavior, reports/exports, and backups.
Salesforce Storage Usage is authoritative; the package record count is not billing evidence.
