# Repository recovery context — 2026-09-19

This note reconstructs verified context retained outside the working tree after the iCloud sync
failure. It is not new release evidence and does not replace the package specifications or test
artifacts.

## What is already safe in GitHub

Commit `378818a6eab063266200b533247bc9cef0833790` (`Initial Commit`, 2026-08-30) already contains
the August RHC Change Monitor specification, implementation, subscriber adapter, security and
operations documentation, and recorded no-namespace evidence. The surviving checkout is based on
that commit and `origin/main` points to it.

The old checkout at `/Users/gkolan/Documents/GitHub/record-health-check-extensions` no longer has a
Git repository and its Change Monitor directory contains no files. Do not use it as the recovery
source. The surviving checkout is `/Users/gkolan/GitHub/record-health-check-extensions`.

## Retained Change Monitor implementation context

The CDC extension deliberately remained source-only. No 2GP package container or package version
was created because package creation was locked until every feasibility and release-worthiness gate
passed.

The analyzer remediation included:

- typed `RHCChangeMonitorEventEnvelope.Facts` input instead of a long positional constructor;
- dedicated `RHCChangeMonitorEventParser` and `RHCChangeMonitorDispatchSupport` classes;
- decomposed intake and routing logic;
- bounded Queueable chaining and finalizer-based recovery;
- finalizer attachment only during a genuine Queueable execution, because direct test invocation
  cannot call `System.attachFinalizer`;
- lower-camel-case tests, bounded fixture queries, and regenerated permission sets; and
- the least-privilege `RHC_Change_Monitor_Runtime` permission set, intended to be paired with the
  core runner permission set after principal validation.

The first complete Recommended Salesforce Code Analyzer run found 164 findings. After remediation,
the complete package-plus-subscriber scan reported zero findings. The ignored generated files
`code-analyzer-results-20260830-zero.json` and
`code-analyzer-results-20260830-zero-posttest.json` are not present in the surviving checkout, but
their results and provenance are recorded in `packages/rhc-change-monitor/RELEASE_EVIDENCE.md` and
`packages/rhc-change-monitor/docs/SHARED_NO_NAMESPACE_ORG.md`. Do not fabricate replacements with
the old filenames; rerun the analyzer against the current source and store new dated evidence.

## Retained no-namespace evidence

Canonical scratch org:

- alias: `rhc-change-monitor-nons-shared-20260830`
- username: `test-9kkmawpwc3kf@example.com`
- org ID: `00DRL00000UKhkO2AT`
- instance: `https://fun-innovation-47-dev-ed.scratch.my.salesforce.com`
- namespace: none
- expiration: 2026-09-29

The org was rechecked on 2026-09-19 and was still active and authenticated. It remains a
time-sensitive independent recovery source for deployed Salesforce metadata.

Recorded successful evidence:

| Evidence | Result |
| --- | --- |
| Refactored source deployment | `0AfRL00000hD5vd0AC` |
| Final Queueable correction | `0AfRL00000hD8v70AC` |
| Focused Change Monitor tests | 19/19 passed, `707RL00001eHWIZ` |
| Account CDC adapter tests | 7/7 passed, `707RL00001eHNA3`, 85% run coverage |
| Complete local regression | 959/959 passed, `707RL00001eHQQq`, 95% org-wide and 96% run coverage |
| Final analyzer scan | 0 findings after the Queueable correction |
| Repository validation at that point | 8 packages, 179 Markdown files, 634 local links; API 66.0 and core 2.0.4-2 |

The adapter suite covered CREATE, 251-record bulk CREATE, matching and nonmatching UPDATE,
UNDELETE, and DELETE. This proved no-namespace source deployment and adapter behavior; it was not a
managed-package installation.

## Why it was not release-ready

The following gates remained open:

1. prove stable identity across actual redelivery/replay and gap scenarios;
2. establish a supported least-privilege execution principal for CDC and Queueable work;
3. prove positive and negative CRUD, FLS, sharing, and core Run-permission behavior;
4. complete the namespaced and no-namespace adapter packaging matrix;
5. measure multi-policy event amplification, backlog, retry, overflow, and operational evidence;
6. complete install, upgrade, and uninstall lifecycle validation only after an explicitly authorized
   release candidate exists; and
7. record an explicit release-worthiness decision before creating any package.

Real CDC ran as Automated Process (`autoproc@00drl00000ukhko2at`). CREATE, matching UPDATE, and
UNDELETE reached the dispatcher but failed closed with `RUNTIME_PERMISSION_MISSING`; nonmatching
UPDATE and DELETE followed their expected ignored paths. A `PlatformEventSubscriberConfig` did not
change the CDC execution principal and was removed. The runtime permission set was deployed but
left unassigned; broad administrator access was intentionally not used as a shortcut.

## Current local recovery state

At inspection time the surviving checkout had 92 modified tracked files, 32 untracked entries, and
no tracked deletions. These include September work beyond the retained August context. Do not run a
reset, clean, checkout-overwrite, pull-with-rebase, or mass regeneration before preserving this
working tree.

Git also contains an `AUTO_MERGE` tree at
`76c45d8a7eb40303f0fb65a8fccc8f07ad354789`. It matches the current tracked working tree except for
one line in `packages/rhc-alerts/force-app/main/default/lwc/rhcAlertsAdmin/rhcAlertsAdmin.js`.
Because it is not a normal branch or commit, it may eventually be garbage-collected. An unreachable
commit `d4c11a790ce98b44a90c8912071c6833d4f6156b` is only an index snapshot based on the initial
commit and does not replace preservation of the current working tree or untracked files.

## Recovery execution results

The non-generated working tree was preserved on 2026-09-19 as commit `a4f8384` and pushed to
`origin/codex/recovery-icloud-2026-09-19`. A clean reconstruction checkout was created at
`/Users/gkolan/GitHub/record-health-check-extensions-reconstruction` from `origin/main`.

The active scratch org was retrieved twice into isolated projects. The full recovery-branch
retrieval returned 72 package files and 6 subscriber files without warnings. All retrieved Apex
classes and triggers were semantically identical to the pushed recovery branch. The subscriber
configuration differed intentionally: the org contained its concrete runtime username and
Salesforce-managed partition settings, while source control retained the distributable placeholder
template.

Fresh validation against the recovered September source produced:

| Check | Result |
| --- | --- |
| Recommended Code Analyzer | 6 findings: 0 Critical, 0 High, 3 Moderate, 3 Low |
| Focused Apex suite | 28/28 passed, run `707RL00001hsh9w` |
| Complete `RunLocalTests` | 980/980 passed, run `707RL00001hsm2P`, 95% org-wide and run coverage |
| LWC Jest | 5/5 passed |
| LWC coverage | 100% statements, lines, and functions; 81.81% branches |
| Dependency audit | 0 vulnerabilities |
| Metadata regeneration | No tracked diff |
| Repository validation | 9 packages, 153 Markdown files, 397 local links; API 66.0 and core 2.0.4-2 |

The six analyzer findings are new September review work and must not be confused with the verified
zero-finding August baseline. Generated reports are retained locally under
`packages/rhc-change-monitor/.release-evidence/recovery-20260919/` and remain ignored by Git.

## Ignored artifact recovery

An audit on 2026-09-19 found 92,114 ignored files totaling 957,907,774 bytes in the preserved
checkout. Of these, 90,904 files were dependency trees, 1,099 were Salesforce local state, and 107
were coverage output. These categories were excluded because they are reproducible or local-state
material rather than product source.

Twenty meaningful ignored or locally generated evidence artifacts totaling 34,442,136 bytes were
copied to `/Users/gkolan/GitHub/record-health-check-extensions-recovered-ignored-20260919`. They
comprise 12 historical analyzer files from the iCloud survivor directory, four current Change
Monitor analyzer/test results, and four metadata-retrieve receipts. The archive contains a manifest
and SHA-256 catalog; all checksums passed and an artifact-only credential-marker scan returned no
matches. The archive remains outside Git intentionally.

## Safe recovery options

1. **Preserve first:** create a local recovery branch and commit the complete non-generated working
   tree, then push that branch before attempting cleanup or reconciliation.
2. **Separate reconstruction:** clone `origin/main` into a new directory, then selectively apply
   reviewed files from the preservation branch. This offers the cleanest audit trail.
3. **Salesforce recovery:** before 2026-09-29, retrieve deployed Change Monitor and subscriber
   metadata from the scratch org into a separate directory and compare it with the preserved branch.
4. **Generated evidence:** rerun Code Analyzer and tests against the reconstructed source. Treat the
   old job IDs as historical proof, not proof of a changed September tree.

Do not include `.sf`, authentication files, `node_modules`, coverage output, passwords, access
tokens, or front-door URLs in a recovery commit.
