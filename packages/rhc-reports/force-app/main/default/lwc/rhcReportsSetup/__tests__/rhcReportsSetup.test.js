import { createElement } from 'lwc';
import RhcReportsSetup from 'c/rhcReportsSetup';
import getSettings from '@salesforce/apex/RHCReportsSetupController.getSettings';
import saveSettings from '@salesforce/apex/RHCReportsSetupController.saveSettings';
import runAggregationNow from '@salesforce/apex/RHCReportsSetupController.runAggregationNow';

jest.mock(
    '@salesforce/apex/RHCReportsSetupController.getSettings',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/RHCReportsSetupController.saveSettings',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/RHCReportsSetupController.runAggregationNow',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const SETTINGS = {
    detailedRetentionDays: 90,
    snapshotRetentionDays: 730,
    dailyAggregationEnabled: true,
    retentionCleanupEnabled: false,
    aggregationTimeZone: 'America/Chicago',
    scheduled: false,
    lastAggregatedDate: '2026-08-28',
    lastAggregationAttemptAt: '2026-08-29T07:15:00.000Z',
    lastAggregationStatus: 'SUCCESS',
    lastAggregationErrorType: null
};
const flushPromises = async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
};

describe('c-rhc-reports-setup', () => {
    beforeEach(() => {
        getSettings.mockResolvedValue(SETTINGS);
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('loads retention and publication guidance', async () => {
        const element = createElement('c-rhc-reports-setup', { is: RhcReportsSetup });
        document.body.appendChild(element);
        await flushPromises();

        expect(getSettings).toHaveBeenCalledTimes(1);
        expect(element.shadowRoot.textContent).toContain('Choose publication coverage deliberately');
        expect(element.shadowRoot.textContent).toContain('Retention deletion is irreversible');
        expect(element.shadowRoot.textContent).toContain('Latest aggregation outcome');
        expect(element.shadowRoot.textContent).toContain('SUCCESS');
    });

    it('saves normalized settings after client validation', async () => {
        saveSettings.mockResolvedValue({ ...SETTINGS, detailedRetentionDays: 120 });
        const element = createElement('c-rhc-reports-setup', { is: RhcReportsSetup });
        document.body.appendChild(element);
        await flushPromises();

        const inputs = element.shadowRoot.querySelectorAll('lightning-input');
        inputs.forEach((input) => {
            input.checkValidity = jest.fn(() => true);
            input.reportValidity = jest.fn();
        });
        inputs[0].value = '120';
        inputs[0].dispatchEvent(new CustomEvent('change'));
        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();

        expect(saveSettings).toHaveBeenCalledWith({
            detailedRetentionDays: 120,
            snapshotRetentionDays: 730,
            dailyAggregationEnabled: true,
            retentionCleanupEnabled: false,
            aggregationTimeZone: 'America/Chicago',
            scheduled: false
        });
    });

    it('queues aggregation on demand and reloads the outcome', async () => {
        runAggregationNow.mockResolvedValue('2026-09-17');
        const element = createElement('c-rhc-reports-setup', { is: RhcReportsSetup });
        document.body.appendChild(element);
        await flushPromises();
        element.shadowRoot.querySelector("[data-action='run-now']").click();
        await flushPromises();
        expect(runAggregationNow).toHaveBeenCalledTimes(1);
        expect(getSettings).toHaveBeenCalledTimes(2);
    });
});
