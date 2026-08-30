Map<String, Object> version = new Map<String, Object>{
  'schemaVersion' => 1,
  'contractVersion' => '1.0',
  'checkSet' => new Map<String, Object>{
    'qualifiedApiName' => 'Builder_CI_Runtime_Acceptance',
    'label' => 'Builder CI Runtime Acceptance',
    'values' => new Map<String, Object>{
      'CardTitle__c' => 'Builder CI Runtime Acceptance',
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
      'qualifiedApiName' => 'Builder_CI_Runtime_Formula',
      'label' => 'Builder CI runtime formula',
      'values' => new Map<String, Object>{
        'Record_Health_Check_Set__c' => 'Builder_CI_Runtime_Acceptance',
        'CheckTitle__c' => 'Builder CI runtime formula',
        'EvaluationOrder__c' => 10,
        'EvaluationType__c' => 'FORMULA',
        'FailureSeverity__c' => 'WARNING',
        'PassConditionFormula__c' => 'NOT(ISBLANK(Name))',
        'FailureMessage__c' => 'Enter an Account Name.',
        'IsActive__c' => false
      }
    }
  }
};
String canonical = JSON.serialize(version);
Map<String, Object> validation = RHCBuilderController.validateCheckSetVersion(canonical);
System.assertEquals(true, validation.get('isValid'), JSON.serialize(validation));
Map<String, Object> saved = RHCBuilderController.saveCheckSetVersion(
  canonical,
  'ci-runtime-save-v1'
);
Map<String, Object> saveRetry = RHCBuilderController.saveCheckSetVersion(
  canonical,
  'ci-runtime-save-v1'
);
System.assertEquals(saved.get('checkSetVersionId'), saveRetry.get('checkSetVersionId'));
Id versionId = (Id) saved.get('checkSetVersionId');
Map<String, Object> publication = RHCBuilderController.publishCheckSetVersion(
  versionId,
  'ci-runtime-publish-inactive-v1'
);
Map<String, Object> publicationRetry = RHCBuilderController.publishCheckSetVersion(
  versionId,
  'ci-runtime-publish-inactive-v1'
);
System.assertEquals(publication.get('operationToken'), publicationRetry.get('operationToken'));
