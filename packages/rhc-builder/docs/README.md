# RHC Builder documentation

Use the document that matches what you are trying to do.

## Salesforce administrators

| I need to…                                                 | Start here                                                    |
| ---------------------------------------------------------- | ------------------------------------------------------------- |
| Install Builder and assign access                          | [Installation and access](INSTALLATION.md)                    |
| Build my first Check Set one click at a time               | [Click-by-click administrator guide](CLICK_BY_CLICK_GUIDE.md) |
| Choose card behavior and understand each design decision   | [Screen guidance and card-style decision guide](SCREEN_GUIDANCE_AND_CARD_STYLE.md) |
| Load sample records and run a complete demo                | [Sandbox demo kit](../demo/README.md)                         |
| Execute and record every acceptance scenario               | [End-to-end demo test plan](../demo/DEMO_TEST_PLAN.md)        |
| Understand versions, publication, activation, and rollback | [Administrator concepts and governance](ADMIN_GUIDE.md)       |
| Diagnose a failed save or publication                      | [Operations and troubleshooting](OPERATIONS.md)               |

## Developers and release maintainers

| I need to…                                                             | Start here                                      |
| ---------------------------------------------------------------------- | ----------------------------------------------- |
| Understand the extension architecture and source tree                  | [Developer guide](DEVELOPER_GUIDE.md)           |
| Understand the Builder-owned contract                                  | [Builder contract](BUILDER_CONTRACT.md)         |
| Audit every core metadata field                                        | [Core metadata field mapping](FIELD_MAPPING.md) |
| See why the prototype and core authoring code were not copied directly | [Gap analysis](GAP_ANALYSIS.md)                 |
| Build, validate, and package a release                                 | [Release guide](RELEASE_GUIDE.md)               |
| Review recorded quality evidence                                       | [Verification record](VERIFICATION.md)          |
| Read the authoritative product contract                                | [Specification](../SPEC.md)                     |

## Terminology

- **Record Health Check core** is the independently installable runtime package. It owns runtime
  Custom Metadata and evaluates records.
- **RHC Builder** is this optional extension. It owns guided authoring, complete Check Set Versions,
  validation, publication history, activation, and rollback.
- A **Check Set** is one runtime configuration grouping.
- A **Check** is one ordered condition within a Check Set.
- A **Check Set Version** is an immutable snapshot of the complete Check Set and every child Check.
- There is no **Check Version**. A Check is never saved or published independently.
- A **Qualified API Name** is the exact namespace-aware metadata identity. Builder preserves it and
  never adds, removes, or guesses a namespace.

## Release applicability

Validated beta `0.2.0.1` is subscriber package version `04tak000000ckt3AAA`. The current source has
one later usability improvement: **Refresh status** appears directly on **3. Publish and monitor**.
The click-by-click guide calls out where that button appears in both the beta and current source.

## Demo dataset

The repository includes a Salesforce sObject Tree JSON file with four synthetic Accounts and two
Contacts. Reserved `.example` domains prevent the data from representing real people or businesses.
Load it only into a sandbox, scratch org, or disposable developer org and follow the documented
cleanup procedure.
