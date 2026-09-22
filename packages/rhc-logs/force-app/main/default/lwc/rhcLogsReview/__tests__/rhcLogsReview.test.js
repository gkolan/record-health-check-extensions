import { createElement } from 'lwc';
import RhcLogsReview from 'c/rhcLogsReview';
import search from '@salesforce/apex/RHCLogsReviewController.search';

const mockNavigate = jest.fn();

jest.mock('lightning/navigation', () => {
    const Navigate = Symbol('Navigate');
    const NavigationMixin = Base => class extends Base {
        [Navigate](pageReference) {
            mockNavigate(pageReference);
        }
    };
    NavigationMixin.Navigate = Navigate;
    return { NavigationMixin };
}, { virtual: true });

jest.mock('@salesforce/apex/RHCLogsReviewController.search', () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = async () => {
    await Promise.resolve();
    await Promise.resolve();
};

describe('c-rhc-logs-review', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.clearAllMocks();
    });

    it('renders retained logs without requiring restricted fields', async () => {
        search.mockResolvedValue({
            rows: [{
                Id: 'a00000000000001AAA',
                Name: 'RHL-0000001',
                Severity__c: 'ERROR',
                Code__c: 'APEX_EVALUATOR_ERROR',
                RunId__c: 'run-1',
                CheckSetDeveloperName__c: 'Managed__Account_Readiness'
            }],
            hasMore: false
        });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data).toHaveLength(1);
        expect(table.data[0].Message__c).toBeUndefined();
        expect(element.shadowRoot.textContent).toContain('Execution Source filtering is unavailable');
    });

    it('sends exact administrator filters to Apex', async () => {
        search.mockResolvedValue({ rows: [], hasMore: false });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();

        const code = element.shadowRoot.querySelectorAll('lightning-input')[3];
        code.value = 'UNHANDLED_EXCEPTION';
        code.dispatchEvent(new CustomEvent('change', { detail: { value: 'UNHANDLED_EXCEPTION' } }));
        [...element.shadowRoot.querySelectorAll('lightning-button')]
            .find(button => button.label === 'Apply Filters')
            .click();
        await flushPromises();

        expect(search).toHaveBeenLastCalledWith({
            filter: expect.objectContaining({ code: 'UNHANDLED_EXCEPTION', pageSize: 100 })
        });
    });

    it('renders an empty state', async () => {
        search.mockResolvedValue({ rows: [], hasMore: false });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.empty-state')).not.toBeNull();
    });

    it('opens a retained log through standard record navigation', async () => {
        search.mockResolvedValue({
            rows: [{ Id: 'a00000000000001AAA', Name: 'RHL-0000001' }],
            hasMore: false
        });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();

        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(
            new CustomEvent('rowaction', {
                detail: { action: { name: 'open' }, row: { Id: 'a00000000000001AAA' } }
            })
        );

        expect(mockNavigate).toHaveBeenCalledWith({
            type: 'standard__recordPage',
            attributes: {
                recordId: 'a00000000000001AAA',
                objectApiName: 'Record_Health_Check_Diagnostic_Log__c',
                actionName: 'view'
            }
        });
    });

    it('renders a sanitized load error', async () => {
        search.mockRejectedValue({ body: { message: 'You do not have access.' } });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.error-message').textContent)
            .toContain('You do not have access.');
    });

    it('appends the next keyset page without replacing earlier rows', async () => {
        search
            .mockResolvedValueOnce({
                rows: [{ Id: 'a00000000000001AAA', Name: 'RHL-0000001' }],
                hasMore: true,
                nextOccurredAt: '2026-08-30T12:00:00.000Z',
                nextId: 'a00000000000001AAA'
            })
            .mockResolvedValueOnce({
                rows: [{ Id: 'a00000000000002AAA', Name: 'RHL-0000002' }],
                hasMore: false
            });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();

        [...element.shadowRoot.querySelectorAll('lightning-button')]
            .find(button => button.label === 'Load More Logs')
            .click();
        await flushPromises();

        expect(search).toHaveBeenLastCalledWith({
            filter: expect.objectContaining({
                cursorOccurredAt: '2026-08-30T12:00:00.000Z',
                cursorId: 'a00000000000001AAA'
            })
        });
        expect(element.shadowRoot.querySelector('lightning-datatable').data).toHaveLength(2);
    });

    it('ignores unrelated row actions', async () => {
        search.mockResolvedValue({
            rows: [{ Id: 'a00000000000001AAA', Name: 'RHL-0000001' }],
            hasMore: false
        });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(
            new CustomEvent('rowaction', {
                detail: { action: { name: 'ignore' }, row: { Id: 'a00000000000001AAA' } }
            })
        );

        expect(mockNavigate).not.toHaveBeenCalled();
    });

    it('handles an empty page payload safely', async () => {
        search.mockResolvedValue({ rows: null, hasMore: false });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.empty-state')).not.toBeNull();
    });

    it('uses a safe fallback for an unstructured load error', async () => {
        search.mockRejectedValue({});
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.error-message').textContent)
            .toContain('Logs could not be loaded.');
    });

    it('shows message and structured details inline for a selected row', async () => {
        search.mockResolvedValue({
            rows: [{ Id: 'a00000000000001AAA', Name: 'RHL-0000001', Code__c: 'SOQL_ERROR', Message__c: 'boom', StructuredDetails__c: '{"a":1}' }],
            hasMore: false
        });
        const element = createElement('c-rhc-logs-review', { is: RhcLogsReview });
        document.body.appendChild(element);
        await flushPromises();
        const [row] = element.shadowRoot.querySelector('lightning-datatable').data;
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(
            new CustomEvent('rowaction', { detail: { action: { name: 'details' }, row } })
        );
        await flushPromises();
        expect(element.shadowRoot.querySelector("[data-field='message']").textContent).toBe('boom');
        expect(element.shadowRoot.querySelector("[data-field='details']").textContent).toBe('{"a":1}');
        expect(mockNavigate).not.toHaveBeenCalled();
        element.shadowRoot.querySelector('lightning-button-icon').click();
        await flushPromises();
        expect(element.shadowRoot.querySelector("[data-region='details']")).toBeNull();
    });
});
