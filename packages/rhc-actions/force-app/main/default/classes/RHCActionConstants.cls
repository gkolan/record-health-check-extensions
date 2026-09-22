/**
 * Defines the Day-1 corrective action contracts.
 */
public with sharing class RHCActionConstants {
  public static final String CORE_CONTRACT_VERSION = '1.0';
  public static final String FLOW_CONTRACT_VERSION = '1.0';
  public static final String MODE_MANUAL = 'MANUAL_APPROVAL';
  public static final String MODE_AUTOMATIC = 'AUTOMATIC';
  public static final String STATUS_PENDING_REVIEW = 'PENDING_REVIEW';
  public static final String STATUS_QUEUED = 'QUEUED';
  public static final String STATUS_RUNNING = 'RUNNING';
  public static final String STATUS_RETRY_WAIT = 'RETRY_WAIT';
  public static final String STATUS_SUCCEEDED = 'SUCCEEDED';
  public static final String STATUS_FAILED = 'FAILED';
  public static final String STATUS_SUPPRESSED = 'SUPPRESSED';
  public static final Integer MAX_RETRY_LIMIT = 3;
  public static final Integer MAX_ERROR_LENGTH = 255;

  @SuppressWarnings('PMD.EmptyStatementBlock')
  private RHCActionConstants() {
  }

  /**
   * Returns the version-one Flow input names accepted by policy validation.
   * @return Names of every permitted version-one Flow input.
   */
  public static Set<String> allowedFlowInputs() {
    return new Set<String>{
      'rhcRecordIdV1',
      'rhcRunIdV1',
      'rhcCheckSetQualifiedApiNameV1',
      'rhcCheckQualifiedApiNameV1',
      'rhcStatusV1',
      'rhcSeverityV1',
      'rhcReasonCodeV1',
      'rhcEventIdV1'
    };
  }
}
