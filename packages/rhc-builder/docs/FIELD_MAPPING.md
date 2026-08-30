# Core metadata field mapping

The canonical version JSON contains a checkSet component and a checks array. Each component has only
qualifiedApiName, label, and values. values keys are exact core custom-field API names. Builder
preserves all Qualified API Names and values verbatim. It never inserts or removes namespace prefixes
and never rewrites formula, SOQL, class, relationship, or prerequisite text.

RHCBuilderFieldMapping is the executable allow-list. It accounts for all 18 Check Set fields and all
44 Check fields in the pinned core source.

## Check Set

`CardRevealMode__c`, `CardRunMode__c`, `CardSubtitle__c`, `CardTitle__c`,
`FoundExpectedDisplay__c`, `IsActive__c`, `ObjectApiName__c`, `PassedChecksDisplay__c`,
`PublishErrorLogEvent__c`, `PublishUserRunEvent__c`, `RerunButtonLabel__c`,
`RunButtonDisplay__c`, `RunButtonIcon__c`, `RunButtonLabel__c`, `ShowDiagnostics__c`,
`SkippedChecksDisplay__c`, `StopOnSystemError__c`, and `SummaryDisplay__c`.

## Check

`ActionLabel__c`, `ActionUrl__c`, `ApexClass__c`, `ApexParametersJson__c`,
`ApplicabilityCountOperator__c`, `ApplicabilityCountQuery__c`,
`ApplicabilityCountThreshold__c`, `ApplicabilityFormula__c`, `ApplicabilityMode__c`,
`ApplicabilityNotMetMessage__c`, `Category__c`, `CheckDescription__c`, `CheckTitle__c`,
`ComparisonOperator__c`, `ComparisonQueryField__c`, `ComparisonQuery__c`,
`DisplayExpectedFormula__c`, `DisplayExpectedText__c`, `DisplayFoundFormula__c`,
`DisplayFoundText__c`, `DisplayValueFormat__c`, `EmptyValueHandling__c`,
`EvaluationOrder__c`, `EvaluationType__c`, `ExpectedCurrencyIsoCode__c`,
`ExpectedFixedValue__c`, `ExpectedRecordFormula__c`, `ExpectedValueSource__c`,
`FailureMessage__c`, `FailureSeverity__c`, `FindInListFormula__c`, `FixMessage__c`,
`FormulaResultType__c`, `IsActive__c`, `MaxQueryRows__c`, `NoRowsResult__c`,
`PassConditionFormula__c`, `PrerequisiteCheck__c`, `PublishUserResultEvent__c`,
`QueryResultHandling__c`, `Record_Health_Check_Set__c`, `SourceQueryField__c`,
`SourceQuery__c`, and `UnableToEvaluateMessage__c`.

## Authoring-only data

The four Builder objects add only stable identity, version number, deterministic fingerprint,
contract version, immutable canonical JSON, timestamps, operation kind/token/status, deployment
request Id, and safe validation/publication summaries. These values never enter the core runtime
definition schema.

Denormalized `RunMode__c`, `EvaluationType__c`, `Severity__c`, and `EvaluationOrder__c` fields support
Builder list views and reports. Their allowed values come from the versioned Builder contract and are
tested against the pinned core package before release.

## How the UI maps to core

| Builder UI answer              | Core field or behavior                                                                         |
| ------------------------------ | ---------------------------------------------------------------------------------------------- |
| Check Set name                 | `CardTitle__c` plus the Builder version label                                                  |
| Check Set Qualified API Name   | Exact metadata identity and each Check's `Record_Health_Check_Set__c` reference                |
| Target Salesforce object       | `ObjectApiName__c`                                                                             |
| When the Check Set runs        | `CardRunMode__c`                                                                               |
| Short explanation              | `CardSubtitle__c`                                                                              |
| What should be true?           | `CheckTitle__c` plus the Builder Check snapshot label                                          |
| Check Qualified API Name       | Exact Check metadata identity                                                                  |
| Evaluation type                | `EvaluationType__c`                                                                            |
| On-screen Check order          | `EvaluationOrder__c`, generated as 10, 20, 30, and so on                                       |
| Failure severity               | `FailureSeverity__c`                                                                           |
| Failure message                | `FailureMessage__c`                                                                            |
| How to fix it                  | `FixMessage__c`                                                                                |
| Guided Formula field plus rule | Generated `PassConditionFormula__c`                                                            |
| Guided related records         | Generated source query, field, result handling, operator, empty/no-row behavior, and row limit |
| Apex plugin class              | `ApexClass__c`                                                                                 |
| Apex parameters                | `ApexParametersJson__c`                                                                        |

## Type-specific inclusion

The browser may remember answers entered while comparing evaluation types, but the canonical saved
Check includes only common Check fields and fields belonging to the selected type:

- Formula: pass/display Formula and display-value fields.
- Query: source/comparison/expected-value, result handling, empty/no-row, row limit, list Formula,
  currency, and display-value fields.
- Compare Two Queries: both queries and result fields, result handling, operator, empty/no-row, row
  limit, and display-value fields.
- Apex: only `ApexClass__c` and `ApexParametersJson__c` in addition to common fields.

This prevents stale answers from an unselected type from leaking into runtime metadata.

## Mapping verification rule

For every supported core release, compare the executable lists in `RHCBuilderFieldMapping` with the
actual fields on both core Custom Metadata types. The release fails if a core field is missing from
the documented inventory, if Builder permits a field not present in core, or if the counts differ
from the pinned compatibility baseline. The current baseline is 18/18 Check Set fields and 44/44
Check fields with no extras or gaps.

