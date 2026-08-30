String builderPrefix = Schema.getGlobalDescribe().containsKey(
    'Record_Health_Check_Set_Version__c'
  )
  ? ''
  : 'rhc__';
SObject v1 = Database.query(
  'SELECT ' +
  builderPrefix +
  'SnapshotJson__c FROM ' +
  builderPrefix +
  'Record_Health_Check_Set_Version__c WHERE ' +
  builderPrefix +
  'CheckSetDraft__r.' +
  builderPrefix +
  'DeveloperName__c = \'Builder_CI_Runtime_Acceptance\' AND ' +
  builderPrefix +
  'VersionNumber__c = 1 LIMIT 1'
);
Map<String, Object> version = (Map<String, Object>) JSON.deserializeUntyped(
  (String) v1.get(builderPrefix + 'SnapshotJson__c')
);
List<Object> checks = (List<Object>) version.get('checks');
checks.add(
  new Map<String, Object>{
    'qualifiedApiName' => 'Builder_CI_Runtime_Second_Check',
    'label' => 'Builder CI runtime second check',
    'values' => new Map<String, Object>{
      'Record_Health_Check_Set__c' => 'Builder_CI_Runtime_Acceptance',
      'CheckTitle__c' => 'Builder CI runtime second check',
      'EvaluationOrder__c' => 20,
      'EvaluationType__c' => 'FORMULA',
      'FailureSeverity__c' => 'INFO',
      'PassConditionFormula__c' => 'NOT(ISBLANK(Industry))',
      'FailureMessage__c' => 'Enter an Industry.',
      'IsActive__c' => false
    }
  }
);
Map<String, Object> saved = RHCBuilderController.saveCheckSetVersion(
  JSON.serialize(version),
  'ci-runtime-save-v2'
);
RHCBuilderController.activateCheckSetVersion(
  (Id) saved.get('checkSetVersionId'),
  'ci-runtime-activate-v2'
);
