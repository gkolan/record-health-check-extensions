/** Tests exact core-field mapping and namespace preservation. */
@IsTest
private class RHCBuilderFieldMappingTest {
  @IsTest
  static void shouldPreserveExactNamesAndValuesWhenCanonicalizing() {
    System.runAs(currentUser()) {
      Test.startTest();
      String canonical = RHCBuilderFieldMapping.canonicalize(
        RHCBuilderTestDataFactory.validCanonicalVersion()
      );
      Test.stopTest();

      Assert.isTrue(
        canonical.contains('Account_Handoff_Review'),
        'Qualified API Name must remain exact and namespace-aware.'
      );
      Assert.isTrue(
        canonical.contains('NOT(ISBLANK(BillingCountry))'),
        'Formula text must not be rewritten.'
      );
      Assert.areEqual(
        18,
        RHCBuilderFieldMapping.CHECK_SET_FIELDS.size(),
        'Every current core Check Set custom field must have a mapping decision.'
      );
      Assert.areEqual(
        44,
        RHCBuilderFieldMapping.CHECK_FIELDS.size(),
        'Every current core Check custom field must have a mapping decision.'
      );
    }
  }

  @IsTest
  static void shouldRejectUnsupportedFieldWhenEnvelopeWouldCreateSecondSchema() {
    System.runAs(currentUser()) {
      Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
        RHCBuilderTestDataFactory.validCanonicalVersion()
      );
      Map<String, Object> setComponent = (Map<String, Object>) envelope.get(
        'checkSet'
      );
      Map<String, Object> values = (Map<String, Object>) setComponent.get(
        'values'
      );
      values.put('BuilderOnlyRuntimeField__c', 'not allowed');

      Test.startTest();
      try {
        RHCBuilderFieldMapping.canonicalize(JSON.serialize(envelope));
        Assert.fail('Unsupported runtime fields must be rejected.');
      } catch (RHCBuilderFieldMapping.MappingException error) {
        Assert.isTrue(
          error.getMessage().contains('unsupported fields'),
          'Failure should identify the exact mapping allow-list.'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void shouldRejectInputLargerThanTheVersionSnapshotField() {
    System.runAs(currentUser()) {
      String oversized = '{"padding":"';
      for (Integer index = 0; index < 1025; index++) {
        oversized += 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
      }
      oversized += '"}';

      Test.startTest();
      try {
        RHCBuilderFieldMapping.canonicalize(oversized);
        Assert.fail('Input larger than the storage field must fail before DML.');
      } catch (RHCBuilderFieldMapping.MappingException error) {
        Assert.isTrue(
          error.getMessage().contains('too large'),
          'The failure should identify the storage-safe size boundary.'
        );
      }
      Test.stopTest();
    }
  }

  private static User currentUser() {
    return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
  }
}
