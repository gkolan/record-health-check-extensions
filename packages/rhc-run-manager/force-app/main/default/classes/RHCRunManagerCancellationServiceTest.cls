/** Verifies Batch Run cancellation eligibility and terminal ledger updates. */
@IsTest
private class RHCRunManagerCancellationServiceTest {
  @TestSetup
  static void assignPermissions() {
    RHCRunManagerTestDataFactory.createAdminUser();
  }

  @IsTest
  static void shouldCancelWhenBatchRunIsActive() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'ALL_ACCESSIBLE',
        'FAIL'
      );
      Record_Health_Check_Batch_Run__c active = RHCRunManagerTestDataFactory.createBatchRun(definition.Id);

      Test.startTest();
      Id cancelledId = RHCRunManagerCancellationService.cancel(active.Id);
      Test.stopTest();

      Record_Health_Check_Batch_Run__c cancelled = [
        SELECT Status__c, CompletedAt__c, ErrorSummary__c
        FROM Record_Health_Check_Batch_Run__c
        WHERE Id = :active.Id
      ];
      Assert.areEqual(active.Id, cancelledId, 'The service should return the cancelled Batch Run ID.');
      Assert.areEqual('CANCELLED', cancelled.Status__c, 'An active Batch Run should become CANCELLED.');
      Assert.isNotNull(cancelled.CompletedAt__c, 'Cancellation should record terminal completion.');
      Assert.isTrue(
        cancelled.ErrorSummary__c.startsWith('Cancelled by '),
        'Cancellation should record the acting user.'
      );
    }
  }

  @IsTest
  static void shouldRejectWhenBatchRunIsTerminal() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Record_Health_Check_Run_Definition__c definition = RHCRunManagerTestDataFactory.createDefinition(
        'ALL_ACCESSIBLE',
        'FAIL'
      );
      Record_Health_Check_Batch_Run__c terminal = RHCRunManagerTestDataFactory.createBatchRun(definition.Id);
      terminal.Status__c = 'COMPLETED';
      update terminal;

      Test.startTest();
      try {
        RHCRunManagerCancellationService.cancel(terminal.Id);
        Assert.fail('A terminal Batch Run must not be cancelled.');
      } catch (RHCRunManagerCancellationService.CancellationException error) {
        Assert.areEqual(
          'Only a queued or processing Batch Run can be cancelled.',
          error.getMessage(),
          'The service should explain terminal-row rejection.'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldRejectWhenBatchRunIdIsNull() {
    System.runAs(RHCRunManagerTestDataFactory.adminUser()) {
      Test.startTest();
      try {
        RHCRunManagerCancellationService.cancel(null);
        Assert.fail('A Batch Run ID is required.');
      } catch (RHCRunManagerCancellationService.CancellationException error) {
        Assert.areEqual('Choose a Batch Run.', error.getMessage(), 'The service should reject null input.');
      }
      Test.stopTest();
    }
  }
}
