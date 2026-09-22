# RHC Actions administrator documentation

These guides are written for a Salesforce administrator who can use Setup and Flow Builder but does
not write Apex. Follow them in order for a first implementation.

Last source verification: **September 20, 2026**, Salesforce Lightning Experience, RHC Actions
`0.1.0.NEXT` source.

## First-time setup path

| Order | Task                                                  | Time to reserve                              | Finish only when                                                                 |
| ----- | ----------------------------------------------------- | -------------------------------------------- | -------------------------------------------------------------------------------- |
| 1     | [Install and verify](INSTALL_AND_VERIFY.md)           | 20–40 minutes plus package installation time | Core and Actions appear as installed and the RHC Actions app opens               |
| 2     | [Assign permissions](ASSIGN_PERMISSIONS.md)           | 20 minutes                                   | Admin, Maya, runtime, and viewer access tests match their roles                  |
| 3     | [Build the corrective Flow](BUILD_CORRECTIVE_FLOW.md) | 45–90 minutes                                | Active Flow passes sandbox Debug and creates exactly one test Task               |
| 4     | [Create a manual policy](CREATE_MANUAL_POLICY.md)     | 20 minutes                                   | Active policy exactly matches the example Check and Flow                         |
| 5     | [Test manual approval](TEST_MANUAL_APPROVAL.md)       | 30–60 minutes                                | One matching event creates one action, one Flow interview, and one audit attempt |
| 6     | [Set up monitoring and retention](MONITOR_AND_TROUBLESHOOT.md) | 30 minutes                            | Owners can interpret states and govern manual audit cleanup                       |

After the first-time setup, use
[Create demo data and test every control](DEMO_DATA_AND_FULL_TEST.md) for the sandbox-only,
click-by-click demonstration, including seed scripts, Maya's review, failure cases, bulk capture,
evidence, and exact cleanup.

Complete [automatic execution](ENABLE_AUTOMATIC_EXECUTION.md) only after the manual acceptance test
passes and the business, security, Flow, and release owners approve automatic correction.

Use [disable and uninstall](DISABLE_AND_UNINSTALL.md) for planned pauses, incidents, and removal.

Use [official Salesforce UI references](OFFICIAL_SALESFORCE_REFERENCES.md) to recheck Setup,
Permission Set, Flow Builder, interview GUID, and Platform Event subscriber navigation after a
Salesforce release.

## Example used throughout

| Item                | Value                                          |
| ------------------- | ---------------------------------------------- |
| Check               | `Account_Has_Primary_Contact`                  |
| Matching status     | `FAIL`                                         |
| Flow label          | Create Data Steward Task                       |
| Flow API name       | `Create_Data_Steward_Task`                     |
| Policy mode         | Manual Approval (`MANUAL_APPROVAL`)            |
| Approver            | Maya                                           |
| Corrective behavior | Create one Task related to the failing Account |

The example never creates a Contact or edits the failing Account. A person reviews the Account
before the Flow creates a stewardship Task.

## How to read the runbooks

Each guide uses these callouts:

- **Enter:** the exact value to type.
- **Select:** the exact choice or checkbox.
- **What you should see:** the expected result before moving on.
- **Stop if:** a condition that means continuing would be unsafe or misleading.
- **Why:** the control being established.

Labels can vary slightly by Salesforce release, locale, edition, and Setup experience. Package
labels and API names in these guides match the source. Never translate, abbreviate, or guess an API
name.

## Boundaries every administrator must understand

- Publication `NONE` produces no event and therefore no action.
- Platform Event delivery and Flow execution are asynchronous.
- The original health check and later correction are separate transactions.
- The execution identity's sharing, CRUD, field access, Flow access, and Apex access apply.
- The package can validate a Flow interface but cannot prove all Flow side effects.
- A correction can cause another evaluation; cooldown and duplicate controls must stay enabled.
- RHC Actions itself sends no human alert and makes no external callout.
- Audit cleanup is Admin-only, manually confirmed, terminal-only, and capped at 1,000 rows; it is
  never scheduled and does not grant direct Delete access.
