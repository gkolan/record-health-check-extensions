/** Validates and persists Run Definitions through resolved core metadata. */
public with sharing class RHCRunManagerDefinitionService {
  private static final Set<String> SELECTION_TYPES = new Set<String>{ 'CHECK_SET', 'CHECK' };
  private static final Set<String> POPULATION_MODES = new Set<String>{
    'ALL_ACCESSIBLE', 'GUIDED_FILTERED', 'SUPPLIED_IDS'
  };
  private static final Set<String> CAPTURE_MODES = new Set<String>{ 'PASS', 'FAIL', 'BOTH' };

  /** Invalid definition input or persistence failure. */
  public class DefinitionException extends Exception {
  }

  /**
   * Validates, canonicalizes, and saves one Run Definition in user mode.
   * @param definition Draft values supplied by the administrator facade.
   * @return Saved Run Definition ID.
   */
  public static Id save(Record_Health_Check_Run_Definition__c definition) {
    if (definition == null) {
      throw new DefinitionException('Run Definition input is required.');
    }
    validate(definition);
    try {
      RHCRunManagerCoreMetadataGateway.DefinitionInfo coreInfo = RHCRunManagerCoreMetadataGateway.resolve(
        definition.SelectionType__c,
        definition.QualifiedApiName__c
      );
      RHCRunManagerFilterService.validate(
        coreInfo.targetObjectApiName,
        definition.PopulationMode__c,
        definition.FilterJson__c
      );
      definition.DisplayName__c = definition.DisplayName__c.trim();
      definition.QualifiedApiName__c = coreInfo.qualifiedApiName;
      definition.TargetObjectApiName__c = coreInfo.targetObjectApiName;
      saveRecord(definition);
      return definition.Id;
    } catch (Exception error) {
      throw new DefinitionException('The Run Definition could not be saved.');
    }
  }

  private static void validate(Record_Health_Check_Run_Definition__c definition) {
    if (String.isBlank(definition.DisplayName__c) || definition.DisplayName__c.trim().length() > 80) {
      throw new DefinitionException('Name is required and must be 80 characters or fewer.');
    }
    requireAllowed(definition.SelectionType__c, SELECTION_TYPES, 'Selection Type is invalid.');
    requireAllowed(definition.PopulationMode__c, POPULATION_MODES, 'Population Mode is invalid.');
    requireAllowed(definition.CaptureMode__c, CAPTURE_MODES, 'Capture Mode is invalid.');
    if (!isWholeNumberWithin(definition.BatchSize__c, 1, 200)) {
      throw new DefinitionException('Batch Size must be a whole number from 1 through 200.');
    }
    if (!isWholeNumberWithin(definition.CoalesceDelayMinutes__c, 1, 10)) {
      throw new DefinitionException('Coalesce delay must be a whole number from 1 through 10.');
    }
  }

  private static void requireAllowed(
    String value,
    Set<String> allowedValues,
    String errorMessage
  ) {
    if (!allowedValues.contains(value)) {
      throw new DefinitionException(errorMessage);
    }
  }

  private static Boolean isWholeNumberWithin(
    Decimal value,
    Integer minimum,
    Integer maximum
  ) {
    return value != null &&
      value >= minimum &&
      value <= maximum &&
      value == value.setScale(0);
  }

  private static void saveRecord(Record_Health_Check_Run_Definition__c definition) {
    if (definition.Id == null) {
      Database.insert(definition, AccessLevel.USER_MODE);
    } else {
      Database.update(definition, AccessLevel.USER_MODE);
    }
  }
}
