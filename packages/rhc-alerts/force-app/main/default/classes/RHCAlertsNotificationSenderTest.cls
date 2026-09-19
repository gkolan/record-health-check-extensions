// Pure message formatting has no user-data security boundary; transport behavior is exercised by
// the Queueable/service tests in the package runtime context.
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class RHCAlertsNotificationSenderTest {
  @IsTest
  static void shouldBuildRecipientMessageWithoutRecordOrRestrictedDetail() {
    Record_Health_Check_Alert_Delivery__c row = new Record_Health_Check_Alert_Delivery__c(
      CheckQualifiedApiName__c = 'pkg__Safe_Check',
      Status__c = 'FAIL',
      Severity__c = 'WARNING',
      RecordId__c = UserInfo.getUserId()
    );

    Test.startTest();
    String message = RHCAlertsNotificationSender.messageBody(row);
    Test.stopTest();

    Assert.isTrue(
      message.contains('pkg__Safe_Check'),
      'Approved identity should explain the alert.'
    );
    Assert.isTrue(
      message.contains('FAIL (WARNING)'),
      'Canonical status and severity should explain the alert.'
    );
    Assert.isFalse(
      message.contains(row.RecordId__c),
      'Raw record IDs should not be exposed to recipients.'
    );
    Assert.isFalse(
      message.toLowerCase().contains('stack'),
      'Stack traces must never be included.'
    );
  }

  @IsTest
  static void shouldTargetRecordWhenIdIsWellFormedOtherwiseDeliveryHistory() {
    Assert.areEqual(
      UserInfo.getUserId(),
      RHCAlertsNotificationSender.resolveTarget(
        new Record_Health_Check_Alert_Delivery__c(RecordId__c = UserInfo.getUserId())
      ),
      'A well-formed record ID becomes the target.'
    );
    Assert.isTrue(
      RHCAlertsNotificationSender.resolveTarget(
        new Record_Health_Check_Alert_Delivery__c(RecordId__c = 'not-an-id')
      ).contains('"apiName":"RHC_Alerts_Delivery_History"'),
      'A malformed ID falls back to the packaged Delivery History navigation item.'
    );
  }

  @IsTest
  static void shouldUseCheckSetIdentityAndOmitBlankSeverity() {
    Record_Health_Check_Alert_Delivery__c row = new Record_Health_Check_Alert_Delivery__c(
      CheckSetQualifiedApiName__c = 'pkg__Safe_Set',
      Status__c = 'COMPLETED'
    );

    Test.startTest();
    String message = RHCAlertsNotificationSender.messageBody(row);
    Test.stopTest();

    Assert.isTrue(
      message.contains('pkg__Safe_Set reported COMPLETED.'),
      'Set-run messages should use the set identity without an empty severity suffix.'
    );
  }

  @IsTest
  static void shouldRejectEmailAudienceAbovePackageLimit() {
    Test.startTest();
    try {
      RHCAlertsNotificationSender.send(
        rowWithChannel('EMAIL'),
        recipientIds(11)
      );
      Assert.fail(
        'An oversized email audience should be rejected before submission.'
      );
    } catch (RHCAlertsNotificationSender.NotificationException error) {
      Assert.areEqual(
        'EMAIL_RECIPIENT_LIMIT',
        error.getMessage(),
        'Email rejection should expose only the bounded package code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectCustomNotificationAudienceAbovePackageLimit() {
    Test.startTest();
    try {
      RHCAlertsNotificationSender.send(
        rowWithChannel('CUSTOM_NOTIFICATION'),
        recipientIds(501)
      );
      Assert.fail(
        'An oversized custom-notification audience should be rejected before submission.'
      );
    } catch (RHCAlertsNotificationSender.NotificationException error) {
      Assert.areEqual(
        'CUSTOM_NOTIFICATION_RECIPIENT_LIMIT',
        error.getMessage(),
        'Custom-notification rejection should expose only the bounded package code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectUnsupportedNotificationChannel() {
    Test.startTest();
    try {
      RHCAlertsNotificationSender.send(rowWithChannel('SMS'), recipientIds(1));
      Assert.fail('Unsupported transport channels should be rejected.');
    } catch (RHCAlertsNotificationSender.NotificationException error) {
      Assert.areEqual(
        'UNSUPPORTED_NOTIFICATION_CHANNEL',
        error.getMessage(),
        'Unsupported channels should expose only the bounded package code.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldSubmitSingleRecipientEmailAtomically() {
    Record_Health_Check_Alert_Delivery__c row = rowWithChannel('EMAIL');
    row.CheckQualifiedApiName__c = 'pkg__Email_Check';
    row.Status__c = 'FAIL';

    Test.startTest();
    RHCAlertsNotificationSender.send(row, new Set<Id>{ UserInfo.getUserId() });
    Integer emailInvocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.areEqual(
      1,
      emailInvocations,
      'A valid single-recipient delivery should make one atomic email submission.'
    );
  }

  private static Record_Health_Check_Alert_Delivery__c rowWithChannel(
    String channel
  ) {
    Record_Health_Check_Alert_Delivery__c row = new Record_Health_Check_Alert_Delivery__c();
    row.Policy__r = new Record_Health_Check_Alert_Policy__c(
      NotificationChannel__c = channel
    );
    return row;
  }

  private static Set<Id> recipientIds(Integer count) {
    Set<Id> ids = new Set<Id>();
    for (Integer index = 0; index < count; index++) {
      ids.add((Id) ('005000000000' + String.valueOf(index).leftPad(3, '0')));
    }
    return ids;
  }
}
