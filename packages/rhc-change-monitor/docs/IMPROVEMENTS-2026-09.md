# RHC Change Monitor — improvement specification (2026-09)

Historical baseline: 44 components deployed, 19 Apex tests passed, and the analyzer reported zero
findings. The package remains an implementation preview. Gate 3 (execution principal) passed on
2026-09-18 through the package dispatch event and subscriber-configured runtime user described
below; Gates 1, 2, and 4 remain open in `GAP_ANALYSIS.md`.

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
- **Dispatch publication atomicity**: intake and administrator retry now inspect the immediate
  platform-event publish result. A rejected signal rolls back the new claims or retry transition
  and returns a bounded domain/UI error instead of leaving signal-less `PENDING` work. Focused
  negative tests cover both rollback paths;
- **Pending-work recovery**: when pending claims exist and no dispatcher is active, an administrator
  can publish one idempotent, data-free wake-up signal without editing claims. The console disables
  the action when there is no work or a dispatcher is already active and surfaces publication
  rejection as a bounded error;
- **Purge**: the 2026-09-20 follow-up added a package-owned settings singleton. The displayed
  90-day recommendation cannot authorize deletion until an administrator saves a 1–3,650-day
  window. Each explicitly confirmed run deletes at most 1,000 oldest terminal claims outside that
  window; `PENDING` is never deleted. Scheduled purge remains deliberately absent.

Historical tests: `RHCChangeMonitorAdminControllerTest` (2), Jest `rhcChangeMonitorConsole` (3).
The current follow-up expands the Aura controller to six operations, its focused Apex test class to
seven methods, and the local Jest suite to eleven tests.
Package gains `package.json`/`jest.config.js` like its siblings. The pre-follow-up shared-org deploy
was 54/54; Apex 21/21 (`707RL00001hk0DS`). Current retention metadata and Apex still require fresh
org validation.

## CM3 — Subscriber adapter generator

`scripts/generate-subscriber-adapter.mjs` creates the three subscriber-owned source-format files
for one standard or custom CDC entity: the `ChangeEvents` channel member, routing-only trigger, and
trigger metadata. It defaults to the installed `rhc` namespace, supports explicit no-namespace
verification, refuses implicit overwrite, and provides `--check` for read-only CI drift detection.
Node tests cover standard/custom naming, namespace modes, exact output, overwrite protection,
invalid input, and drift detection. Generation and checking never deploy metadata or create a
package or package version.

## Remaining before registration

1. Rebuild the shared org before 2026-09-29 and repeat the evidence table with a dedicated
   integration user rather than the scratch administrator.
2. Gate 4 load/limit measurements. The executable Apex scenario now asserts the proposed
   ten-policy boundary over 251 record IDs produces exactly 2,510 policy-record claims, but it must
   be compiled and measured in an authorized org before it counts as capacity evidence.
3. Measure retained-evaluation volume and seek explicit records-policy approval before designing
   any scheduled cleanup; manual bounded cleanup is implemented.
