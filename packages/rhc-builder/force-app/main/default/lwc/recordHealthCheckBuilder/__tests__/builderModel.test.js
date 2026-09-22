import {
  diffVersions,
  buildCanonicalVersion,
  applyCardExperience,
  apiNameFromLabel,
  createCheck,
  createDraft,
  describeCardExperience,
  draftFromVersion,
  inferCardExperience,
  validateLocalDraft,
} from "../builderModel";

describe("builderModel", () => {
  it.each([
    ["FORMULA", "PassConditionFormula__c"],
    ["QUERY", "SourceQuery__c"],
    ["COMPARE_TWO_QUERIES", "ComparisonQuery__c"],
    ["APEX", "ApexClass__c"],
  ])("maps the %s path to exact core fields", (evaluationType, fieldName) => {
    const contract = { schemaVersion: 1, contractVersion: "1.0" };
    const draft = createDraft(contract);
    draft.checkSetQualifiedApiName = "pkg__Set";
    draft.checkSetLabel = "Set";
    draft.objectApiName = "Account";
    const check = createCheck(contract);
    check.qualifiedApiName = `pkg__${evaluationType}_Check`;
    check.label = `${evaluationType} Check`;
    check.evaluationType = evaluationType;
    check.values[fieldName] = "exact value";
    draft.checks = [check];

    const version = buildCanonicalVersion(draft);

    expect(version.checks[0].qualifiedApiName).toBe(
      `pkg__${evaluationType}_Check`,
    );
    expect(version.checks[0].values[fieldName]).toBe("exact value");
    expect(version.checks[0].values.IsActive__c).toBe(false);
  });

  it("clears fields owned by a discarded evaluation branch", () => {
    const contract = { schemaVersion: 1, contractVersion: "1.0" };
    const draft = createDraft(contract);
    draft.checkSetQualifiedApiName = "pkg__Set";
    draft.checkSetLabel = "Set";
    draft.objectApiName = "Account";
    const check = createCheck(contract);
    check.qualifiedApiName = "pkg__Apex_Check";
    check.label = "Apex Check";
    check.evaluationType = "APEX";
    check.values.ApexClass__c = "pkg.Plugin";
    check.values.SourceQuery__c = "SELECT Id FROM Contact";
    draft.checks = [check];

    const version = buildCanonicalVersion(draft);

    expect(version.checks[0].values.ApexClass__c).toBe("pkg.Plugin");
    expect(version.checks[0].values.SourceQuery__c).toBeUndefined();
  });

  it("generates a safe editable API name without inventing a namespace", () => {
    expect(apiNameFromLabel("  2026 Account readiness! ")).toBe(
      "X_2026_Account_readiness",
    );
  });

  it("copies a complete immutable version back to an inactive draft", () => {
    const version = {
      schemaVersion: 1,
      contractVersion: "1.0",
      checkSet: {
        qualifiedApiName: "pkg__Readiness",
        label: "Readiness",
        values: { ObjectApiName__c: "Account", IsActive__c: true },
      },
      checks: [
        {
          qualifiedApiName: "pkg__Has_Name",
          label: "Has Name",
          values: {
            EvaluationType__c: "FORMULA",
            EvaluationOrder__c: 10,
            IsActive__c: true,
          },
        },
      ],
    };

    const draft = draftFromVersion(version);

    expect(draft.checkSetQualifiedApiName).toBe("pkg__Readiness");
    expect(draft.checkSetValues.IsActive__c).toBe(false);
    expect(draft.checks[0].values.IsActive__c).toBe(false);
  });

  it("applies and recognizes the compact card experience", () => {
    const values = applyCardExperience({ IsActive__c: false }, "COMPACT");

    expect(values.PassedChecksDisplay__c).toBe("SHOW_COUNT_ONLY");
    expect(values.SummaryDisplay__c).toBe("TOP");
    expect(inferCardExperience(values)).toBe("COMPACT");
    expect(describeCardExperience(values)).toContain(
      "Passed rows are summarized as a count",
    );
  });

  it("recognizes a modified preset as Custom", () => {
    const values = applyCardExperience({}, "USER_CONTROLLED");
    values.RunButtonDisplay__c = "LABEL_ONLY";

    expect(inferCardExperience(values)).toBe("CUSTOM");
  });

  it("rejects a hidden Run action for a user-request Check Set", () => {
    const draft = createDraft({
      defaults: {
        checkSet: {
          CardRunMode__c: "RUN_ON_REQUEST",
          RunButtonDisplay__c: "HIDE",
        },
      },
    });

    expect(validateLocalDraft(draft)).toContain(
      "Keep a Run action visible when the Check Set waits for the user.",
    );
  });

  it("diffs two versions by check identity and changed field names", () => {
    const base = {
      checkSet: { values: { CardTitle__c: "A", IsActive__c: true } },
      checks: [
        { qualifiedApiName: "Keep", values: { EvaluationOrder__c: 10, FailureSeverity__c: "WARNING" } },
        { qualifiedApiName: "Gone", values: { EvaluationOrder__c: 20 } }
      ]
    };
    const target = {
      checkSet: { values: { CardTitle__c: "B", IsActive__c: true } },
      checks: [
        { qualifiedApiName: "Keep", values: { EvaluationOrder__c: 10, FailureSeverity__c: "ERROR" } },
        { qualifiedApiName: "New", values: { EvaluationOrder__c: 30 } }
      ]
    };
    const diff = diffVersions(base, target);
    expect(diff.added).toEqual(["New"]);
    expect(diff.removed).toEqual(["Gone"]);
    expect(diff.changed).toEqual([{ qualifiedApiName: "Keep", fields: ["FailureSeverity__c"] }]);
    expect(diff.checkSetFields).toEqual(["CardTitle__c"]);
    expect(diff.isEmpty).toBe(false);
    expect(diffVersions(base, base).isEmpty).toBe(true);
  });
});
