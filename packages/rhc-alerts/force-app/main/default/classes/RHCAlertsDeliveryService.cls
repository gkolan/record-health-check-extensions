/** Applies cooldown, resolves human recipients, and sends bounded platform notifications. */
// Invoked by the package event subscriber/Queueable platform context. It accesses only package-owned
// policy and ledger objects; administrator-facing reads remain USER_MODE in the controller.
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class RHCAlertsDeliveryService {
  private static final Integer MAX_ATTEMPTS = 3;

  /**
   * Delivers claimed rows and returns only transient rows eligible for another attempt.
   * @param deliveryIds Claimed package ledger row identifiers.
   * @return Transient delivery identifiers eligible for another attempt.
   */
  public static List<Id> deliver(List<Id> deliveryIds) {
    if (deliveryIds == null || deliveryIds.isEmpty()) {
      return new List<Id>();
    }
    List<Record_Health_Check_Alert_Delivery__c> deliveries = pendingDeliveries(
      deliveryIds
    );
    if (deliveries.isEmpty()) {
      return new List<Id>();
    }
    DeliveryContext context = buildContext(deliveries);
    for (Record_Health_Check_Alert_Delivery__c row : deliveries) {
      processDelivery(row, context);
    }
    assertAllSucceeded(Database.update(deliveries, false));
    return context.retryIds;
  }

  private static List<Record_Health_Check_Alert_Delivery__c> pendingDeliveries(
    List<Id> deliveryIds
  ) {
    return [
      SELECT
        Id,
        Policy__c,
        DeliveryKey__c,
        EventId__c,
        RecordId__c,
        CheckSetQualifiedApiName__c,
        CheckQualifiedApiName__c,
        Status__c,
        Severity__c,
        Outcome__c,
        AttemptCount__c,
        CooldownKey__c,
        OccurredAt__c,
        Policy__r.Active__c,
        Policy__r.CooldownMinutes__c,
        Policy__r.RecipientType__c,
        Policy__r.RecipientId__c,
        Policy__r.NotificationChannel__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE Id IN :deliveryIds AND Outcome__c = 'PENDING'
      ORDER BY Policy__c, Id
      LIMIT 10
    ];
  }

  private static DeliveryContext buildContext(
    List<Record_Health_Check_Alert_Delivery__c> deliveries
  ) {
    Set<Id> policyIds = new Set<Id>();
    Set<String> cooldownKeys = new Set<String>();
    for (Record_Health_Check_Alert_Delivery__c row : deliveries) {
      if (row.Policy__c != null) {
        policyIds.add(row.Policy__c);
      }
      if (row.CooldownKey__c != null) {
        cooldownKeys.add(row.CooldownKey__c);
      }
    }
    // Locking policy rows serializes distinct event transactions for the same policy.
    List<Record_Health_Check_Alert_Policy__c> lockedPolicies = [
      SELECT Id
      FROM Record_Health_Check_Alert_Policy__c
      WHERE Id IN :policyIds
      FOR UPDATE
    ];
    DeliveryContext context = new DeliveryContext();
    context.lockedPolicyIds = new Map<Id, Record_Health_Check_Alert_Policy__c>(
        lockedPolicies
      )
      .keySet();
    for (Record_Health_Check_Alert_Delivery__c prior : [
      SELECT CooldownKey__c, DeliveredAt__c
      FROM Record_Health_Check_Alert_Delivery__c
      WHERE CooldownKey__c IN :cooldownKeys AND Outcome__c = 'DELIVERED'
      ORDER BY DeliveredAt__c DESC
      LIMIT 10000
    ]) {
      if (
        !context.latestDeliveredByCooldownKey.containsKey(prior.CooldownKey__c)
      ) {
        context.latestDeliveredByCooldownKey.put(
          prior.CooldownKey__c,
          prior.DeliveredAt__c
        );
      }
    }
    return context;
  }

  private static void processDelivery(
    Record_Health_Check_Alert_Delivery__c row,
    DeliveryContext context
  ) {
    row.AttemptCount__c =
      (row.AttemptCount__c == null ? 0 : row.AttemptCount__c) + 1;
    row.AttemptedAt__c = System.now();
    if (!hasAvailablePolicy(row, context.lockedPolicyIds)) {
      failTerminal(row, 'CONFIGURATION', 'POLICY_UNAVAILABLE');
      return;
    }
    if (row.Policy__r.Active__c != true) {
      suppress(row, 'POLICY_INACTIVE');
      return;
    }
    if (isCoolingDown(row, context.latestDeliveredByCooldownKey)) {
      suppress(row, 'COOLDOWN');
      return;
    }
    RHCAlertsRecipientResolver.Resolution recipients = RHCAlertsRecipientResolver.resolve(
      row.Policy__r.RecipientType__c,
      row.Policy__r.RecipientId__c
    );
    row.RecipientCount__c = recipients.userIds.size();
    if (recipients.errorCode != null) {
      failTerminal(row, 'CONFIGURATION', recipients.errorCode);
      return;
    }
    attemptDelivery(row, recipients.userIds, context);
  }

  private static Boolean hasAvailablePolicy(
    Record_Health_Check_Alert_Delivery__c row,
    Set<Id> lockedPolicyIds
  ) {
    return row.Policy__c != null && lockedPolicyIds.contains(row.Policy__c);
  }

  private static Boolean isCoolingDown(
    Record_Health_Check_Alert_Delivery__c row,
    Map<String, Datetime> latestDeliveredByCooldownKey
  ) {
    Datetime priorDelivery = latestDeliveredByCooldownKey.get(
      row.CooldownKey__c
    );
    Decimal cooldownMinutes = row.Policy__r.CooldownMinutes__c == null
      ? 0
      : row.Policy__r.CooldownMinutes__c;
    return priorDelivery != null &&
      cooldownMinutes > 0 &&
      priorDelivery.addMinutes(Integer.valueOf(cooldownMinutes)) >
      row.OccurredAt__c;
  }

  private static void attemptDelivery(
    Record_Health_Check_Alert_Delivery__c row,
    Set<Id> recipientIds,
    DeliveryContext context
  ) {
    try {
      RHCAlertsNotificationSender.send(row, recipientIds);
      markDelivered(row, context.latestDeliveredByCooldownKey);
    } catch (RHCAlertsNotificationSender.NotificationException error) {
      fail(
        row,
        RHCAlertsDeliveryFailure.fromCode(error.getMessage()),
        context.retryIds
      );
    } catch (DeliveryException error) {
      fail(
        row,
        RHCAlertsDeliveryFailure.fromCode(error.getMessage()),
        context.retryIds
      );
    } catch (DmlException error) {
      fail(row, RHCAlertsDeliveryFailure.fromDml(error), context.retryIds);
    } catch (Exception error) {
      failTerminal(row, 'PERMANENT', 'PLATFORM_DELIVERY_FAILURE');
    }
  }

  private static void markDelivered(
    Record_Health_Check_Alert_Delivery__c row,
    Map<String, Datetime> latestDeliveredByCooldownKey
  ) {
    row.Outcome__c = 'DELIVERED';
    row.DeliveredAt__c = System.now();
    row.NextRetryAt__c = null;
    row.SuppressionReason__c = null;
    row.FailureClass__c = null;
    row.ErrorCode__c = null;
    latestDeliveredByCooldownKey.put(row.CooldownKey__c, row.DeliveredAt__c);
  }

  private static void assertAllSucceeded(List<Database.SaveResult> results) {
    for (Database.SaveResult result : results) {
      if (!result.isSuccess()) {
        throw new DeliveryException('LEDGER_UPDATE_FAILED');
      }
    }
  }

  private static void suppress(
    Record_Health_Check_Alert_Delivery__c row,
    String reason
  ) {
    row.Outcome__c = 'SUPPRESSED';
    row.SuppressionReason__c = reason;
    row.FailureClass__c = null;
    row.ErrorCode__c = null;
    row.NextRetryAt__c = null;
  }

  private static void fail(
    Record_Health_Check_Alert_Delivery__c row,
    RHCAlertsDeliveryFailure.Disposition disposition,
    List<Id> retryIds
  ) {
    row.SuppressionReason__c = null;
    row.FailureClass__c = disposition.classification;
    row.ErrorCode__c = disposition.code;
    if (disposition.retryable && row.AttemptCount__c < MAX_ATTEMPTS) {
      row.Outcome__c = 'PENDING';
      row.NextRetryAt__c = System.now().addMinutes(1);
      retryIds.add(row.Id);
    } else {
      row.Outcome__c = 'FAILED';
      row.NextRetryAt__c = null;
    }
  }

  @TestVisible
  private static void failTransient(
    Record_Health_Check_Alert_Delivery__c row,
    String code,
    List<Id> retryIds
  ) {
    fail(row, RHCAlertsDeliveryFailure.transientFailure(code), retryIds);
  }

  private static void failTerminal(
    Record_Health_Check_Alert_Delivery__c row,
    String classification,
    String code
  ) {
    fail(
      row,
      RHCAlertsDeliveryFailure.terminal(classification, code),
      new List<Id>()
    );
  }

  private class DeliveryContext {
    private Set<Id> lockedPolicyIds = new Set<Id>();
    private Map<String, Datetime> latestDeliveredByCooldownKey = new Map<String, Datetime>();
    private List<Id> retryIds = new List<Id>();
  }

  /** Sanitized internal delivery signal; its message is a bounded package code. */
  public class DeliveryException extends Exception {
  }
}
