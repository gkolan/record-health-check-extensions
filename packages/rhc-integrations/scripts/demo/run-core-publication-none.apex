Opportunity demoOpportunity = [SELECT Id FROM Opportunity WHERE Name = 'RHC Demo - Integration Event Reference' LIMIT 1];
String runId = 'RHC-DEMO-CORE-NONE-' + String.valueOf(Datetime.now().getTime());
rhc.RecordHealthCheckRequest request = rhc.RecordHealthCheckRequest.forCheckSet(
    'rhc__Example_Opportunity_Deal_Readiness',
    new List<Id>{ demoOpportunity.Id }
).withRunId(runId).withEventPublication(rhc.RecordHealthCheckEventPublication.NONE);
rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(request);
System.assert(!response.results.isEmpty(), 'Publication NONE must still return evaluation results to the caller.');
System.debug(LoggingLevel.INFO, 'RHC_DEMO_CORE_NONE_RUN_ID=' + runId
    + ' resultCount=' + response.results.size() + ' expectedDeliveryCount=0');

