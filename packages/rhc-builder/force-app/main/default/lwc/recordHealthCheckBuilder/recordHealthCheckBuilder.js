import { LightningElement } from "lwc";
import LightningConfirm from "lightning/confirm";
import hasAuthorPermission from "@salesforce/customPermission/RHC_Builder_Author";
import getAuthoringContract from "@salesforce/apex/RHCBuilderController.getAuthoringContract";
import getBuilderHome from "@salesforce/apex/RHCBuilderController.getBuilderHome";
import listReadableObjects from "@salesforce/apex/RHCBuilderController.listReadableObjects";
import listReadableFields from "@salesforce/apex/RHCBuilderController.listReadableFields";
import listReadableRelationships from "@salesforce/apex/RHCBuilderController.listReadableRelationships";
import getCheckSetVersion from "@salesforce/apex/RHCBuilderController.getCheckSetVersion";
import validateCheckSetVersion from "@salesforce/apex/RHCBuilderController.validateCheckSetVersion";
import saveCheckSetVersion from "@salesforce/apex/RHCBuilderController.saveCheckSetVersion";
import publishCheckSetVersion from "@salesforce/apex/RHCBuilderController.publishCheckSetVersion";
import activateCheckSetVersion from "@salesforce/apex/RHCBuilderController.activateCheckSetVersion";
import rollbackToCheckSetVersion from "@salesforce/apex/RHCBuilderController.rollbackToCheckSetVersion";
import {
  buildCanonicalVersion,
  applyCardExperience,
  apiNameFromLabel,
  describeCardExperience,
  createCheck,
  createDraft,
  draftFromVersion,
  inferCardExperience,
  toOptions,
  validateLocalDraft,
} from "./builderModel";

export default class RecordHealthCheckBuilder extends LightningElement {
  contract;
  draft;
  objectOptions = [];
  fieldOptions = [];
  fieldError;
  relationshipOptions = [];
  relationshipError;
  isRelationshipLoading = false;
  home = { versions: [], recentOperations: [] };
  validationIssues = [];
  errorMessage;
  successMessage;
  isLoading = true;
  isWorking = false;
  currentStep = "design";
  selectedVersion;
  apiNameEdited = false;
  nextCheckKey = 1;
  saveOperationKey;
  publicationOperationKeys = {};
  cardExperience = "USER_CONTROLLED";
  previewState = "COMPLETED";
  validatedVersionJson;
  draftChangedAfterValidation = false;

  connectedCallback() {
    if (this.canAuthor) this.initialize();
  }

  get canAuthor() {
    return hasAuthorPermission === true;
  }

  get showPermissionBlock() {
    return !this.canAuthor;
  }

  get isReady() {
    return this.canAuthor && !this.isLoading && this.contract && this.draft;
  }

  get evaluationTypeOptions() {
    const values =
      this.contract?.allowedValues?.EvaluationType__c ||
      this.contract?.evaluationTypes ||
      [];
    const labels = {
      FORMULA: "Formula — fields on this record",
      QUERY: "Related records — bounded query",
      COMPARE_TWO_QUERIES: "Compare two queries — two datasets",
      APEX: "Apex plugin — approved developer extension",
    };
    return values.map((value) => ({ label: labels[value] || value, value }));
  }

  get severityOptions() {
    const labels = {
      CRITICAL: "Critical — work must stop or data is unsafe",
      WARNING: "Warning — important action; work can continue",
      INFO: "Info — helpful improvement",
    };
    return (this.contract?.allowedValues?.FailureSeverity__c || []).map(
      (value) => ({ label: labels[value] || value, value }),
    );
  }

  get runModeOptions() {
    return this.labelledOptions("CardRunMode__c", {
      RUN_ON_REQUEST: "When the user clicks Run",
      RUN_ON_LOAD: "When the page opens",
    });
  }

  get runButtonDisplayOptions() {
    return this.labelledOptions("RunButtonDisplay__c", {
      LABEL_AND_ICON: "Label and icon",
      LABEL_ONLY: "Label only",
      ICON_ONLY: "Icon only",
      HIDE: "Hide",
    });
  }

  get revealModeOptions() {
    return this.labelledOptions("CardRevealMode__c", {
      ALL_AT_ONCE: "All at once",
      ONE_BY_ONE: "One by one",
    });
  }

  get foundExpectedDisplayOptions() {
    return this.labelledOptions("FoundExpectedDisplay__c", {
      ON_DEMAND: "On demand",
      FAILURES_ONLY: "Failed checks only",
      ALL_ROWS: "Every check",
    });
  }

  get passedChecksDisplayOptions() {
    return this.labelledOptions("PassedChecksDisplay__c", {
      SHOW_EACH_CHECK: "Show each check",
      SHOW_COUNT_ONLY: "Show count only",
    });
  }

  get skippedChecksDisplayOptions() {
    return this.labelledOptions("SkippedChecksDisplay__c", {
      SHOW_EACH_CHECK: "Show each check",
      SHOW_COUNT_ONLY: "Show count only",
    });
  }

  get summaryDisplayOptions() {
    return this.labelledOptions("SummaryDisplay__c", {
      TOP: "Above Checks",
      BOTTOM: "Below Checks",
    });
  }

  get cardExperienceOptions() {
    const options = [
      {
        value: "USER_CONTROLLED",
        label: "User-controlled review",
        recommendation: "Recommended",
        summary: "Users decide when to run, and every result remains visible.",
        bestFor: "Approvals, handoffs, and occasional reviews.",
        tradeoff: "Results are not current until someone selects Run.",
      },
      {
        value: "AUTOMATIC",
        label: "Automatic status",
        summary: "Checks run on page open and keep a visible Run Again action.",
        bestFor: "Lightweight checks useful on nearly every visit.",
        tradeoff: "Every page visit invokes evaluation.",
      },
      {
        value: "GUIDED",
        label: "Guided walkthrough",
        summary: "Users start the run, and Checks appear one at a time.",
        bestFor: "Training and complex readiness reviews.",
        tradeoff: "Progressive reveal can feel slower for routine checks.",
      },
      {
        value: "COMPACT",
        label: "Compact exception view",
        summary: "Summary counts lead; passing and skipped rows stay hidden.",
        bestFor: "Mature Check Sets with many result rows.",
        tradeoff: "Individual passed and skipped rows cannot be inspected.",
      },
      {
        value: "CUSTOM",
        label: "Custom",
        summary: "Choose every supported behavior individually.",
        bestFor: "A documented requirement the presets do not cover.",
        tradeoff: "You own the usability and load implications.",
      },
    ];
    return options.map((option) => ({
      ...option,
      checked: option.value === this.cardExperience,
      inputId: `card-experience-${option.value.toLowerCase()}`,
      descriptionId: `card-experience-${option.value.toLowerCase()}-details`,
    }));
  }

  get isCustomCardExperience() {
    return this.cardExperience === "CUSTOM";
  }

  get selectedCardExperienceLabel() {
    return (
      this.cardExperienceOptions.find((option) => option.checked)?.label ||
      "Custom"
    );
  }

  get cardExperienceExplanation() {
    return describeCardExperience(this.draft?.checkSetValues || {});
  }

  get previewStateOptions() {
    return [
      { label: "Before run", value: "BEFORE" },
      { label: "Running", value: "RUNNING" },
      { label: "Completed", value: "COMPLETED" },
    ].map((option) => ({
      ...option,
      variant: option.value === this.previewState ? "brand" : "neutral",
    }));
  }

  get previewIsBefore() {
    return this.previewState === "BEFORE";
  }

  get previewIsRunning() {
    return this.previewState === "RUNNING";
  }

  get previewIsCompleted() {
    return this.previewState === "COMPLETED";
  }

  get previewTitle() {
    return this.draft?.checkSetLabel?.trim() || "Example health check";
  }

  get previewSubtitle() {
    return (
      this.draft?.checkSetValues?.CardSubtitle__c?.trim() ||
      "Review this record before the next business step."
    );
  }

  get previewStatusText() {
    if (this.previewIsBefore) {
      return this.draft.checkSetValues.CardRunMode__c === "RUN_ON_LOAD"
        ? "Checks will begin when the page opens."
        : "No example checks have run yet.";
    }
    if (this.previewIsRunning) return "Example evaluation in progress.";
    return "Example evaluation completed: one passed, one failed, one skipped.";
  }

  get previewShowAction() {
    if (this.draft.checkSetValues.RunButtonDisplay__c === "HIDE") return false;
    if (this.previewIsRunning) return false;
    return (
      this.previewIsCompleted ||
      this.draft.checkSetValues.CardRunMode__c === "RUN_ON_REQUEST"
    );
  }

  get previewShowActionLabel() {
    return ["LABEL_AND_ICON", "LABEL_ONLY"].includes(
      this.draft.checkSetValues.RunButtonDisplay__c,
    );
  }

  get previewShowActionIcon() {
    return ["LABEL_AND_ICON", "ICON_ONLY"].includes(
      this.draft.checkSetValues.RunButtonDisplay__c,
    );
  }

  get previewActionLabel() {
    return this.previewIsCompleted
      ? this.draft.checkSetValues.RerunButtonLabel__c || "Rerun"
      : this.draft.checkSetValues.RunButtonLabel__c || "Run";
  }

  get previewIconName() {
    const icon = this.draft.checkSetValues.RunButtonIcon__c || "";
    return /^(action|custom|doctype|standard|utility):[a-z0-9_]+$/.test(icon)
      ? icon
      : "utility:check";
  }

  get previewShowPreRunHint() {
    return (
      this.previewIsBefore &&
      this.draft.checkSetValues.CardRunMode__c === "RUN_ON_REQUEST" &&
      this.previewShowAction
    );
  }

  get previewVisibleRows() {
    const values = this.draft.checkSetValues;
    if (this.previewIsBefore) return [];
    if (this.previewIsRunning) {
      const pendingRows = [
        { key: "pass", label: "Account name is present" },
        { key: "fail", label: "Primary Contact is assigned" },
        { key: "skip", label: "Approval prerequisites are complete" },
      ].map((row) => ({
        ...row,
        status: "Checking…",
        detail: "Example result pending.",
      }));
      return values.CardRevealMode__c === "ONE_BY_ONE"
        ? pendingRows.slice(0, 1)
        : pendingRows;
    }
    const showAllComparisons = values.FoundExpectedDisplay__c === "ALL_ROWS";
    const rows = [
      {
        key: "pass",
        label: "Account name is present",
        status: "Passed",
        detail: "The required Account Name is available.",
        comparison: showAllComparisons
          ? "Found: Acme Corporation · Expected: a value"
          : undefined,
        hidden: values.PassedChecksDisplay__c === "SHOW_COUNT_ONLY",
      },
      {
        key: "fail",
        label: "Primary Contact is assigned",
        status: "Failed",
        detail: "Add a primary Contact before continuing.",
        comparison:
          values.FoundExpectedDisplay__c === "FAILURES_ONLY" ||
          values.FoundExpectedDisplay__c === "ON_DEMAND" ||
          showAllComparisons
            ? "Found: none · Expected: one primary Contact"
            : undefined,
        hidden: false,
      },
      {
        key: "skip",
        label: "Approval prerequisites are complete",
        status: "Skipped",
        detail: "This Check does not apply to the example record.",
        comparison: undefined,
        hidden: values.SkippedChecksDisplay__c === "SHOW_COUNT_ONLY",
      },
    ];
    return rows.filter((row) => !row.hidden);
  }

  get previewShowSummaryAbove() {
    return (
      this.previewIsCompleted &&
      this.draft.checkSetValues.SummaryDisplay__c === "TOP"
    );
  }

  get previewShowSummaryBelow() {
    return this.previewIsCompleted && !this.previewShowSummaryAbove;
  }

  get previewShowsHiddenResultsNotice() {
    return this.previewIsCompleted && this.previewVisibleRows.length === 1;
  }

  get showHiddenAutomaticActionWarning() {
    const values = this.draft?.checkSetValues || {};
    return (
      values.CardRunMode__c === "RUN_ON_LOAD" &&
      values.RunButtonDisplay__c === "HIDE"
    );
  }

  get showHiddenManualActionError() {
    const values = this.draft?.checkSetValues || {};
    return (
      values.CardRunMode__c === "RUN_ON_REQUEST" &&
      values.RunButtonDisplay__c === "HIDE"
    );
  }

  get comparisonOperatorOptions() {
    return toOptions(this.contract?.allowedValues?.ComparisonOperator__c || []);
  }

  get expectedValueSourceOptions() {
    return toOptions(
      this.contract?.allowedValues?.ExpectedValueSource__c || [],
    );
  }

  get formulaRuleOptions() {
    return [
      { label: "has a value", value: "PRESENT" },
      { label: "is blank", value: "BLANK" },
    ];
  }

  get guidedFieldOptions() {
    const supportedTypes = new Set([
      "STRING",
      "TEXTAREA",
      "EMAIL",
      "PHONE",
      "URL",
    ]);
    return this.fieldOptions.filter((field) =>
      supportedTypes.has(field.dataType),
    );
  }

  get hasChecks() {
    return (this.draft?.checks || []).length > 0;
  }

  get decoratedChecks() {
    return (this.draft?.checks || []).map((check, index) => ({
      ...check,
      index,
      number: index + 1,
      isFormula: check.evaluationType === "FORMULA",
      isQuery: check.evaluationType === "QUERY",
      isCompare: check.evaluationType === "COMPARE_TWO_QUERIES",
      isApex: check.evaluationType === "APEX",
      removeAlternativeText: `Remove Check ${index + 1}${
        check.label ? `: ${check.label}` : ""
      }`,
      showTypeChangedNotice: check.typeChanged === true,
    }));
  }

  get reviewCheckSummaries() {
    const evaluationLabels = Object.fromEntries(
      this.evaluationTypeOptions.map((option) => [option.value, option.label]),
    );
    const severityLabels = Object.fromEntries(
      this.severityOptions.map((option) => [option.value, option.label]),
    );
    return this.decoratedChecks.map((check) => ({
      key: check.clientKey || check.qualifiedApiName,
      number: check.number,
      label: check.label || "Unnamed Check",
      qualifiedApiName: check.qualifiedApiName || "Not provided",
      evaluationType: evaluationLabels[check.evaluationType] || "Not selected",
      severity:
        severityLabels[check.values.FailureSeverity__c] || "Not selected",
      failureMessage: check.values.FailureMessage__c || "Not provided",
      fixMessage: check.values.FixMessage__c || "Not provided",
    }));
  }

  get hasVersions() {
    return this.home.versions.length > 0;
  }

  get hasValidationIssues() {
    return this.validationIssues.length > 0;
  }

  get decoratedValidationIssues() {
    return this.validationIssues.map((issue, index) => ({
      ...issue,
      key: `${issue.reasonCode || "ISSUE"}-${issue.path || "version"}-${index}`,
      path: issue.path || "version",
    }));
  }

  get isDesignStep() {
    return this.currentStep === "design";
  }

  get isReviewStep() {
    return this.currentStep === "review";
  }

  get isVersionsStep() {
    return this.currentStep === "versions";
  }

  get hasOperations() {
    return this.home.recentOperations.length > 0;
  }

  get decoratedOperations() {
    return this.home.recentOperations.map((operation) => {
      let guidance =
        "Salesforce accepted the operation. The version is not published until status is Succeeded.";
      if (operation.status === "SUCCEEDED") {
        guidance =
          "Publication finished. Verify known passing, failing, and skipped records before activation or release approval.";
      } else if (operation.status === "FAILED") {
        guidance =
          "Do not assume anything is active. Record the diagnostic details, correct the design, and publish a newly validated version when appropriate.";
      }
      return { ...operation, guidance };
    });
  }

  get reviewJson() {
    return this.draft
      ? JSON.stringify(buildCanonicalVersion(this.draft), null, 2)
      : "";
  }

  get selectedVersionJson() {
    return this.selectedVersion
      ? JSON.stringify(this.selectedVersion.version, null, 2)
      : "";
  }

  get canonicalVersionJson() {
    return this.draft
      ? JSON.stringify(buildCanonicalVersion(this.draft))
      : undefined;
  }

  get isDraftValidated() {
    return (
      Boolean(this.validatedVersionJson) &&
      this.validatedVersionJson === this.canonicalVersionJson
    );
  }

  get saveDisabled() {
    return this.isWorking || !this.isDraftValidated;
  }

  async initialize() {
    this.isLoading = true;
    this.errorMessage = undefined;
    try {
      const [contract, objects, home] = await Promise.all([
        getAuthoringContract(),
        listReadableObjects(),
        getBuilderHome(),
      ]);
      this.contract = contract;
      this.draft = createDraft(contract);
      this.cardExperience = inferCardExperience(this.draft.checkSetValues);
      this.objectOptions = [...objects].sort((left, right) =>
        left.label.localeCompare(right.label),
      );
      this.home = {
        versions: home?.versions || [],
        recentOperations: home?.recentOperations || [],
      };
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.isLoading = false;
    }
  }

  handleSetChange(event) {
    const field = event.target.dataset.field;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : (event.detail?.value ?? event.target.value);
    if (field === "checkSetLabel") {
      this.draft = {
        ...this.draft,
        checkSetLabel: value,
        checkSetQualifiedApiName: this.apiNameEdited
          ? this.draft.checkSetQualifiedApiName
          : apiNameFromLabel(value),
      };
    } else if (field === "checkSetQualifiedApiName") {
      this.apiNameEdited = true;
      this.draft = { ...this.draft, checkSetQualifiedApiName: value };
    } else if (field === "objectApiName") {
      this.draft = { ...this.draft, objectApiName: value };
      this.loadFields(value);
      this.loadRelationships(value);
    } else {
      this.draft = {
        ...this.draft,
        checkSetValues: { ...this.draft.checkSetValues, [field]: value },
      };
    }
    this.markDraftChanged();
  }

  handleCardExperienceChange(event) {
    const experience = event.target.value;
    this.cardExperience = experience;
    if (experience === "CUSTOM") {
      this.clearMessages();
      return;
    }
    this.draft = {
      ...this.draft,
      checkSetValues: applyCardExperience(
        this.draft.checkSetValues,
        experience,
      ),
    };
    this.markDraftChanged();
  }

  handleCustomCardChange(event) {
    this.cardExperience = "CUSTOM";
    this.handleSetChange(event);
  }

  handlePreviewStateChange(event) {
    this.previewState = event.currentTarget.dataset.state;
  }

  labelledOptions(fieldName, labels) {
    return (this.contract?.allowedValues?.[fieldName] || []).map((value) => ({
      label: labels[value] || value,
      value,
    }));
  }

  async loadFields(objectApiName) {
    this.fieldError = undefined;
    try {
      const fields = await listReadableFields({ objectApiName });
      this.fieldOptions = fields || [];
      if (!this.guidedFieldOptions.length) {
        this.fieldError =
          "No readable fields are available. Use Advanced formula or ask an administrator to review access.";
      }
    } catch (error) {
      this.fieldOptions = [];
      this.fieldError = this.messageFrom(error);
    }
  }

  async loadRelationships(objectApiName) {
    this.isRelationshipLoading = true;
    this.relationshipError = undefined;
    try {
      const relationships = await listReadableRelationships({ objectApiName });
      this.relationshipOptions = relationships || [];
      if (!this.relationshipOptions.length) {
        this.relationshipError =
          "No readable related records are available for this object. Use Advanced query or ask an administrator to review access.";
      }
    } catch (error) {
      this.relationshipOptions = [];
      this.relationshipError = this.messageFrom(error);
    } finally {
      this.isRelationshipLoading = false;
    }
  }

  addCheck() {
    const checks = [
      ...this.draft.checks,
      {
        ...createCheck(this.contract, (this.draft.checks.length + 1) * 10),
        clientKey: `check-${this.nextCheckKey++}`,
      },
    ];
    this.draft = { ...this.draft, checks };
    this.markDraftChanged();
  }

  navigateStep(event) {
    this.currentStep = event.target.value;
  }

  goToReview() {
    this.currentStep = "review";
  }

  goToDesign() {
    this.currentStep = "design";
  }

  goToVersions() {
    this.currentStep = "versions";
  }

  removeCheck(event) {
    const index = Number(event.currentTarget.dataset.index);
    this.draft = {
      ...this.draft,
      checks: this.draft.checks.filter((_, checkIndex) => checkIndex !== index),
    };
    this.markDraftChanged();
  }

  handleCheckChange(event) {
    const index = Number(event.target.dataset.index);
    const field = event.target.dataset.field;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : (event.detail?.value ?? event.target.value);
    const checks = this.draft.checks.map((check, checkIndex) => {
      if (checkIndex !== index) return check;
      if (field === "label" || field === "qualifiedApiName") {
        const next = { ...check, [field]: value };
        if (field === "label" && !check.apiNameEdited) {
          next.qualifiedApiName = apiNameFromLabel(value);
        }
        if (field === "qualifiedApiName") next.apiNameEdited = true;
        return next;
      }
      if (field === "EvaluationType__c") {
        return {
          ...check,
          evaluationType: value,
          typeChanged: Boolean(
            check.evaluationType && check.evaluationType !== value,
          ),
        };
      }
      if (field === "relationshipSelection") {
        return this.withGeneratedRelationshipQuery({
          ...check,
          relationshipSelection: value,
        });
      }
      if (field === "formulaFieldApiName" || field === "formulaRule") {
        return this.withGeneratedFormula({ ...check, [field]: value });
      }
      return { ...check, values: { ...check.values, [field]: value } };
    });
    this.draft = { ...this.draft, checks };
    this.markDraftChanged();
  }

  withGeneratedFormula(check) {
    if (!check.formulaFieldApiName || !check.formulaRule) return check;
    const blankExpression = `ISBLANK(${check.formulaFieldApiName})`;
    return {
      ...check,
      values: {
        ...check.values,
        PassConditionFormula__c:
          check.formulaRule === "BLANK"
            ? blankExpression
            : `NOT(${blankExpression})`,
      },
    };
  }

  withGeneratedRelationshipQuery(check) {
    const relationship = this.relationshipOptions.find(
      (option) => option.value === check.relationshipSelection,
    );
    if (!relationship) return check;
    return {
      ...check,
      values: {
        ...check.values,
        SourceQuery__c: `SELECT Id FROM ${relationship.childObjectApiName} WHERE ${relationship.parentFieldApiName} = {!record.Id} LIMIT 1`,
        SourceQueryField__c: "Id",
        ComparisonOperator__c: "IS_NOT_BLANK",
        QueryResultHandling__c: "ONE_RESULT",
        NoRowsResult__c: "FAIL",
        EmptyValueHandling__c: "SKIP_RECORD",
        MaxQueryRows__c: 1,
      },
    };
  }

  async validateVersion() {
    const localErrors = validateLocalDraft(this.draft);
    if (localErrors.length) {
      this.validatedVersionJson = undefined;
      this.validationIssues = localErrors.map((userMessage, index) => ({
        severity: "ERROR",
        reasonCode: `LOCAL_${index}`,
        userMessage,
      }));
      return false;
    }
    this.isWorking = true;
    this.clearMessages();
    const candidateVersionJson = this.canonicalVersionJson;
    try {
      const result = await validateCheckSetVersion({
        canonicalVersionJson: candidateVersionJson,
      });
      this.validationIssues = result.issues || [];
      if (result.isValid) {
        this.validatedVersionJson = candidateVersionJson;
        this.draftChangedAfterValidation = false;
        this.successMessage =
          "Builder validation passed for the complete Check Set Version.";
      } else {
        this.validatedVersionJson = undefined;
      }
      return result.isValid === true;
    } catch (error) {
      this.validatedVersionJson = undefined;
      this.errorMessage = this.messageFrom(error);
      return false;
    } finally {
      this.isWorking = false;
    }
  }

  async saveVersion() {
    if (!this.isDraftValidated && !(await this.validateVersion())) return;
    this.isWorking = true;
    try {
      this.saveOperationKey ||= this.newIdempotencyKey("save");
      const operation = await saveCheckSetVersion({
        canonicalVersionJson: JSON.stringify(buildCanonicalVersion(this.draft)),
        idempotencyKey: this.saveOperationKey,
      });
      this.successMessage = operation.resultSummary;
      await this.refreshHome();
      this.saveOperationKey = undefined;
      this.currentStep = "versions";
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.isWorking = false;
    }
  }

  async publishVersion(event) {
    return this.confirmPublication(
      publishCheckSetVersion,
      event.currentTarget.dataset.versionId,
      "publish",
      "It will replace the corresponding core metadata but will not run for users yet.",
    );
  }

  async activateVersion(event) {
    return this.confirmPublication(
      activateCheckSetVersion,
      event.currentTarget.dataset.versionId,
      "activate",
      "The Check Set and every Check in it will become active together.",
    );
  }

  async rollbackVersion(event) {
    return this.confirmPublication(
      rollbackToCheckSetVersion,
      event.currentTarget.dataset.versionId,
      "rollback",
      "This republishes the entire saved version as a new metadata deployment; it is not a database undo.",
    );
  }

  async confirmPublication(method, versionId, operation, message) {
    const version = this.home.versions.find(
      (candidate) => candidate.versionId === versionId,
    );
    const actionLabels = {
      publish: "Publish complete version inactive",
      activate: "Activate complete version",
      rollback: "Roll back to complete version",
    };
    const identity = version
      ? `${version.label}, Version ${version.versionNumber}, ${version.checkCount} Checks, Qualified API Name ${version.checkSetQualifiedApiName}. `
      : "";
    const confirmed = await LightningConfirm.open({
      label: actionLabels[operation],
      message: `${identity}${message}`,
      theme: operation === "rollback" ? "warning" : "info",
    });
    if (confirmed) return this.runPublication(method, versionId, operation);
    return undefined;
  }

  async reviewSavedVersion(event) {
    this.isWorking = true;
    this.clearMessages();
    try {
      this.selectedVersion = await getCheckSetVersion({
        checkSetVersionId: event.currentTarget.dataset.versionId,
      });
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.isWorking = false;
    }
  }

  async cloneSavedVersion(event) {
    await this.reviewSavedVersion(event);
    if (!this.selectedVersion) return;
    this.draft = draftFromVersion(this.selectedVersion.version);
    this.draft = {
      ...this.draft,
      checks: this.draft.checks.map((check) => ({
        ...check,
        clientKey: `check-${this.nextCheckKey++}`,
      })),
    };
    this.apiNameEdited = true;
    this.cardExperience = inferCardExperience(this.draft.checkSetValues);
    this.validatedVersionJson = undefined;
    this.draftChangedAfterValidation = false;
    this.currentStep = "design";
    this.successMessage = `Version ${this.selectedVersion.versionNumber} copied into a new unsaved draft.`;
  }

  async runPublication(method, checkSetVersionId, operation) {
    this.isWorking = true;
    this.clearMessages();
    try {
      const operationKey = `${operation}:${checkSetVersionId}`;
      this.publicationOperationKeys[operationKey] ||=
        this.newIdempotencyKey(operation);
      const result = await method({
        checkSetVersionId,
        idempotencyKey: this.publicationOperationKeys[operationKey],
      });
      this.successMessage = result.resultSummary;
      await this.refreshHome();
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.isWorking = false;
    }
  }

  async refreshOperationStatus() {
    this.isWorking = true;
    try {
      await this.refreshHome();
      this.successMessage = "Publication status refreshed.";
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.isWorking = false;
    }
  }

  async refreshHome() {
    const result = await getBuilderHome();
    this.home = {
      versions: result?.versions || [],
      recentOperations: result?.recentOperations || [],
    };
    this.releaseTerminalPublicationKeys();
  }

  releaseTerminalPublicationKeys() {
    const terminalTokens = new Set(
      this.home.recentOperations
        .filter(
          (operation) =>
            operation.status === "SUCCEEDED" || operation.status === "FAILED",
        )
        .map((operation) => operation.operationToken),
    );
    Object.entries(this.publicationOperationKeys).forEach(([key, token]) => {
      if (terminalTokens.has(token)) delete this.publicationOperationKeys[key];
    });
  }

  clearMessages() {
    this.errorMessage = undefined;
    this.successMessage = undefined;
    this.validationIssues = [];
  }

  markDraftChanged() {
    if (this.validatedVersionJson) this.draftChangedAfterValidation = true;
    this.validatedVersionJson = undefined;
    this.saveOperationKey = undefined;
    this.clearMessages();
  }

  newIdempotencyKey(operation) {
    return `${operation}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  messageFrom(error) {
    return (
      error?.body?.message ||
      error?.message ||
      "Salesforce could not complete the Builder request."
    );
  }
}
