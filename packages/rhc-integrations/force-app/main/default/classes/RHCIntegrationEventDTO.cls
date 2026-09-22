/**
 * Canonical, minimal event shape used by the integration pipeline.
 */
@SuppressWarnings('PMD.ExcessivePublicCount')
public class RHCIntegrationEventDTO {
  /** Canonical event family: RESULT, RUN, or LOG. */
  public String eventType { get; set; }
  /** Stable event idempotency identifier supplied by core. */
  public String eventId { get; set; }
  /** Core evaluation-run identifier. */
  public String runId { get; set; }
  /** Qualified Check Set API name. */
  public String checkSetQualifiedApiName { get; set; }
  /** Qualified Check API name when the event is Check-specific. */
  public String checkQualifiedApiName { get; set; }
  /** Canonical outcome or log status. */
  public String status { get; set; }
  /** Canonical result severity when applicable. */
  public String severity { get; set; }
  /** Disclosure-safe reason classification when applicable. */
  public String reasonCode { get; set; }
  /** Core execution source classification. */
  public String source { get; set; }
  /** Canonical event contract version. */
  public String contractVersion { get; set; }
  /** Record Health Check framework version. */
  public String frameworkVersion { get; set; }
  /** Time the canonical event occurred. */
  public Datetime occurredAt { get; set; }
  /** Durable source-record identifier when disclosed by the event contract. */
  public String recordId { get; set; }
  /** Disclosure-safe Log code. */
  public String code { get; set; }
  /** Eligible Check count for Run events. */
  public Decimal eligibleCount { get; set; }
  /** Evaluated Check count for Run events. */
  public Decimal evaluatedCount { get; set; }
  /** Passed Check count for Run events. */
  public Decimal passedCount { get; set; }
  /** Failed Check count for Run events. */
  public Decimal failedCount { get; set; }
  /** Skipped Check count for Run events. */
  public Decimal skippedCount { get; set; }
  /** Unable-to-evaluate Check count for Run events. */
  public Decimal unableCount { get; set; }
  /** System-error Check count for Run events. */
  public Decimal systemErrorCount { get; set; }
}
