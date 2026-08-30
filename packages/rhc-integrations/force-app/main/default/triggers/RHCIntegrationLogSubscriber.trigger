/** Routes only the approved, non-diagnostic subset of canonical core Log events. */
trigger RHCIntegrationLogSubscriber on Record_Health_Check_Log__e (after insert) {
    RHCIntegrationSubscriberCoordinator.processLogs(Trigger.new);
}
