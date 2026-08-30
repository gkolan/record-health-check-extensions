trigger RHCReportsSetRunSubscriber on Record_Health_Check_Set_Run__e (after insert) {
    RHCReportsIngestionService.ingestRuns(Trigger.new);
}
