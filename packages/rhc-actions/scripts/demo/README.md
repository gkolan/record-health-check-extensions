# RHC Actions sandbox demo kit

This directory contains synthetic, repeatable subscriber-org data for demonstrating RHC Actions.
It is an operator aid, not deployable package metadata. Run it only in a sandbox or disposable test
org after installing Record Health Check core and RHC Actions.

The complete junior-admin procedure is in
[Demo data and full functional test](../../docs/admin/DEMO_DATA_AND_FULL_TEST.md). That guide says
exactly which Salesforce page to open, which script to run, and what result to record.

## Safety and scope

- Every owned business record uses the exact marker `[RHC ACTIONS DEMO]`.
- The policy uses Check Set `RHC_Actions_Demo` and Check `Account_Has_Primary_Contact`.
- Event IDs are deterministic. Re-running a scenario proves event-ID idempotency instead of
  silently producing another execution.
- The seed is idempotent and stops if it finds more than one exact Account or policy.
- Cleanup has a read-only preview and deletes only the exact demo Account, policy, related package
  audit records, and exact-subject demo Tasks.
- Cleanup is intentionally separate because the package permission sets do not grant delete access
  to operational audit records.
- These scripts use installed subscriber names such as `rhc__RHC_Action_Policy__c`. They are not for
  a namespace-free source scratch org.

## Prerequisites

1. Install the minimum compatible promoted core package and RHC Actions package.
2. Assign RHC Actions Admin to the setup administrator and RHC Actions Approver to Maya.
3. Build and activate `Create_Data_Steward_Task` exactly as the admin guide specifies.
4. Make the demo Flow's Task subject exactly
   `[RHC Actions Demo] Review primary contact` so verification and cleanup can identify it.
5. Give the executing identities the Account, Task, Flow, sharing, CRUD, and field access the Flow
   requires.
6. Authenticate the sandbox with Salesforce CLI and choose its alias. The examples below use
   `<sandbox-alias>` as a placeholder; do not type the angle brackets.

Run commands from `packages/rhc-actions`.

```bash
sf apex run --file scripts/demo/apex/00_preflight.apex --target-org <sandbox-alias>
sf apex run --file scripts/demo/apex/01_seed_demo.apex --target-org <sandbox-alias>
```

`00_preflight.apex` is read-only. `01_seed_demo.apex` creates or resets the exact demo Account and
manual policy. It does not erase earlier queue/history/Task evidence, and deterministic scenario
IDs cannot execute again until the exact cleanup is completed. Neither script creates the Flow
because Flow behavior needs deliberate admin review.

## Scenario inventory

| Script                                     | Demonstrates                             | Expected result                                  |
| ------------------------------------------ | ---------------------------------------- | ------------------------------------------------ |
| `02_publish_manual_fail.apex`              | manual review and successful Flow        | one action, one interview, one history, one Task |
| `03_publish_rejection_fail.apex`           | human rejection                          | REJECTED; no interview, history, or Task         |
| `04_publish_duplicate_fail.apex`           | event-ID idempotency                     | one Pending Action for two deliveries            |
| `05_publish_nonmatching_pass.apex`         | policy matching                          | no Pending Action                                |
| `06_publish_cooldown_fail.apex`            | per-record loop/cooldown guard           | after approval, SUPPRESSED and no new Task       |
| `07_publish_unsupported_contract.apex`     | core contract version gate               | no Pending Action                                |
| `08_publish_contract_validation_fail.apex` | active Flow and input validation         | approval is blocked or execution fails closed    |
| `09_publish_retry_fail.apex`               | bounded retry                            | RETRY_WAIT, then FAILED after attempt 2          |
| `10_publish_automatic_fail.apex`           | optional permission-gated automatic mode | automatic success only when all three gates pass |
| `11_publish_bulk_251.apex`                 | bulk capture                             | 251 independently idempotent manual proposals    |
| `12_verify_demo.apex`                      | read-only evidence summary               | logs owned policies, actions, history, and Tasks |
| `13_cleanup_preview.apex`                  | exact deletion preview                   | logs counts, changes nothing                     |
| `14_cleanup_execute.apex`                  | sandbox cleanup                          | removes only exact demo-owned records            |

Platform Event acceptance is not delivery. Wait for asynchronous subscriber and Queueable work
before declaring a scenario failed. Do not publish another event merely because the UI did not
refresh immediately.

## Typical command pattern

```bash
sf apex run --file scripts/demo/apex/02_publish_manual_fail.apex --target-org <sandbox-alias>
sf apex run --file scripts/demo/apex/12_verify_demo.apex --target-org <sandbox-alias>
```

For cleanup, run the preview first, compare every count to your evidence sheet, then use an
authorized release or System Administrator for the execute script:

```bash
sf apex run --file scripts/demo/apex/13_cleanup_preview.apex --target-org <sandbox-alias>
sf apex run --file scripts/demo/apex/14_cleanup_execute.apex --target-org <sandbox-alias>
```

## What is not faked

- Publication `NONE`: run the real approved core caller with `NONE`; the correct proof is no Result
  Platform Event and no Pending Action.
- A real core evaluation: synthetic events isolate the Actions subscriber. Complete one separate
  end-to-end run through the actual core caller before release.
- Identity permissions: scripts do not bypass sharing, CRUD, FLS, Flow access, or Custom
  Permissions.
- Flow safety: the package validates the interface, not every side effect. Review the active Flow
  and its dependencies.
- Atomicity: the core check, Platform Event delivery, approval, Queueable, and Flow are deliberately
  separate asynchronous transactions.
