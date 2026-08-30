/** Routes finalized core Check Result events after event delivery commit. */
trigger RHCIntegrationResultSubscriber on Record_Health_Check_Result__e (after insert) {
    RHCIntegrationSubscriberCoordinator.processResults(Trigger.new);
}
