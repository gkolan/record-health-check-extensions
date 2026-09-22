import { createElement } from 'lwc';
import RhcIntegrationDeadLetters from 'c/rhcIntegrationDeadLetters';
import getDeadLetters from '@salesforce/apex/RHCIntegrationDeadLetterController.getDeadLetters';
import replay from '@salesforce/apex/RHCIntegrationDeadLetterController.replay';
import replayAll from '@salesforce/apex/RHCIntegrationDeadLetterController.replayAll';
import getRetentionSettings from '@salesforce/apex/RHCIntegrationDeadLetterController.getRetentionSettings';
import saveRetentionSettings from '@salesforce/apex/RHCIntegrationDeadLetterController.saveRetentionSettings';
import purgeDeliveries from '@salesforce/apex/RHCIntegrationDeadLetterController.purgeDeliveries';

jest.mock('@salesforce/customPermission/RHC_Integration_Replay', () => ({ default: true }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.getDeadLetters', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.replay', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.replayAll', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.getRetentionSettings', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.saveRetentionSettings', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.purgeDeliveries', () => ({ default: jest.fn() }), { virtual: true });

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
    beforeEach(() => {
        getRetentionSettings.mockResolvedValue({
            retentionDays: 90,
            configured: false,
            maxDeleteRows: 1000,
            canManage: true
        });
    });

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

    it('replays the selected rows in one request', async () => {
        getDeadLetters.mockResolvedValue([ROW]);
        replayAll.mockResolvedValue(1);
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        const button = element.shadowRoot.querySelector("[data-action='replay-selected']");
        expect(button.disabled).toBe(true);
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowselection', {
            detail: { selectedRows: [ROW] }
        }));
        await flushPromises();
        expect(button.disabled).toBe(false);
        button.click();
        await flushPromises();
        expect(replayAll).toHaveBeenCalledWith({ deliveryIds: [ROW.id] });
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
        [...element.shadowRoot.querySelectorAll('lightning-button')].find((b) => b.label === 'Refresh').click();
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

    it('surfaces a bulk replay rejection', async () => {
        getDeadLetters.mockResolvedValue([ROW]);
        replayAll.mockRejectedValue({ body: { message: 'Activate and correct the route before replay.' } });
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        const toastHandler = jest.fn();
        element.addEventListener('lightning__showtoast', toastHandler);
        document.body.appendChild(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowselection', {
            detail: { selectedRows: [ROW] }
        }));
        await flushPromises();
        element.shadowRoot.querySelector("[data-action='replay-selected']").click();
        await flushPromises();
        expect(toastHandler.mock.calls.at(-1)[0].detail.message).toContain('Activate and correct');
    });

    it('saves a validated retention window without authorizing automatic cleanup', async () => {
        getDeadLetters.mockResolvedValue([]);
        saveRetentionSettings.mockResolvedValue();
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        const input = element.shadowRoot.querySelector('[data-retention-days]');
        input.value = 45;
        input.reportValidity = jest.fn(() => true);
        input.dispatchEvent(new CustomEvent('change'));
        await flushPromises();
        element.shadowRoot.querySelector("[data-action='save-retention']").click();
        await flushPromises();
        expect(saveRetentionSettings).toHaveBeenCalledWith({ retentionDays: 45 });
        expect(element.shadowRoot.querySelector("[data-action='purge']").disabled).toBe(true);
    });

    it('requires confirmation before a bounded terminal-delivery purge', async () => {
        getDeadLetters.mockResolvedValue([]);
        getRetentionSettings.mockResolvedValue({
            retentionDays: 30,
            configured: true,
            maxDeleteRows: 1000,
            canManage: true
        });
        purgeDeliveries.mockResolvedValue(2);
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        const purgeButton = element.shadowRoot.querySelector("[data-action='purge']");
        expect(purgeButton.disabled).toBe(true);
        const confirmation = element.shadowRoot.querySelector('[data-retention-confirm]');
        confirmation.checked = true;
        confirmation.dispatchEvent(new CustomEvent('change'));
        await flushPromises();
        expect(purgeButton.disabled).toBe(false);
        purgeButton.click();
        await flushPromises();
        expect(purgeDeliveries).toHaveBeenCalledTimes(1);
        expect(getDeadLetters).toHaveBeenCalledTimes(2);
        expect(purgeButton.disabled).toBe(true);
    });

    it('hides retention controls from users without management access', async () => {
        getDeadLetters.mockResolvedValue([]);
        getRetentionSettings.mockResolvedValue({
            retentionDays: 90,
            configured: false,
            maxDeleteRows: 1000,
            canManage: false
        });
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        expect(element.shadowRoot.querySelector('[data-retention-days]')).toBeNull();
        expect(element.shadowRoot.querySelector("[data-action='purge']")).toBeNull();
    });

    it('does not save an invalid retention window', async () => {
        getDeadLetters.mockResolvedValue([]);
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();
        const input = element.shadowRoot.querySelector('[data-retention-days]');
        input.reportValidity = jest.fn(() => false);
        element.shadowRoot.querySelector("[data-action='save-retention']").click();
        await flushPromises();
        expect(saveRetentionSettings).not.toHaveBeenCalled();
    });

    it('surfaces retention save and purge rejections', async () => {
        getDeadLetters.mockResolvedValue([]);
        getRetentionSettings.mockResolvedValue({
            retentionDays: 30,
            configured: true,
            maxDeleteRows: 1000,
            canManage: true
        });
        saveRetentionSettings.mockRejectedValue({ body: { message: 'Retention save denied' } });
        purgeDeliveries.mockRejectedValue({ body: { message: 'Retention purge denied' } });
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();

        const input = element.shadowRoot.querySelector('[data-retention-days]');
        input.reportValidity = jest.fn(() => true);
        element.shadowRoot.querySelector("[data-action='save-retention']").click();
        await flushPromises();
        expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe('Retention save denied');

        const confirmation = element.shadowRoot.querySelector('[data-retention-confirm]');
        confirmation.checked = true;
        confirmation.dispatchEvent(new CustomEvent('change'));
        await flushPromises();
        element.shadowRoot.querySelector("[data-action='purge']").click();
        await flushPromises();
        expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe('Retention purge denied');
    });
});
