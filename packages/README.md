# RHC extension projects

Each implemented directory is an independent Salesforce DX project intended for its own 2GP
package. Package registration and installable-version status vary by project. RHC Change Monitor is
an implementation preview whose package registration remains blocked by CDC feasibility gates. Every
implemented project:

- declares only `Record Health Check@2.0.4-2` as a package dependency;
- uses the core `rhc` namespace and Metadata API version `66.0`;
- owns its configuration, runtime records, permissions, tests, and uninstall boundary;
- never reads another extension's objects or calls another extension's Apex API; and
- uses canonical core Platform Events when it must observe outcomes produced elsewhere.

| Project            | Package overview                                      |
| ------------------ | ----------------------------------------------------- |
| `rhc-logs`         | [RHC Logs](rhc-logs/README.md)                        |
| `rhc-run-manager`  | [RHC Run Manager](rhc-run-manager/README.md)          |
| `rhc-builder`      | [RHC Builder](rhc-builder/README.md)                  |
| `rhc-alerts`       | [RHC Alerts](rhc-alerts/README.md)                    |
| `rhc-change-monitor` | [RHC Change Monitor (development preview)](rhc-change-monitor/README.md) |
| `rhc-reports`      | [RHC Reports](rhc-reports/README.md)                  |
| `rhc-actions`      | [RHC Actions](rhc-actions/README.md)                  |
| `rhc-integrations` | [RHC Integrations](rhc-integrations/README.md)        |
| `rhc-agent-actions` | [RHC Agent Actions](rhc-agent-actions/README.md)     |

## Package container status

The package projects currently declare these Dev Hub package-container aliases:

| Project                     | Container ID         |
| --------------------------- | -------------------- |
| RHC Logs                    | Not registered       |
| RHC Run Manager             | `0Hoak0000005FhZCAU` |
| Record Health Check Builder | `0Hoak0000005Fb7CAE` |
| RHC Alerts                  | `0Hoak0000005LtRCAU` |
| RHC Change Monitor          | Not registered; feasibility build |
| RHC Reports                 | `0Hoak0000005M7xCAE` |
| RHC Actions                 | `0Hoak0000005M6LCAU` |
| RHC Integrations            | `0Hoak0000005Lv3CAE` |
| RHC Agent Actions           | Not registered       |

A registered `0Ho` container is not an installable package version. Consult each project's release
documentation for its current `04t` status and validation evidence. The core dependency pin is the
currently verified baseline and must be raised only when a specification requires a newer promoted
core contract.

RHC Logs source and release gates are documented in its package README.
