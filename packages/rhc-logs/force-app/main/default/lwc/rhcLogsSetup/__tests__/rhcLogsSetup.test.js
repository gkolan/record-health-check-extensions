import { createElement } from 'lwc';
import RhcLogsSetup from 'c/rhcLogsSetup';
import getStatus from '@salesforce/apex/RHCLogsAdminController.getStatus';
import saveSettings from '@salesforce/apex/RHCLogsAdminController.saveSettings';
import runCleanup from '@salesforce/apex/RHCLogsAdminController.runCleanup';

jest.mock('@salesforce/apex/RHCLogsAdminController.getStatus', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCLogsAdminController.saveSettings', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCLogsAdminController.runCleanup', () => ({ default: jest.fn() }), { virtual: true });

const STATUS = {
    minimumCoreVersion: '2.0.4.2',
    coreLogEventInstalled: true,
    coreContractCompatible: true,
    currentUserCanReadCoreEvent: true,
    currentUserCanPublishCoreEvent: false,
    checkSets: [
        { developerName: 'Managed__Account_Readiness', publishesLogEvents: true },
        { developerName: 'Contact_Readiness', publishesLogEvents: false }
    ],
    settings: {
        RetentionDays__c: 30,
        CleanupBatchSize__c: 2000,
        AutomatedCleanupEnabled__c: false,
        LastIngestionCount__c: 12,
        LastDuplicateCount__c: 2,
        LastIngestionFailureCount__c: 1,
        LastIngestionStatus__c: 'PARTIAL_FAILURE',
        LastIngestionErrorCodes__c: 'MALFORMED_CONTRACT',
        LastCleanupStatus__c: 'SUCCESS',
        LastCleanupDeletedCount__c: 3,
        LastCleanupFailureCount__c: 0,
        CleanupInProgress__c: false
    },
    cleanupScheduled: false,
    retainedCount: 4,
    unsupportedContractCount: 1
};

const flushPromises = async () => {
    await Promise.resolve();
    await Promise.resolve();
};

describe('c-rhc-logs-setup', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.clearAllMocks();
    });

    it('renders core, publication, retention, and operations findings', async () => {
        getStatus.mockResolvedValue(STATUS);
        const element = createElement('c-rhc-logs-setup', { is: RhcLogsSetup });
        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain('Minimum compatible promoted core');
        expect(element.shadowRoot.textContent).toContain('1 of 2 visible Check Sets');
        expect(element.shadowRoot.textContent).toContain('Managed__Account_Readiness');
        expect(element.shadowRoot.textContent).toContain('Retained logs');
        expect(element.shadowRoot.textContent).toContain('Unsupported retained contract versions');
        expect(element.shadowRoot.textContent).toContain('Failures in last ingestion batch');
        expect(element.shadowRoot.textContent).toContain('Cleanup lease active');
    });

    it('saves deliberately configured bounded retention', async () => {
        getStatus.mockResolvedValue(STATUS);
        saveSettings.mockResolvedValue(STATUS);
        const element = createElement('c-rhc-logs-setup', { is: RhcLogsSetup });
        document.body.appendChild(element);
        await flushPromises();

        const inputs = element.shadowRoot.querySelectorAll('lightning-input');
        inputs[0].dispatchEvent(new CustomEvent('change', { detail: { value: '45' } }));
        inputs[1].dispatchEvent(new CustomEvent('change', { detail: { value: '500' } }));
        inputs[2].dispatchEvent(new CustomEvent('change', { detail: { checked: true } }));
        element.shadowRoot.querySelectorAll('lightning-button')[0].click();
        await flushPromises();

        expect(saveSettings).toHaveBeenCalledWith({
            settingsInput: {
                retentionDays: 45,
                cleanupBatchSize: 500,
                automatedCleanupEnabled: true
            }
        });
    });

    it('invokes one bounded manual cleanup', async () => {
        getStatus.mockResolvedValue(STATUS);
        runCleanup.mockResolvedValue({ status: 'SUCCESS', deletedCount: 2, failureCount: 0 });
        const element = createElement('c-rhc-logs-setup', { is: RhcLogsSetup });
        document.body.appendChild(element);
        await flushPromises();

        element.shadowRoot.querySelectorAll('lightning-button')[1].click();
        await flushPromises();

        expect(runCleanup).toHaveBeenCalledTimes(1);
    });

    it('shows a sanitized setup error', async () => {
        getStatus.mockRejectedValue({ body: { message: 'Access denied.' } });
        const element = createElement('c-rhc-logs-setup', { is: RhcLogsSetup });
        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.error-message').textContent).toContain('Access denied.');
    });

    it('shows a sanitized cleanup error', async () => {
        getStatus.mockResolvedValue(STATUS);
        runCleanup.mockRejectedValue(new Error('Cleanup unavailable.'));
        const element = createElement('c-rhc-logs-setup', { is: RhcLogsSetup });
        document.body.appendChild(element);
        await flushPromises();

        element.shadowRoot.querySelectorAll('lightning-button')[1].click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('.error-message').textContent)
            .toContain('Cleanup unavailable.');
    });

    it('uses safe defaults before the singleton settings record exists', async () => {
        getStatus.mockResolvedValue({ ...STATUS, settings: null, checkSets: null });
        const element = createElement('c-rhc-logs-setup', { is: RhcLogsSetup });
        document.body.appendChild(element);
        await flushPromises();

        const inputs = element.shadowRoot.querySelectorAll('lightning-input');
        expect(inputs[1].value).toBe(2000);
        expect(element.shadowRoot.textContent).toContain('0 of 0 visible Check Sets');
    });

    it('uses a safe fallback for an unstructured operation error', async () => {
        getStatus.mockResolvedValue(STATUS);
        runCleanup.mockRejectedValue({});
        const element = createElement('c-rhc-logs-setup', { is: RhcLogsSetup });
        document.body.appendChild(element);
        await flushPromises();

        element.shadowRoot.querySelectorAll('lightning-button')[1].click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('.error-message').textContent)
            .toContain('The request could not be completed.');
    });
});
