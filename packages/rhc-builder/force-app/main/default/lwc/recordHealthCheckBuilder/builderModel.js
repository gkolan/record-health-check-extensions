const COMMON_CHECK_FIELDS = Object.freeze([
  "CheckDescription__c",
  "Category__c",
  "FailureMessage__c",
  "FailureSeverity__c",
  "FixMessage__c",
  "UnableToEvaluateMessage__c",
  "ActionLabel__c",
  "ActionUrl__c",
  "PublishUserResultEvent__c",
  "PrerequisiteCheck__c",
  "ApplicabilityMode__c",
  "ApplicabilityFormula__c",
  "ApplicabilityCountQuery__c",
  "ApplicabilityCountOperator__c",
  "ApplicabilityCountThreshold__c",
  "ApplicabilityNotMetMessage__c",
]);

const TYPE_FIELDS = Object.freeze({
  FORMULA: [
    "PassConditionFormula__c",
    "DisplayFoundFormula__c",
    "DisplayExpectedFormula__c",
    "FormulaResultType__c",
    "DisplayValueFormat__c",
    "DisplayFoundText__c",
    "DisplayExpectedText__c",
  ],
  QUERY: [
    "SourceQuery__c",
    "SourceQueryField__c",
    "QueryResultHandling__c",
    "ComparisonOperator__c",
    "ExpectedValueSource__c",
    "ExpectedFixedValue__c",
    "ExpectedRecordFormula__c",
    "ComparisonQuery__c",
    "ComparisonQueryField__c",
    "NoRowsResult__c",
    "EmptyValueHandling__c",
    "MaxQueryRows__c",
    "ExpectedCurrencyIsoCode__c",
    "FindInListFormula__c",
    "FormulaResultType__c",
    "DisplayValueFormat__c",
    "DisplayFoundText__c",
    "DisplayExpectedText__c",
  ],
  COMPARE_TWO_QUERIES: [
    "SourceQuery__c",
    "SourceQueryField__c",
    "ComparisonQuery__c",
    "ComparisonQueryField__c",
    "QueryResultHandling__c",
    "ComparisonOperator__c",
    "NoRowsResult__c",
    "EmptyValueHandling__c",
    "MaxQueryRows__c",
    "FormulaResultType__c",
    "DisplayValueFormat__c",
    "DisplayFoundText__c",
    "DisplayExpectedText__c",
  ],
  APEX: ["ApexClass__c", "ApexParametersJson__c"],
});

const CARD_EXPERIENCE_FIELDS = Object.freeze([
  "CardRunMode__c",
  "RunButtonDisplay__c",
  "RunButtonLabel__c",
  "RerunButtonLabel__c",
  "RunButtonIcon__c",
  "CardRevealMode__c",
  "FoundExpectedDisplay__c",
  "PassedChecksDisplay__c",
  "SkippedChecksDisplay__c",
  "SummaryDisplay__c",
]);

export const CARD_EXPERIENCE_PRESETS = Object.freeze({
  USER_CONTROLLED: Object.freeze({
    CardRunMode__c: "RUN_ON_REQUEST",
    RunButtonDisplay__c: "LABEL_AND_ICON",
    RunButtonLabel__c: "Run Checks",
    RerunButtonLabel__c: "Run Again",
    RunButtonIcon__c: "utility:check",
    CardRevealMode__c: "ALL_AT_ONCE",
    FoundExpectedDisplay__c: "ON_DEMAND",
    PassedChecksDisplay__c: "SHOW_EACH_CHECK",
    SkippedChecksDisplay__c: "SHOW_EACH_CHECK",
    SummaryDisplay__c: "BOTTOM",
  }),
  AUTOMATIC: Object.freeze({
    CardRunMode__c: "RUN_ON_LOAD",
    RunButtonDisplay__c: "LABEL_AND_ICON",
    RunButtonLabel__c: "Run Checks",
    RerunButtonLabel__c: "Run Again",
    RunButtonIcon__c: "utility:check",
    CardRevealMode__c: "ALL_AT_ONCE",
    FoundExpectedDisplay__c: "ON_DEMAND",
    PassedChecksDisplay__c: "SHOW_EACH_CHECK",
    SkippedChecksDisplay__c: "SHOW_EACH_CHECK",
    SummaryDisplay__c: "BOTTOM",
  }),
  GUIDED: Object.freeze({
    CardRunMode__c: "RUN_ON_REQUEST",
    RunButtonDisplay__c: "LABEL_AND_ICON",
    RunButtonLabel__c: "Run Checks",
    RerunButtonLabel__c: "Run Again",
    RunButtonIcon__c: "utility:check",
    CardRevealMode__c: "ONE_BY_ONE",
    FoundExpectedDisplay__c: "ON_DEMAND",
    PassedChecksDisplay__c: "SHOW_EACH_CHECK",
    SkippedChecksDisplay__c: "SHOW_EACH_CHECK",
    SummaryDisplay__c: "BOTTOM",
  }),
  COMPACT: Object.freeze({
    CardRunMode__c: "RUN_ON_REQUEST",
    RunButtonDisplay__c: "LABEL_AND_ICON",
    RunButtonLabel__c: "Run Checks",
    RerunButtonLabel__c: "Run Again",
    RunButtonIcon__c: "utility:check",
    CardRevealMode__c: "ALL_AT_ONCE",
    FoundExpectedDisplay__c: "FAILURES_ONLY",
    PassedChecksDisplay__c: "SHOW_COUNT_ONLY",
    SkippedChecksDisplay__c: "SHOW_COUNT_ONLY",
    SummaryDisplay__c: "TOP",
  }),
});

export function applyCardExperience(values = {}, experience) {
  const preset = CARD_EXPERIENCE_PRESETS[experience];
  return preset ? { ...values, ...preset } : { ...values };
}

export function inferCardExperience(values = {}) {
  return (
    Object.entries(CARD_EXPERIENCE_PRESETS).find(([, preset]) =>
      CARD_EXPERIENCE_FIELDS.every((field) => values[field] === preset[field]),
    )?.[0] || "CUSTOM"
  );
}

export function describeCardExperience(values = {}) {
  const starts =
    values.CardRunMode__c === "RUN_ON_LOAD"
      ? "Checks run when the page opens"
      : "Users start this Check Set themselves";
  const reveal =
    values.CardRevealMode__c === "ONE_BY_ONE"
      ? "results appear one Check at a time"
      : "all result rows appear together";
  const rows = [];
  if (values.PassedChecksDisplay__c === "SHOW_COUNT_ONLY") {
    rows.push("passed rows are summarized as a count");
  } else {
    rows.push("passed Checks remain visible");
  }
  if (values.SkippedChecksDisplay__c === "SHOW_COUNT_ONLY") {
    rows.push("skipped rows are summarized as a count");
  } else {
    rows.push("skipped Checks remain visible");
  }
  const summary =
    values.SummaryDisplay__c === "TOP"
      ? "The summary appears above the results"
      : "The summary appears below the results";
  const comparisons = {
    ON_DEMAND:
      "Found and expected values are available on demand and appear inline on failures.",
    FAILURES_ONLY:
      "Found and expected values appear only for failed Checks when available.",
    ALL_ROWS:
      "Found and expected values appear inline for every Check that provides them.",
  };
  return `${starts}; ${reveal}. ${capitalize(rows.join("; "))}. ${summary}. ${
    comparisons[values.FoundExpectedDisplay__c] || comparisons.ON_DEMAND
  }`;
}

export function createDraft(contract = {}) {
  return {
    schemaVersion: contract.schemaVersion,
    contractVersion: contract.contractVersion,
    checkSetQualifiedApiName: "",
    checkSetLabel: "",
    objectApiName: "",
    checkSetValues: { ...(contract.defaults?.checkSet || {}) },
    checks: [],
  };
}

export function createCheck(contract = {}, evaluationOrder = 10) {
  return {
    qualifiedApiName: "",
    label: "",
    evaluationType: "",
    evaluationOrder,
    values: { ...(contract.defaults?.check || {}) },
  };
}

export function toOptions(values = []) {
  return values.map((entry) =>
    typeof entry === "string"
      ? { label: entry, value: entry }
      : { label: entry.label || entry.value, value: entry.value },
  );
}

export function apiNameFromLabel(label = "") {
  return label
    .trim()
    .replace(/[^A-Za-z0-9_]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/^([0-9])/, "X_$1")
    .slice(0, 80);
}

export function draftFromVersion(version) {
  const checkSet = version.checkSet;
  return {
    schemaVersion: version.schemaVersion,
    contractVersion: version.contractVersion,
    checkSetQualifiedApiName: checkSet.qualifiedApiName,
    checkSetLabel: checkSet.label,
    objectApiName: checkSet.values.ObjectApiName__c,
    checkSetValues: { ...checkSet.values, IsActive__c: false },
    checks: version.checks.map((check, index) => ({
      qualifiedApiName: check.qualifiedApiName,
      label: check.label,
      evaluationType: check.values.EvaluationType__c,
      evaluationOrder: check.values.EvaluationOrder__c || (index + 1) * 10,
      values: { ...check.values, IsActive__c: false },
    })),
  };
}

export function buildCanonicalVersion(draft) {
  const setValues = compact({
    ...draft.checkSetValues,
    CardTitle__c: draft.checkSetLabel,
    ObjectApiName__c: draft.objectApiName,
    IsActive__c: false,
  });
  return {
    schemaVersion: draft.schemaVersion,
    contractVersion: draft.contractVersion,
    checkSet: {
      qualifiedApiName: draft.checkSetQualifiedApiName,
      label: draft.checkSetLabel,
      values: setValues,
    },
    checks: draft.checks.map((check, index) => {
      const selectedFields = [
        ...COMMON_CHECK_FIELDS,
        ...(TYPE_FIELDS[check.evaluationType] || []),
      ];
      const values = {
        Record_Health_Check_Set__c: draft.checkSetQualifiedApiName,
        CheckTitle__c: check.label,
        EvaluationType__c: check.evaluationType,
        EvaluationOrder__c: (index + 1) * 10,
        IsActive__c: false,
      };
      selectedFields.forEach((fieldName) => {
        if (Object.prototype.hasOwnProperty.call(check.values, fieldName)) {
          values[fieldName] = check.values[fieldName];
        }
      });
      return {
        qualifiedApiName: check.qualifiedApiName,
        label: check.label,
        values: compact(values),
      };
    }),
  };
}

export function validateLocalDraft(draft) {
  const errors = [];
  if (!draft.checkSetLabel.trim()) errors.push("Name the Check Set.");
  if (!draft.checkSetQualifiedApiName.trim())
    errors.push("Provide the exact Check Set Qualified API Name.");
  if (!draft.objectApiName) errors.push("Choose a target object.");
  if (
    draft.checkSetValues.CardRunMode__c === "RUN_ON_REQUEST" &&
    draft.checkSetValues.RunButtonDisplay__c === "HIDE"
  ) {
    errors.push(
      "Keep a Run action visible when the Check Set waits for the user.",
    );
  }
  if (!draft.checks.length) errors.push("Add at least one Check.");
  const qualifiedNames = new Set();
  draft.checks.forEach((check, index) => {
    const prefix = `Check ${index + 1}: `;
    if (!check.label.trim()) errors.push(`${prefix}state what should be true.`);
    if (!check.qualifiedApiName.trim())
      errors.push(`${prefix}provide the exact Qualified API Name.`);
    if (!check.evaluationType)
      errors.push(`${prefix}choose an evaluation type.`);
    if (qualifiedNames.has(check.qualifiedApiName))
      errors.push(`${prefix}Qualified API Name must be unique.`);
    qualifiedNames.add(check.qualifiedApiName);
  });
  return errors;
}

function capitalize(value) {
  return value ? `${value[0].toUpperCase()}${value.slice(1)}` : value;
}

function compact(values) {
  return Object.fromEntries(
    Object.entries(values).filter(
      ([, value]) => value !== undefined && value !== null && value !== "",
    ),
  );
}
