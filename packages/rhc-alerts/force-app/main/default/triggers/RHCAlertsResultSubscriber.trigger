/** Direct canonical core Result event subscriber. */
trigger RHCAlertsResultSubscriber on Record_Health_Check_Result__e(
  after insert
) {
  RHCAlertsEventService.processResults(Trigger.new);
}
