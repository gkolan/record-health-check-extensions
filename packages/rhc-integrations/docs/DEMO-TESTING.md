# Complete demo-data and functional test guide

> Audience: Salesforce administrator paired with an integration/receiver owner  
> Environment: sandbox or disposable verification org only  
> Estimated time: 90–150 minutes, including bounded retry waits

This guide exercises every implemented functional boundary with repeatable demo data. It is separate
from Apex/Jest unit tests: these steps prove installed-package behavior, administrator permissions,
subscriber identity, Named Credential authentication, Queueable execution, and an actual external
HTTP receiver.

## Validation status

The repository contains the complete kit and its documentation. As of 2026-08-25:

- the demo directory passes the available Code Analyzer Recommended regex rules with zero findings;
- the package LWC Jest suites pass all eight tests;
- the production Apex suite previously passed 13 tests at 92.03% aggregate coverage;
- the namespaced anonymous Apex demo scripts have not yet been compiled or executed in a subscriber
  org because no installable RHC Integrations `04t` is currently available.

Therefore, do not treat the demo itself as executed release evidence yet. The release owner must run
Sections 5–22 after installing the promoted core version and a newly created Integrations package
version in a clean subscriber org.

## 1. What the kit creates

`scripts/demo/seed-demo.apex` creates:

- one Opportunity named **RHC Demo - Integration Event Reference**;
- seven inactive routes whose names begin **[RHC Demo]**;
- one sanitized `HTTP_400` dead-letter fixture for UI/permission demonstrations.

| Route | Profile/path | Feature exercised |
| --- | --- | --- |
| 01 Result Critical Error - Success | RHC Error v1, `/demo/success` | Check Set + ERROR + CRITICAL exact match |
| 02 Result Warning Failure - Success | RHC Outcome v1, `/demo/success` | Check identity + FAIL + WARNING |
| 03 Run Error - Success | RHC Run v1, `/demo/success` | Run counts and derived ERROR |
| 04 Log Error - Success | RHC Log v1, `/demo/success` | Approved Log routing and diagnostic exclusion |
| 05 Result Error - Retry 503 | RHC Error v1, `/demo/503` | Standard bounded retry |
| 06 Result Error - Permanent 400 | RHC Error v1, `/demo/400` | Immediate dead letter and replay |
| 07 Core Opportunity Actionable - Success | RHC Outcome v1, `/demo/success` | Real core evaluation and ACTIONABLE publication |

The seed is idempotent by route name and fixture Event ID. Running it again adds missing demo records
but does not reset changed routes. Use cleanup and reseed when you need a known baseline.

## 2. What the kit deliberately does not create

- Named Credential or External Credential
- External Credential principal or secret
- Platform Event subscriber-user configuration
- External mock service
- production business data
- active outbound route

Those are subscriber-owned security/operational choices. Follow the
[administrator guide](JUNIOR-ADMIN-GUIDE.md) through subscriber verification before this demo.

## 3. Mock receiver contract

Use an organization-approved HTTPS test receiver. Do not use public request-bin/echo websites with
Salesforce data. Configure it to support:

| Method/path | Response | Evidence it must retain safely |
| --- | --- | --- |
| `POST /demo/success` | 202 or another 2xx | timestamp, Event ID headers, parsed allow-listed JSON, duplicate disposition |
| `POST /demo/503` | 503 with an empty or fixed body | timestamp and Event ID only |
| `POST /demo/400` | 400 with a fixed body | timestamp and Event ID only |

The receiver must deduplicate `Idempotency-Key`. It may record the approved demo payload in its
controlled sandbox evidence store, but must not require Salesforce to retain its response body.

Create a modern Named Credential with API name `RHC_Demo_Service`, the receiver's base URL, and its
approved External Credential. Assign the principal to the dedicated subscriber user. Never store a
secret in these demo files or routes.

## 4. Required access

The administrator running scripts needs:

- Author Apex or equivalent permission to execute anonymous Apex;
- **RHC Integrations Admin**;
- core **Record Health Check User** for the real core scenarios;
- the narrowly assigned core Log publisher/event access required to publish the synthetic Log;
- access to the demo Opportunity and packaged Platform Events.

The dedicated subscriber user—not necessarily the script-running administrator—needs **RHC
Integrations Runtime** plus the `RHC_Demo_Service` External Credential principal.

## 5. Authorize the sandbox and seed data

From `packages/rhc-integrations`:

```sh
sf org login web --alias rhc-integrations-demo --instance-url https://test.salesforce.com
sf apex run --file scripts/demo/seed-demo.apex --target-org rhc-integrations-demo
```

Expected first-run output includes `RHC_DEMO_SEED_COMPLETE`, seven routes, an Opportunity ID, and
`activeRouteCount=0`. A later seed does not overwrite administrator changes. If a repeat run reports
a nonzero active count, deactivate every demo route before continuing.

Click verification:

1. Open **App Launcher → RHC Integrations → Record Health Check Integration Routes**.
2. Select a list view that shows all routes.
3. Confirm seven `[RHC Demo]` rows exist and every **Active** value is false.
4. Open each route and compare it with the table in Section 1.
5. Open **RHC Integrations → Dead Letters → Refresh**.
6. Confirm the `RHC-DEMO-DEAD-LETTER-FIXTURE` row appears with HTTP 400/PERMANENT.

Stop if a route is active, the Named Credential name is not `RHC_Demo_Service`, or a non-demo route
was altered.

## 6. How to run a publisher and capture its Event ID

Example:

```sh
sf apex run \
  --file scripts/demo/publish-result-critical-error.apex \
  --target-org rhc-integrations-demo
```

Copy the `RHC_DEMO_EVENT_ID=` value from output. Wait for Platform Event and Queueable processing,
then inspect **Setup → Apex Jobs** and the receiver evidence. Admins can query a specific ledger row:

```sh
sf data query \
  --target-org rhc-integrations-demo \
  --query "SELECT Name,rhc__EventId__c,rhc__EventType__c,rhc__Status__c,rhc__AttemptCount__c,rhc__HttpStatus__c,rhc__HttpClassification__c,rhc__ErrorCode__c FROM rhc__Record_Health_Check_Integration_Delivery__c WHERE rhc__EventId__c = '<EVENT_ID>'"
```

Use the original Event ID for each query; do not use Salesforce Replay ID.

## 7. Scenario A — sanitized dead-letter UI and roles

1. Leave all routes inactive.
2. As Admin, open Dead Letters and find `RHC-DEMO-DEAD-LETTER-FIXTURE`.
3. Confirm Event ID, route, HTTP 400, PERMANENT, bounded guidance, and Replay action appear.
4. Confirm no payload, response body, exception message, or stack trace appears.
5. Select Replay while Route 06 is inactive; expect **Activate and correct the route before replay**.
6. Repeat as Operator and Viewer; confirm no Replay action.
7. Confirm an unassigned user cannot access the app/data.

Pass: sanitized projection and permission boundaries match [Security](SECURITY.md).

## 8. Scenario B — RHC Error v1 success

1. Activate only Route 01.
2. Run `publish-result-critical-error.apex` and copy its Event ID.
3. Confirm one Queueable completes and one receiver request reaches `/demo/success`.
4. Confirm both idempotency headers equal the Event ID.
5. Confirm JSON profile version `1.0`, contract `1.0`, event type RESULT, demo identities, ERROR,
   CRITICAL, reason code, and demo Opportunity ID.
6. Confirm the ledger status is SUCCEEDED, HTTP 202 (or configured 2xx), Attempt Count 1.
7. Deactivate Route 01.

## 9. Scenario C — RHC Outcome v1 and exact Check identity

1. Activate only Route 02.
2. Run `publish-result-warning-fail.apex`.
3. Confirm one `/demo/success` request with FAIL/WARNING and Check `RHC_Demo_Check`.
4. Confirm profile is RHC Outcome v1 version 1.0 and ledger succeeds once.
5. Deactivate Route 02.

## 10. Scenario D — RHC Run v1 and derived status

1. Activate only Route 03.
2. Run `publish-run-error.apex`.
3. Confirm one request contains counts 4 eligible, 4 evaluated, 2 passed, 1 failed, 1 system
   error, and derived status ERROR.
4. Confirm no severity or Check identity is invented.
5. Deactivate Route 03.

## 11. Scenario E — RHC Log v1 data minimization

1. Activate only Route 04.
2. Run `publish-log-error.apex`.
3. Confirm the receiver gets Event ID, Run ID, occurrence/version fields, event type LOG, and code
   `RHC_DEMO_ERROR`.
4. Search receiver evidence for all of these strings and require zero matches:
   - `DEMO_RESTRICTED_MESSAGE_MUST_NOT_LEAVE_SALESFORCE`
   - `DemoRestrictedException`
   - `DEMO_RESTRICTED_STACK_MUST_NOT_LEAVE_SALESFORCE`
   - `demoRestricted`
5. Confirm user ID and Opportunity ID are also absent from the Log payload.
6. Deactivate Route 04.

## 12. Scenario F — exact filters reject nonmatches

1. Activate Routes 01 and 02 only.
2. Record the receiver's current request count.
3. Run `publish-nonmatching-result.apex`.
4. Wait for event processing.
5. Confirm no ledger row exists for that Event ID and receiver request count is unchanged.
6. Deactivate both routes.

The event deliberately has different identities, PASS, and INFO, so it fails multiple exact filters.

## 13. Scenario G — route/Event ID idempotency

1. Activate only Route 01.
2. Run `publish-duplicate-result.apex`; it publishes two source events with the same Event ID.
3. Confirm exactly one ledger row exists for Route 01 plus that Event ID.
4. Confirm the receiver sees at most one accepted logical request for that Event ID.
5. If transport ambiguity produces a repeated HTTP request, confirm the receiver reports it as a
   duplicate and performs no repeated external work.
6. Deactivate Route 01.

## 14. Scenario H — unsupported payload contract fails closed

1. Activate only Route 01.
2. Run `publish-unsupported-contract.apex`.
3. Confirm no receiver request occurs.
4. Refresh Dead Letters and find the Event ID.
5. Confirm `UNSUPPORTED_EVENT_CONTRACT`, contract version 2.0, and terminal dead-letter status.
6. Do not replay; package version 0.1.0 supports event contract 1.0 only.
7. Deactivate Route 01.

## 15. Scenario I — bounded 503 retry

1. Confirm `/demo/503` always returns 503.
2. Activate only Route 05.
3. Run `publish-result-critical-error.apex`.
4. Query the ledger after each attempt.
5. Confirm Standard policy attempts at most three times with approximately 1- and 5-minute minimum
   delays. Salesforce scheduling can make them later.
6. Confirm final status DEAD_LETTER, HTTP 503, RETRYABLE classification/error code, Attempt Count 3.
7. Confirm the response body is absent from Salesforce.
8. Deactivate Route 05.

## 16. Scenario J — permanent 400 and corrected replay

1. Confirm `/demo/400` returns 400.
2. Activate only Route 06.
3. Run `publish-result-critical-error.apex`.
4. Confirm one attempt and immediate DEAD_LETTER with HTTP 400/PERMANENT.
5. Change the approved mock receiver behavior for `/demo/400` to return 202; do not edit a secret or
   full URL into the route.
6. Open Dead Letters, choose the row action, and select Replay as Admin.
7. Confirm Replay Count increments, Attempt Count restarts, and original Event ID is reused.
8. Confirm the receiver deduplicates the Event ID if it had accepted work before returning 400.
9. Restore `/demo/400` to its normal test behavior and deactivate Route 06.

## 17. Scenario K — actual core ACTIONABLE publication

1. Activate only Route 07.
2. Run `run-core-actionable.apex`.
3. The seeded Opportunity has Amount 0, so the packaged Opportunity Deal Readiness Check Set should
   return at least one actionable failure and publish Result event(s).
4. Confirm receiver requests use the real qualified Check Set
   `rhc__Example_Opportunity_Deal_Readiness` and RHC Outcome v1.
5. Record the script's Run ID, resulting Event IDs, and ledger rows.
6. Deactivate Route 07.

This scenario proves direct consumption of core events rather than only synthetic event mapping.

## 18. Scenario L — Publication NONE produces no delivery

1. Activate Route 07 so a published matching Result would be accepted.
2. Record current ledger row and receiver request counts.
3. Run `run-core-publication-none.apex`.
4. Confirm the script returns evaluation results and prints a Run ID.
5. Wait for the same observation period used in Scenario K.
6. Confirm no ledger row or receiver request exists for that Run ID.
7. Deactivate Route 07.

Pass: core evaluation occurred, but NONE published no event and Integrations produced no delivery.

## 19. Scenario M — payload profile incompatibility

This is package-enforced configuration behavior covered by Apex tests because route picklists alone
cannot prevent every cross-field combination:

1. In a sandbox only, clone Route 03 and select **RHC Outcome v1** while keeping Event Type Run.
2. Activate only that clone and publish `publish-run-error.apex`.
3. Confirm no delivery row and no request—the builder refuses Run + Outcome.
4. Delete the incompatible clone.

Automated evidence: `RHCIntegrationPayloadBuilderTest.shouldReturnNull_WhenProfileIsNotCompatible`.

## 20. Cleanup

First deactivate every `[RHC Demo]` route and confirm no expected retries remain. Then run:

```sh
sf apex run --file scripts/demo/cleanup-demo.apex --target-org rhc-integrations-demo
```

Expected output reports deleted demo delivery, route, and Opportunity counts. Verify:

1. No `[RHC Demo]` route remains.
2. No `RHC-DEMO-*` Event ID remains in the ledger.
3. The named demo Opportunity is gone.
4. The `RHC_Demo_Service` credential remains because it is administrator-owned and cleanup never
   deletes security configuration.
5. No non-demo route, delivery, or business record changed.

## 21. Functional coverage map

| Requirement | Demo scenario | Automated coverage |
| --- | --- | --- |
| Outbound route configuration | Seed + B–L | Event handler tests |
| Check Set/Check exact identity | B, C, F | Exact-match test |
| Status/severity filter | B, C, F | Exact-match test |
| Named Credential/relative endpoint | B–E, I–K | Queueable mock endpoint assertion |
| Four payload profiles/versioning | B–E | Payload builder/subscriber tests |
| Post-commit Queueable | B–E | Queueable tests |
| Delivery ledger | All delivery scenarios | Handler/Queueable tests |
| Retry policy/backoff | I | 503/exhaustion tests |
| Dead-letter queue | A, H–J | 400 and controller tests |
| Permission-gated replay | A, J | allowed/denied replay tests |
| Event ID idempotency | G, J | duplicate test |
| Publication NONE | L | no-event test |
| Restricted Log exclusion | E | subscriber test |
| Unsupported contract | H | handler contract behavior |
| Independent core consumption | K, L | direct subscriber test |

Record every result in the [administrator implementation worksheet](ADMIN-IMPLEMENTATION-WORKSHEET.md).

## 22. What counts as complete

The demo is complete only when the change record contains:

1. the installed core and Integrations package versions;
2. the seven seeded route names and the sanitized fixture Event ID;
3. one captured Event ID or Run ID for every scenario performed;
4. ledger evidence for accepted, retried, dead-lettered, and replayed deliveries;
5. receiver evidence for request path, idempotency header, payload profile/version, and dedupe;
6. negative evidence showing no request for nonmatches and Publication NONE;
7. Admin, Operator, Viewer, and unassigned-user access results;
8. cleanup output and the five cleanup verification checks.

Do not mark a scenario passed based only on `EventBus.publish()` succeeding. That confirms Salesforce
accepted the event for publication; it does not prove subscriber execution, Queueable completion,
HTTP delivery, receiver deduplication, or downstream completion.
