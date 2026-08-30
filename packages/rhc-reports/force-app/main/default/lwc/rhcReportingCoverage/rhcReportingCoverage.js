import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCoverage from "@salesforce/apex/RHCReportsCoverageController.getCoverage";
export default class RhcReportingCoverage extends LightningElement {
    rows = [];
    loading = true;
    connectedCallback() {
        this.load();
    }
    get hasRows() {
        return this.rows.length > 0;
    }
    async load() {
        this.loading = true;
        try {
            this.rows = await getCoverage();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Unable to load reporting coverage",
                    message: error?.body?.message || error?.message || "Unexpected error",
                    variant: "error"
                })
            );
        } finally {
            this.loading = false;
        }
    }
}
