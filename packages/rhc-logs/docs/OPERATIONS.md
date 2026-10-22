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
each initiating run processes at most six batches. A larger backlog requires another run; async
capacity can also prevent continuation. Partial failures remain for retry. Active overlap locks
skip; locks older than 60 minutes are recoverable.
Cleanup is disabled until configured and deliberately enabled for the schedule.
The manual-cleanup toast reports the initiating batch's outcome and counts. Skipped, unconfigured,
access-denied, and partially failed outcomes show a warning. Success does not certify that all
expired logs were deleted or that queued follow-up batches have finished.

Plan for daily Platform Event allocation, at-least-once delivery, temporary event retention,
Automated Process behavior, Apex CPU/heap/SOQL/DML, async and scheduled Apex quotas, query
selectivity, custom-object storage, delete/recycle-bin behavior, reports/exports, and backups.
Salesforce Storage Usage is authoritative; the package record count is not billing evidence.

Development and CI run four dependency-security checks before Jest. The pinned brace-parser
replacement rejects nesting deeper than 100 levels; keep test globs within that bound. Run the
full dependency audit after lockfile changes and review the overrides documented in
[Security](SECURITY.md#development-dependencies).
