# Shared no-namespace validation org

Use this org as the canonical shared no-namespace source-validation environment for RHC Change
Monitor until it expires. It is a disposable development environment, not a production org and not
release approval.

## Canonical identity

| Property | Value |
| --- | --- |
| CLI alias | `rhc-change-monitor-nons-shared-20260830` |
| Username | `test-9kkmawpwc3kf@example.com` |
| Org ID | `00DRL00000UKhkO2AT` |
| Instance | `https://fun-innovation-47-dev-ed.scratch.my.salesforce.com` |
| Namespace | None (`null`) |
| Edition | Developer |
| Dev Hub | `rhc-dev-hub` / `devhub@rhcgksf.com` |
| Created | 2026-08-30 |
| Expires | 2026-09-29 |

The alias is already authenticated for tasks running on the maintainer's current Codex host. CLI
aliases and authentication are workstation-local. A contributor on another workstation must obtain
access through an approved secure channel and use this same alias after authentication. Never put a
password, access token, or front-door URL in this repository.

Confirm the target before every operation:

```bash
sf org display --target-org rhc-change-monitor-nons-shared-20260830 --json
```

Always pass `--target-org rhc-change-monitor-nons-shared-20260830`; do not make this shared org the
global default.

## Installed baseline

The org was created with the core repository's `config/subscriber-scratch-def.json`, a 30-day
duration, and the Salesforce CLI `--no-namespace` option.

| Layer | Provenance | Deployment evidence |
| --- | --- | --- |
| Record Health Check core | Unmanaged source exported from release commit `74fe1d6`, which records stable `2.0.4.2` / `04tak000000cZBFAA2` | 382/382 components passed, job `0AfRL00000hD9zB0AS` |
| RHC Change Monitor | Current implementation-preview `force-app` | Analyzer-refactored source deployed, job `0AfRL00000hD5vd0AC`; final Queueable test-context correction deployed as `0AfRL00000hD8v70AC` |
| Account CDC subscriber fixture | Subscriber-owned `AccountChangeEvent` channel membership and `RHCAccountChangeMonitor` trigger | Included in analyzer-refactored deployment `0AfRL00000hD5vd0AC` |

`RecordHealthCheck` and `RHCChangeMonitorIntake` were queried after deployment and both returned
`NamespacePrefix = null`. `sf package installed list` returned no packages. This is deliberately a
source-compatibility org; no package container or version was created or installed.

The scratch-org administrator has `Record_Health_Check_Admin` and
`RHC_Change_Monitor_Admin`. Those assignments support administrator setup but do not prove the
effective CDC trigger or Queueable principal.

## Test evidence

- Focused Change Monitor suite: 19/19 passed, run `707RL00001eGqx1`.
- Focused regression after adding the least-privilege runtime permission set: 19/19 passed, run
  `707RL00001eGCyC`, 95% test-run coverage and 96% org-wide coverage.
- Complete `RunLocalTests` regression: job `707RL00001eGxrHYAS`, 637 completed methods and zero
  failed methods.
- Final org-wide Apex coverage: 98%.
- Change Monitor production-class coverage: Claim Key 94%, Dispatcher 78%, Event Envelope 81%,
  Intake 87%, and Routing 88%.
- Post-analyzer-refactor focused suite: 19/19 passed, run `707RL00001eHWIZ`; Salesforce reported
  84% org-wide coverage.
- Subscriber-owned Account CDC adapter suite: 7/7 passed, run `707RL00001eHNA3`; the tests cover
  CREATE, 251-record bulk CREATE, matching and nonmatching UPDATE, UNDELETE, and DELETE, with 85%
  test-run coverage.
- Final post-refactor `RunLocalTests`: 959/959 passed with zero failures, run
  `707RL00001eHQQq`; Salesforce reported 95% org-wide coverage and 96% test-run coverage.

## Shared-org rules

1. Treat the deployed baseline as shared test infrastructure. Record material changes and their
   evidence before making them.
2. Do not delete the org, deploy destructive changes, change the alias, or replace the core baseline
   without maintainer coordination.
3. Account CDC and the object-specific adapter are active. Coordinate changes because those
   settings affect every Account CDC publisher and subscriber in this org.
4. Do not present a successful source deployment as package-install, upgrade, uninstall, or release
   evidence.
5. Rebuild the org after 2026-09-29 rather than extending claims based on an expired environment.

## Real CDC evidence and current blocker

Account CDC and the subscriber-owned trigger are active. The synthetic policy `CDC Gate Account`
and Account `001RL00002sHLG4YAO` produced the following durable evidence on 2026-08-30:

| Event | Replay ID | Outcome | Reason | Effective creator |
| --- | ---: | --- | --- | --- |
| CREATE | `72747208` | `FAILED` | `RUNTIME_PERMISSION_MISSING` | `autoproc@00drl00000ukhko2at` |
| UPDATE (`Name`) | `72747210` | `FAILED` | `RUNTIME_PERMISSION_MISSING` | `autoproc@00drl00000ukhko2at` |
| UPDATE (`Phone`) | `72747211` | `IGNORED` | `CHANGED_FIELDS_NOT_MATCHED` | `autoproc@00drl00000ukhko2at` |
| DELETE | `72747212` | `IGNORED` | `RECORD_DELETED` | `autoproc@00drl00000ukhko2at` |
| UNDELETE | `72747213` | `FAILED` | `RUNTIME_PERMISSION_MISSING` | `autoproc@00drl00000ukhko2at` |

Every row had a distinct nonblank transaction key, sequence `1`, and the expected source record ID.
This proves real adapter delivery and the two routing-only paths, but does not clear replay,
redelivery, principal, evaluation, or load gates.

A `PlatformEventSubscriberConfig` naming the scratch administrator passed check-only deployment
`0AfRL00000hDCU10AO` and deployed as `0AfRL00000hDBL40AO`. The next real CDC event still ran as
Automated Process, so the configuration was removed and must not be presented as a CDC principal
solution. Automated Process has no profile and lacks core's `Record_Health_Check_Run` permission.
No broad administrator permission set has been assigned to it. A least-privilege, supportable
principal design remains a release blocker. `RHC_Change_Monitor_Runtime` was check-only validated
as job `0AfRL00000hD0xY0AS` and deployed unassigned as job `0AfRL00000hDC7S0AW`. The candidate
experiment is to assign that role plus the no-namespace core `Record_Health_Check_User` role to
Automated Process, but that persistent security change requires explicit approval and still needs
positive/negative CRUD, FLS, sharing, and core execution evidence.

The initial complete Recommended Code Analyzer run found 164 findings. The implementation was
refactored to use typed envelope facts, dedicated CDC parsing and dispatch-support classes, smaller
intake/routing methods, bounded Queueable finalization, compliant tests, and restrictive fixture
queries. The final complete scans found zero violations across package and subscriber source. The
initial zero-finding evidence is `code-analyzer-results-20260830-zero.json`; the scan repeated after
the Queueable test-context correction is `code-analyzer-results-20260830-zero-posttest.json` and
also contains zero findings.

The CLI org-list evidence captured at creation is stored in
[`../evidence/shared-no-namespace-org/scratch-org-result.json`](../evidence/shared-no-namespace-org/scratch-org-result.json).
