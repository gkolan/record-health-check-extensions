# RHC Logs troubleshooting

## No logs appear

Confirm core 2.0.4.2 or later is installed, the Check Set has **Publish Error Log Event** selected,
the actual running identity has core **Record Health Check Error Log Publisher**, and the run
produced a framework ERROR. Ordinary FAIL results do not create Log events. Publication is best
effort and an uncatchable limit can stop core before flush.

## Viewer sees blank restricted columns

This is expected. Viewer does not receive Message, Structured Details, Record ID, or Running User ID.

## Duplicate deliveries

Salesforce delivers Platform Events at least once. Unique canonical Event ID suppresses a second
record. Never substitute Replay ID as the durable key.

## Ingestion reports partial failure

Review Last Ingestion Status, Failure Count, and Error Categories on Setup. `MALFORMED_CONTRACT`
means required canonical fields were absent. Permanent row failures are counted without retaining
the rejected payload. Transient lock or unknown platform database errors request Salesforce event
retry and roll back the whole delivery; use org subscriber monitoring and debug evidence to diagnose
repeated retry exhaustion.

## Cleanup does not run

Retention must be 1–365, batch size 1–9,998, automation enabled, and the exact package schedule
present. SKIPPED_OVERLAP means an active lock; a lock older than 60 minutes is recoverable.
PARTIAL_FAILURE leaves failed records eligible for retry.

## Source filter is unavailable

Core Log contract 1.0 has no Execution Source. The package refuses to infer it. Check Set and Check
fields are developer names from core, not reconstructed Qualified API Names.

## More matching logs exist

Use **Load More Logs**. Review uses an occurrence-time-and-record-ID keyset cursor, so it does not
silently stop at the first 100 matching rows and does not depend on an unstable offset.
