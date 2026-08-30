import { createElement } from "lwc";
import RecordHealthCheckBuilder from "c/recordHealthCheckBuilder";
import LightningConfirm from "lightning/confirm";
import getAuthoringContract from "@salesforce/apex/RHCBuilderController.getAuthoringContract";
import getBuilderHome from "@salesforce/apex/RHCBuilderController.getBuilderHome";
import listReadableObjects from "@salesforce/apex/RHCBuilderController.listReadableObjects";
import listReadableFields from "@salesforce/apex/RHCBuilderController.listReadableFields";
import listReadableRelationships from "@salesforce/apex/RHCBuilderController.listReadableRelationships";
import getCheckSetVersion from "@salesforce/apex/RHCBuilderController.getCheckSetVersion";
import validateCheckSetVersion from "@salesforce/apex/RHCBuilderController.validateCheckSetVersion";
import saveCheckSetVersion from "@salesforce/apex/RHCBuilderController.saveCheckSetVersion";
import publishCheckSetVersion from "@salesforce/apex/RHCBuilderController.publishCheckSetVersion";

jest.mock("lightning/confirm", () => ({ open: jest.fn() }), {
  virtual: true,
});
jest.mock(
  "@salesforce/customPermission/RHC_Builder_Author",
  () => ({ default: true }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.getAuthoringContract",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.getBuilderHome",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.listReadableObjects",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.listReadableFields",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.listReadableRelationships",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.validateCheckSetVersion",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.saveCheckSetVersion",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.publishCheckSetVersion",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.activateCheckSetVersion",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.rollbackToCheckSetVersion",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCBuilderController.getCheckSetVersion",
  () => ({ default: jest.fn() }),
  { virtual: true },
);

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
};

const findButton = (element, label) =>
  [...element.shadowRoot.querySelectorAll("lightning-button")].find(
    (button) => button.label === label,
  );

const change = (element, selector, value) => {
  const control = element.shadowRoot.querySelector(selector);
  control.value = value;
  control.dispatchEvent(new CustomEvent("change", { detail: { value } }));
};

const createBuilder = async () => {
  const element = createElement("c-record-health-check-builder", {
    is: RecordHealthCheckBuilder,
  });
  document.body.appendChild(element);
  await flushPromises();
  return element;
};

const completeFormulaDraft = async (element) => {
  change(
    element,
    'lightning-input[data-field="checkSetLabel"]',
    "Account Readiness",
  );
  change(element, 'lightning-combobox[data-field="objectApiName"]', "Account");
  findButton(element, "Add Check").click();
  await flushPromises();
  change(element, 'lightning-input[data-field="label"]', "Name is present");
  change(
    element,
    'lightning-combobox[data-field="EvaluationType__c"]',
    "FORMULA",
  );
  await flushPromises();
  change(
    element,
    'lightning-textarea[data-field="PassConditionFormula__c"]',
    "NOT(ISBLANK(Name))",
  );
  change(
    element,
    'lightning-textarea[data-field="FailureMessage__c"]',
    "Add an Account Name.",
  );
};

describe("c-record-health-check-builder", () => {
  beforeEach(() => {
    getAuthoringContract.mockResolvedValue({
      schemaVersion: 1,
      contractVersion: "1.0",
      evaluationTypes: ["FORMULA", "QUERY", "COMPARE_TWO_QUERIES", "APEX"],
      allowedValues: {
        FailureSeverity__c: ["CRITICAL", "WARNING", "INFO"],
        CardRunMode__c: ["RUN_ON_REQUEST", "RUN_ON_LOAD"],
        RunButtonDisplay__c: [
          "LABEL_AND_ICON",
          "LABEL_ONLY",
          "ICON_ONLY",
          "HIDE",
        ],
        CardRevealMode__c: ["ALL_AT_ONCE", "ONE_BY_ONE"],
        FoundExpectedDisplay__c: ["ON_DEMAND", "FAILURES_ONLY", "ALL_ROWS"],
        PassedChecksDisplay__c: ["SHOW_EACH_CHECK", "SHOW_COUNT_ONLY"],
        SkippedChecksDisplay__c: ["SHOW_EACH_CHECK", "SHOW_COUNT_ONLY"],
        SummaryDisplay__c: ["TOP", "BOTTOM"],
        ComparisonOperator__c: ["EQUALS"],
        ExpectedValueSource__c: ["FIXED_VALUE"],
      },
      defaults: {
        checkSet: {
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
        },
        check: {},
      },
    });
    listReadableObjects.mockResolvedValue([
      { label: "Account — Account", value: "Account" },
    ]);
    listReadableFields.mockResolvedValue([
      { label: "Account Name — Name", value: "Name", dataType: "STRING" },
    ]);
    listReadableRelationships.mockResolvedValue([
      {
        label: "Contacts — Contacts",
        value: "Contact.AccountId",
        childObjectApiName: "Contact",
        parentFieldApiName: "AccountId",
      },
    ]);
    getBuilderHome.mockResolvedValue({ versions: [], recentOperations: [] });
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("loads Builder-owned options and the describe-backed object picker", async () => {
    const element = await createBuilder();

    expect(getAuthoringContract).toHaveBeenCalledTimes(1);
    expect(listReadableObjects).toHaveBeenCalledTimes(1);
    expect(
      element.shadowRoot.querySelector(
        'lightning-combobox[data-field="objectApiName"]',
      ),
    ).not.toBeNull();
    expect(element.shadowRoot.textContent).toContain(
      "Builder keeps the Check Set and every Check together as one version",
    );
  });

  it("generates an editable Qualified API Name from the Check Set name", async () => {
    const element = await createBuilder();

    const nameInput = element.shadowRoot.querySelector(
      'lightning-input[data-field="checkSetLabel"]',
    );
    nameInput.value = "Account Readiness 2026";
    nameInput.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(
        'lightning-input[data-field="checkSetQualifiedApiName"]',
      ).value,
    ).toBe("Account_Readiness_2026");
  });

  it("starts with the recommended user-controlled card experience", async () => {
    const element = await createBuilder();
    const selected = element.shadowRoot.querySelector(
      'input[name="card-experience"]:checked',
    );

    expect(selected.value).toBe("USER_CONTROLLED");
    expect(element.shadowRoot.textContent).toContain(
      "Users start this Check Set themselves",
    );
  });

  it("renders the experience cards as one native keyboard radio group", async () => {
    const element = await createBuilder();
    const radios = [
      ...element.shadowRoot.querySelectorAll('input[name="card-experience"]'),
    ];

    expect(radios).toHaveLength(5);
    expect(radios.filter((radio) => radio.checked)).toHaveLength(1);
    radios.forEach((radio) => {
      expect(radio.type).toBe("radio");
      expect(radio.getAttribute("aria-describedby")).toBeTruthy();
      expect(
        element.shadowRoot.querySelector(`label[for="${radio.id}"]`),
      ).not.toBeNull();
    });
  });

  it("applies the compact preset and explains its consequences", async () => {
    const element = await createBuilder();
    const compact = element.shadowRoot.querySelector(
      'input[name="card-experience"][value="COMPACT"]',
    );
    compact.click();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "Passed rows are summarized as a count",
    );
    findButton(element, "Continue to validation").click();
    await flushPromises();
    expect(element.shadowRoot.textContent).toContain("Compact exception view");
    expect(element.shadowRoot.textContent).toContain(
      "The summary appears above the results",
    );
  });

  it("previews before-run, running, and completed example states", async () => {
    const element = await createBuilder();

    findButton(element, "Before run").click();
    await flushPromises();
    expect(element.shadowRoot.textContent).toContain(
      "No example checks have run yet",
    );
    expect(
      element.shadowRoot.querySelectorAll(".rhc-builder-preview-row"),
    ).toHaveLength(0);

    findButton(element, "Running").click();
    await flushPromises();
    expect(element.shadowRoot.textContent).toContain(
      "Example evaluation in progress",
    );
    expect(
      element.shadowRoot.querySelectorAll(".rhc-builder-preview-row"),
    ).toHaveLength(3);

    findButton(element, "Completed").click();
    await flushPromises();
    expect(element.shadowRoot.textContent).toContain(
      "Example evaluation completed",
    );
  });

  it("previews compact results with only the failed row visible", async () => {
    const element = await createBuilder();
    element.shadowRoot
      .querySelector('input[name="card-experience"][value="COMPACT"]')
      .click();
    await flushPromises();

    const rows = element.shadowRoot.querySelectorAll(
      ".rhc-builder-preview-row",
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].textContent).toContain("Primary Contact is assigned");
    expect(element.shadowRoot.textContent).toContain(
      "Passed and skipped details are hidden",
    );
  });

  it("preserves preset values when opening Custom and replaces them on a new preset", async () => {
    const element = await createBuilder();
    element.shadowRoot
      .querySelector('input[name="card-experience"][value="GUIDED"]')
      .click();
    await flushPromises();
    element.shadowRoot
      .querySelector('input[name="card-experience"][value="CUSTOM"]')
      .click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(
        'lightning-combobox[data-field="CardRevealMode__c"]',
      ).value,
    ).toBe("ONE_BY_ONE");

    change(
      element,
      'lightning-combobox[data-field="RunButtonDisplay__c"]',
      "LABEL_ONLY",
    );
    element.shadowRoot
      .querySelector('input[name="card-experience"][value="USER_CONTROLLED"]')
      .click();
    await flushPromises();
    element.shadowRoot
      .querySelector('input[name="card-experience"][value="CUSTOM"]')
      .click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(
        'lightning-combobox[data-field="RunButtonDisplay__c"]',
      ).value,
    ).toBe("LABEL_AND_ICON");
  });

  it("shows Custom controls and blocks a hidden manual Run action", async () => {
    const element = await createBuilder();
    const custom = element.shadowRoot.querySelector(
      'input[name="card-experience"][value="CUSTOM"]',
    );
    custom.click();
    await flushPromises();

    change(
      element,
      'lightning-combobox[data-field="RunButtonDisplay__c"]',
      "HIDE",
    );
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "Keep a Run action visible",
    );
    findButton(element, "Continue to validation").click();
    await flushPromises();
    findButton(element, "Validate complete version").click();
    await flushPromises();
    expect(validateCheckSetVersion).not.toHaveBeenCalled();
    expect(element.shadowRoot.textContent).toContain(
      "Keep a Run action visible when the Check Set waits for the user",
    );
  });

  it("warns when an automatic Custom experience hides the rerun action", async () => {
    const element = await createBuilder();
    element.shadowRoot
      .querySelector('input[name="card-experience"][value="CUSTOM"]')
      .click();
    await flushPromises();
    change(
      element,
      'lightning-combobox[data-field="CardRunMode__c"]',
      "RUN_ON_LOAD",
    );
    change(
      element,
      'lightning-combobox[data-field="RunButtonDisplay__c"]',
      "HIDE",
    );
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "Users cannot rerun from this card",
    );
    expect(element.shadowRoot.textContent).not.toContain(
      "Keep a Run action visible.",
    );
  });

  it("moves from design to complete-version validation", async () => {
    const element = await createBuilder();

    const continueButton = findButton(element, "Continue to validation");
    continueButton.click();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Validate and review");
    expect(element.shadowRoot.textContent).toContain(
      "Checks cannot be saved or published independently",
    );
  });

  it("shows local errors without calling Apex for an incomplete version", async () => {
    const element = await createBuilder();
    findButton(element, "Continue to validation").click();
    await flushPromises();

    findButton(element, "Validate complete version").click();
    await flushPromises();

    expect(validateCheckSetVersion).not.toHaveBeenCalled();
    expect(element.shadowRoot.textContent).toContain("Name the Check Set");
    expect(element.shadowRoot.textContent).toContain("Add at least one Check");
  });

  it("generates bounded SOQL from a describe-backed relationship", async () => {
    const element = await createBuilder();
    change(
      element,
      'lightning-combobox[data-field="objectApiName"]',
      "Account",
    );
    await flushPromises();
    findButton(element, "Add Check").click();
    await flushPromises();
    change(
      element,
      'lightning-combobox[data-field="EvaluationType__c"]',
      "QUERY",
    );
    await flushPromises();
    change(
      element,
      'lightning-combobox[data-field="relationshipSelection"]',
      "Contact.AccountId",
    );
    await flushPromises();

    expect(listReadableRelationships).toHaveBeenCalledWith({
      objectApiName: "Account",
    });
    const advanced = element.shadowRoot.querySelector("details");
    expect(advanced.textContent).toContain("Advanced query settings");
    expect(
      advanced.querySelector('lightning-textarea[data-field="SourceQuery__c"]')
        .value,
    ).toBe("SELECT Id FROM Contact WHERE AccountId = {!record.Id} LIMIT 1");
  });

  it("generates a formula from a describe-backed field condition", async () => {
    const element = await createBuilder();
    change(
      element,
      'lightning-combobox[data-field="objectApiName"]',
      "Account",
    );
    await flushPromises();
    findButton(element, "Add Check").click();
    await flushPromises();
    change(
      element,
      'lightning-combobox[data-field="EvaluationType__c"]',
      "FORMULA",
    );
    await flushPromises();
    change(
      element,
      'lightning-combobox[data-field="formulaFieldApiName"]',
      "Name",
    );
    change(
      element,
      'lightning-radio-group[data-field="formulaRule"]',
      "PRESENT",
    );
    await flushPromises();

    expect(listReadableFields).toHaveBeenCalledWith({
      objectApiName: "Account",
    });
    expect(
      element.shadowRoot.querySelector(
        'lightning-textarea[data-field="PassConditionFormula__c"]',
      ).value,
    ).toBe("NOT(ISBLANK(Name))");
  });

  it("explains that only the newly selected evaluation type is saved", async () => {
    const element = await createBuilder();
    findButton(element, "Add Check").click();
    await flushPromises();
    change(
      element,
      'lightning-combobox[data-field="EvaluationType__c"]',
      "FORMULA",
    );
    change(
      element,
      'lightning-combobox[data-field="EvaluationType__c"]',
      "QUERY",
    );
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "Only the selected evaluation type's settings will be saved",
    );
    expect(element.shadowRoot.textContent).toContain(
      "Advanced query settings — bounded SOQL required",
    );
  });

  it("validates and saves one complete version", async () => {
    validateCheckSetVersion.mockResolvedValue({ isValid: true, issues: [] });
    saveCheckSetVersion.mockResolvedValue({
      resultSummary: "Check Set Version 1 saved and validated.",
    });
    const element = await createBuilder();
    await completeFormulaDraft(element);
    findButton(element, "Continue to validation").click();
    await flushPromises();

    findButton(element, "Validate complete version").click();
    await flushPromises();
    findButton(element, "Save validated version").click();
    await flushPromises();
    await flushPromises();

    expect(validateCheckSetVersion).toHaveBeenCalledTimes(1);
    expect(saveCheckSetVersion).toHaveBeenCalledTimes(1);
    expect(element.shadowRoot.textContent).toContain("Publish and monitor");
  });

  it("invalidates a successful validation when the draft changes", async () => {
    validateCheckSetVersion.mockResolvedValue({ isValid: true, issues: [] });
    const element = await createBuilder();
    await completeFormulaDraft(element);
    findButton(element, "Continue to validation").click();
    await flushPromises();

    findButton(element, "Validate complete version").click();
    await flushPromises();
    expect(findButton(element, "Save validated version").disabled).toBe(false);

    findButton(element, "Back to design").click();
    await flushPromises();
    change(
      element,
      'lightning-textarea[data-field="CardSubtitle__c"]',
      "Updated after validation",
    );
    findButton(element, "Continue to validation").click();
    await flushPromises();

    expect(findButton(element, "Save validated version").disabled).toBe(true);
    expect(element.shadowRoot.textContent).toContain(
      "The design changed after the last validation",
    );
  });

  it("reuses the save idempotency key after an uncertain failure", async () => {
    validateCheckSetVersion.mockResolvedValue({ isValid: true, issues: [] });
    saveCheckSetVersion
      .mockRejectedValueOnce(new Error("Connection interrupted"))
      .mockResolvedValueOnce({ resultSummary: "Saved exactly once." });
    const element = await createBuilder();
    await completeFormulaDraft(element);
    findButton(element, "Continue to validation").click();
    await flushPromises();

    findButton(element, "Save validated version").click();
    await flushPromises();
    findButton(element, "Save validated version").click();
    await flushPromises();
    await flushPromises();

    expect(saveCheckSetVersion).toHaveBeenCalledTimes(2);
    expect(saveCheckSetVersion.mock.calls[0][0].idempotencyKey).toBe(
      saveCheckSetVersion.mock.calls[1][0].idempotencyKey,
    );
  });

  it("reuses the save key when persistence succeeds but home refresh fails", async () => {
    validateCheckSetVersion.mockResolvedValue({ isValid: true, issues: [] });
    getBuilderHome
      .mockResolvedValueOnce({ versions: [], recentOperations: [] })
      .mockRejectedValueOnce(new Error("Refresh failed"))
      .mockResolvedValueOnce({ versions: [], recentOperations: [] });
    saveCheckSetVersion.mockResolvedValue({
      resultSummary: "Saved exactly once.",
    });
    const element = await createBuilder();
    await completeFormulaDraft(element);
    findButton(element, "Continue to validation").click();
    await flushPromises();

    findButton(element, "Save validated version").click();
    await flushPromises();
    await flushPromises();
    findButton(element, "Save validated version").click();
    await flushPromises();
    await flushPromises();

    expect(saveCheckSetVersion).toHaveBeenCalledTimes(2);
    expect(saveCheckSetVersion.mock.calls[0][0].idempotencyKey).toBe(
      saveCheckSetVersion.mock.calls[1][0].idempotencyKey,
    );
  });

  it("reviews, copies, and confirms publication of a saved complete version", async () => {
    const savedVersion = {
      versionId: "a01VERSION",
      label: "Account Readiness",
      versionNumber: 1,
      checkSetQualifiedApiName: "Account_Readiness",
      status: "VALIDATED",
      checkCount: 1,
    };
    getBuilderHome.mockResolvedValue({
      versions: [savedVersion],
      recentOperations: [
        {
          operationToken: "operation-1",
          operationKind: "SAVE_VERSION",
          status: "SUCCEEDED",
          resultSummary: "Saved.",
          requestedFingerprint: "abc123",
          metadataRequestId: "0AfREQUEST",
          requestedAt: "2026-08-29T12:00:00.000Z",
          completedAt: "2026-08-29T12:00:05.000Z",
        },
      ],
    });
    getCheckSetVersion.mockResolvedValue({
      versionNumber: 1,
      status: "VALIDATED",
      fingerprint: "abc123",
      version: {
        schemaVersion: 1,
        contractVersion: "1.0",
        checkSet: {
          qualifiedApiName: "Account_Readiness",
          label: "Account Readiness",
          values: { ObjectApiName__c: "Account" },
        },
        checks: [],
      },
    });
    publishCheckSetVersion.mockResolvedValue({ resultSummary: "Accepted." });
    LightningConfirm.open.mockResolvedValue(true);
    const element = await createBuilder();
    const versionsStep = [
      ...element.shadowRoot.querySelectorAll("lightning-progress-step"),
    ].find((step) => step.value === "versions");
    versionsStep.click();
    await flushPromises();

    findButton(element, "Review").click();
    await flushPromises();
    expect(getCheckSetVersion).toHaveBeenCalledWith({
      checkSetVersionId: "a01VERSION",
    });
    expect(element.shadowRoot.textContent).toContain("Fingerprint: abc123");
    expect(element.shadowRoot.textContent).toContain("Operation: operation-1");
    expect(element.shadowRoot.textContent).toContain(
      "Metadata request: 0AfREQUEST",
    );

    findButton(element, "Publish inactive").click();
    await flushPromises();
    await flushPromises();
    expect(LightningConfirm.open).toHaveBeenCalledWith(
      expect.objectContaining({
        label: "Publish complete version inactive",
        message: expect.stringContaining(
          "Account Readiness, Version 1, 1 Checks",
        ),
      }),
    );
    expect(publishCheckSetVersion).toHaveBeenCalledWith(
      expect.objectContaining({ checkSetVersionId: "a01VERSION" }),
    );

    findButton(element, "Publish inactive").click();
    await flushPromises();
    await flushPromises();
    expect(publishCheckSetVersion.mock.calls[0][0].idempotencyKey).toBe(
      publishCheckSetVersion.mock.calls[1][0].idempotencyKey,
    );
  });

  it("refreshes recent operation status from Publish and monitor", async () => {
    getBuilderHome
      .mockResolvedValueOnce({ versions: [], recentOperations: [] })
      .mockResolvedValueOnce({
        versions: [],
        recentOperations: [
          {
            operationToken: "operation-1",
            operationKind: "PUBLISH",
            status: "SUCCEEDED",
            resultSummary: "Publication completed.",
          },
        ],
      });
    const element = await createBuilder();
    const versionsStep = [
      ...element.shadowRoot.querySelectorAll("lightning-progress-step"),
    ].find((step) => step.value === "versions");
    versionsStep.click();
    await flushPromises();

    findButton(element, "Refresh status").click();
    await flushPromises();
    await flushPromises();

    expect(getBuilderHome).toHaveBeenCalledTimes(2);
    expect(element.shadowRoot.textContent).toContain("Publication completed.");
    expect(element.shadowRoot.textContent).toContain(
      "Publication status refreshed.",
    );
  });

  it("shows initialization failures in plain language", async () => {
    getAuthoringContract.mockRejectedValue({ body: { message: "No access" } });
    const element = await createBuilder();
    expect(element.shadowRoot.textContent).toContain("No access");
  });
});
