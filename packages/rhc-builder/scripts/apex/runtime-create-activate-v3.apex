String builderPrefix = Schema.getGlobalDescribe().containsKey(
    'Record_Health_Check_Set_Version__c'
  )
  ? ''
  : 'rhc__';
SObject v2 = Database.query(
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
  'VersionNumber__c = 2 LIMIT 1'
);
Map<String, Object> version = (Map<String, Object>) JSON.deserializeUntyped(
  (String) v2.get(builderPrefix + 'SnapshotJson__c')
);
((List<Object>) version.get('checks')).remove(1);
Map<String, Object> saved = RHCBuilderController.saveCheckSetVersion(
  JSON.serialize(version),
  'ci-runtime-save-v3'
);
RHCBuilderController.activateCheckSetVersion(
  (Id) saved.get('checkSetVersionId'),
  'ci-runtime-activate-v3'
);
