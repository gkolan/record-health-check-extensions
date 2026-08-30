/** Direct canonical core Set Run event subscriber. */
trigger RHCAlertsSetRunSubscriber on Record_Health_Check_Set_Run__e(
  after insert
) {
  RHCAlertsEventService.processSetRuns(Trigger.new);
}
