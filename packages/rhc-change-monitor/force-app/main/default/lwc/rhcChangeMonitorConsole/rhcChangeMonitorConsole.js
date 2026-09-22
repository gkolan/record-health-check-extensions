import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getStatus from "@salesforce/apex/RHCChangeMonitorAdminController.getStatus";
import retryFailed from "@salesforce/apex/RHCChangeMonitorAdminController.retryFailed";
import dispatchPending from "@salesforce/apex/RHCChangeMonitorAdminController.dispatchPending";
import getRetentionSettings from "@salesforce/apex/RHCChangeMonitorAdminController.getRetentionSettings";
import saveRetentionSettings from "@salesforce/apex/RHCChangeMonitorAdminController.saveRetentionSettings";
import purgeEvaluations from "@salesforce/apex/RHCChangeMonitorAdminController.purgeEvaluations";

const SUMMARY_COLUMNS = [
  { label: "Outcome", fieldName: "outcome" },
  { label: "Reason", fieldName: "reasonCode" },
  { label: "Last 7 days", fieldName: "count", type: "number" }
];
const POLICY_COLUMNS = [
  { label: "Policy", fieldName: "DisplayName__c" },
  { label: "Active", fieldName: "Active__c", type: "boolean" },
  { label: "Object", fieldName: "SourceObjectApiName__c" },
  { label: "Selection", fieldName: "QualifiedApiName__c" },
  { label: "Change types", fieldName: "ChangeTypes__c" },
  { label: "Publication", fieldName: "EventPublication__c" }
];
const RECENT_COLUMNS = [
  { label: "Claim", fieldName: "Name" },
  { label: "Policy", fieldName: "policyName" },
  { label: "Change", fieldName: "ChangeType__c" },
  { label: "Outcome", fieldName: "Outcome__c" },
  { label: "Reason", fieldName: "ReasonCode__c" },
  { label: "Record", fieldName: "RecordId__c" },
  { label: "Attempts", fieldName: "AttemptCount__c", type: "number" },
  { label: "Actionable", fieldName: "ActionableCount__c", type: "number" },
  { label: "Accepted", fieldName: "AcceptedAt__c", type: "date", typeAttributes: { month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" } }
];

export default class RhcChangeMonitorConsole extends LightningElement {
  summaryColumns = SUMMARY_COLUMNS;
  policyColumns = POLICY_COLUMNS;
  recentColumns = RECENT_COLUMNS;
  status;
  loading = true;
  errorMessage;
  retention = { retentionDays: 90, configured: false, maxDeleteRows: 1000 };
  retentionConfirmed = false;
  retentionDirty = false;

  connectedCallback() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.errorMessage = undefined;
    try {
      const [result, retention] = await Promise.all([
        getStatus(),
        getRetentionSettings()
      ]);
      this.status = {
        ...result,
        recent: (result.recent || []).map((row) => ({ ...row, policyName: row.Policy__r?.DisplayName__c }))
      };
      this.retention = retention;
      this.retentionDirty = false;
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.loading = false;
    }
  }

  get principalWarning() {
    const buckets = this.status?.lastSevenDays || [];
    return buckets.some((b) => b.reasonCode === "RUNTIME_PERMISSION_MISSING")
      ? "Claims failed with RUNTIME_PERMISSION_MISSING: the dispatch trigger is running as Automated Process. Create a PlatformEventSubscriberConfig for RHCChangeMonitorDispatchSubscriber naming a runtime user that holds RHC Change Monitor Runtime and the core Record Health Check User permission sets, then use Retry failed claims."
      : undefined;
  }

  handleRetentionChange(event) {
    this.retention = {
      ...this.retention,
      retentionDays: Number(event.target.value)
    };
    this.retentionDirty = true;
    this.retentionConfirmed = false;
  }

  handleRetentionConfirm(event) {
    this.retentionConfirmed = event.target.checked;
  }

  get purgeDisabled() {
    return (
      this.loading ||
      !this.retention.configured ||
      this.retentionDirty ||
      !this.retentionConfirmed
    );
  }

  get dispatchDisabled() {
    return (
      this.loading ||
      !this.status ||
      this.status.pendingCount < 1 ||
      this.status.dispatcherQueued
    );
  }

  async handleRetry() {
    await this.perform(retryFailed, (count) => `${count} claim(s) returned to PENDING and dispatch requested.`);
  }

  async handleDispatchPending() {
    await this.perform(
      dispatchPending,
      (count) => `Dispatch requested for ${count} pending claim(s).`
    );
  }

  async handleSaveRetention() {
    const input = this.template.querySelector("[data-retention-days]");
    if (!input.reportValidity()) return;
    this.loading = true;
    this.errorMessage = undefined;
    try {
      await saveRetentionSettings({
        retentionDays: this.retention.retentionDays
      });
      this.retention = { ...this.retention, configured: true };
      this.retentionDirty = false;
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Retention settings saved",
          message: "Cleanup remains manual and requires confirmation for each purge.",
          variant: "success"
        })
      );
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
    } finally {
      this.loading = false;
    }
  }

  async handlePurge() {
    await this.perform(
      purgeEvaluations,
      (count) => `${count} terminal claim(s) older than ${this.retention.retentionDays} days deleted.`
    );
    this.retentionConfirmed = false;
  }

  async perform(operation, message) {
    this.loading = true;
    this.errorMessage = undefined;
    try {
      const result = await operation();
      this.dispatchEvent(new ShowToastEvent({ title: "RHC Change Monitor", message: message(result), variant: "success" }));
      await this.refresh();
    } catch (error) {
      this.errorMessage = this.messageFrom(error);
      this.loading = false;
    }
  }

  messageFrom(error) {
    return error?.body?.message || error?.message || "The request could not be completed.";
  }
}
