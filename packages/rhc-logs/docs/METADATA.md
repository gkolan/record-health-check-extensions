# RHC Logs metadata inventory

The current source contains **56 deployable metadata members**, at API 66.0. This is a source
inventory; no installable RHC Logs package version has been recorded.

| Metadata type | Count |
| --- | ---: |
| ApexClass | 10 |
| ApexTrigger | 1 |
| CustomApplication | 1 |
| CustomField | 32 |
| CustomObject | 2 |
| CustomTab | 3 |
| LightningComponentBundle | 2 |
| ListView | 3 |
| PermissionSet | 2 |

## ApexClass

- `RHCLogsAdminController`
- `RHCLogsCleanupScheduler`
- `RHCLogsCleanupSchedulerTest`
- `RHCLogsCleanupService`
- `RHCLogsCleanupServiceTest`
- `RHCLogsControllersTest`
- `RHCLogsIngestionService`
- `RHCLogsIngestionServiceTest`
- `RHCLogsReviewController`
- `RHCLogsTestDataFactory`

## ApexTrigger

- `RHCLogsLogSubscriber`

## CustomApplication

- `RHC_Logs`

## CustomObject

- `Record_Health_Check_Diagnostic_Log__c`
- `Record_Health_Check_Log_Settings__c`

## CustomTab

- `RHC_Logs_Review`
- `RHC_Logs_Setup`
- `Record_Health_Check_Diagnostic_Log__c`

## LightningComponentBundle

- `rhcLogsReview`
- `rhcLogsSetup`

## ListView

- `Record_Health_Check_Diagnostic_Log__c.Critical_Logs`
- `Record_Health_Check_Diagnostic_Log__c.Recent_Logs`
- `Record_Health_Check_Diagnostic_Log__c.Requires_Investigation`

## PermissionSet

- `RHC_Logs_Admin`
- `RHC_Logs_Viewer`

## CustomField

Diagnostic Log has **15** custom fields; Settings has **17**. Standard fields such as Id, Name,
OwnerId, and audit fields are supplied by Salesforce and are not additional CustomField members.

### Record_Health_Check_Diagnostic_Log__c

| Field | Type | Required |
| --- | --- | --- |
| `CheckDeveloperName__c` | Text (120) | No |
| `CheckSetDeveloperName__c` | Text (120) | No |
| `Code__c` | Text (120) | No |
| `ContractVersion__c` | Text (10) | Yes |
| `EventId__c` | Text (80) | Yes |
| `ExceptionType__c` | Text (120) | No |
| `FrameworkVersion__c` | Text (20) | No |
| `IngestedAt__c` | DateTime | Yes |
| `Message__c` | LongTextArea (8000) | No |
| `OccurredAt__c` | DateTime | Yes |
| `RecordId__c` | Text (18) | No |
| `RunId__c` | Text (120) | Yes |
| `RunningUserId__c` | Text (18) | No |
| `Severity__c` | Text (10) | Yes |
| `StructuredDetails__c` | LongTextArea (8000) | No |

### Record_Health_Check_Log_Settings__c

| Field | Type | Required |
| --- | --- | --- |
| `AutomatedCleanupEnabled__c` | Checkbox | No |
| `CleanupBatchSize__c` | Number | No |
| `CleanupInProgress__c` | Checkbox | No |
| `CleanupLockAcquiredAt__c` | DateTime | No |
| `CleanupRunToken__c` | Text (80) | No |
| `LastCleanupAt__c` | DateTime | No |
| `LastCleanupDeletedCount__c` | Number | No |
| `LastCleanupFailureCount__c` | Number | No |
| `LastCleanupStatus__c` | Text (80) | No |
| `LastDuplicateCount__c` | Number | No |
| `LastIngestionAt__c` | DateTime | No |
| `LastIngestionCount__c` | Number | No |
| `LastIngestionErrorCodes__c` | Text (255) | No |
| `LastIngestionFailureCount__c` | Number | No |
| `LastIngestionStatus__c` | Text (40) | No |
| `RetentionDays__c` | Number | No |
| `SettingsKey__c` | Text (40) | Yes |

## Ownership and runtime state

- Five Apex classes implement runtime behavior; four are test classes and one is a test-data factory.
- All three list views belong to `Record_Health_Check_Diagnostic_Log__c`.
- The Log Platform Event `Record_Health_Check_Log__e`, Check Set custom metadata, and the Error Log
  Publisher permission set belong to the core dependency and are **not** metadata owned by Logs.
- The `Default` settings record, retained logs, and optional daily cleanup job are runtime data/state.
- Jest tests, dependency-security tests, scripts, npm dependencies, and documentation are development
  assets and are not Salesforce metadata.
- This source includes no Flows, layouts, record types, reports, dashboards, custom labels, custom
  permissions, Named Credentials, or package-owned Platform Events.
