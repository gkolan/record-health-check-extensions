/** Sends one bounded package delivery through its administrator-selected human channel. */
// CustomNotificationType is public setup metadata and has no object CRUD permission. The package
// runtime never queries checked business data here; recipient User access is resolved upstream.
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class RHCAlertsNotificationSender {
  /**
   * Sends a complete configured audience atomically where the platform API supports it.
   * @param row Claimed delivery row with its parent policy relationship populated.
   * @param recipientIds Resolved active human User identifiers.
   */
  public static void send(
    Record_Health_Check_Alert_Delivery__c row,
    Set<Id> recipientIds
  ) {
    if ('CUSTOM_NOTIFICATION'.equals(row.Policy__r.NotificationChannel__c)) {
      sendCustomNotification(row, recipientIds);
      return;
    }
    if ('EMAIL'.equals(row.Policy__r.NotificationChannel__c)) {
      sendEmail(row, recipientIds);
      return;
    }
    throw new NotificationException('UNSUPPORTED_NOTIFICATION_CHANNEL');
  }

  private static void sendCustomNotification(
    Record_Health_Check_Alert_Delivery__c row,
    Set<Id> recipientIds
  ) {
    if (
      recipientIds.size() >
      RHCAlertsRecipientResolver.CUSTOM_NOTIFICATION_RECIPIENT_LIMIT
    ) {
      throw new NotificationException('CUSTOM_NOTIFICATION_RECIPIENT_LIMIT');
    }
    List<CustomNotificationType> types = [
      SELECT Id
      FROM CustomNotificationType
      WHERE DeveloperName = 'RHC_Alert'
      LIMIT 1
    ];
    if (types.isEmpty()) {
      throw new NotificationException('NOTIFICATION_TYPE_UNAVAILABLE');
    }
    Messaging.CustomNotification notification = new Messaging.CustomNotification();
    notification.setNotificationTypeId(types[0].Id);
    notification.setTitle('Record health check alert');
    notification.setBody(messageBody(row));
    String target = resolveTarget(row);
    if (target.startsWith('{')) {
      notification.setTargetPageRef(target);
    } else {
      notification.setTargetId(target);
    }
    notification.send(stringIds(recipientIds));
  }

  /**
   * Chooses the checked record ID when it is well formed; otherwise the packaged Delivery History
   * page reference. Never an administrator-entered URL or page reference.
   * @param row delivery containing the optional checked-record identifier
   * @return a checked-record ID or the packaged Delivery History page reference
   */
  @TestVisible
  private static String resolveTarget(
    Record_Health_Check_Alert_Delivery__c row
  ) {
    if (
      String.isNotBlank(row.RecordId__c) &&
      Pattern.matches('[a-zA-Z0-9]{15,18}', row.RecordId__c)
    ) {
      return row.RecordId__c;
    }
    return '{"type":"standard__navItemPage","attributes":{"apiName":"RHC_Alerts_Delivery_History"}}';
  }

  private static void sendEmail(
    Record_Health_Check_Alert_Delivery__c row,
    Set<Id> recipientIds
  ) {
    if (
      recipientIds.size() > RHCAlertsRecipientResolver.EMAIL_RECIPIENT_LIMIT
    ) {
      throw new NotificationException('EMAIL_RECIPIENT_LIMIT');
    }
    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
    for (Id recipientId : recipientIds) {
      Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
      message.setTargetObjectId(recipientId);
      message.setSaveAsActivity(false);
      message.setSubject('Record health check alert');
      message.setPlainTextBody(messageBody(row));
      messages.add(message);
    }
    // One ledger row represents the full configured audience. Atomic submission prevents a row
    // from being marked FAILED after Salesforce already accepted only part of that audience.
    Messaging.SendEmailResult[] results = Messaging.sendEmail(messages, true);
    for (Messaging.SendEmailResult result : results) {
      if (!result.isSuccess()) {
        throw new NotificationException('EMAIL_PLATFORM_REJECTED');
      }
    }
  }

  private static Set<String> stringIds(Set<Id> ids) {
    Set<String> result = new Set<String>();
    for (Id value : ids) {
      result.add(String.valueOf(value));
    }
    return result;
  }

  @TestVisible
  private static String messageBody(Record_Health_Check_Alert_Delivery__c row) {
    String identity = String.isBlank(row.CheckQualifiedApiName__c)
      ? row.CheckSetQualifiedApiName__c
      : row.CheckQualifiedApiName__c;
    String severity = String.isBlank(row.Severity__c)
      ? ''
      : ' (' + row.Severity__c + ')';
    return 'Health check ' +
      identity +
      ' reported ' +
      row.Status__c +
      severity +
      '. Open Salesforce to review the record if you have access.';
  }

  /** Sanitized notification failure whose message is a bounded package code. */
  public class NotificationException extends Exception {
  }
}
