import { createElement } from 'lwc';
import RhcIntegrationDeadLetters from 'c/rhcIntegrationDeadLetters';
import getDeadLetters from '@salesforce/apex/RHCIntegrationDeadLetterController.getDeadLetters';

jest.mock('@salesforce/customPermission/RHC_Integration_Replay', () => ({ default: false }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.getDeadLetters', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/RHCIntegrationDeadLetterController.replay', () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
};

describe('c-rhc-integration-dead-letters viewer', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('does not expose the replay action without the custom permission', async () => {
        getDeadLetters.mockResolvedValue([{ id: 'a01000000000001AAA' }]);
        const element = createElement('c-rhc-integration-dead-letters', { is: RhcIntegrationDeadLetters });
        document.body.appendChild(element);
        await flushPromises();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.columns).toHaveLength(9);
        expect(table.columns.some((column) => column.type === 'action')).toBe(false);
    });
});
