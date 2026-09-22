# RHC Reports Code Analyzer suppressions

Every suppression is limited to `RHCReportsCoverageController` and preserves a public or analytical
contract that should not be changed to satisfy a heuristic.

| Source | Rule | Reason |
| --- | --- | --- |
| `CoverageRow` | `AvoidBooleanMethodParameters` | The findings represent generated Aura property setters for `configurationAvailable` and `userRunPublicationEnabled`, not authored methods with ambiguous Boolean arguments. Changing either property type would break the LWC response contract. |
| `applyObservedRunCounts` and `applyObservedResultCounts` | `AvoidNonRestrictiveQueries` | Coverage requires complete grouped fact-table aggregates across retained Run and Result rows. Each query returns bounded aggregate groups rather than materializing every fact row; adding a filter or row limit would silently make the coverage state incorrect. |

The package source validator locks these three annotations and both rationales. Adding or widening a
suppression requires updating this record and rerunning the full Recommended scan.
