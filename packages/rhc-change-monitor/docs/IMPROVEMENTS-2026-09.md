# RHC Change Monitor — improvement specification (2026-09)

Baseline: 44 components deploy, 19 Apex tests pass, zero analyzer findings. The package is an
implementation preview whose release is blocked on Gate 3 (execution principal) in
`GAP_ANALYSIS.md`; the shared no-namespace org still shows real CDC deliveries failing closed with
`RUNTIME_PERMISSION_MISSING`.

## Decision for this pass — revised

The first pass made no runtime change. At the maintainer's request the Gate 3 experiment was run
and the package was completed with the resulting design.

## CM1 — Execution principal (Gate 3)

**Finding.** Permission sets can be assigned to Automated Process, but custom permissions granted
that way are not honored: CREATE and UPDATE deliveries still failed `RUNTIME_PERMISSION_MISSING`
(claims for Account `001RL00002zpHMTYA2`). Assignments reverted.

**Change.** New platform event `Record_Health_Check_Change_Dispatch__e` (`ClaimCount__c`).
`RHCChangeMonitorIntake` publishes it after persisting pending claims instead of enqueueing.
New trigger `RHCChangeMonitorDispatchSubscriber` calls
`RHCChangeMonitorDispatchSupport.enqueueDispatcher()`, which enqueues one dispatcher unless one is
already queued. The subscriber deploys a `PlatformEventSubscriberConfig` naming its runtime user
(template under `subscriber-app`). Admin and Runtime permission sets gain read/create on the event.

**Evidence (shared org, 2026-09-18).** Account `001RL00002zzRFIYA2` UPDATE → `EVALUATED /
ACCEPTED`, `ResultCount__c = 1`, run `cm-v1-d60fed50e886aa11ae053c8a959e496a7eebf483cbb23280`,
dispatcher `AsyncApexJob` created by the configured user. Note: a trigger already subscribed
before the config exists keeps running as Automated Process until it is deactivated and
reactivated once.

## CM2 — Operations console, retry, and retention

`RHCChangeMonitorAdminController` (user mode, sanitized errors) plus LWC
`rhcChangeMonitorConsole`, tab, and app **RHC Change Monitor** (Admin permission set):

- outcome/reason buckets for the last 7 days, pending count, retryable-failure count, whether a
  dispatcher is queued, whether the viewer holds the core run permission, policies, last 50 claims;
- a warning with the exact remediation when `RUNTIME_PERMISSION_MISSING` appears;
- **Retry failed claims**: resets up to 2,000 `FAILED` claims whose reason is
  `RUNTIME_PERMISSION_MISSING`, `TRANSIENT_RETRY`, `RETRY_EXHAUSTED`, or
  `DISPATCH_CHAIN_EXHAUSTED` (never routing/configuration verdicts) to `PENDING` and publishes one
  dispatch event — used to re-dispatch the seven historical failures (all reached `EVALUATED`);
- **Purge**: deletes up to 10,000 terminal claims older than N days (1–3650); `PENDING` is never
  deleted. Scheduled purge is deliberately not added until claim volume is measured.

Tests: `RHCChangeMonitorAdminControllerTest` (2), Jest `rhcChangeMonitorConsole` (3). Package gains
`package.json`/`jest.config.js` like its siblings. Shared-org deploy 54/54; Apex 21/21
(`707RL00001hk0DS`).

## Remaining before registration

1. Rebuild the shared org before 2026-09-29 and repeat the evidence table with a dedicated
   integration user rather than the scratch administrator.
2. Gate 4 load/limit measurements and the amplification scenario.
3. Change Evaluation scheduled retention once volume is known.
