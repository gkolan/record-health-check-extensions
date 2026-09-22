# RHC Agent Actions release evidence

Status: **source-only; not release-ready**.

No package container or subscriber version exists. Passing local or source-deployment checks does
not authorize package creation. A release owner must separately authorize any future container or
version operation after the gates below pass for one exact commit.

## Declared contract

| Item | Current value |
| --- | --- |
| Package project | `RHC Agent Actions` |
| Namespace declaration | `rhc` |
| Source API | `66.0` |
| Core dependency | `Record Health Check@2.0.4-2` / `04tak000000cZBFAA2` |
| Package container | Not registered |
| Subscriber version | None |
| Package-owned data or automation | None; Apex actions and one Apex-access permission set only |

## Current working-tree evidence — 2026-09-20

| Gate | Result |
| --- | --- |
| Repository contracts and links | Passed as part of the nine-project suite validation |
| Metadata XML parsing | Passed |
| Metadata API conversion | Passed; `/tmp/rhc-agent-actions-convert-20260920` |
| Repository Code Analyzer policy | Passed with zero findings; `/tmp/rhc-agent-actions-ci-clean2-20260920.json` |
| Current Apex execution | Not run; the selected scratch-org authorization was unavailable before submission |
| Exact-commit CI | Pending; the suite-wide working tree is uncommitted |

The five-test shared no-namespace run recorded on 2026-09-18 is historical evidence for the source
deployed then. It is not proof for the current working tree.

## Required before any package artifact

- [ ] Commit the intended source and obtain passing static/local CI for that exact SHA.
- [ ] Run namespaced source validation and all `RHCAgentActionsTest` methods with coverage in a
      disposable org containing only the pinned core dependency.
- [ ] Validate the actions with an actual least-privilege Agentforce runtime user, including
      authorized, unauthorized, inaccessible-record, and inaccessible-field behavior.
- [ ] Confirm output labels and topic instructions in the supported Agent Builder experience.
- [ ] Review conversational latency for the five-Check-Set and 25-finding bounds.
- [ ] Complete a security and release-worthiness review and explicitly authorize package creation.

If a candidate is later authorized, clean-subscriber installation, permission assignment, agent
configuration, upgrade, and uninstall acceptance must pass before promotion. A `0Ho` container is
never an installation ID, and a beta `04t` is not release approval.
