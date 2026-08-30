/** Test-data helpers for complete Builder Check Set Versions. */
@IsTest
public inherited sharing class RHCBuilderTestDataFactory {
  /**
   * Creates a complete valid Check Set Version envelope.
   * @return Deterministic canonical-version JSON.
   */
  public static String validCanonicalVersion() {
    return JSON.serialize(
      new Map<String, Object>{
        'schemaVersion' => 1,
        'contractVersion' => '1.0',
        'checkSet' => new Map<String, Object>{
          'qualifiedApiName' => 'Account_Handoff_Review',
          'label' => 'Account Handoff Review',
          'values' => new Map<String, Object>{
            'CardTitle__c' => 'Account Handoff Review',
            'CardSubtitle__c' => 'Confirms that an Account is ready for handoff.',
            'ObjectApiName__c' => 'Account',
            'CardRunMode__c' => 'RUN_ON_REQUEST',
            'RunButtonDisplay__c' => 'LABEL_AND_ICON',
            'CardRevealMode__c' => 'ALL_AT_ONCE',
            'FoundExpectedDisplay__c' => 'ON_DEMAND',
            'PassedChecksDisplay__c' => 'SHOW_EACH_CHECK',
            'SkippedChecksDisplay__c' => 'SHOW_EACH_CHECK',
            'SummaryDisplay__c' => 'BOTTOM',
            'IsActive__c' => false
          }
        },
        'checks' => new List<Object>{
          new Map<String, Object>{
            'qualifiedApiName' => 'Billing_Country_Is_Populated',
            'label' => 'Billing Country is populated',
            'values' => new Map<String, Object>{
              'Record_Health_Check_Set__c' => 'Account_Handoff_Review',
              'CheckTitle__c' => 'Billing Country is populated',
              'EvaluationOrder__c' => 10,
              'EvaluationType__c' => 'FORMULA',
              'FailureSeverity__c' => 'WARNING',
              'PassConditionFormula__c' => 'NOT(ISBLANK(BillingCountry))',
              'FailureMessage__c' => 'Enter the account Billing Country.',
              'IsActive__c' => false
            }
          }
        }
      }
    );
  }

  /**
   * Creates a successful Builder validation response.
   * @return Deterministic validation-report JSON.
   */
  public static String validValidationReport() {
    return '{"isValid":true,"issues":[]}';
  }

  /**
   * Creates a Builder publication plan with exact qualified names and fields.
   * @return Deterministic deployment-plan JSON.
   */
  public static String deploymentPlan() {
    return JSON.serialize(
      new Map<String, Object>{
        'components' => new List<Object>{
          new Map<String, Object>{
            'fullName' => 'rhc__Record_Health_Check_Set__mdt.Account_Handoff_Review',
            'label' => 'Account Handoff Review',
            'values' => new Map<String, Object>{
              'rhc__CardTitle__c' => 'Account Handoff Review',
              'rhc__ObjectApiName__c' => 'Account',
              'rhc__IsActive__c' => false
            }
          },
          new Map<String, Object>{
            'fullName' => 'rhc__Record_Health_Check__mdt.Billing_Country_Is_Populated',
            'label' => 'Billing Country is populated',
            'values' => new Map<String, Object>{
              'rhc__Record_Health_Check_Set__c' => 'Account_Handoff_Review',
              'rhc__EvaluationType__c' => 'FORMULA',
              'rhc__IsActive__c' => false
            }
          }
        }
      }
    );
  }

  /**
   * Creates one persisted validated complete version.
   * @return Builder Check Set Version record identifier.
   */
  public static Id createValidatedVersion() {
    Record_Health_Check_Set_Draft__c draft = new Record_Health_Check_Set_Draft__c(
      Name = 'Account Handoff Review',
      DeveloperName__c = 'Account_Handoff_Review',
      ObjectApiName__c = 'Account',
      Status__c = 'DRAFT'
    );
    insert draft;
    String canonical = RHCBuilderFieldMapping.canonicalize(
      validCanonicalVersion()
    );
    Record_Health_Check_Set_Version__c version = new Record_Health_Check_Set_Version__c(
      CheckSetDraft__c = draft.Id,
      VersionNumber__c = 1,
      Status__c = 'VALIDATED',
      Label__c = 'Account Handoff Review',
      SnapshotJson__c = canonical,
      Fingerprint__c = EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(canonical))
      ),
      ValidatedAt__c = System.now(),
      IsActive__c = false
    );
    insert version;
    return version.Id;
  }
}
