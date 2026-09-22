/**
 * Maps administrator commands to domain services and translates failures for the LWC facade.
 */
public with sharing class RHCRunManagerAdminCommandService {
  /**
   * Saves a validated Day-1 Run Definition.
   * @param input Administrator-supplied definition values.
   * @return Saved Run Definition ID.
   */
  public static Id saveDefinition(
    RHCRunManagerAdminController.DefinitionInput input
  ) {
    if (input == null) {
      throw handled('Run Definition input is required.');
    }
    try {
      return RHCRunManagerDefinitionService.save(
        new Record_Health_Check_Run_Definition__c(
          Id = input.id,
          DisplayName__c = input.displayName,
          Active__c = input.active,
          SelectionType__c = input.selectionType,
          QualifiedApiName__c = input.qualifiedApiName,
          PopulationMode__c = input.populationMode,
          FilterJson__c = input.filterJson,
          BatchSize__c = input.batchSize,
          CaptureMode__c = input.captureMode,
          CoalesceDelayMinutes__c = input.coalesceDelayMinutes
        )
      );
    } catch (RHCRunManagerDefinitionService.DefinitionException error) {
      throw handled(error.getMessage());
    } catch (Exception error) {
      throw handled('The Run Definition could not be saved.');
    }
  }

  /**
   * Starts Run Now through the shared execution path.
   * @param definitionId Saved Run Definition ID.
   * @return Created Batch Run ID.
   */
  public static Id runNow(Id definitionId) {
    try {
      return RHCRunManagerExecutionService.runNow(definitionId);
    } catch (RHCRunManagerExecutionService.ExecutionException error) {
      throw handled(error.getMessage());
    } catch (Exception error) {
      throw handled('The Run Definition could not be started.');
    }
  }

  /**
   * Cancels an active owned Batch Run.
   * @param batchRunId Active owned Batch Run ID.
   * @return Cancelled Batch Run ID.
   */
  public static Id cancelBatchRun(Id batchRunId) {
    try {
      return RHCRunManagerCancellationService.cancel(batchRunId);
    } catch (RHCRunManagerCancellationService.CancellationException error) {
      throw handled(error.getMessage());
    } catch (Exception error) {
      throw handled('The Batch Run could not be cancelled.');
    }
  }

  /**
   * Saves a human recurrence without accepting CRON.
   * @param input Administrator-supplied schedule values.
   * @return Saved Schedule ID.
   */
  public static Id saveSchedule(
    RHCRunManagerAdminController.ScheduleInput input
  ) {
    if (input == null) {
      throw handled('Schedule input is required.');
    }
    try {
      RHCRunManagerScheduleService.Request request =
        new RHCRunManagerScheduleService.Request();
      request.scheduleId = input.id;
      request.definitionId = input.runDefinitionId;
      request.active = input.active;
      request.frequency = input.frequency;
      request.preferredStartTime = input.preferredStartTime;
      request.dayOfWeek = input.dayOfWeek;
      request.startDate = input.startDate;
      request.endDate = input.endDate;
      return RHCRunManagerScheduleService.save(request);
    } catch (Exception error) {
      throw handled('The schedule could not be saved.');
    }
  }

  /**
   * Deactivates a schedule and safely removes only its owned platform job.
   * @param scheduleId Owned Schedule ID.
   * @return Paused Schedule ID.
   */
  public static Id pauseSchedule(Id scheduleId) {
    if (scheduleId == null) {
      throw handled('Choose a schedule.');
    }
    try {
      return RHCRunManagerScheduleService.pause(scheduleId);
    } catch (Exception error) {
      throw handled('The schedule could not be paused.');
    }
  }

  private static AuraHandledException handled(String message) {
    return new AuraHandledException(message);
  }
}
