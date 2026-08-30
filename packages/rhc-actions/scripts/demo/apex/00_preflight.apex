// Read-only subscriber-org preflight for the RHC Actions demo. Sandbox only.

List<String> requiredTypes = new List<String>{
  'Account',
  'Task',
  'rhc__RHC_Action_Policy__c',
  'rhc__RHC_Pending_Action__c',
  'rhc__RHC_Action_History__c',
  'rhc__Record_Health_Check_Result__e'
};
Map<String, Schema.SObjectType> allTypes = Schema.getGlobalDescribe();
for (String requiredType : requiredTypes) {
  if (!allTypes.containsKey(requiredType)) {
    throw new IllegalArgumentException('Missing required object: ' + requiredType);
  }
}

List<FlowDefinitionView> demoFlows = [
  SELECT ApiName, ActiveVersionId, ProcessType
  FROM FlowDefinitionView
  WHERE ApiName = 'Create_Data_Steward_Task'
  LIMIT 1
];
if (demoFlows.isEmpty()) {
  throw new IllegalArgumentException(
    'Create and activate the Create_Data_Steward_Task autolaunched Flow first.'
  );
}
FlowDefinitionView demoFlow = demoFlows[0];
if (demoFlow.ActiveVersionId == null || demoFlow.ProcessType != 'AutoLaunchedFlow') {
  throw new IllegalArgumentException(
    'Create_Data_Steward_Task must be an active autolaunched Flow.'
  );
}

System.debug(LoggingLevel.INFO, 'RHC_ACTIONS_DEMO_PREFLIGHT=PASS');
System.debug(LoggingLevel.INFO, 'ACTIVE_FLOW_VERSION_ID=' + demoFlow.ActiveVersionId);
System.debug(
  LoggingLevel.INFO,
  'CURRENT_USER_HAS_APPROVE=' +
    FeatureManagement.checkPermission('rhc__RHC_Actions_Approve')
);
System.debug(
  LoggingLevel.INFO,
  'CURRENT_USER_HAS_AUTO_EXECUTE=' +
    FeatureManagement.checkPermission('rhc__RHC_Actions_Automatic_Execution')
);
