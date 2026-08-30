@IsTest
private class RHCAlertsViewerControllerTest {
  @TestSetup
  static void setup() {
    User viewer = new User(
      Alias = 'rhcview',
      Email = 'rhc-alerts-viewer@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Alerts Viewer',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Chicago',
      Username = 'rhc-alerts-viewer-' +
        UserInfo.getOrganizationId() +
        '@example.invalid'
    );
    insert viewer;
    PermissionSet permissionValue = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'RHC_Alerts_Viewer_Runtime'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = viewer.Id,
      PermissionSetId = permissionValue.Id
    );
  }

  @IsTest
  static void shouldReturnOnlyBoundedDeliveryHistory() {
    Record_Health_Check_Alert_Policy__c policy = RHCAlertsTestDataFactory.createCheckPolicy(
      'pkg__Viewer_Check',
      0
    );
    Record_Health_Check_Alert_Delivery__c delivery = RHCAlertsTestDataFactory.createPendingDelivery(
      policy,
      'viewer-event'
    );

    User viewer = [SELECT Id FROM User WHERE Alias = 'rhcview' LIMIT 1];
    List<Record_Health_Check_Alert_Delivery__c> rows;
    System.runAs(viewer) {
      Test.startTest();
      rows = RHCAlertsViewerController.listDeliveries();
      Test.stopTest();
    }

    Assert.areEqual(
      1,
      rows.size(),
      'The visible delivery should be returned once.'
    );
    Assert.areEqual(
      delivery.Id,
      rows[0].Id,
      'The exact delivery should be returned.'
    );
    Assert.areEqual(
      'Test policy pkg__Viewer_Check',
      rows[0].Policy__r.DisplayName__c,
      'Only the policy display name is needed by history.'
    );
    Map<String, Object> populatedFields = rows[0].getPopulatedFieldsAsMap();
    Assert.isFalse(
      populatedFields.containsKey('RecordId__c'),
      'The history contract must not query checked record IDs.'
    );
    Assert.isFalse(
      populatedFields.containsKey('DeliveryKey__c'),
      'The history contract must not query internal idempotency digests.'
    );
  }
}
