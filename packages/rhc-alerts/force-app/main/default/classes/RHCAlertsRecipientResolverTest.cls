/**
 * Proves the recipient directory never widens an audience and never resolves a principal the
 * administrator did not configure, including hostile and misconfigured recipient input.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsRecipientResolverTest {
  private static final List<String> HOSTILE_IDS = new List<String>{
    '005000000000000\'',
    '005%00000000000',
    '005\\000000000000',
    '005000000000000 OR Id != null',
    '005000000000000;DROP',
    '<script>alert(1)</script>'
  };

  @IsTest
  static void shouldRejectBlankAndNullRecipientIdWithoutQuerying() {
    Integer queriesBefore = Limits.getQueries();

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution nullResult = RHCAlertsRecipientResolver.resolve(
      'USER',
      null
    );
    RHCAlertsRecipientResolver.Resolution blankResult = RHCAlertsRecipientResolver.resolve(
      'USER',
      '   '
    );
    Test.stopTest();

    Assert.areEqual(
      'INVALID_RECIPIENT_ID',
      nullResult.errorCode,
      'A null recipient must fail closed with the bounded package code'
    );
    Assert.areEqual(
      'INVALID_RECIPIENT_ID',
      blankResult.errorCode,
      'A blank recipient must fail closed with the bounded package code'
    );
    Assert.isTrue(
      nullResult.userIds.isEmpty(),
      'A rejected recipient must resolve to nobody'
    );
    Assert.isTrue(
      blankResult.userIds.isEmpty(),
      'A rejected recipient must resolve to nobody'
    );
    Assert.areEqual(
      queriesBefore,
      Limits.getQueries(),
      'Malformed recipient input must be rejected before any directory query'
    );
  }

  @IsTest
  static void shouldRejectHostileRecipientIdWithoutResolvingAnyUser() {
    Test.startTest();
    for (String hostileId : HOSTILE_IDS) {
      RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
        'USER',
        hostileId
      );
      Assert.areEqual(
        'INVALID_RECIPIENT_ID',
        result.errorCode,
        'Hostile recipient input must fail closed: ' + hostileId
      );
      Assert.areEqual(
        0,
        result.userIds.size(),
        'Hostile recipient input must never resolve a principal: ' + hostileId
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectHostileRecipientIdForPublicGroupWithoutResolvingAnyUser() {
    Test.startTest();
    for (String hostileId : HOSTILE_IDS) {
      RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
        'PUBLIC_GROUP',
        hostileId
      );
      Assert.areEqual(
        'INVALID_RECIPIENT_ID',
        result.errorCode,
        'Hostile group input must fail closed: ' + hostileId
      );
      Assert.areEqual(
        0,
        result.userIds.size(),
        'Hostile group input must never resolve a principal: ' + hostileId
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectUnsupportedAndNullRecipientType() {
    Id currentUserId = UserInfo.getUserId();

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution queueResult = RHCAlertsRecipientResolver.resolve(
      'QUEUE',
      currentUserId
    );
    RHCAlertsRecipientResolver.Resolution nullTypeResult = RHCAlertsRecipientResolver.resolve(
      null,
      currentUserId
    );
    RHCAlertsRecipientResolver.Resolution caseResult = RHCAlertsRecipientResolver.resolve(
      'user',
      currentUserId
    );
    Test.stopTest();

    Assert.areEqual(
      'UNSUPPORTED_RECIPIENT_TYPE',
      queueResult.errorCode,
      'A queue recipient type is not an approved human channel'
    );
    Assert.areEqual(
      'UNSUPPORTED_RECIPIENT_TYPE',
      nullTypeResult.errorCode,
      'A null recipient type must fail closed'
    );
    Assert.areEqual(
      'UNSUPPORTED_RECIPIENT_TYPE',
      caseResult.errorCode,
      'Recipient type matching is exact, so a lowercase value must fail closed'
    );
    Assert.isTrue(
      queueResult.userIds.isEmpty() &&
        nullTypeResult.userIds.isEmpty() &&
        caseResult.userIds.isEmpty(),
      'An unsupported recipient type must resolve to nobody'
    );
  }

  @IsTest
  static void shouldResolveNobodyWhenConfiguredUserIsDeactivated() {
    User targetUser = RHCAlertsTestDataFactory.createStandardUser('deact');
    Id targetUserId = targetUser.Id;

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution activeResult = RHCAlertsRecipientResolver.resolve(
      'USER',
      targetUserId
    );
    targetUser.IsActive = false;
    update targetUser;
    RHCAlertsRecipientResolver.Resolution inactiveResult = RHCAlertsRecipientResolver.resolve(
      'USER',
      targetUserId
    );
    Test.stopTest();

    Assert.areEqual(
      null,
      activeResult.errorCode,
      'An active configured user resolves without an error code'
    );
    Assert.areEqual(
      new Set<Id>{ targetUserId },
      activeResult.userIds,
      'An active configured user resolves to exactly that principal'
    );
    Assert.areEqual(
      'RECIPIENT_USER_UNAVAILABLE',
      inactiveResult.errorCode,
      'Deactivating the configured user must fail the alert closed'
    );
    Assert.areEqual(
      0,
      inactiveResult.userIds.size(),
      'A deactivated user must never remain in a resolved audience'
    );
  }

  @IsTest
  static void shouldResolveNobodyWhenConfiguredGroupWasDeleted() {
    Group removedGroup = new Group(
      Name = 'RHC Alerts Removed',
      Type = 'Regular'
    );
    insert removedGroup;
    Id removedGroupId = removedGroup.Id;
    delete removedGroup;

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'PUBLIC_GROUP',
      removedGroupId
    );
    Test.stopTest();

    Assert.areEqual(
      'PUBLIC_GROUP_UNAVAILABLE',
      result.errorCode,
      'A recipient group deleted after the policy was saved must fail the alert closed'
    );
    Assert.areEqual(
      0,
      result.userIds.size(),
      'A deleted recipient group must resolve to nobody'
    );
  }

  @IsTest
  static void shouldRejectGroupThatIsNotAPublicGroup() {
    Group queueGroup = new Group(Name = 'RHC Alerts Queue', Type = 'Queue');
    insert queueGroup;
    Id queueGroupId = queueGroup.Id;

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'PUBLIC_GROUP',
      queueGroupId
    );
    Test.stopTest();

    Assert.areEqual(
      'PUBLIC_GROUP_UNAVAILABLE',
      result.errorCode,
      'A queue is not an approved public group recipient'
    );
    Assert.areEqual(
      0,
      result.userIds.size(),
      'A queue recipient must resolve to nobody'
    );
  }

  @IsTest
  static void shouldResolveNobodyWhenPublicGroupIsEmpty() {
    Group emptyGroup = new Group(Name = 'RHC Alerts Empty', Type = 'Regular');
    insert emptyGroup;
    Id emptyGroupId = emptyGroup.Id;

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'PUBLIC_GROUP',
      emptyGroupId
    );
    Test.stopTest();

    Assert.areEqual(
      'NO_DIRECT_ACTIVE_USERS',
      result.errorCode,
      'An empty public group must fail the alert closed rather than send to nobody silently'
    );
    Assert.areEqual(
      0,
      result.userIds.size(),
      'An empty public group must resolve to nobody'
    );
  }

  @IsTest
  static void shouldResolveNobodyWhenPublicGroupHoldsOnlyInactiveUsers() {
    User inactiveUser = RHCAlertsTestDataFactory.createStandardUser('ginact');
    Group group1 = new Group(Name = 'RHC Alerts Inactive', Type = 'Regular');
    insert group1;
    insert new GroupMember(
      GroupId = group1.Id,
      UserOrGroupId = inactiveUser.Id
    );
    inactiveUser.IsActive = false;
    update inactiveUser;
    Id groupId = group1.Id;

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'PUBLIC_GROUP',
      groupId
    );
    Test.stopTest();

    Assert.areEqual(
      'NO_DIRECT_ACTIVE_USERS',
      result.errorCode,
      'A group whose only member was deactivated must fail the alert closed'
    );
    Assert.areEqual(
      0,
      result.userIds.size(),
      'A deactivated group member must never remain in a resolved audience'
    );
  }

  @IsTest
  static void shouldResolveOnlyDirectActiveMembersAndExcludeNestedGroups() {
    User directUser = RHCAlertsTestDataFactory.createStandardUser('gdirect');
    User nestedUser = RHCAlertsTestDataFactory.createStandardUser('gnested');
    Group nestedGroup = new Group(Name = 'RHC Alerts Nested', Type = 'Regular');
    Group parentGroup = new Group(Name = 'RHC Alerts Parent', Type = 'Regular');
    insert new List<Group>{ nestedGroup, parentGroup };
    insert new List<GroupMember>{
      new GroupMember(GroupId = nestedGroup.Id, UserOrGroupId = nestedUser.Id),
      new GroupMember(GroupId = parentGroup.Id, UserOrGroupId = directUser.Id),
      new GroupMember(GroupId = parentGroup.Id, UserOrGroupId = nestedGroup.Id)
    };
    Id parentGroupId = parentGroup.Id;

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'PUBLIC_GROUP',
      parentGroupId
    );
    Test.stopTest();

    Assert.areEqual(
      null,
      result.errorCode,
      'A group with one direct active member resolves successfully'
    );
    Assert.areEqual(
      new Set<Id>{ directUser.Id },
      result.userIds,
      'Only direct active members resolve; a nested group must not widen the audience'
    );
    Assert.isFalse(
      result.userIds.contains(nestedUser.Id),
      'A nested group member must never receive an alert configured for the parent group'
    );
  }

  @IsTest
  static void shouldKeepDirectoryQueryCountFlatAsGroupMembershipGrows() {
    Group smallGroup = new Group(Name = 'RHC Alerts Small', Type = 'Regular');
    Group largeGroup = new Group(Name = 'RHC Alerts Large', Type = 'Regular');
    insert new List<Group>{ smallGroup, largeGroup };
    List<User> members = new List<User>();
    for (Integer index = 0; index < 5; index++) {
      members.add(RHCAlertsTestDataFactory.createStandardUser('bulk' + index));
    }
    List<GroupMember> memberships = new List<GroupMember>{
      new GroupMember(GroupId = smallGroup.Id, UserOrGroupId = members[0].Id)
    };
    for (User member : members) {
      memberships.add(
        new GroupMember(GroupId = largeGroup.Id, UserOrGroupId = member.Id)
      );
    }
    insert memberships;
    Id smallGroupId = smallGroup.Id;
    Id largeGroupId = largeGroup.Id;

    Test.startTest();
    Integer beforeSmall = Limits.getQueries();
    RHCAlertsRecipientResolver.Resolution smallResult = RHCAlertsRecipientResolver.resolve(
      'PUBLIC_GROUP',
      smallGroupId
    );
    Integer smallQueries = Limits.getQueries() - beforeSmall;
    Integer beforeLarge = Limits.getQueries();
    RHCAlertsRecipientResolver.Resolution largeResult = RHCAlertsRecipientResolver.resolve(
      'PUBLIC_GROUP',
      largeGroupId
    );
    Integer largeQueries = Limits.getQueries() - beforeLarge;
    Integer dmlUsed = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(
      1,
      smallResult.userIds.size(),
      'The single-member group resolves exactly one principal'
    );
    Assert.areEqual(
      5,
      largeResult.userIds.size(),
      'The five-member group resolves exactly five principals'
    );
    Assert.areEqual(
      smallQueries,
      largeQueries,
      'Query count must stay flat as membership grows, proving no query runs per member'
    );
    Assert.areEqual(0, dmlUsed, 'Resolving recipients must never perform DML');
  }

  @IsTest
  static void shouldNotLeakRecipientOrRecordDataInErrorCodes() {
    User targetUser = RHCAlertsTestDataFactory.createStandardUser('leak');
    String targetUserName = targetUser.Username;
    Id targetUserId = targetUser.Id;
    targetUser.IsActive = false;
    update targetUser;

    Test.startTest();
    RHCAlertsRecipientResolver.Resolution result = RHCAlertsRecipientResolver.resolve(
      'USER',
      targetUserId
    );
    Test.stopTest();

    Assert.areEqual(
      'RECIPIENT_USER_UNAVAILABLE',
      result.errorCode,
      'The failure must surface only the stable bounded package code'
    );
    Assert.isFalse(
      result.errorCode.contains(targetUserName),
      'An error code must never echo a username'
    );
    Assert.isFalse(
      result.errorCode.contains(String.valueOf(targetUserId)),
      'An error code must never echo a record identifier'
    );
    Assert.isFalse(
      result.errorCode.contains(UserInfo.getOrganizationId()),
      'An error code must never echo the organization identifier'
    );
    Assert.isTrue(
      Pattern.matches('[A-Z_]+', result.errorCode),
      'Error codes are stable uppercase package constants, never formatted detail'
    );
  }
}
