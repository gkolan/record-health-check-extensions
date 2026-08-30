/** Calls the validation and publication contract supplied by RHC Builder. */
public inherited sharing class RHCBuilderContractGateway {
  /** Whether publication should activate the version immediately. */
  public enum PublicationMode {
    ACTIVATE_NOW,
    INACTIVE
  }

  @TestVisible
  private static Callable testContract;

  /** User-safe failure raised when Builder cannot complete its contract action. */
  public class BuilderContractException extends Exception {
  }

  /**
   * Returns the choices and limits supported by this Builder version.
   * @return Builder contract JSON, including allowed values and limits.
   */
  public static String describeContract() {
    return invoke('describeContract', new Map<String, Object>());
  }

  /**
   * Validates a complete Check Set Version through the Builder contract.
   * @param canonicalVersionJson Complete Check Set Version JSON.
   * @return Validation report JSON with locations that match the Builder screen.
   */
  public static String validateVersion(String canonicalVersionJson) {
    return invoke(
      'validateVersion',
      new Map<String, Object>{ 'canonicalVersionJson' => canonicalVersionJson }
    );
  }

  /**
   * Builds an allow-listed Metadata API publication plan.
   * @param canonicalVersionJson Complete previously validated version.
   * @param publicationMode Whether the published version should be active.
   * @return Builder-owned Metadata API publication-plan JSON.
   */
  public static String buildDeploymentPlan(
    String canonicalVersionJson,
    PublicationMode publicationMode
  ) {
    return buildDeploymentPlan(
      canonicalVersionJson,
      publicationMode,
      null
    );
  }

  /**
   * Builds an allow-listed publication plan and deactivates Checks omitted from the prior active version.
   * @param canonicalVersionJson Complete previously validated target version.
   * @param publicationMode Whether the published version should be active.
   * @param priorActiveVersionJson Prior active complete version, or null when none exists.
   * @return Builder-owned Metadata API publication-plan JSON.
   */
  public static String buildDeploymentPlan(
    String canonicalVersionJson,
    PublicationMode publicationMode,
    String priorActiveVersionJson
  ) {
    return invoke(
      'buildDeploymentPlan',
      new Map<String, Object>{
        'canonicalVersionJson' => canonicalVersionJson,
        'activate' => String.valueOf(publicationMode) == 'ACTIVATE_NOW',
        'priorActiveVersionJson' => priorActiveVersionJson
      }
    );
  }

  private static String invoke(String action, Map<String, Object> arguments) {
    Callable contract = resolveContract();
    try {
      Object response = contract.call(action, arguments);
      if (!(response instanceof String) || String.isBlank((String) response)) {
        throw new BuilderContractException(
          'RHC Builder returned an empty validation or publication response.'
        );
      }
      return (String) response;
    } catch (BuilderContractException error) {
      throw error;
    } catch (Exception error) {
      throw new BuilderContractException(
        'RHC Builder could not complete validation or publication.',
        error
      );
    }
  }

  private static Callable resolveContract() {
    if (Test.isRunningTest() && testContract != null) {
      return testContract;
    }
    return new RecordHealthCheckBuilderContract();
  }
}
