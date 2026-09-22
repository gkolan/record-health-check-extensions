# RHC Reports documentation

This directory contains the administrator, operator, security, reporting, and developer references
for RHC Reports 0.1.0. Record Health Check core 2.0.4.2 and event contract 1.0 are the minimum
compatible promoted contract.

## Choose a document

| I need to... | Start here |
| --- | --- |
| Install or upgrade the extension | [Installation and upgrade](INSTALLATION.md) |
| Configure it for the first time with exact clicks | [Click-by-click setup](CLICK_BY_CLICK_SETUP.md) |
| Load safe demo data and test every subscriber-facing capability | [Demo data and complete functional test](DEMO_TEST_DATA.md) |
| Understand publication choices and normal administration | [Administrator guide](ADMIN_GUIDE.md) |
| Understand the event flow, Apex responsibilities, and objects | [Architecture and data model](ARCHITECTURE_AND_DATA_MODEL.md) |
| Understand deduplication, ordering, and contract handling | [Event ingestion contract](EVENT_INGESTION.md) |
| Understand every report, dashboard widget, and metric | [Reporting reference](REPORTING_REFERENCE.md) |
| Operate retention, aggregation, monitoring, and recovery | [Operations and security](OPERATIONS_AND_SECURITY.md) |
| Diagnose an empty dashboard or missing events | [Troubleshooting](TROUBLESHOOTING.md) |
| Change code, run tests, or build the package | [Contributor guide](CONTRIBUTING.md) |
| Review static-analysis exceptions | [Code Analyzer suppressions](CODE-ANALYZER-SUPPRESSIONS.md) |
| Review why core 2.0.4.2 is sufficient | [Core event gap analysis](GAP_ANALYSIS.md) |
| Review validation evidence and release gates | [Package validation](PACKAGE_VALIDATION.md) |

## Audience map

| Audience | Read in this order |
| --- | --- |
| Junior Salesforce administrator | Click-by-click setup → Demo data and complete functional test → Administrator guide → Troubleshooting |
| Salesforce platform owner | Installation → Operations and security → Reporting reference |
| Security or compliance reviewer | Architecture and data model → Event ingestion → Operations and security |
| Salesforce developer | Architecture and data model → Event ingestion → Contributor guide |
| Release engineer | Installation → Package validation → Contributor guide |

## Documentation rules

When package behavior changes, update documentation in the same change:

- object or field changes require the data dictionary and report-type tables to change;
- event mapping or supported contract changes require Event ingestion and the gap analysis to change;
- Setup labels, buttons, defaults, or validation changes require both administrator guides to change;
- scheduled or retention behavior changes require Operations and security to change;
- packaged report or dashboard changes require Reporting reference to change;
- package IDs, test counts, or release results require Package validation to change.
- demo identities, expected counts, script behavior, or acceptance steps require Demo data and the
  relevant files under `scripts/demo` to change together.

Do not document unpublished behavior as available. Do not imply that historical events can be
reconstructed, that Platform Event delivery is synchronous, or that RHC Reports evaluates records.
