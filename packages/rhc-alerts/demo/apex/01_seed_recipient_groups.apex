// SANDBOX/DEMO ONLY. Setup-object DML is isolated here to avoid Mixed DML.
Set<String> developerNames = new Set<String>{
  'RHC_Alerts_Demo_Recipients',
  'RHC_Alerts_Demo_Empty_Group'
};
Map<String, Group> groupsByDeveloperName = new Map<String, Group>();
for (Group groupValue : [
  SELECT Id, DeveloperName
  FROM Group
  WHERE DeveloperName IN :developerNames AND Type = 'Regular'
]) {
  groupsByDeveloperName.put(groupValue.DeveloperName, groupValue);
}

List<Group> groupsToInsert = new List<Group>();
if (!groupsByDeveloperName.containsKey('RHC_Alerts_Demo_Recipients')) {
  groupsToInsert.add(
    new Group(
      Name = '[RHC Alerts Demo] Recipients',
      DeveloperName = 'RHC_Alerts_Demo_Recipients',
      Type = 'Regular'
    )
  );
}
if (!groupsByDeveloperName.containsKey('RHC_Alerts_Demo_Empty_Group')) {
  groupsToInsert.add(
    new Group(
      Name = '[RHC Alerts Demo] Empty Group',
      DeveloperName = 'RHC_Alerts_Demo_Empty_Group',
      Type = 'Regular'
    )
  );
}
if (!groupsToInsert.isEmpty()) {
  insert groupsToInsert;
}

groupsByDeveloperName.clear();
for (Group groupValue : [
  SELECT Id, DeveloperName
  FROM Group
  WHERE DeveloperName IN :developerNames AND Type = 'Regular'
]) {
  groupsByDeveloperName.put(groupValue.DeveloperName, groupValue);
}

Id recipientGroupId = groupsByDeveloperName.get('RHC_Alerts_Demo_Recipients')
  .Id;
List<GroupMember> existingMembership = [
  SELECT Id
  FROM GroupMember
  WHERE GroupId = :recipientGroupId AND UserOrGroupId = :UserInfo.getUserId()
  LIMIT 1
];
if (existingMembership.isEmpty()) {
  insert new GroupMember(
    GroupId = recipientGroupId,
    UserOrGroupId = UserInfo.getUserId()
  );
}

System.assertEquals(
  2,
  groupsByDeveloperName.size(),
  'Both demo public groups must exist.'
);
