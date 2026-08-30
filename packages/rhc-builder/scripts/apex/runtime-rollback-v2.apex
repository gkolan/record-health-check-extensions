String builderPrefix = Schema.getGlobalDescribe().containsKey(
    'Record_Health_Check_Set_Version__c'
  )
  ? ''
  : 'rhc__';
SObject v2 = Database.query(
  'SELECT Id FROM ' +
  builderPrefix +
  'Record_Health_Check_Set_Version__c WHERE ' +
  builderPrefix +
  'CheckSetDraft__r.' +
  builderPrefix +
  'DeveloperName__c = \'Builder_CI_Runtime_Acceptance\' AND ' +
  builderPrefix +
  'VersionNumber__c = 2 LIMIT 1'
);
Map<String, Object> operation = RHCBuilderController.rollbackToCheckSetVersion(
  (Id) v2.get('Id'),
  'ci-runtime-rollback-v2'
);
Map<String, Object> retry = RHCBuilderController.rollbackToCheckSetVersion(
  (Id) v2.get('Id'),
  'ci-runtime-rollback-v2'
);
System.assertEquals(operation.get('operationToken'), retry.get('operationToken'));
