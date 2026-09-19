import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import listPolicies from "@salesforce/apex/RHCAlertsAdminController.listPolicies";
import listSelections from "@salesforce/apex/RHCAlertsAdminController.listSelections";
import listRecipients from "@salesforce/apex/RHCAlertsAdminController.listRecipients";
import savePolicy from "@salesforce/apex/RHCAlertsAdminController.savePolicy";
import analyzeCoverage from "@salesforce/apex/RHCAlertsAdminController.analyzeCoverage";
import getLimitInfo from "@salesforce/apex/RHCAlertsAdminController.getLimitInfo";
import sendTestAlert from "@salesforce/apex/RHCAlertsAdminController.sendTestAlert";

const EMPTY_POLICY = {
  DisplayName__c: "",
  Active__c: true,
  SelectionType__c: "CHECK_SET",
  QualifiedApiName__c: "",
  MatchingStatuses__c: "FAIL;UNABLE_TO_EVALUATE;ERROR",
  MinimumSeverity__c: "INFO",
  RecipientType__c: "USER",
  RecipientId__c: "",
  RecipientLabel__c: "",
  NotificationChannel__c: "CUSTOM_NOTIFICATION",
  CooldownMinutes__c: 0
};

export default class RhcAlertsAdmin extends LightningElement {
  policy = { ...EMPTY_POLICY };
  policies = [];
  selections = [];
  recipients = [];
  gaps = [];
  coverageAnalyzed = false;
  limits;
  loading = true;

  selectionTypes = [
    { label: "Check Set", value: "CHECK_SET" },
    { label: "Check", value: "CHECK" }
  ];
  statuses = ["PASS", "FAIL", "SKIPPED", "UNABLE_TO_EVALUATE", "ERROR"].map(
    (value) => ({ label: value.replaceAll("_", " "), value })
  );
  severities = ["INFO", "WARNING", "CRITICAL"].map((value) => ({
    label: value,
    value
  }));
  recipientTypes = [
    { label: "User", value: "USER" },
    { label: "Public Group", value: "PUBLIC_GROUP" }
  ];
  channels = [
    { label: "Salesforce notification (bell)", value: "CUSTOM_NOTIFICATION" },
    { label: "Email", value: "EMAIL" }
  ];

  connectedCallback() {
    this.initialize();
  }

  async initialize() {
    this.loading = true;
    try {
      const [policies, limits] = await Promise.all([
        listPolicies(),
        getLimitInfo()
      ]);
      this.policies = policies;
      this.limits = limits;
      await Promise.all([this.loadSelections(), this.loadRecipients()]);
    } catch (error) {
      this.toast("RHC Alerts could not load", this.message(error), "error");
    } finally {
      this.loading = false;
    }
  }

  async loadSelections() {
    this.selections = await listSelections({
      selectionType: this.policy.SelectionType__c
    });
  }
  async loadRecipients() {
    this.recipients = await listRecipients({
      recipientType: this.policy.RecipientType__c
    });
  }

  get selectionOptions() {
    return this.selections.map(({ label, value }) => ({ label, value }));
  }
  get recipientOptions() {
    return this.recipients.map(({ label, value }) => ({ label, value }));
  }
  get selectedStatuses() {
    return this.policy.MatchingStatuses__c
      ? this.policy.MatchingStatuses__c.split(";")
      : [];
  }
  get hasGaps() {
    return this.gaps.length > 0;
  }
  get coverageComplete() {
    return this.coverageAnalyzed && !this.hasGaps;
  }
  get hasPolicies() {
    return this.policies.length > 0;
  }
  get policyColumns() {
    return [
      { label: "Policy", fieldName: "DisplayName__c" },
      { label: "Type", fieldName: "SelectionType__c" },
      { label: "Qualified API Name", fieldName: "QualifiedApiName__c" },
      { label: "Channel", fieldName: "NotificationChannel__c" },
      { label: "Active", fieldName: "Active__c", type: "boolean" },
      { type: "action", typeAttributes: { rowActions: [{ label: "Send test alert to me", name: "test" }] } }
    ];
  }

  async handlePolicyAction(event) {
    if (event.detail.action.name !== "test") {
      return;
    }
    this.loading = true;
    try {
      await sendTestAlert({ policyId: event.detail.row.Id });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Test alert sent",
          message: "Check your notification bell or inbox. Test sends are not recorded in Delivery History.",
          variant: "success"
        })
      );
    } catch (error) {
      this.toast("Test alert was not sent", this.message(error), "error");
    } finally {
      this.loading = false;
    }
  }

  handleChange(event) {
    const field = event.target.dataset.field;
    const booleanInput =
      event.target.type === "checkbox" || event.target.type === "toggle";
    const value = booleanInput
      ? event.target.checked
      : (event.detail?.value ?? event.target.value);
    this.policy = { ...this.policy, [field]: value };
  }

  async handleSelectionType(event) {
    this.handleChange(event);
    this.policy.QualifiedApiName__c = "";
    await this.loadSelections();
  }
  async handleRecipientType(event) {
    this.handleChange(event);
    this.policy.RecipientId__c = "";
    await this.loadRecipients();
  }
  handleStatuses(event) {
    this.policy = {
      ...this.policy,
      MatchingStatuses__c: event.detail.value.join(";")
    };
  }
  handleRecipient(event) {
    this.handleChange(event);
    this.policy.RecipientLabel__c =
      this.recipients.find((item) => item.value === event.detail.value)
        ?.label ?? "";
  }

  async handleSave() {
    if (this.loading) return;
    const inputs = [
      ...this.template.querySelectorAll(
        "lightning-input, lightning-combobox, lightning-dual-listbox"
      )
    ];
    if (!inputs.reduce((valid, input) => input.reportValidity() && valid, true))
      return;
    this.loading = true;
    try {
      await savePolicy({ policy: this.policy });
      this.toast(
        "Policy saved",
        "RHC Alerts will evaluate future published events.",
        "success"
      );
      this.policy = { ...EMPTY_POLICY };
      this.policies = await listPolicies();
      await Promise.all([this.loadSelections(), this.loadRecipients()]);
    } catch (error) {
      this.toast("Policy was not saved", this.message(error), "error");
    } finally {
      this.loading = false;
    }
  }

  async handleAnalyze() {
    if (this.loading) return;
    this.loading = true;
    this.coverageAnalyzed = false;
    try {
      this.gaps = await analyzeCoverage();
      this.coverageAnalyzed = true;
    } catch (error) {
      this.toast("Coverage analysis failed", this.message(error), "error");
    } finally {
      this.loading = false;
    }
  }

  message(error) {
    return (
      error?.body?.message ??
      "Try again or contact your Salesforce administrator."
    );
  }
  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
