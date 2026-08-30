import { createElement } from 'lwc';
import RhcIntegrationDeadLetters from 'c/rhcIntegrationDeadLetters';
import getDeadLetters from '@salesforce/apex/RHCIntegrationDeadLetterController.getDeadLetters';
import replay from '@salesforce/apex/RHCIntegrationDeadLetterController.replay';

jest.mock('@salesforce/customPermission/RHC_Integration_Replay', () => ({ default: true }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.getDeadLetters', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.replay', () => ({ default: jest.fn() }), { virtual: true });

const ROW = {
    id: 'a01000000000001AAA',
    deliveryNumber: 'RHCD-00000001',
    routeName: 'Service Management Errors',
    eventId: 'event-001',
    eventType: 'RESULT',
    attemptCount: 1,
    httpStatus: 400,
    classification: 'PERMANENT',
    errorCode: 'HTTP_400'
};
const flushPromises = async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
};

describe('c-rhc-integration-dead-letters', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders dead-letter rows returned by Apex', async () => {
        getDeadLetters.mockResolvedValue([ROW]);
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table).not.toBeNull();
        expect(table.data).toEqual([ROW]);
    });

    it('replays the selected delivery and refreshes the rows', async () => {
        getDeadLetters.mockResolvedValue([ROW]);
        replay.mockResolvedValue();
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowaction', {
            detail: { action: { name: 'replay' }, row: ROW }
        }));
        await flushPromises();
        expect(replay).toHaveBeenCalledWith({ deliveryId: ROW.id });
        expect(getDeadLetters).toHaveBeenCalledTimes(2);
    });

    it('shows an accessible error when Apex rejects the load', async () => {
        getDeadLetters.mockRejectedValue({ body: { message: 'Access denied' } });
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        const alert = element.shadowRoot.querySelector('[role="alert"]');
        expect(alert).not.toBeNull();
        expect(alert.textContent).toBe('Access denied');
    });

    it('uses a bounded fallback when Apex returns an unstructured error', async () => {
        getDeadLetters.mockRejectedValue(new Error('Untrusted transport detail'));
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        const alert = element.shadowRoot.querySelector('[role="alert"]');
        expect(alert.textContent).toBe('Unable to load integration delivery operations.');
        expect(alert.textContent).not.toContain('Untrusted transport detail');
    });

    it('refreshes when the administrator selects Refresh', async () => {
        getDeadLetters.mockResolvedValue([]);
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();
        expect(getDeadLetters).toHaveBeenCalledTimes(2);
    });

    it('preserves the dead-letter row when replay is rejected', async () => {
        getDeadLetters.mockResolvedValue([ROW]);
        replay.mockRejectedValue({ body: { message: 'Replay denied' } });
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowaction', {
            detail: { action: { name: 'replay' }, row: ROW }
        }));
        await flushPromises();
        expect(replay).toHaveBeenCalledWith({ deliveryId: ROW.id });
        expect(element.shadowRoot.querySelector('lightning-datatable').data).toEqual([ROW]);
    });

    it('ignores unknown datatable actions', async () => {
        getDeadLetters.mockResolvedValue([ROW]);
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowaction', {
            detail: { action: { name: 'inspect' }, row: ROW }
        }));
        await flushPromises();
        expect(replay).not.toHaveBeenCalled();
    });
});
