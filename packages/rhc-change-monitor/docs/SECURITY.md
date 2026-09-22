# RHC Change Monitor security implementation

The intake API accepts only Salesforce ChangeEvent sObjects. It verifies the concrete event type,
header entity, stable transaction and sequence fields, and record-ID syntax before policy lookup.
Payload values are never read into the envelope or ledger.

All data-access Apex classes declare `with sharing` or `inherited sharing`; the dispatch support
helper inherits the explicit sharing context of its `with sharing` Queueable caller. The pure data
envelope and other side-effect-free helpers do not query or mutate records. No path uses `without
sharing`, synthetic `runAs`, privileged core internals, dynamic SOQL, or a permission bypass. Core
continues to reload durable records and enforce its own Run permission and user-mode access.

The Queueable checks the core `Record_Health_Check_Run` custom permission under its actual effective
principal before invoking core. Failure is terminal `RUNTIME_PERMISSION_MISSING`. This check does
not prove who the CDC/Queueable principal is; the namespaced subscriber-style Gate 3 experiment must
capture and approve that identity and its positive and negative CRUD/FLS behavior.

Exception text and event payloads are not persisted. Operational records contain bounded reason
codes and counts only. Package permission sets provide no access to the checked business objects.
The administrator-only pending recovery action uses user-mode count access and publishes only the
number of visible pending claims. It does not carry record IDs or payload values, mutate claims, or
start a second dispatcher while the console reports one active.

`RHC_Change_Monitor_Runtime` is the package's least-privilege asynchronous role. It grants read-only
access to every policy field, create/read/edit access to evaluation evidence, and access to the seven
runtime Apex classes. It grants neither policy mutation nor evaluation deletion, and it does not
grant access to any monitored business object. The effective runtime user must also receive an
appropriate core runner permission set; Change Monitor does not duplicate or bypass core's Run
custom permission.

Only `RHC_Change_Monitor_Admin` receives create/read/edit access to the package-owned retention
setting and delete access to Change Evaluations. It cannot delete the setting. Runtime and Viewer
roles receive no setting access, and Runtime cannot delete evidence. Manual purge reads the saved
singleton in user mode, excludes `PENDING`, selects at most 1,000 oldest eligible rows, and performs
user-mode deletion. The LWC requires a saved policy and an explicit permanent-deletion
acknowledgment; no scheduler or permission-elevating cleanup path is packaged.
