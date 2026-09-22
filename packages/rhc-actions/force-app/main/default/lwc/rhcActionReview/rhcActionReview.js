import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getPendingActions from "@salesforce/apex/RHCActionReviewController.getPendingActions";
import validatePolicy from "@salesforce/apex/RHCActionReviewController.validatePolicy";
import runAction from "@salesforce/apex/RHCActionReviewController.runAction";
import rejectAction from "@salesforce/apex/RHCActionReviewController.rejectAction";
import runActions from "@salesforce/apex/RHCActionReviewController.runActions";
import rejectActions from "@salesforce/apex/RHCActionReviewController.rejectActions";
import getRetentionSettings from "@salesforce/apex/RHCActionReviewController.getRetentionSettings";
import saveRetentionSettings from "@salesforce/apex/RHCActionReviewController.saveRetentionSettings";
import purgeAuditRecords from "@salesforce/apex/RHCActionReviewController.purgeAuditRecords";

const ROW_ACTIONS = [{ label: "Review", name: "review" }];

export default class RhcActionReview extends LightningElement {
  actions = [];
  selectedAction;
  selectedIds = [];
  loading = true;
  submitting = false;
  errorMessage;
  retention = {
    retentionDays: 365,
    configured: false,
    maxDeleteRows: 1000,
    canManage: false,
  };
  retentionConfirmed = false;
  retentionDirty = false;

  columns = [
    { label: "Action", fieldName: "Name" },
    { label: "Policy", fieldName: "policyName" },
    { label: "Check", fieldName: "Check_Qualified_API_Name__c" },
    { label: "Status", fieldName: "Status__c" },
    { label: "Severity", fieldName: "Severity__c" },
    { label: "Record", fieldName: "Record_Id__c" },
    { label: "Flow", fieldName: "flowName" },
    { type: "action", typeAttributes: { rowActions: ROW_ACTIONS } },
  ];

  connectedCallback() {
    this.initialize();
  }

  get showRetention() {
    return Boolean(this.retention?.canManage);
  }

  get purgeDisabled() {
    return (
      this.submitting ||
      !this.retention.configured ||
      this.retentionDirty ||
      !this.retentionConfirmed
    );
  }

  // Row actions stay disabled while a request is in flight so a second record cannot be
  // opened and submitted before the first approve/reject call returns.
  get tableBusy() {
    return this.loading || this.submitting;
  }

  async loadActions() {
    this.loading = true;
    this.errorMessage = undefined;
    try {
      const rows = await getPendingActions();
      this.actions = this.mapActions(rows);
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.loading = false;
    }
  }

  async initialize() {
    this.loading = true;
    this.errorMessage = undefined;
    try {
      const [rows, retention] = await Promise.all([
        getPendingActions(),
        getRetentionSettings(),
      ]);
      this.actions = this.mapActions(rows);
      this.retention = retention || this.retention;
      this.retentionDirty = false;
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.loading = false;
    }
  }

  mapActions(rows) {
    return rows.map((row) => ({
      ...row,
      policyName: row.Policy__r?.Name,
      flowName: row.Policy__r?.Flow_API_Name__c,
      recordUrl: row.Record_Id__c
        ? `/lightning/r/${row.Record_Id__c}/view`
        : undefined,
    }));
  }

  handleRetentionChange(event) {
    this.retention = {
      ...this.retention,
      retentionDays: Number(event.target.value),
    };
    this.retentionDirty = true;
    this.retentionConfirmed = false;
  }

  handleRetentionConfirm(event) {
    this.retentionConfirmed = event.target.checked;
  }

  async handleSaveRetention() {
    const input = this.template.querySelector("[data-retention-days]");
    if (!input.reportValidity()) return;
    this.submitting = true;
    this.errorMessage = undefined;
    try {
      this.retention = await saveRetentionSettings({
        retentionDays: this.retention.retentionDays,
      });
      this.retentionDirty = false;
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Retention settings saved",
          message:
            "Cleanup remains manual and requires confirmation for each purge.",
          variant: "success",
        }),
      );
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.submitting = false;
    }
  }

  async handlePurge() {
    this.submitting = true;
    this.errorMessage = undefined;
    try {
      const outcome = await purgeAuditRecords();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Audit retention complete",
          message: `${outcome.historiesDeleted} history and ${outcome.pendingActionsDeleted} terminal pending-action record(s) deleted.`,
          variant: "success",
        }),
      );
      this.retentionConfirmed = false;
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.submitting = false;
    }
  }

  handleRowSelection(event) {
    this.selectedIds = event.detail.selectedRows.map((row) => row.Id);
  }

  get hasSelection() {
    return this.selectedIds.length > 0;
  }

  get bulkDisabled() {
    return this.submitting || !this.hasSelection;
  }

  // Bulk decisions skip the per-action Flow contract dialog; the execution service re-validates
  // each policy at run time and fails an invalid one closed.
  async runSelectedRows() {
    await this.decide(runActions, "queued");
  }

  async rejectSelectedRows() {
    await this.decide(rejectActions, "rejected");
  }

  async decide(operation, verb) {
    this.submitting = true;
    this.errorMessage = undefined;
    try {
      const outcome = await operation({ pendingActionIds: this.selectedIds });
      this.dispatchEvent(
        new ShowToastEvent({
          title: `${outcome.processed} action(s) ${verb}`,
          message: outcome.skipped
            ? `${outcome.skipped} no longer pending review were skipped.`
            : undefined,
          variant: "success",
        }),
      );
      this.selectedIds = [];
      this.selectedAction = undefined;
      await this.loadActions();
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.submitting = false;
    }
  }

  handleRowAction(event) {
    if (event.detail.action.name === "review") {
      this.selectedAction = event.detail.row;
    }
  }

  clearSelection() {
    this.selectedAction = undefined;
  }

  async runSelected() {
    if (!this.selectedAction) return;
    this.submitting = true;
    this.errorMessage = undefined;
    try {
      const validation = await validatePolicy({
        policyId: this.selectedAction.Policy__c,
      });
      if (!validation.valid) {
        this.errorMessage = validation.errors.join(" ");
        return;
      }
      await runAction({ pendingActionId: this.selectedAction.Id });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Action queued",
          message: "The approved Flow will run asynchronously.",
          variant: "success",
        }),
      );
      this.selectedAction = undefined;
      await this.loadActions();
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.submitting = false;
    }
  }

  async rejectSelected() {
    if (!this.selectedAction) return;
    this.submitting = true;
    try {
      await rejectAction({ pendingActionId: this.selectedAction.Id });
      this.dispatchEvent(
        new ShowToastEvent({ title: "Action rejected", variant: "info" }),
      );
      this.selectedAction = undefined;
      await this.loadActions();
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.submitting = false;
    }
  }

  messageFrom(error) {
    return (
      error?.body?.message ||
      error?.message ||
      "RHC Actions could not complete the request."
    );
  }
}
