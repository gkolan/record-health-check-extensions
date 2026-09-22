/** Creates and safely replaces Run Manager-owned scheduled jobs. */
public with sharing class RHCRunManagerScheduleService {
  /** Cohesive human-schedule values accepted by the scheduling service. */
  public class Request {
    public Id scheduleId;
    public Id definitionId;
    public Boolean active;
    public String frequency;
    public String preferredStartTime;
    public String dayOfWeek;
    public Date startDate;
    public Date endDate;
  }

  /** Invalid recurrence or unsafe schedule operation. */
  public class ScheduleException extends Exception {
  }

  /**
   * Creates or updates a human schedule and its exact owned CronTrigger.
   * @param request Validated human-schedule values from the administrator facade.
   * @return Saved Schedule ID.
   */
  public static Id save(Request request) {
    if (request == null) {
      throw new ScheduleException('Schedule input is required.');
    }
    String cron = cronExpression(request.frequency, request.preferredStartTime, request.dayOfWeek);
    validateDateWindow(request.startDate, request.endDate);
    validateSchedulableDefinition(request.definitionId);
    Record_Health_Check_Schedule__c scheduleRecord = loadSchedule(request.scheduleId);
    String oldCronTriggerId = scheduleRecord.CronTriggerId__c;
    scheduleRecord.RunDefinition__c = request.definitionId;
    scheduleRecord.Active__c = request.active == true;
    scheduleRecord.Frequency__c = request.frequency;
    scheduleRecord.PreferredStartTime__c = request.preferredStartTime;
    scheduleRecord.DayOfWeek__c = request.dayOfWeek;
    scheduleRecord.StartDate__c = request.startDate;
    scheduleRecord.EndDate__c = request.endDate;
    saveScheduleRecord(scheduleRecord);

    String newCronTriggerId = scheduleIfActive(scheduleRecord, cron);
    replaceOwnedJob(scheduleRecord.Id, oldCronTriggerId);
    scheduleRecord.CronTriggerId__c = newCronTriggerId;
    Database.update(scheduleRecord, AccessLevel.USER_MODE);
    return scheduleRecord.Id;
  }

  /**
   * Deactivates one saved schedule and removes only its exact owned platform job.
   * @param scheduleId Saved Schedule ID.
   * @return Paused Schedule ID.
   */
  public static Id pause(Id scheduleId) {
    if (scheduleId == null) {
      throw new ScheduleException('Choose a schedule.');
    }
    Record_Health_Check_Schedule__c existing = [
      SELECT Id, RunDefinition__c, Frequency__c, PreferredStartTime__c, DayOfWeek__c,
        StartDate__c, EndDate__c
      FROM Record_Health_Check_Schedule__c
      WHERE Id = :scheduleId
      WITH USER_MODE
      LIMIT 1
    ];
    Request request = new Request();
    request.scheduleId = existing.Id;
    request.definitionId = existing.RunDefinition__c;
    request.active = false;
    request.frequency = existing.Frequency__c;
    request.preferredStartTime = existing.PreferredStartTime__c;
    request.dayOfWeek = existing.DayOfWeek__c;
    request.startDate = existing.StartDate__c;
    request.endDate = existing.EndDate__c;
    return save(request);
  }

  private static void validateDateWindow(Date startDate, Date endDate) {
    if (startDate != null && endDate != null && startDate > endDate) {
      throw new ScheduleException('Start Date must be on or before End Date.');
    }
  }

  private static void validateSchedulableDefinition(Id definitionId) {
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
  }

  private static Record_Health_Check_Schedule__c loadSchedule(Id scheduleId) {
    if (scheduleId == null) {
      return new Record_Health_Check_Schedule__c();
    }
    return [
      SELECT Id, CronTriggerId__c
      FROM Record_Health_Check_Schedule__c
      WHERE Id = :scheduleId
      WITH USER_MODE
      LIMIT 1
    ];
  }

  private static void saveScheduleRecord(Record_Health_Check_Schedule__c scheduleRecord) {
    if (scheduleRecord.Id == null) {
      Database.insert(scheduleRecord, AccessLevel.USER_MODE);
    } else {
      Database.update(scheduleRecord, AccessLevel.USER_MODE);
    }
  }

  private static String scheduleIfActive(Record_Health_Check_Schedule__c scheduleRecord, String cron) {
    if (scheduleRecord.Active__c == true) {
      return System.schedule(
        'RHC Run Manager ' + scheduleRecord.Id + ' ' + Datetime.now().getTime(),
        cron,
        new RHCRunManagerScheduled(scheduleRecord.Id)
      );
    }
    return null;
  }

  private static void replaceOwnedJob(Id scheduleId, String oldCronTriggerId) {
    if (String.isNotBlank(oldCronTriggerId)) {
      abortOwned(scheduleId, oldCronTriggerId);
    }
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
    if ('DAILY'.equals(frequency)) {
      return prefix + ' * * ?';
    }
    if ('WEEKDAYS'.equals(frequency)) {
      return prefix + ' ? * MON-FRI';
    }
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
