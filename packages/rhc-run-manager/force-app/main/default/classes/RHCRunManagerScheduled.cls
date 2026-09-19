/** Lightweight owned schedule adapter that delegates to the shared execution service. */
public with sharing class RHCRunManagerScheduled implements Schedulable {
  private Id scheduleId;

  /** @param scheduleId Owned Schedule record ID. */
  public RHCRunManagerScheduled(Id scheduleId) {
    if (scheduleId == null) throw new IllegalArgumentException('Schedule ID is required.');
    this.scheduleId = scheduleId;
  }

  /** Launches the saved definition under the schedule owner. */
  public void execute(SchedulableContext context) {
    Record_Health_Check_Schedule__c scheduleRecord = [
      SELECT Id, Active__c, RunDefinition__c, StartDate__c, EndDate__c, CronTriggerId__c
      FROM Record_Health_Check_Schedule__c
      WHERE Id = :scheduleId
      WITH USER_MODE
      LIMIT 1
    ];
    if (scheduleRecord.Active__c != true) return;
    Date todayValue = Date.today();
    if (scheduleRecord.StartDate__c != null && todayValue < scheduleRecord.StartDate__c) return;
    if (scheduleRecord.EndDate__c != null && todayValue > scheduleRecord.EndDate__c) {
      Database.update(new Record_Health_Check_Schedule__c(
        Id = scheduleRecord.Id,
        Active__c = false,
        CronTriggerId__c = null
      ), AccessLevel.USER_MODE);
      if (context != null && String.valueOf(context.getTriggerId()) == scheduleRecord.CronTriggerId__c) {
        System.abortJob(context.getTriggerId());
      }
      return;
    }
    try {
      RHCRunManagerExecutionService.start(
        scheduleRecord.RunDefinition__c,
        'SCHEDULED',
        scheduleRecord.Id,
        null
      );
    } catch (RHCRunManagerExecutionService.ExecutionException overlap) {
      // The previous run is still active; leave LastFiredAt unchanged and let the next occurrence try.
      return;
    }
    Database.update(new Record_Health_Check_Schedule__c(
      Id = scheduleRecord.Id,
      LastFiredAt__c = System.now()
    ), AccessLevel.USER_MODE);
  }
}
