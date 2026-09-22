import { LightningElement } from 'lwc';
import search from '@salesforce/apex/RHCLogsReviewController.search';
import { NavigationMixin } from 'lightning/navigation';

const COLUMNS = [
    { label: 'Log', fieldName: 'Name', type: 'button', typeAttributes: { label: { fieldName: 'Name' }, name: 'open', variant: 'base' } },
    { label: 'Occurred At', fieldName: 'OccurredAt__c', type: 'date', typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'Severity', fieldName: 'Severity__c' },
    { label: 'Code', fieldName: 'Code__c' },
    { label: 'Run ID', fieldName: 'RunId__c' },
    { label: 'Check Set', fieldName: 'CheckSetDeveloperName__c' },
    { label: 'Check', fieldName: 'CheckDeveloperName__c' },
    { label: 'Record ID', fieldName: 'RecordId__c' },
    { type: 'action', typeAttributes: { rowActions: [{ label: 'Show details', name: 'details' }] } }
];

export default class RhcLogsReview extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    rows = [];
    loading = true;
    errorMessage;
    filters = { pageSize: 100 };
    nextCursor;
    hasMore = false;
    selectedRow;

    connectedCallback() {
        this.load();
    }

    handleFilter(event) {
        this.filters = { ...this.filters, [event.target.name]: event.detail.value };
    }

    applyFilters() {
        this.rows = [];
        this.nextCursor = undefined;
        this.hasMore = false;
        this.load();
    }

    loadMore() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.errorMessage = undefined;
        try {
            const page = await search({
                filter: {
                    ...this.filters,
                    cursorOccurredAt: this.nextCursor?.occurredAt,
                    cursorId: this.nextCursor?.id
                }
            });
            this.rows = [...this.rows, ...(page.rows || [])];
            this.hasMore = Boolean(page.hasMore);
            this.nextCursor = this.hasMore
                ? { occurredAt: page.nextOccurredAt, id: page.nextId }
                : undefined;
        } catch (error) {
            this.errorMessage =
                error?.body?.message || error?.message || 'Logs could not be loaded.';
        } finally {
            this.loading = false;
        }
    }

    get showEmptyState() {
        return !this.loading && !this.errorMessage && this.rows.length === 0;
    }

    // Message and structured details are shown inline so an investigator can scan several rows
    // without leaving the filtered list; fields the user cannot read are simply absent.
    get selectedDetails() {
        if (!this.selectedRow) {
            return undefined;
        }
        return {
            ...this.selectedRow,
            hasMessage: this.selectedRow.Message__c !== undefined,
            hasStructuredDetails: this.selectedRow.StructuredDetails__c !== undefined
        };
    }

    closeDetails() {
        this.selectedRow = undefined;
    }

    handleRowAction(event) {
        if (event.detail.action.name === 'details') {
            this.selectedRow = event.detail.row;
            return;
        }
        if (event.detail.action.name !== 'open') {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.detail.row.Id,
                objectApiName: 'Record_Health_Check_Diagnostic_Log__c',
                actionName: 'view'
            }
        });
    }
}
