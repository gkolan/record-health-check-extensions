# RHC Actions requirements traceability

| Requirement                              | Implementation                                      | Primary tests or evidence                                       |
| ---------------------------------------- | --------------------------------------------------- | --------------------------------------------------------------- |
| Independent 2GP extension                | `sfdx-project.json`, container `0Hoak0000005M6LCAU` | Metadata conversion, source deploy; `04t` pending Dev Hub quota |
| Depends only on core                     | Single dependency `Record Health Check@2.0.4-2`     | Package configuration review                                    |
| Direct finalized Result subscription     | `RHCActionResultSubscriber`                         | Direct Platform Event delivery test                             |
| No other extension reads                 | Capture uses only Policy plus core event            | Static scope audit and architecture review                      |
| Core read-only                           | No DML to core metadata/runtime records             | Static scope audit                                              |
| Policy, queue, history owned by Actions  | Three private custom objects                        | Metadata deployment and object tests                            |
| Same-org autolaunched Flow only          | `RHCActionPolicyService` and `RHCActionFlowGateway` | active, inactive, wrong-type tests                              |
| Manual default                           | `Mode__c` default and capture branch                | metadata review and manual execution tests                      |
| Explicit permission-gated automatic mode | checkbox plus Custom Permission check               | automatic capture tests/security review                         |
| Versioned Flow contract                  | `Input_Contract_Version__c = 1.0`                   | valid and unsupported contract tests                            |
| Allow-listed inputs only                 | constants, validation, `buildInputs`                | arbitrary input rejection and captured input assertion          |
| Manual review UI                         | `rhcActionReview` and controller                    | four Jest tests and controller tests                            |
| Event ID idempotency                     | unique `Idempotency_Key__c`                         | duplicate event test                                            |
| Per-record cooldown                      | recent successful History query by policy/record    | cooldown suppression test                                       |
| Retry limits                             | policy validation and Queueable delay               | retry exhaustion test                                           |
| Loop prevention                          | positive cooldown plus policy-record guard          | cooldown and duplicate tests                                    |
| Persona permission sets                  | Admin, Approver, Runtime, Viewer metadata           | source deploy and permission matrix review                      |
| Safe audit                               | Action History and bounded error summaries          | execution and review tests                                      |
| No human alerts or callouts              | no messaging or HTTP components                     | static scope audit and Flow governance docs                     |
| Publication NONE creates nothing         | absence of event is the boundary                    | core contract/gap analysis                                      |
| Async and non-atomic documented          | architecture and admin runbooks                     | documentation review                                            |
| Reproducible demo and cleanup            | `scripts/demo` plus junior-admin runbook            | scenario matrix, verification output, exact cleanup preview     |

This table maps the authoritative requirements to current source. It does not replace tests or the
threat model.
