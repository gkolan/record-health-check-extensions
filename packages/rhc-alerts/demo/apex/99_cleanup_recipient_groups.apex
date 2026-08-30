// SANDBOX/DEMO ONLY. Setup-object cleanup is isolated to avoid Mixed DML.
Set<String> developerNames = new Set<String>{
  'RHC_Alerts_Demo_Recipients',
  'RHC_Alerts_Demo_Empty_Group'
};
List<Group> demoGroups = [
  SELECT Id
  FROM Group
  WHERE DeveloperName IN :developerNames AND Type = 'Regular'
];
Set<Id> demoGroupIds = new Map<Id, Group>(demoGroups).keySet();
List<GroupMember> demoMembers = [
  SELECT Id
  FROM GroupMember
  WHERE GroupId IN :demoGroupIds
];
if (!demoMembers.isEmpty()) {
  delete demoMembers;
}
if (!demoGroups.isEmpty()) {
  delete demoGroups;
}
