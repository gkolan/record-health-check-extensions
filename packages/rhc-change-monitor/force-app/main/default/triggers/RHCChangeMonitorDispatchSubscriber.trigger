/**
 * Runs the dispatcher under the subscriber-configured runtime user (PlatformEventSubscriberConfig),
 * because change-event triggers and their Queueables always execute as Automated Process, which
 * cannot hold the core run permission even when permission sets are assigned to it.
 */
trigger RHCChangeMonitorDispatchSubscriber on Record_Health_Check_Change_Dispatch__e (after insert) {
  RHCChangeMonitorDispatchSupport.enqueueDispatcher();
}
