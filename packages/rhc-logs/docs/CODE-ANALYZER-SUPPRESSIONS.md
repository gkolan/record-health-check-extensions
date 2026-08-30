# RHC Logs Code Analyzer suppressions

Every suppression below is narrow and reviewable. The release scan keeps all Recommended rules
enabled and currently reports zero findings.

| Source | Rule | Reason |
| --- | --- | --- |
| `RHCLogsIngestionService.cls` | `ApexCRUDViolation` | The service is reachable only from the package Platform Event trigger. It writes package-owned Logs and best-effort operational state in automation system context; subscriber CRUD/FLS must not prevent event retention. |
| `RHCLogsCleanupService.cls` (`loadSettingsWithLock`) | `ApexCRUDViolation` | Entry checks require Settings read/update and Log read/delete. `FOR UPDATE` cannot be combined with user-mode SOQL and supplies the concurrency lock. |
| `RHCLogsCleanupService.cls` (`acquireLease`) | `ApexCRUDViolation` | Entry checks enforce object CRUD; lease fields are package-owned and deliberately unavailable for subscriber editing. |
| `RHCLogsCleanupScheduler.cls` (`findJobs`) | `ApexCRUDViolation` | The method explicitly checks `CronTrigger.isAccessible()` before querying the package job name. |
| `RHCLogsAdminController.cls` | `CyclomaticComplexity` | The cohesive setup endpoint has aggregate complexity 52 against the rule threshold 50; its highest method complexity is 10 and work is split into focused helpers. |
| `RHCLogsAdminController.cls` (`populateLogSummary`) | `AvoidNonRestrictiveQueries` | The setup dashboard intentionally computes count/min/max across the retained-log table. Salesforce rejects `LIMIT` on a non-grouped overall aggregate, and the aggregate returns exactly one row without materializing records. |
| Four `*Test.cls` classes | `ApexUnitTestClassShouldHaveRunAs` | Persona-sensitive tests use explicit Viewer/Admin/unprivileged `System.runAs`. Wrapping every system-context unit test in `runAs` for the same current user adds no security evidence. |

Changing or adding a suppression requires updating this page and rerunning the full Recommended scan.

The 2026-08-30 unsuppressed-copy audit produced exactly 30 expected findings: three High
`ApexCRUDViolation` entry findings, two Moderate complexity findings, and 25 Low test-method
`runAs` advisories. The ordinary release scan, with these reviewed suppressions active, produced
zero findings.
