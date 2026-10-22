/**
 * Red and war scenarios for the Builder's hostile-input boundary: admin-supplied query
 * configuration, malformed envelopes, authoring denial, and bulk authoring volume.
 */
@IsTest
private class RHCBuilderAdversarialTest {
  private static final String VALID_QUERY = 'SELECT Id FROM Contact WHERE AccountId = {!record.Id}';

  private static Map<String, Object> queryValues(String sourceQuery) {
    return new Map<String, Object>{
      'SourceQuery__c' => sourceQuery,
      'SourceQueryField__c' => 'Id',
      'ComparisonOperator__c' => 'EQUALS',
      'QueryResultHandling__c' => 'ONE_RESULT',
      'ExpectedValueSource__c' => 'FIXED_VALUE',
      'ExpectedFixedValue__c' => 'expected'
    };
  }

  private static String issuesFor(String sourceQuery) {
    return JSON.serialize(
      RHCBuilderQueryValidator.validate(queryValues(sourceQuery), 'QUERY')
    );
  }

  @IsTest
  static void shouldRejectQueryTemplatesCarryingBindVariables() {
    Test.startTest();
    Boolean accepted = RHCBuilderQueryValidator.isSupportedBulkShape(
      'SELECT Id FROM Account WHERE OwnerId = :UserInfo.getUserId()'
    );
    Test.stopTest();
    Assert.isFalse(
      accepted,
      'A bind variable must never survive into a stored query template.'
    );
  }

  @IsTest
  static void shouldRejectMoreThanOneRecordToken() {
    Test.startTest();
    Boolean accepted = RHCBuilderQueryValidator.isSupportedBulkShape(
      'SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND Email = {!record.Email}'
    );
    Test.stopTest();
    Assert.isFalse(
      accepted,
      'Two correlation tokens break the scope-safe boundary and must be rejected.'
    );
  }

  @IsTest
  static void shouldRejectUnterminatedTokenSyntax() {
    Test.startTest();
    Boolean accepted = RHCBuilderQueryValidator.isSupportedBulkShape(
      'SELECT Id FROM Contact WHERE AccountId = {!record'
    );
    Test.stopTest();
    Assert.isFalse(
      accepted,
      'A malformed token must be rejected rather than passed through verbatim.'
    );
  }

  @IsTest
  static void shouldRejectCorrelationTokenOutsideAnEqualityComparison() {
    Test.startTest();
    Boolean accepted = RHCBuilderQueryValidator.isSupportedBulkShape(
      'SELECT Id FROM Contact WHERE Name LIKE {!record.Name}'
    );
    Test.stopTest();
    Assert.isFalse(
      accepted,
      'A correlation token is only scope-safe inside an equality comparison.'
    );
  }

  @IsTest
  static void shouldRejectCorrelatedQueryWithANonSingleRowLimit() {
    Test.startTest();
    Boolean accepted = RHCBuilderQueryValidator.isSupportedBulkShape(
      'SELECT Id FROM Contact WHERE AccountId = {!record.Id} LIMIT 200'
    );
    Test.stopTest();
    Assert.isFalse(
      accepted,
      'A correlated template may only return one row per scope record.'
    );
  }

  @IsTest
  static void shouldRejectCorrelatedQueryWithMultiKeyOrdering() {
    Test.startTest();
    Boolean accepted = RHCBuilderQueryValidator.isSupportedBulkShape(
      'SELECT Id FROM Contact WHERE AccountId = {!record.Id} ORDER BY Name, Email'
    );
    Test.stopTest();
    Assert.isFalse(
      accepted,
      'Multi-key ordering is not a shape the pinned core can execute per scope record.'
    );
  }

  @IsTest
  static void shouldRejectQuotesPercentsAndBackslashesAsIncompleteStatements() {
    Map<String, String> hostileByLabel = new Map<String, String>{
      'bare single quote' => '\'',
      'percent wildcard' => '%',
      'backslash' => '\\',
      'comment sequence' => '// SELECT Id FROM Account',
      'statement keyword only' => 'DELETE FROM Account',
      'subquery as the whole query' => '(SELECT Id FROM Contact)'
    };
    Test.startTest();
    for (String label : hostileByLabel.keySet()) {
      String serialized = issuesFor(hostileByLabel.get(label));
      Assert.isTrue(
        serialized.contains('CORE_INVALID_SOQL_TEMPLATE'),
        'Hostile input must be rejected as an incomplete SELECT: ' + label
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectAQueryWhoseRootObjectDoesNotExist() {
    Test.startTest();
    String serialized = issuesFor('SELECT Id FROM NoSuchObject__c');
    Test.stopTest();
    Assert.isTrue(
      serialized.contains('does not identify an object in this org'),
      'A query naming a removed object must fail at authoring time: ' + serialized
    );
    Assert.isTrue(
      serialized.contains('SourceQuery__c'),
      'The issue must point at the offending query field.'
    );
  }

  @IsTest
  static void shouldRejectAQueryWhoseRootObjectTheAuthorCannotRead() {
    User restricted = RHCBuilderTestDataFactory.restrictedUser('rootread');
    String serialized;
    Test.startTest();
    System.runAs(restricted) {
      serialized = issuesFor(
        'SELECT Id FROM Record_Health_Check_Set_Draft__c'
      );
    }
    Test.stopTest();
    Assert.isTrue(
      serialized.contains('CORE_RECORD_NOT_ACCESSIBLE'),
      'A query root the author cannot read must be refused: ' + serialized
    );
    Assert.isFalse(
      serialized.contains('SELECT'),
      'The refusal must not echo the query text back to the UI.'
    );
  }

  @IsTest
  static void shouldStillAcceptAReadableRootForTheSameAuthor() {
    Test.startTest();
    String serialized = issuesFor(VALID_QUERY);
    Test.stopTest();
    Assert.areEqual(
      '[]',
      serialized,
      'A readable, scope-safe query must remain valid.'
    );
  }

  @IsTest
  static void shouldRejectARelationshipResultFieldOnANonAggregateQuery() {
    Map<String, Object> values = queryValues(VALID_QUERY);
    values.put('ComparisonOperator__c', 'CONTAINS');
    values.put('SourceQueryField__c', 'Account.Name');
    Test.startTest();
    List<Object> issues = RHCBuilderQueryValidator.validate(values, 'QUERY');
    Test.stopTest();
    Assert.isTrue(
      JSON.serialize(issues).contains('TEXT_OPERATOR_REQUIRES_TEXT'),
      'A dotted result path cannot be proven to be text and must be refused.'
    );
  }

  @IsTest
  static void shouldRejectTextOperatorsOnANonTextField() {
    Map<String, Object> values = queryValues('SELECT Id FROM Account');
    values.put('ComparisonOperator__c', 'CONTAINS');
    values.put('SourceQueryField__c', 'NumberOfEmployees');
    Test.startTest();
    List<Object> issues = RHCBuilderQueryValidator.validate(values, 'QUERY');
    Test.stopTest();
    Assert.isTrue(
      JSON.serialize(issues).contains('TEXT_OPERATOR_REQUIRES_TEXT'),
      'A contains operator on a numeric field must be refused.'
    );
  }

  @IsTest
  static void shouldRejectDualQueryOperatorsOnASingleQueryCheck() {
    Map<String, Object> values = queryValues(VALID_QUERY);
    values.put('ComparisonOperator__c', 'LISTS_OVERLAP');
    Test.startTest();
    List<Object> issues = RHCBuilderQueryValidator.validate(values, 'QUERY');
    Test.stopTest();
    Assert.isTrue(
      JSON.serialize(issues).contains('CORE_INVALID_OPERATOR'),
      'A compare-two-queries operator must not be accepted on a single Query check.'
    );
  }

  @IsTest
  static void shouldRejectCompareAsListsWithoutAListOperator() {
    Map<String, Object> values = new Map<String, Object>{
      'SourceQuery__c' => 'SELECT Id FROM Account',
      'SourceQueryField__c' => 'Id',
      'ComparisonQuery__c' => 'SELECT Id FROM Contact',
      'ComparisonQueryField__c' => 'Id',
      'ComparisonOperator__c' => 'EQUALS',
      'QueryResultHandling__c' => 'COMPARE_AS_LISTS'
    };
    Test.startTest();
    List<Object> issues = RHCBuilderQueryValidator.validate(
      values,
      'COMPARE_TWO_QUERIES'
    );
    Test.stopTest();
    Assert.isTrue(
      JSON.serialize(issues).contains('CORE_INVALID_OPERATOR'),
      'Compare-as-lists requires a list operator.'
    );
  }

  @IsTest
  static void shouldRejectUnrecognizedResultHandlingForCompareTwoQueries() {
    Map<String, Object> values = new Map<String, Object>{
      'SourceQuery__c' => 'SELECT Id FROM Account',
      'SourceQueryField__c' => 'Id',
      'ComparisonQuery__c' => 'SELECT Id FROM Contact',
      'ComparisonQueryField__c' => 'Id',
      'ComparisonOperator__c' => 'EQUALS',
      'QueryResultHandling__c' => 'ANY_ROW_PASSES'
    };
    Test.startTest();
    List<Object> issues = RHCBuilderQueryValidator.validate(
      values,
      'COMPARE_TWO_QUERIES'
    );
    Test.stopTest();
    Assert.isTrue(
      JSON.serialize(issues).contains('CORE_INVALID_CONFIG'),
      'Compare two queries supports only ONE_RESULT or COMPARE_AS_LISTS.'
    );
  }

  @IsTest
  static void shouldTreatNullValueMapEntriesAsMissingRatherThanThrowing() {
    Map<String, Object> values = new Map<String, Object>{
      'SourceQuery__c' => null,
      'SourceQueryField__c' => null,
      'ComparisonOperator__c' => null,
      'QueryResultHandling__c' => null
    };
    Test.startTest();
    List<Object> issues = RHCBuilderQueryValidator.validate(values, 'QUERY');
    Test.stopTest();
    Assert.isTrue(
      issues.size() >= 3,
      'Null configuration must produce explicit required-field issues, not an exception.'
    );
    Assert.isTrue(
      JSON.serialize(issues).contains('CORE_MISSING_REQUIRED_FIELD'),
      'Missing query configuration must be reported as a required-field issue.'
    );
  }

  @IsTest
  static void shouldTreatNonStringValuesAsAbsent() {
    Map<String, Object> values = queryValues(VALID_QUERY);
    values.put('ComparisonOperator__c', 42);
    Test.startTest();
    List<Object> issues = RHCBuilderQueryValidator.validate(values, 'QUERY');
    Test.stopTest();
    Assert.isTrue(
      JSON.serialize(issues).contains('ComparisonOperator__c'),
      'A wrongly typed operator must be refused rather than coerced.'
    );
  }

  @IsTest
  static void shouldRejectAnAggregateApplicabilityQueryThatGroupsRows() {
    Test.startTest();
    Boolean grouped = RHCBuilderQueryValidator.isSingleCountQuery(
      'SELECT COUNT(Id) FROM Contact GROUP BY AccountId'
    );
    Boolean ungrouped = RHCBuilderQueryValidator.isSingleCountQuery(
      'SELECT COUNT(Id) FROM Contact'
    );
    Test.stopTest();
    Assert.isFalse(
      grouped,
      'A grouped count does not yield the single value applicability requires.'
    );
    Assert.isTrue(ungrouped, 'An ungrouped count is a single applicability value.');
  }

  @IsTest
  static void shouldRejectMalformedAndOversizedEnvelopes() {
    Map<String, String> hostileByLabel = new Map<String, String>{
      'unparseable json' => '{"schemaVersion":1,',
      'json array' => '[]',
      'empty string' => '',
      'bare scalar' => '"text"'
    };
    Test.startTest();
    for (String label : hostileByLabel.keySet()) {
      try {
        RHCBuilderFieldMapping.canonicalize(hostileByLabel.get(label));
        Assert.fail('Expected a MappingException for ' + label);
      } catch (RHCBuilderFieldMapping.MappingException error) {
        Assert.isTrue(
          String.isNotBlank(error.getMessage()),
          'The envelope refusal must carry an admin-facing message: ' + label
        );
      }
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectAnEnvelopeCarryingUnsupportedFields() {
    Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
      RHCBuilderTestDataFactory.validCanonicalVersion()
    );
    Map<String, Object> checkSet = (Map<String, Object>) envelope.get('checkSet');
    ((Map<String, Object>) checkSet.get('values')).put('Injected__c', 'value');
    Test.startTest();
    try {
      RHCBuilderFieldMapping.canonicalize(JSON.serialize(envelope));
      Assert.fail('Expected an unsupported-field refusal.');
    } catch (RHCBuilderFieldMapping.MappingException error) {
      Assert.isTrue(
        error.getMessage().contains('unsupported fields'),
        'An unknown field must be named as unsupported: ' + error.getMessage()
      );
      Assert.isFalse(
        error.getMessage().contains('Injected__c'),
        'The refusal must not echo the attacker-supplied field name.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldRejectAnEnvelopeWithNoChecks() {
    Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
      RHCBuilderTestDataFactory.validCanonicalVersion()
    );
    envelope.put('checks', new List<Object>());
    Test.startTest();
    try {
      RHCBuilderFieldMapping.canonicalize(JSON.serialize(envelope));
      Assert.fail('Expected a refusal for an empty Check list.');
    } catch (RHCBuilderFieldMapping.MappingException error) {
      Assert.isTrue(
        error.getMessage().contains('at least one Check'),
        'An empty version must be refused explicitly: ' + error.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void shouldCanonicalizeDeterministicallyRegardlessOfKeyOrder() {
    String canonical = RHCBuilderFieldMapping.canonicalize(
      RHCBuilderTestDataFactory.validCanonicalVersion()
    );
    Map<String, Object> reordered = (Map<String, Object>) JSON.deserializeUntyped(
      RHCBuilderTestDataFactory.validCanonicalVersion()
    );
    Map<String, Object> checkSet = (Map<String, Object>) reordered.get('checkSet');
    Map<String, Object> values = (Map<String, Object>) checkSet.get('values');
    Map<String, Object> shuffled = new Map<String, Object>();
    List<String> keys = new List<String>(values.keySet());
    keys.sort();
    for (Integer index = keys.size() - 1; index >= 0; index--) {
      shuffled.put(keys[index], values.get(keys[index]));
    }
    checkSet.put('values', shuffled);
    Test.startTest();
    String recanonicalized = RHCBuilderFieldMapping.canonicalize(
      JSON.serialize(reordered)
    );
    Test.stopTest();
    Assert.areEqual(
      canonical,
      recanonicalized,
      'Canonical output must be byte-identical so fingerprints stay stable.'
    );
  }

  @IsTest
  static void shouldDenyAuthoringToAUserWithoutTheBuilderPermission() {
    User restricted = RHCBuilderTestDataFactory.restrictedUser('authoring');
    Integer dmlBefore;
    Boolean denied = false;
    String message;
    Test.startTest();
    System.runAs(restricted) {
      dmlBefore = Limits.getDmlStatements();
      try {
        RHCBuilderController.getBuilderHome();
      } catch (AuraHandledException error) {
        denied = true;
        message = error.getMessage();
      }
      Assert.areEqual(
        dmlBefore,
        Limits.getDmlStatements(),
        'A denied authoring call must perform no DML.'
      );
    }
    Test.stopTest();
    Assert.isTrue(denied, 'A user without the Builder permission must be denied.');
    Assert.areEqual(
      'Record Health Check Builder authoring access is required.',
      message,
      'The denial must be the stable typed message, with no internals.'
    );
  }

  @IsTest
  static void shouldDenySavingToAUserWithoutTheBuilderPermission() {
    User restricted = RHCBuilderTestDataFactory.restrictedUser('saving');
    Integer versionsBefore = [
      SELECT COUNT()
      FROM Record_Health_Check_Set_Version__c
    ];
    Boolean denied = false;
    Test.startTest();
    System.runAs(restricted) {
      try {
        RHCBuilderController.saveCheckSetVersion(
          RHCBuilderTestDataFactory.validCanonicalVersion(),
          'key-denied'
        );
      } catch (AuraHandledException error) {
        denied = true;
      }
    }
    Test.stopTest();
    Assert.isTrue(denied, 'Saving must be denied without the Builder permission.');
    Assert.areEqual(
      versionsBefore,
      [SELECT COUNT() FROM Record_Health_Check_Set_Version__c],
      'A denied save must leave no version behind.'
    );
  }

  @IsTest
  static void shouldRejectAnOversizedIdempotencyKey() {
    RHCBuilderController.testAuthorAccess = true;
    Boolean rejected = false;
    String message;
    Test.startTest();
    try {
      RHCBuilderController.saveCheckSetVersion(
        RHCBuilderTestDataFactory.validCanonicalVersion(),
        'k'.repeat(81)
      );
    } catch (AuraHandledException error) {
      rejected = true;
      message = error.getMessage();
    }
    Test.stopTest();
    Assert.isTrue(rejected, 'An 81-character idempotency key must be refused.');
    Assert.isTrue(
      message.contains('80 characters or fewer'),
      'The refusal must state the boundary: ' + message
    );
  }

  @IsTest
  static void shouldRejectABlankIdempotencyKey() {
    RHCBuilderController.testAuthorAccess = true;
    Boolean rejected = false;
    Test.startTest();
    try {
      RHCBuilderController.saveCheckSetVersion(
        RHCBuilderTestDataFactory.validCanonicalVersion(),
        '   '
      );
    } catch (AuraHandledException error) {
      rejected = true;
    }
    Test.stopTest();
    Assert.isTrue(rejected, 'A blank idempotency key must be refused.');
  }

  @IsTest
  static void shouldKeepValidationQueryCountFlatAcrossAuthoringVolume() {
    List<Map<String, Object>> single = new List<Map<String, Object>>{
      queryValues(VALID_QUERY)
    };
    List<Map<String, Object>> many = new List<Map<String, Object>>();
    for (Integer index = 0; index < 251; index++) {
      many.add(queryValues(VALID_QUERY));
    }
    Test.startTest();
    Integer queriesBeforeSingle = Limits.getQueries();
    for (Map<String, Object> values : single) {
      RHCBuilderQueryValidator.validate(values, 'QUERY');
    }
    Integer singleCost = Limits.getQueries() - queriesBeforeSingle;
    Integer queriesBeforeMany = Limits.getQueries();
    for (Map<String, Object> values : many) {
      RHCBuilderQueryValidator.validate(values, 'QUERY');
    }
    Integer manyCost = Limits.getQueries() - queriesBeforeMany;
    Test.stopTest();
    Assert.areEqual(
      0,
      singleCost,
      'Query validation must be describe-only and issue no SOQL.'
    );
    Assert.areEqual(
      0,
      manyCost,
      'Validating 251 checks must not issue SOQL per check.'
    );
  }

  @IsTest
  static void shouldCanonicalizeManyChecksWithoutSoqlOrDml() {
    Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
      RHCBuilderTestDataFactory.validCanonicalVersion()
    );
    List<Object> checks = (List<Object>) envelope.get('checks');
    Map<String, Object> template = (Map<String, Object>) checks[0];
    List<Object> many = new List<Object>();
    for (Integer index = 0; index < 251; index++) {
      Map<String, Object> copy = (Map<String, Object>) JSON.deserializeUntyped(
        JSON.serialize(template)
      );
      copy.put('qualifiedApiName', 'Check_' + index);
      many.add(copy);
    }
    envelope.put('checks', many);
    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    Integer dmlBefore = Limits.getDmlStatements();
    String canonical = RHCBuilderFieldMapping.canonicalize(
      JSON.serialize(envelope)
    );
    Test.stopTest();
    Assert.areEqual(
      queriesBefore,
      Limits.getQueries(),
      'Canonicalizing 251 checks must issue no SOQL.'
    );
    Assert.areEqual(
      dmlBefore,
      Limits.getDmlStatements(),
      'Canonicalizing must perform no DML.'
    );
    Assert.isTrue(
      canonical.contains('Check_250'),
      'All 251 checks must survive canonicalization.'
    );
  }
}
