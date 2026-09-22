/**
 * Subscriber-owned adapter for Account change events.
 */
trigger RHCAccountChangeMonitor on AccountChangeEvent (after insert) {
  RHCChangeMonitorIntake.accept(Trigger.new);
}
