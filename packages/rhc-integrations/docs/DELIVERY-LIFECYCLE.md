# Delivery lifecycle, retry, and idempotency

## Runtime states

```text
matching event
     │
     ▼
  PENDING ── 2xx ───────────────> SUCCEEDED
     │
     ├── retryable + attempts left ─> RETRY_WAIT ─> PENDING processing
     │
     ├── retryable + exhausted ─────> DEAD_LETTER
     │
     ├── permanent response ─────────> DEAD_LETTER
     │
     └── invalid route/config ────────> DEAD_LETTER

DEAD_LETTER ── authorized replay after correction ──> PENDING
```

Unsupported event contract `1.0` comparison fails before callout and creates a terminal dead letter
with `UNSUPPORTED_EVENT_CONTRACT`. Duplicate route/Event ID inserts are ignored because the unique
ledger key already represents that logical delivery.

The subscriber processes Platform Events in checkpointed chunks of 50. A chunk rejects
event-to-route fan-out above 1,000 delivery rows before inserting anything. Duplicate rows are safe
idempotent redelivery; row-lock and unknown platform failures request bounded redelivery, while
permanent non-duplicate partial-DML failures raise a bounded ingestion exception instead of silently
losing an event or retrying forever. Operators must investigate repeated subscriber failures and
reduce matching route count when the fan-out boundary is reported.

## HTTP classification

| Observation | Classification | Action |
| --- | --- | --- |
| 200–299 | SUCCESS | Succeeded, terminal |
| 408, 425, 429 | RETRYABLE | Retry if policy has attempts remaining |
| 500–599 | RETRYABLE | Retry if policy has attempts remaining |
| `CalloutException` | TRANSPORT | Retry if policy has attempts remaining |
| Any other HTTP status, including 400/401/403/404 | PERMANENT | Dead-letter immediately |
| Unsafe/inactive runtime route | configuration error | Dead-letter without callout |

Only status code and a bounded package classification are saved. The response body is not read.

## Retry policies

| Route choice | Maximum total attempts | Delay after attempt 1 | After attempt 2 | After attempt 3 | After attempt 4 |
| --- | ---: | ---: | ---: | ---: | ---: |
| No Retry | 1 | — | — | — | — |
| Standard | 3 | 1 minute | 5 minutes | terminal | — |
| Aggressive | 5 | 1 minute | 2 minutes | 5 minutes | 10 minutes |

These are bounded fixed schedules, not customer-configurable formulas. Salesforce scheduling and
Queueable availability can make actual execution later than `Next Attempt At`.

## Replay contract

Replay requires all of the following:

1. The user can access the private ledger row in user mode.
2. Status is `DEAD_LETTER`.
3. The route is active.
4. The user has custom permission `RHC_Integration_Replay`.

Replay resets Attempt Count and transient HTTP/error fields, increments Replay Count, preserves the
retained payload and original Event ID, and enqueues a new Queueable. Up to 50 dead letters can be
replayed in one request; they share one delivery chain, and an inactive route anywhere in the
selection rejects the whole request. Replay is at-least-once; an
earlier timed-out request may already have completed externally.

Each Queueable hop locks a slice of up to ten ledger rows in queue order, performs every callout
of the slice, and then persists the whole slice with one update. Callouts always precede DML
because Salesforce forbids a callout after uncommitted DML. Concurrent workers therefore never
claim the same visible state. If a hop ends with an unhandled exception before that update, its
Finalizer records `QUEUEABLE_UNHANDLED` on every row of the slice that is still deliverable,
without persisting exception text, and chains the remaining work. Rows whose request had already
been sent in that hop are resent on replay; the `Idempotency-Key` header carries the same Event ID
so a compliant receiver does not duplicate them. Review the corresponding Async Apex job before
authorizing replay.

A delivery whose `NextAttemptAt__c` is still in the future is rotated to the end of the retained
work list without consuming an attempt. Independent ready deliveries continue without delay; the
Queueable uses the shortest bounded delay only when every remaining row is waiting.

## Operational interpretation

- Empty Dead Letters does not prove that an event was published or matched.
- `SUCCEEDED` proves only that Salesforce received a 2xx response.
- `RETRY_WAIT` is not permission for manual replay.
- A permanent 400 requires contract/endpoint correction before replay.
- A 401/403 usually requires credential/principal correction, then replay.
- Network, DNS, TLS, endpoint availability, rate limits, event delivery, and async capacity remain
  outside the package's transactional guarantee.
