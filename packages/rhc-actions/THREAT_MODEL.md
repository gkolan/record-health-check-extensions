# RHC Actions threat model

Core's finalized `Record_Health_Check_Result__e` is the only inbound data boundary. Actions does
not trust arbitrary Flow variables, raw payloads, diagnostic detail, another extension's records,
or client-provided approval state.

| Threat                                 | Control                                                                                       | Residual risk                                               |
| -------------------------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| Duplicate events execute twice         | Unique policy-plus-Event-ID key, partial insert, row lock, terminal state, unique attempt key | Salesforce can redeliver                                    |
| Correction causes a loop               | Mandatory policy-record cooldown, recent-success check, retry cap                             | A later event after cooldown can propose another correction |
| Inactive, screen, or incompatible Flow | Active autolaunched and v1 variable validation at review and execution                        | Internal Flow behavior cannot be proven                     |
| Arbitrary content enters Flow          | Eight scalar Text inputs; unknown inputs fail closed                                          | Approved identifiers can remain sensitive                   |
| Review is bypassed                     | Server Custom Permission, row lock, state transition, approver audit                          | Permission admins remain trusted                            |
| Automatic correction is accidental     | Manual default, automatic mode, explicit policy checkbox, dedicated Custom Permission         | Privileged admins can authorize risk                        |
| Errors leak diagnostics                | Fixed codes and bounded authored summaries; no stacks, payloads, exception text, or outputs   | Flow logs follow org retention                              |
| Runtime elevates access                | `with sharing`, user-mode data access, execution identity permissions                         | Customer Flow context can broaden effects                   |

Actions does not send alerts, call external systems, inspect other extensions, or mutate core. It
cannot make the original check and correction atomic or roll back committed downstream work.
