/**
 * Canonical, minimal event shape used by the integration pipeline.
 */
@SuppressWarnings('PMD.ExcessivePublicCount')
public class RHCIntegrationEventDTO {
    public String eventType { get; set; }
    public String eventId { get; set; }
    public String runId { get; set; }
    public String checkSetQualifiedApiName { get; set; }
    public String checkQualifiedApiName { get; set; }
    public String status { get; set; }
    public String severity { get; set; }
    public String reasonCode { get; set; }
    public String source { get; set; }
    public String contractVersion { get; set; }
    public String frameworkVersion { get; set; }
    public Datetime occurredAt { get; set; }
    public String recordId { get; set; }
    public String code { get; set; }
    public Decimal eligibleCount { get; set; }
    public Decimal evaluatedCount { get; set; }
    public Decimal passedCount { get; set; }
    public Decimal failedCount { get; set; }
    public Decimal skippedCount { get; set; }
    public Decimal unableCount { get; set; }
    public Decimal systemErrorCount { get; set; }
}
