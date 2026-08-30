/** Analyzes whether active alert policies can receive canonical core Result events. */
// Public Custom Metadata has no object CRUD permission. Policy reads are explicitly USER_MODE.
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class RHCAlertsCoverageAnalyzer {
  /**
   * Reports interactive and programmatic event-publication coverage gaps for active policies.
   * @return Coverage gaps and contract guidance for active policies.
   */
  public static List<RHCAlertsCoreMetadataGateway.CoverageGap> analyzeCoverage() {
    List<Record_Health_Check_Alert_Policy__c> policies = [
      SELECT SelectionType__c, QualifiedApiName__c
      FROM Record_Health_Check_Alert_Policy__c
      WHERE Active__c = TRUE
      WITH USER_MODE
      ORDER BY QualifiedApiName__c
      LIMIT 2000
    ];
    return analyzePolicies(policies, activeChecksByName());
  }

  @TestVisible
  private static List<RHCAlertsCoreMetadataGateway.CoverageGap> analyzePolicies(
    List<Record_Health_Check_Alert_Policy__c> policies,
    Map<String, Record_Health_Check__mdt> checksByName
  ) {
    List<RHCAlertsCoreMetadataGateway.CoverageGap> gaps = new List<RHCAlertsCoreMetadataGateway.CoverageGap>();
    Map<String, Set<String>> policyNames = policyNames(policies);
    addCheckGaps(gaps, policyNames.get('CHECK'), checksByName);
    addCheckSetGaps(gaps, policyNames.get('CHECK_SET'), checksByName);
    addContractNotes(gaps, policies, policyNames.get('CHECK_SET'));
    return gaps;
  }

  private static Map<String, Set<String>> policyNames(
    List<Record_Health_Check_Alert_Policy__c> policies
  ) {
    Set<String> checkNames = new Set<String>();
    Set<String> setNames = new Set<String>();
    for (Record_Health_Check_Alert_Policy__c policy : policies) {
      if ('CHECK'.equals(policy.SelectionType__c)) {
        checkNames.add(policy.QualifiedApiName__c);
      }
      if ('CHECK_SET'.equals(policy.SelectionType__c)) {
        setNames.add(policy.QualifiedApiName__c);
      }
    }
    return new Map<String, Set<String>>{
      'CHECK' => checkNames,
      'CHECK_SET' => setNames
    };
  }

  private static Map<String, Record_Health_Check__mdt> activeChecksByName() {
    Map<String, Record_Health_Check__mdt> checksByName = new Map<String, Record_Health_Check__mdt>();
    for (Record_Health_Check__mdt item : [
      SELECT
        QualifiedApiName,
        PublishUserResultEvent__c,
        Record_Health_Check_Set__r.QualifiedApiName
      FROM Record_Health_Check__mdt
      WHERE IsActive__c = TRUE
      LIMIT 5000
    ]) {
      checksByName.put(item.QualifiedApiName, item);
    }
    return checksByName;
  }

  private static void addCheckGaps(
    List<RHCAlertsCoreMetadataGateway.CoverageGap> gaps,
    Set<String> checkNames,
    Map<String, Record_Health_Check__mdt> checksByName
  ) {
    for (String checkName : checkNames) {
      Record_Health_Check__mdt item = checksByName.get(checkName);
      if (item == null) {
        gaps.add(
          gap(
            'ERROR',
            'DEFINITION_NOT_FOUND',
            'Active Check policy does not exactly match an active core Check: ' +
            checkName
          )
        );
      } else if (item.PublishUserResultEvent__c != true) {
        gaps.add(
          gap(
            'WARNING',
            'INTERACTIVE_RESULT_DISABLED',
            'User-initiated runs do not publish Result events for Check: ' +
            checkName
          )
        );
      }
    }
  }

  private static void addCheckSetGaps(
    List<RHCAlertsCoreMetadataGateway.CoverageGap> gaps,
    Set<String> setNames,
    Map<String, Record_Health_Check__mdt> checksByName
  ) {
    for (String setName : setNames) {
      Integer activeCount = 0;
      Integer enabledCount = 0;
      for (Record_Health_Check__mdt item : checksByName.values()) {
        if (item.Record_Health_Check_Set__r?.QualifiedApiName == setName) {
          activeCount++;
          if (item.PublishUserResultEvent__c == true) {
            enabledCount++;
          }
        }
      }
      if (activeCount == 0) {
        gaps.add(
          gap(
            'ERROR',
            'CHECK_SET_NOT_FOUND',
            'Active Check Set policy has no active matching Checks: ' + setName
          )
        );
      } else if (enabledCount < activeCount) {
        gaps.add(
          gap(
            'WARNING',
            'CHECK_SET_RESULT_GAP',
            'Check Set policy requires Result publication; ' +
              (activeCount - enabledCount) +
              ' of ' +
              activeCount +
              ' active Checks are disabled for user-initiated Result publication: ' +
              setName
          )
        );
      }
    }
  }

  private static void addContractNotes(
    List<RHCAlertsCoreMetadataGateway.CoverageGap> gaps,
    List<Record_Health_Check_Alert_Policy__c> policies,
    Set<String> setNames
  ) {
    if (!policies.isEmpty()) {
      gaps.add(
        gap(
          'INFO',
          'PROGRAMMATIC_CALLER_CHOICE',
          'Apex, Flow, Batch, Queueable, and Scheduled callers must request ACTIONABLE or ALL. Publication NONE is invisible to RHC Alerts.'
        )
      );
    }
    if (!setNames.isEmpty()) {
      gaps.add(
        gap(
          'INFO',
          'SET_RUN_CONTRACT_1_0',
          'Set Run contract 1.0 has no canonical severity. Check Set alert status and severity matching therefore uses Result events; Set Run events are recorded as suppressed contract gaps.'
        )
      );
    }
  }

  private static RHCAlertsCoreMetadataGateway.CoverageGap gap(
    String severity,
    String code,
    String message
  ) {
    RHCAlertsCoreMetadataGateway.CoverageGap result = new RHCAlertsCoreMetadataGateway.CoverageGap();
    result.severity = severity;
    result.code = code;
    result.message = message;
    return result;
  }
}
