/** Tests calls between the Builder controller and its contract. */
@IsTest
private inherited sharing class RHCBuilderContractGatewayTest {
  private class CapturingContract implements Callable {
    /**
     * Captures the publication choice and returns predictable Builder responses.
     * @param action Builder contract action name.
     * @param arguments Builder contract action values.
     * @return Predictable validation or publication-plan JSON.
     */
    public Object call(String action, Map<String, Object> arguments) {
      if (action == 'buildDeploymentPlan') {
        Assert.areEqual(
          true,
          arguments.get('activate'),
          'Activation choice must reach the Builder publication-plan service.'
        );
        Assert.areEqual(
          'prior-active-version',
          arguments.get('priorActiveVersionJson'),
          'The prior active version must reach the publication contract.'
        );
        return RHCBuilderTestDataFactory.deploymentPlan();
      }
      return RHCBuilderTestDataFactory.validValidationReport();
    }
  }

  /** Returns an invalid empty payload so gateway fail-closed behavior is testable. */
  private class EmptyContract implements Callable {
    /**
     * Returns an invalid empty response.
     * @param action Ignored contract action.
     * @param arguments Ignored contract arguments.
     * @return An intentionally invalid empty response.
     */
    public Object call(String action, Map<String, Object> arguments) {
      return '';
    }
  }

  /** Raises an internal exception so gateway error sanitization is testable. */
  private class ThrowingContract implements Callable {
    /**
     * Raises the internal exception used to test sanitization.
     * @param action Ignored contract action.
     * @param arguments Ignored contract arguments.
     * @return No value because this implementation intentionally throws.
     */
    public Object call(String action, Map<String, Object> arguments) {
      throw new IllegalArgumentException('internal detail');
    }
  }

  @IsTest
  static void shouldDelegateValidationAndPlanToBuilderContract() {
    System.runAs(currentUser()) {
      RHCBuilderContractGateway.testContract = new CapturingContract();

      Test.startTest();
      String validation = RHCBuilderContractGateway.validateVersion(
        RHCBuilderTestDataFactory.validCanonicalVersion()
      );
      String plan = RHCBuilderContractGateway.buildDeploymentPlan(
        RHCBuilderTestDataFactory.validCanonicalVersion(),
        RHCBuilderContractGateway.PublicationMode.ACTIVATE_NOW,
        'prior-active-version'
      );
      Test.stopTest();

      Assert.isTrue(
        validation.contains('"isValid":true'),
        'Builder validation response should pass through.'
      );
      Assert.isTrue(
        plan.contains('components'),
        'Builder publication plan should pass through.'
      );
    }
  }

  @IsTest
  static void shouldUseInactiveConveniencePlanAndDescribeRealContract() {
    System.runAs(currentUser()) {
      Test.startTest();
      String description = RHCBuilderContractGateway.describeContract();
      String plan = RHCBuilderContractGateway.buildDeploymentPlan(
        RHCBuilderTestDataFactory.validCanonicalVersion(),
        RHCBuilderContractGateway.PublicationMode.INACTIVE
      );
      Test.stopTest();

      Assert.isTrue(description.contains('contractVersion'), 'The real contract must resolve.');
      Assert.isTrue(plan.contains('components'), 'The convenience overload must build a plan.');
    }
  }

  @IsTest
  static void shouldFailClosedForEmptyOrThrowingContractResponses() {
    System.runAs(currentUser()) {
      RHCBuilderContractGateway.testContract = new EmptyContract();
      try {
        RHCBuilderContractGateway.describeContract();
        Assert.fail('An empty contract response must fail closed.');
      } catch (RHCBuilderContractGateway.BuilderContractException error) {
        Assert.isTrue(error.getMessage().contains('empty'), 'The empty response must be identified.');
      }

      RHCBuilderContractGateway.testContract = new ThrowingContract();
      try {
        RHCBuilderContractGateway.validateVersion('{}');
        Assert.fail('An implementation exception must be wrapped.');
      } catch (RHCBuilderContractGateway.BuilderContractException error) {
        Assert.isTrue(
          error.getMessage().contains('could not complete'),
          'The gateway must return a stable user-safe contract failure.'
        );
      }
    }
  }

  private static User currentUser() {
    return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
  }
}
