// Removes only records created by scripts/demo/create-demo-data.apex.
// Child operational history is removed before configuration and standard demo records.

Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
String rhcPrefix = globalDescribe.containsKey('rhc__Record_Health_Check_Run_Definition__c')
  ? 'rhc__'
  : '';
String definitionObject = rhcPrefix + 'Record_Health_Check_Run_Definition__c';
String displayNameField = rhcPrefix + 'DisplayName__c';
Set<String> definitionNames = new Set<String>{
  'RHC Demo - All Accessible Accounts',
  'RHC Demo - Filtered Accounts',
  'RHC Demo - Accounts from Contact Changes'
};
List<SObject> definitions = Database.query(
  'SELECT Id FROM ' + definitionObject +
  ' WHERE ' + displayNameField + ' IN :definitionNames'
);
Set<Id> definitionIds = new Map<Id, SObject>(definitions).keySet();

if (!definitionIds.isEmpty()) {
  String batchObject = rhcPrefix + 'Record_Health_Check_Batch_Run__c';
  String batchDefinitionField = rhcPrefix + 'RunDefinition__c';
  List<SObject> batchRuns = Database.query(
    'SELECT Id FROM ' + batchObject +
    ' WHERE ' + batchDefinitionField + ' IN :definitionIds'
  );
  Set<Id> batchRunIds = new Map<Id, SObject>(batchRuns).keySet();

  if (!batchRunIds.isEmpty()) {
    String runObject = rhcPrefix + 'Record_Health_Check_Run__c';
    String runBatchField = rhcPrefix + 'BatchRun__c';
    List<SObject> runs = Database.query(
      'SELECT Id FROM ' + runObject +
      ' WHERE ' + runBatchField + ' IN :batchRunIds'
    );
    Set<Id> runIds = new Map<Id, SObject>(runs).keySet();
    if (!runIds.isEmpty()) {
      String resultObject = rhcPrefix + 'Record_Health_Check_Run_Result__c';
      String resultRunField = rhcPrefix + 'Run__c';
      Database.delete(Database.query(
        'SELECT Id FROM ' + resultObject +
        ' WHERE ' + resultRunField + ' IN :runIds'
      ), false);
      Database.delete(runs, false);
    }
    Database.delete(batchRuns, false);
  }

  String requestObject = rhcPrefix + 'Record_Health_Check_Run_Request__c';
  String requestDefinitionField = rhcPrefix + 'RunDefinition__c';
  Database.delete(Database.query(
    'SELECT Id FROM ' + requestObject +
    ' WHERE ' + requestDefinitionField + ' IN :definitionIds'
  ), false);

  String scheduleObject = rhcPrefix + 'Record_Health_Check_Schedule__c';
  String scheduleDefinitionField = rhcPrefix + 'RunDefinition__c';
  Database.delete(Database.query(
    'SELECT Id FROM ' + scheduleObject +
    ' WHERE ' + scheduleDefinitionField + ' IN :definitionIds'
  ), false);
  Database.delete(definitions, false);
}

Set<String> demoContactLastNames = new Set<String>{
  'RHC Demo Relationship Change',
  'RHC Demo Bulk One',
  'RHC Demo Bulk Two'
};
delete [SELECT Id FROM Contact WHERE LastName IN :demoContactLastNames];

Set<String> accountNames = new Set<String>{
  'RHC Demo - Complete Account',
  'RHC Demo - Sparse Account',
  'RHC Demo - Previous Parent',
  'RHC Demo - Current Parent'
};
delete [SELECT Id FROM Account WHERE Name IN :accountNames];
System.debug(LoggingLevel.ERROR, 'RHC DEMO REMOVED');

