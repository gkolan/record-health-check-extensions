import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import canReplay from '@salesforce/customPermission/RHC_Integration_Replay';
import getDeadLetters from '@salesforce/apex/RHCIntegrationDeadLetterController.getDeadLetters';
import replay from '@salesforce/apex/RHCIntegrationDeadLetterController.replay';
import replayAll from '@salesforce/apex/RHCIntegrationDeadLetterController.replayAll';
import getRetentionSettings from '@salesforce/apex/RHCIntegrationDeadLetterController.getRetentionSettings';
import saveRetentionSettings from '@salesforce/apex/RHCIntegrationDeadLetterController.saveRetentionSettings';
import purgeDeliveries from '@salesforce/apex/RHCIntegrationDeadLetterController.purgeDeliveries';

const BASE_COLUMNS = [
    { label: 'Delivery', fieldName: 'deliveryNumber', type: 'text' },
    { label: 'Route', fieldName: 'routeName', type: 'text' },
    { label: 'Event ID', fieldName: 'eventId', type: 'text' },
    { label: 'Type', fieldName: 'eventType', type: 'text' },
    { label: 'Attempts', fieldName: 'attemptCount', type: 'number' },
    { label: 'HTTP', fieldName: 'httpStatus', type: 'number' },
    { label: 'Classification', fieldName: 'classification', type: 'text' },
    { label: 'Error Code', fieldName: 'errorCode', type: 'text' },
    { label: 'Completed', fieldName: 'completedAt', type: 'date' }
];

export default class RhcIntegrationDeadLetters extends LightningElement {
    rows = [];
    errorMessage;
    isLoading = false;
    retention = { retentionDays: 90, configured: false, maxDeleteRows: 1000, canManage: false };
    retentionConfirmed = false;
    retentionDirty = false;

    get columns() {
        return canReplay
            ? [...BASE_COLUMNS, {
                type: 'action',
                typeAttributes: { rowActions: [{ label: 'Replay', name: 'replay' }] }
            }]
            : BASE_COLUMNS;
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    selectedIds = [];

    connectedCallback() {
        this.refresh();
    }

    get showRetention() {
        return Boolean(this.retention?.canManage);
    }

    get hideSelection() {
        return !canReplay;
    }

    get replaySelectedDisabled() {
        return this.isLoading || this.selectedIds.length === 0;
    }

    get purgeDisabled() {
        return this.isLoading || !this.retention.configured ||
            this.retentionDirty || !this.retentionConfirmed;
    }

    handleRowSelection(event) {
        this.selectedIds = event.detail.selectedRows.map((row) => row.id);
    }

    async handleReplaySelected() {
        this.isLoading = true;
        try {
            const count = await replayAll({ deliveryIds: this.selectedIds });
            this.dispatchEvent(new ShowToastEvent({
                title: `${count} replay(s) queued`,
                message: 'Each delivery reuses its original Event ID idempotency key.',
                variant: 'success'
            }));
            this.selectedIds = [];
            await this.refresh();
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.refresh();
    }

    handleRetentionChange(event) {
        this.retention = { ...this.retention, retentionDays: Number(event.target.value) };
        this.retentionDirty = true;
        this.retentionConfirmed = false;
    }

    handleRetentionConfirm(event) {
        this.retentionConfirmed = event.target.checked;
    }

    async handleSaveRetention() {
        const input = this.template.querySelector('[data-retention-days]');
        if (!input.reportValidity()) {
            return;
        }
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            await saveRetentionSettings({ retentionDays: this.retention.retentionDays });
            this.retention = { ...this.retention, configured: true };
            this.retentionDirty = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Retention settings saved',
                message: 'Cleanup remains manual and requires confirmation for each purge.',
                variant: 'success'
            }));
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handlePurge() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const count = await purgeDeliveries();
            this.dispatchEvent(new ShowToastEvent({
                title: 'RHC Integrations',
                message: `${count} terminal delivery record(s) older than ${this.retention.retentionDays} days deleted.`,
                variant: 'success'
            }));
            this.retentionConfirmed = false;
            await this.refresh();
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleRowAction(event) {
        if (event.detail.action.name !== 'replay') {
            return;
        }
        this.isLoading = true;
        try {
            await replay({ deliveryId: event.detail.row.id });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Replay queued',
                message: 'The delivery will reuse its original Event ID idempotency key.',
                variant: 'success'
            }));
            await this.refresh();
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async refresh() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const [rows, retention] = await Promise.all([
                getDeadLetters(),
                getRetentionSettings()
            ]);
            this.rows = rows;
            this.retention = retention || this.retention;
            this.retentionDirty = false;
        } catch (error) {
            this.rows = [];
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    showError(error) {
        this.errorMessage = error?.body?.message || 'Unable to load integration delivery operations.';
        this.dispatchEvent(new ShowToastEvent({
            title: 'RHC Integrations',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
