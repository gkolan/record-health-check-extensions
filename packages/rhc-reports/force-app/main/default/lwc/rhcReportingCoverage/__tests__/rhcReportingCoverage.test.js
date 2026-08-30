import { createElement } from 'lwc';
import RhcReportingCoverage from 'c/rhcReportingCoverage';
import getCoverage from '@salesforce/apex/RHCReportsCoverageController.getCoverage';

jest.mock(
    '@salesforce/apex/RHCReportsCoverageController.getCoverage',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('c-rhc-reporting-coverage', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders observed run and result coverage', async () => {
        getCoverage.mockResolvedValue([
            {
                checkSetQualifiedApiName: 'rhc__Opportunity_Close_Readiness',
                label: 'Opportunity Close Readiness',
                stateLabel: 'ALL — current',
                runFactCount: 12,
                resultFactCount: 48,
                latestEventAt: '2026-08-25T18:00:00.000Z'
            }
        ]);

        const element = createElement('c-rhc-reporting-coverage', {
            is: RhcReportingCoverage
        });
        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain('Opportunity Close Readiness');
        expect(element.shadowRoot.textContent).toContain('rhc__Opportunity_Close_Readiness');
        expect(element.shadowRoot.textContent).toContain('48');
    });

    it('distinguishes no observed coverage from a clean result', async () => {
        getCoverage.mockResolvedValue([]);

        const element = createElement('c-rhc-reporting-coverage', {
            is: RhcReportingCoverage
        });
        document.body.appendChild(element);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain('No active Check Sets were found.');
    });

    it('reports a sanitized load error', async () => {
        getCoverage.mockRejectedValue({ body: { message: 'Coverage access denied.' } });
        const element = createElement('c-rhc-reporting-coverage', {
            is: RhcReportingCoverage
        });
        const toastHandler = jest.fn();
        element.addEventListener('lightning__showtoast', toastHandler);
        document.body.appendChild(element);
        await flushPromises();

        expect(toastHandler).toHaveBeenCalledTimes(1);
        expect(toastHandler.mock.calls[0][0].detail.message).toBe('Coverage access denied.');
    });
});
