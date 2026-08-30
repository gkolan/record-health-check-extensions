# RHC Change Monitor data model

## Change Policy

`Record_Health_Check_Change_Policy__c` is administrator configuration for one exact source-to-core
route. It stores the durable source API name, explicit selection type and Qualified API Name, closed
change types, optional newline-delimited UPDATE fields, publication mode, and activation boundary.

Policies default inactive. Source-object access is not granted by Change Monitor permission sets.

## Change Evaluation

`Record_Health_Check_Change_Evaluation__c` is an orchestration ledger, not health-result history.
Its unique `ClaimKey__c` makes one stable event-policy-record identity insertable only once.
`Outcome__c` uses `PENDING`, `EVALUATED`, `IGNORED`, `FAILED`, or `DUPLICATE`; the current intake
contract suppresses a duplicate insert and preserves the original row rather than overwriting a
completed claim with `DUPLICATE`.

Stored facts are limited to source and stream correlation, bounded status/reason codes, attempt and
result counts, and timestamps. The object never stores changed or old values, raw event JSON, core
Found/Expected values, display messages, stack traces, session data, or notification content.

Both objects use Private sharing. The Admin permission set grants complete package-object access;
the Viewer set grants read-only access. The Runtime set reads policies and creates, reads, and
updates evaluation evidence, but cannot mutate policies or delete evidence. None grants
business-object access or the core Run custom permission.
