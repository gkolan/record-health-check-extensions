/** Routes finalized core Check Set Run events after event delivery commit. */
trigger RHCIntegrationRunSubscriber on Record_Health_Check_Set_Run__e (after insert) {
    RHCIntegrationSubscriberCoordinator.processRuns(Trigger.new);
}
