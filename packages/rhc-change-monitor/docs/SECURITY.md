# RHC Change Monitor security implementation

The intake API accepts only Salesforce ChangeEvent sObjects. It verifies the concrete event type,
header entity, stable transaction and sequence fields, and record-ID syntax before policy lookup.
Payload values are never read into the envelope or ledger.

All Apex classes declare `with sharing` except the pure data envelope. No path uses `without
sharing`, synthetic `runAs`, privileged core internals, dynamic SOQL, or a permission bypass. Core
continues to reload durable records and enforce its own Run permission and user-mode access.

The Queueable checks the core `Record_Health_Check_Run` custom permission under its actual effective
principal before invoking core. Failure is terminal `RUNTIME_PERMISSION_MISSING`. This check does
not prove who the CDC/Queueable principal is; the namespaced subscriber-style Gate 3 experiment must
capture and approve that identity and its positive and negative CRUD/FLS behavior.

Exception text and event payloads are not persisted. Operational records contain bounded reason
codes and counts only. Package permission sets provide no access to the checked business objects.

`RHC_Change_Monitor_Runtime` is the package's least-privilege asynchronous role. It grants read-only
access to every policy field, create/read/edit access to evaluation evidence, and access to the seven
runtime Apex classes. It grants neither policy mutation nor evaluation deletion, and it does not
grant access to any monitored business object. The effective runtime user must also receive an
appropriate core runner permission set; Change Monitor does not duplicate or bypass core's Run
custom permission.
