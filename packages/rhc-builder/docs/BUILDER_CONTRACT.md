# Builder contract

`RecordHealthCheckBuilderContract` belongs to the RHC Builder package. Core does not provide or call
this class.

The contract supports three Builder actions:

| Action                | Purpose                                                                                           |
| --------------------- | ------------------------------------------------------------------------------------------------- |
| `describeContract`    | Supplies the choices, defaults, field lists, and Check limit shown by this Builder release        |
| `validateVersion`     | Validates one complete Check Set Version and returns errors connected to Builder screen locations |
| `buildDeploymentPlan` | Produces an allow-listed Metadata API plan for the Check Set and every Check in that version      |

The Builder controller calls the contract directly. Tests may replace it with a predictable test
implementation. There is no dynamic lookup of a Builder-named class in core.

Core remains the installed runtime package and owns runtime evaluation. Builder owns its authoring
rules and must be tested against every supported core package version before release. When a core
metadata field or runtime choice changes, Builder must update its field mapping, contract version,
tests, and pinned package dependency together.

## Versioned contract response

The current contract reports schema version `1`, contract version `1.0`, and a maximum of 25 Checks
per complete Check Set Version. It returns these supported authoring values:

| Core field                                 | Values supported by this Builder release                            |
| ------------------------------------------ | ------------------------------------------------------------------- |
| `EvaluationType__c`                        | `FORMULA`, `QUERY`, `COMPARE_TWO_QUERIES`, `APEX`                   |
| `FailureSeverity__c`                       | `CRITICAL`, `WARNING`, `INFO`                                       |
| `CardRunMode__c`                           | `RUN_ON_LOAD`, `RUN_ON_REQUEST`                                     |
| `ExpectedValueSource__c`                   | `FIXED_VALUE`, `RECORD_FORMULA`, `COMPARISON_QUERY`                 |
| `QueryResultHandling__c`                   | `ONE_RESULT`, `ANY_ROW_PASSES`, `ALL_ROWS_PASS`, `COMPARE_AS_LISTS` |
| `NoRowsResult__c`                          | `PASS`, `FAIL`, `SKIP`, `UNABLE_TO_EVALUATE`                        |
| `EmptyValueHandling__c`                    | `AS_NO_MATCH`, `SKIP_RECORD`, `AS_BLANK`                             |
| `ApplicabilityMode__c`                     | `ALL_RECORDS`, `WHEN_FORMULA_TRUE`, `WHEN_COUNT_QUERY_MATCHES`      |

Supported comparison operators are `EQUALS`, `NOT_EQUALS`, `GREATER_THAN`,
`GREATER_THAN_OR_EQUAL`, `LESS_THAN`, `LESS_THAN_OR_EQUAL`, `CONTAINS`,
`DOES_NOT_CONTAIN`, `IS_BLANK`, `IS_NOT_BLANK`, `LIST_CONTAINS_ANY`,
`LIST_CONTAINS_NONE`, `LISTS_OVERLAP`, `LISTS_CONTAIN_ALL`, and `LISTS_MATCH_EXACTLY`.

Safe defaults keep new configuration inactive. The default Check Set run mode is `RUN_ON_REQUEST`;
the default Check severity is `WARNING`; applicability is `ALL_RECORDS`; and ordinary query defaults
use one result, at most 200 rows, `UNABLE_TO_EVALUATE` for no-row outcomes, and `SKIP_RECORD` for
empty field values. The
guided related-record path intentionally tightens its generated existence query to one row and a
failure outcome when no related record exists.

## Canonical envelope

The contract accepts one complete JSON envelope. This is an internal saved/published representation,
not a second runtime schema:

```json
{
  "schemaVersion": 1,
  "contractVersion": "1.0",
  "checkSet": {
    "qualifiedApiName": "Account_Data_Quality",
    "label": "Account Data Quality",
    "values": {
      "ObjectApiName__c": "Account",
      "CardRunMode__c": "RUN_ON_REQUEST",
      "IsActive__c": false
    }
  },
  "checks": [
    {
      "qualifiedApiName": "Account_name_is_present",
      "label": "Account name is present",
      "values": {
        "Record_Health_Check_Set__c": "Account_Data_Quality",
        "EvaluationType__c": "FORMULA",
        "EvaluationOrder__c": 10,
        "PassConditionFormula__c": "NOT(ISBLANK(Name))",
        "FailureSeverity__c": "WARNING",
        "FailureMessage__c": "Enter an Account Name.",
        "IsActive__c": false
      }
    }
  ]
}
```

Every key inside `values` is an exact core field API name from `RHCBuilderFieldMapping`.
Canonicalization rejects an unsupported envelope property or field rather than silently storing it.

## Validation guarantees

Validation checks the complete envelope, including:

- readable JSON and supported schema/contract versions;
- one Check Set component and a Checks array;
- required labels, target object, exact Qualified API Names, and required type-specific values;
- Qualified API Name format and maximum length without namespace rewriting;
- at least one and no more than 25 Checks;
- unique Check Qualified API Names and evaluation orders;
- each Check's exact reference to the parent Check Set Qualified API Name;
- supported evaluation types, severities, operators, result handling, and applicability modes;
- exact check-level parity with the installed core validator, including query shape, required query
  fields and expected values, Apex plugin/parameter validity, applicability sub-fields, row caps,
  and empty-value/no-row behavior;
- installed core Custom Metadata types and the mapped fields required for publication; and
- inactive saved defaults before a deliberate activation operation.

Validation does not prove business correctness, Formula/SOQL selectivity, Apex plugin quality, or
runtime outcomes against representative records.

## Publication plan

`buildDeploymentPlan` returns only core `Record_Health_Check_Set__mdt` and
`Record_Health_Check__mdt` components. It resolves the installed namespace through Salesforce
describe information and maps the exact allow-listed values into Metadata API field entries.

- Inactive publication forces the Check Set and all Checks inactive.
- Activation publishes the complete selected snapshot with the deliberate active state.
- Rollback uses the same activation plan for an older validated snapshot.
- No individual Check plan exists.

The controller revalidates a saved version before asking the asynchronous metadata service to deploy
it. A changed Builder contract can therefore prevent publication of a formerly valid snapshot rather
than publishing configuration that no longer meets the installed rules.
