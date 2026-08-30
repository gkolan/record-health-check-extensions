import { LightningElement } from 'lwc';
import getStatus from '@salesforce/apex/RHCLogsAdminController.getStatus';
import saveSettings from '@salesforce/apex/RHCLogsAdminController.saveSettings';
import runCleanup from '@salesforce/apex/RHCLogsAdminController.runCleanup';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RhcLogsSetup extends LightningElement {
    status;
    errorMessage;
    loading = true;
    retentionDays;
    cleanupBatchSize = 2000;
    automatedCleanupEnabled = false;

    connectedCallback() {
        this.refresh();
    }

    async refresh() {
        this.loading = true;
        this.errorMessage = undefined;
        try {
            const result = await getStatus();
            this.status = {
                ...result,
                settings: result?.settings || {},
                checkSets: result?.checkSets || []
            };
            const settings = this.status?.settings;
            this.retentionDays = settings?.RetentionDays__c;
            this.cleanupBatchSize = settings?.CleanupBatchSize__c || 2000;
            this.automatedCleanupEnabled =
                settings?.AutomatedCleanupEnabled__c === true;
        } catch (error) {
            this.errorMessage = this.messageFrom(error);
        } finally {
            this.loading = false;
        }
    }

    get publicationSummary() {
        const sets = this.status?.checkSets || [];
        const enabled = sets.filter(item => item.publishesLogEvents).length;
        return `${enabled} of ${sets.length} visible Check Sets publish Log events.`;
    }

    handleRetentionChange(event) {
        this.retentionDays = event.detail.value;
    }

    handleBatchChange(event) {
        this.cleanupBatchSize = event.detail.value;
    }

    handleAutomationChange(event) {
        this.automatedCleanupEnabled = event.detail.checked;
    }

    async handleSave() {
        await this.perform(
            () =>
                saveSettings({
                    settingsInput: {
                        retentionDays: Number(this.retentionDays),
                        cleanupBatchSize: Number(this.cleanupBatchSize),
                        automatedCleanupEnabled: this.automatedCleanupEnabled
                    }
                }),
            'Retention settings saved.'
        );
    }

    async handleCleanup() {
        await this.perform(runCleanup, 'Bounded cleanup completed.');
    }

    async perform(operation, successMessage) {
        this.loading = true;
        this.errorMessage = undefined;
        try {
            await operation();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'RHC Logs',
                    message: successMessage,
                    variant: 'success'
                })
            );
            await this.refresh();
        } catch (error) {
            this.errorMessage = this.messageFrom(error);
            this.loading = false;
        }
    }

    messageFrom(error) {
        return error?.body?.message || error?.message || 'The request could not be completed.';
    }
}
