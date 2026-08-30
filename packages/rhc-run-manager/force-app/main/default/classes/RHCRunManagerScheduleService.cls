/** Creates and safely replaces Run Manager-owned scheduled jobs. */
public with sharing class RHCRunManagerScheduleService {
  /** Invalid recurrence or unsafe schedule operation. */
  public class ScheduleException extends Exception {
  }

  /**
   * Creates or updates a human schedule and its exact owned CronTrigger.
   * @param scheduleId Existing Schedule ID or null.
   * @param definitionId Saved Run Definition.
   * @param active Whether the platform schedule is active.
   * @param frequency DAILY, WEEKDAYS, or WEEKLY.
   * @param preferredStartTime HH:mm in the scheduling user's time zone.
   * @param dayOfWeek Required for WEEKLY.
   * @param startDate Optional first eligible local date.
   * @param endDate Optional last eligible local date.
   * @return Saved Schedule ID.
   */
  public static Id save(
    Id scheduleId,
    Id definitionId,
    Boolean active,
    String frequency,
    String preferredStartTime,
    String dayOfWeek,
    Date startDate,
    Date endDate
  ) {
    String cron = cronExpression(frequency, preferredStartTime, dayOfWeek);
    if (startDate != null && endDate != null && startDate > endDate) {
      throw new ScheduleException('Start Date must be on or before End Date.');
    }
    List<Record_Health_Check_Run_Definition__c> definitions = [
      SELECT Id, Active__c, PopulationMode__c
      FROM Record_Health_Check_Run_Definition__c
      WHERE Id = :definitionId
      WITH USER_MODE
      LIMIT 1
    ];
    if (definitions.isEmpty() || definitions[0].Active__c != true) {
      throw new ScheduleException('An active Run Definition is required.');
    }
    if ('SUPPLIED_IDS'.equals(definitions[0].PopulationMode__c)) {
      throw new ScheduleException('Supplied-ID definitions are launched by Flow and cannot be scheduled.');
    }
    Record_Health_Check_Schedule__c scheduleRecord;
    String oldCronTriggerId;
    if (scheduleId == null) {
      scheduleRecord = new Record_Health_Check_Schedule__c();
    } else {
      scheduleRecord = [
        SELECT Id, CronTriggerId__c
        FROM Record_Health_Check_Schedule__c
        WHERE Id = :scheduleId
        WITH USER_MODE
        LIMIT 1
      ];
      oldCronTriggerId = scheduleRecord.CronTriggerId__c;
    }
    scheduleRecord.RunDefinition__c = definitionId;
    scheduleRecord.Active__c = active == true;
    scheduleRecord.Frequency__c = frequency;
    scheduleRecord.PreferredStartTime__c = preferredStartTime;
    scheduleRecord.DayOfWeek__c = dayOfWeek;
    scheduleRecord.StartDate__c = startDate;
    scheduleRecord.EndDate__c = endDate;
    if (scheduleRecord.Id == null) Database.insert(scheduleRecord, AccessLevel.USER_MODE);
    else Database.update(scheduleRecord, AccessLevel.USER_MODE);

    String newCronTriggerId;
    if (active == true) {
      newCronTriggerId = System.schedule(
        'RHC Run Manager ' + scheduleRecord.Id + ' ' + Datetime.now().getTime(),
        cron,
        new RHCRunManagerScheduled(scheduleRecord.Id)
      );
    }
    if (String.isNotBlank(oldCronTriggerId)) abortOwned(scheduleRecord.Id, oldCronTriggerId);
    scheduleRecord.CronTriggerId__c = newCronTriggerId;
    Database.update(scheduleRecord, AccessLevel.USER_MODE);
    return scheduleRecord.Id;
  }

  @TestVisible
  private static String cronExpression(
    String frequency,
    String preferredStartTime,
    String dayOfWeek
  ) {
    if (String.isBlank(preferredStartTime) || !Pattern.matches('(?:[01]\\d|2[0-3]):[0-5]\\d', preferredStartTime)) {
      throw new ScheduleException('Preferred Start Time must use HH:mm.');
    }
    List<String> timeParts = preferredStartTime.split(':');
    String prefix = '0 ' + Integer.valueOf(timeParts[1]) + ' ' + Integer.valueOf(timeParts[0]);
    if ('DAILY'.equals(frequency)) return prefix + ' * * ?';
    if ('WEEKDAYS'.equals(frequency)) return prefix + ' ? * MON-FRI';
    if ('WEEKLY'.equals(frequency) && new Set<String>{ 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN' }.contains(dayOfWeek)) {
      return prefix + ' ? * ' + dayOfWeek;
    }
    throw new ScheduleException('Frequency and Day of Week are invalid.');
  }

  // CronTrigger is a platform scheduling view, not a CRUD-governed customer object.
  @SuppressWarnings('PMD.ApexCRUDViolation')
  private static void abortOwned(Id scheduleId, String cronTriggerId) {
    List<CronTrigger> triggers = [
      SELECT Id, CronJobDetail.Name
      FROM CronTrigger
      WHERE Id = :cronTriggerId
      LIMIT 1
    ];
    if (triggers.isEmpty() || !triggers[0].CronJobDetail.Name.startsWith('RHC Run Manager ' + scheduleId + ' ')) {
      throw new ScheduleException('The stored Cron Trigger is not owned by this schedule.');
    }
    System.abortJob(triggers[0].Id);
  }
}
