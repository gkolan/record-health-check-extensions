/** Classifies sanitized delivery failures and their bounded retry disposition. */
public inherited sharing class RHCAlertsDeliveryFailure {
  /**
   * Returns the disposition for a notification transport package code.
   * @param code Sanitized package error code.
   * @return Retry classification for the delivery ledger.
   */
  public static Disposition fromCode(String code) {
    Boolean transientFailure = code == 'TEMPORARY_PLATFORM_FAILURE';
    return new Disposition(
      transientFailure
        ? 'TRANSIENT'
        : (code.endsWith('_LIMIT') ? 'LIMIT' : 'PERMANENT'),
      code,
      transientFailure
    );
  }

  /**
   * Returns the bounded disposition for a platform DML failure.
   * @param error Platform DML failure caught at the delivery boundary.
   * @return Retry classification without exception details.
   */
  public static Disposition fromDml(DmlException error) {
    Boolean transientFailure =
      error.getDmlType(0) == StatusCode.UNABLE_TO_LOCK_ROW;
    return new Disposition(
      transientFailure ? 'TRANSIENT' : 'PERMANENT',
      transientFailure ? 'UNABLE_TO_LOCK_ROW' : 'PLATFORM_DML_FAILURE',
      transientFailure
    );
  }

  /**
   * Returns an explicitly retryable transient package disposition.
   * @param code Sanitized package error code.
   * @return Retryable transient classification.
   */
  public static Disposition transientFailure(String code) {
    return new Disposition('TRANSIENT', code, true);
  }

  /**
   * Returns an explicitly terminal package disposition.
   * @param classification Bounded failure class.
   * @param code Sanitized package error code.
   * @return Nonretryable terminal classification.
   */
  public static Disposition terminal(String classification, String code) {
    return new Disposition(classification, code, false);
  }

  /** Immutable bounded failure classification consumed by the delivery ledger service. */
  public class Disposition {
    /** Bounded operational failure class. */
    public String classification { get; private set; }
    /** Sanitized package error code. */
    public String code { get; private set; }
    /** Whether another bounded Queueable attempt is permitted. */
    public Boolean retryable { get; private set; }

    private Disposition(String classification, String code, Boolean retryable) {
      this.classification = classification;
      this.code = code;
      this.retryable = retryable;
    }
  }
}
