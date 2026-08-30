import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import canReplay from '@salesforce/customPermission/RHC_Integration_Replay';
import getDeadLetters from '@salesforce/apex/RHCIntegrationDeadLetterController.getDeadLetters';
import replay from '@salesforce/apex/RHCIntegrationDeadLetterController.replay';

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

    connectedCallback() {
        this.loadRows();
    }

    handleRefresh() {
        this.loadRows();
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
            await this.loadRows();
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadRows() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            this.rows = await getDeadLetters();
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
