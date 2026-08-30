/**
 * Retains canonical Record Health Check Log events without invoking Record Health Check.
 */
trigger RHCLogsLogSubscriber on Record_Health_Check_Log__e (after insert) {
    RHCLogsIngestionService.ingest(Trigger.new);
}
