/** Resolves configured human recipients without reading checked business records. */
// User, Group, and GroupMember are setup recipient directories resolved by Automated Process. The
// result contains IDs only and is bounded before any human delivery.
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class RHCAlertsRecipientResolver {
  public static final Integer CUSTOM_NOTIFICATION_RECIPIENT_LIMIT = 500;
  public static final Integer EMAIL_RECIPIENT_LIMIT = 10;

  /** Bounded recipient-resolution result. */
  public class Resolution {
    public Set<Id> userIds = new Set<Id>();
    public String errorCode;
  }

  /**
   * Resolves one User or direct User members of one public Group.
   * @param recipientType USER or PUBLIC_GROUP.
   * @param recipientId Salesforce Id stored by the validated policy.
   * @return Bounded active-user identifiers or a package error code.
   */
  public static Resolution resolve(String recipientType, String recipientId) {
    Id targetId = parseRecipientId(recipientId);
    if (targetId == null) {
      Resolution result = new Resolution();
      result.errorCode = 'INVALID_RECIPIENT_ID';
      return result;
    }
    if ('USER'.equals(recipientType)) {
      return resolveUser(targetId);
    }
    if (!'PUBLIC_GROUP'.equals(recipientType)) {
      Resolution result = new Resolution();
      result.errorCode = 'UNSUPPORTED_RECIPIENT_TYPE';
      return result;
    }
    return resolvePublicGroup(targetId);
  }

  private static Id parseRecipientId(String recipientId) {
    if (
      String.isBlank(recipientId) ||
      !Pattern.matches('[a-zA-Z0-9]{15,18}', recipientId)
    ) {
      return null;
    }
    try {
      return (Id) recipientId;
    } catch (StringException error) {
      return null;
    }
  }

  private static Resolution resolveUser(Id targetId) {
    Resolution result = new Resolution();
    for (User userValue : [
      SELECT Id
      FROM User
      WHERE Id = :targetId AND IsActive = TRUE
      LIMIT 1
    ]) {
      result.userIds.add(userValue.Id);
    }
    if (result.userIds.isEmpty()) {
      result.errorCode = 'RECIPIENT_USER_UNAVAILABLE';
    }
    return result;
  }

  private static Resolution resolvePublicGroup(Id targetId) {
    Resolution result = new Resolution();
    List<Group> groups = [
      SELECT Id
      FROM Group
      WHERE Id = :targetId AND Type = 'Regular'
      LIMIT 1
    ];
    if (groups.isEmpty()) {
      result.errorCode = 'PUBLIC_GROUP_UNAVAILABLE';
      return result;
    }
    Set<Id> memberIds = new Set<Id>();
    for (GroupMember member : [
      SELECT UserOrGroupId
      FROM GroupMember
      WHERE GroupId = :targetId
      LIMIT 5001
    ]) {
      memberIds.add(member.UserOrGroupId);
    }
    for (User userValue : [
      SELECT Id
      FROM User
      WHERE Id IN :memberIds AND IsActive = TRUE
      LIMIT 5000
    ]) {
      result.userIds.add(userValue.Id);
    }
    if (result.userIds.isEmpty()) {
      result.errorCode = 'NO_DIRECT_ACTIVE_USERS';
    }
    return result;
  }
}
