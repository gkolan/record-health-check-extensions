import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getSettings from "@salesforce/apex/RHCReportsSetupController.getSettings";
import saveSettings from "@salesforce/apex/RHCReportsSetupController.saveSettings";
export default class RhcReportsSetup extends LightningElement {
    settings = {};
    loading = true;
    saving = false;
    connectedCallback() {
        this.load();
    }
    async load() {
        this.loading = true;
        try {
            this.settings = await getSettings();
        } catch (error) {
            this.toast("Unable to load setup", this.message(error), "error");
        } finally {
            this.loading = false;
        }
    }
    handleChange(event) {
        const { name, type, checked, value } = event.target;
        const parsedValue = type === "toggle" ? checked : value;
        this.settings = { ...this.settings, [name]: parsedValue };
    }
    async save() {
        if (!this.validate()) {
            return;
        }
        this.saving = true;
        try {
            this.settings = await saveSettings({
                detailedRetentionDays: Number(this.settings.detailedRetentionDays),
                snapshotRetentionDays: Number(this.settings.snapshotRetentionDays),
                dailyAggregationEnabled: this.settings.dailyAggregationEnabled,
                retentionCleanupEnabled: this.settings.retentionCleanupEnabled,
                aggregationTimeZone: this.settings.aggregationTimeZone,
                scheduled: this.settings.scheduled
            });
            this.toast("RHC Reports configured", "Settings and maintenance schedule were saved.", "success");
        } catch (error) {
            this.toast("Unable to save setup", this.message(error), "error");
        } finally {
            this.saving = false;
        }
    }
    validate() {
        return [...this.template.querySelectorAll("lightning-input")].reduce(
            (valid, input) => {
                input.reportValidity();
                return input.checkValidity() && valid;
            },
            true
        );
    }
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    message(error) {
        return error?.body?.message || error?.message || "Unexpected error";
    }
}
