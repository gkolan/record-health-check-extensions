trigger RHCReportsResultSubscriber on Record_Health_Check_Result__e (after insert) {
    RHCReportsIngestionService.ingestResults(Trigger.new);
}
