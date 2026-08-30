/** Subscribes directly to finalized Record Health Check Result events. */
trigger RHCActionResultSubscriber on Record_Health_Check_Result__e(
  after insert
) {
  RHCActionResultSubscriberHandler.process(Trigger.New);
}
