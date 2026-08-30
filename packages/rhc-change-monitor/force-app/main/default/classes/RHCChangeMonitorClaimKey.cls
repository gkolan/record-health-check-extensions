/** Produces versioned, delimiter-safe CDC event-policy-record claim identities. */
public class RHCChangeMonitorClaimKey {
  private static final String VERSION = 'rhc-change-monitor-claim-v1';

  @SuppressWarnings('PMD.EmptyStatementBlock')
  private RHCChangeMonitorClaimKey() {
  }

  /**
   * Creates the stable SHA-256 claim key required before core dispatch.
   * @param eventEnvelope Validated CDC header facts.
   * @param policyId Durable policy identity.
   * @param recordId Source record identity, or null for a gap incident.
   * @return Lowercase 64-character SHA-256 digest.
   */
  public static String create(
    RHCChangeMonitorEventEnvelope eventEnvelope,
    Id policyId,
    String recordId
  ) {
    if (eventEnvelope == null || policyId == null) {
      throw new IllegalArgumentException('An event envelope and policy ID are required.');
    }
    List<String> components = new List<String>{
      VERSION,
      eventEnvelope.sourceObjectApiName,
      eventEnvelope.transactionKey,
      String.valueOf(eventEnvelope.sequenceNumber),
      eventEnvelope.changeType,
      String.valueOf(policyId),
      recordId
    };
    List<String> encoded = new List<String>();
    for (String component : components) {
      encoded.add(component == null ? '-' : EncodingUtil.base64Encode(Blob.valueOf(component)));
    }
    return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(String.join(encoded, '.'))));
  }
}
