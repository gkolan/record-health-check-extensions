import { LightningElement } from "lwc";
import listDeliveries from "@salesforce/apex/RHCAlertsViewerController.listDeliveries";

export default class RhcAlertsDeliveryHistory extends LightningElement {
  deliveries = [];
  loading = true;
  errorMessage;
  columns = [
    { label: "Delivery", fieldName: "Name" },
    { label: "Policy", fieldName: "policyName" },
    { label: "Outcome", fieldName: "Outcome__c" },
    { label: "Status", fieldName: "Status__c" },
    { label: "Severity", fieldName: "Severity__c" },
    { label: "Attempts", fieldName: "AttemptCount__c", type: "number" },
    { label: "Recipients", fieldName: "RecipientCount__c", type: "number" },
    { label: "Suppression", fieldName: "SuppressionReason__c" },
    { label: "Failure class", fieldName: "FailureClass__c" },
    { label: "Error code", fieldName: "ErrorCode__c" },
    {
      label: "Occurred",
      fieldName: "OccurredAt__c",
      type: "date",
      typeAttributes: {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit"
      }
    }
  ];

  connectedCallback() {
    this.refresh();
  }
  get isEmpty() {
    return !this.loading && !this.errorMessage && this.deliveries.length === 0;
  }

  async refresh() {
    if (this.loading && this.deliveries.length > 0) return;
    this.loading = true;
    this.errorMessage = undefined;
    try {
      const rows = await listDeliveries();
      this.deliveries = rows.map((row) => ({
        ...row,
        policyName: row.Policy__r?.DisplayName__c ?? ""
      }));
    } catch (error) {
      this.errorMessage =
        error?.body?.message ?? "Delivery history could not be loaded.";
    } finally {
      this.loading = false;
    }
  }
}
