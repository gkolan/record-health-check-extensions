import { createElement } from "lwc";
import RhcActionReview from "c/rhcActionReview";
import getPendingActions from "@salesforce/apex/RHCActionReviewController.getPendingActions";
import validatePolicy from "@salesforce/apex/RHCActionReviewController.validatePolicy";
import runAction from "@salesforce/apex/RHCActionReviewController.runAction";
import rejectAction from "@salesforce/apex/RHCActionReviewController.rejectAction";
import runActions from "@salesforce/apex/RHCActionReviewController.runActions";
import rejectActions from "@salesforce/apex/RHCActionReviewController.rejectActions";

jest.mock(
  "@salesforce/apex/RHCActionReviewController.getPendingActions",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCActionReviewController.validatePolicy",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCActionReviewController.runAction",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCActionReviewController.rejectAction",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCActionReviewController.runActions",
  () => ({ default: jest.fn() }),
  { virtual: true },
);
jest.mock(
  "@salesforce/apex/RHCActionReviewController.rejectActions",
  () => ({ default: jest.fn() }),
  { virtual: true },
);

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
};
const pending = [
  {
    Id: "a00000000000001AAA",
    Name: "RHC-ACT-000001",
    Policy__c: "a01000000000001AAA",
    Policy__r: {
      Name: "Primary contact",
      Flow_API_Name__c: "Create_Data_Steward_Task",
    },
    Record_Id__c: "001000000000001AAA",
    Check_Qualified_API_Name__c: "Account_Has_Primary_Contact",
    Status__c: "FAIL",
    Severity__c: "HIGH",
    Reason_Code__c: "NO_PRIMARY_CONTACT",
  },
];

describe("c-rhc-action-review", () => {
  beforeEach(() => {
    getPendingActions.mockResolvedValue(pending);
    validatePolicy.mockResolvedValue({ valid: true, errors: [] });
    runAction.mockResolvedValue();
    rejectAction.mockResolvedValue();
    runActions.mockResolvedValue({ processed: 1, skipped: 0 });
    rejectActions.mockResolvedValue({ processed: 1, skipped: 0 });
  });

  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("loads the pending review queue", async () => {
    const element = createElement("c-rhc-action-review", {
      is: RhcActionReview,
    });
    document.body.appendChild(element);
    await flushPromises();
    expect(getPendingActions).toHaveBeenCalledTimes(1);
    expect(
      element.shadowRoot.querySelector("lightning-datatable").data,
    ).toHaveLength(1);
  });

  it("validates and queues Maya's selected action once", async () => {
    const element = createElement("c-rhc-action-review", {
      is: RhcActionReview,
    });
    document.body.appendChild(element);
    await flushPromises();
    element.shadowRoot.querySelector("lightning-datatable").dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "review" },
          row: {
            ...pending[0],
            recordUrl: "/lightning/r/001000000000001AAA/view",
          },
        },
      }),
    );
    await flushPromises();
    element.shadowRoot.querySelector("[data-action='run']").click();
    await flushPromises();
    expect(validatePolicy).toHaveBeenCalledWith({
      policyId: pending[0].Policy__c,
    });
    expect(runAction).toHaveBeenCalledWith({ pendingActionId: pending[0].Id });
  });

  it("keeps the queue busy while an approval is in flight", async () => {
    let resolveRun;
    runAction.mockImplementation(
      () => new Promise((resolve) => { resolveRun = resolve; }),
    );
    const element = createElement("c-rhc-action-review", {
      is: RhcActionReview,
    });
    document.body.appendChild(element);
    await flushPromises();
    const table = element.shadowRoot.querySelector("lightning-datatable");
    table.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { action: { name: "review" }, row: pending[0] },
      }),
    );
    await flushPromises();
    element.shadowRoot.querySelector("[data-action='run']").click();
    await flushPromises();
    expect(table.isLoading).toBe(true);
    resolveRun();
    await flushPromises();
    expect(table.isLoading).toBe(false);
  });

  it("approves the selected rows in one decision and reloads", async () => {
    const element = createElement("c-rhc-action-review", {
      is: RhcActionReview,
    });
    document.body.appendChild(element);
    await flushPromises();
    const approve = element.shadowRoot.querySelector("[data-action='approve-selected']");
    expect(approve.disabled).toBe(true);
    element.shadowRoot.querySelector("lightning-datatable").dispatchEvent(
      new CustomEvent("rowselection", { detail: { selectedRows: [pending[0]] } }),
    );
    await flushPromises();
    expect(approve.disabled).toBe(false);
    approve.click();
    await flushPromises();
    expect(runActions).toHaveBeenCalledWith({ pendingActionIds: [pending[0].Id] });
    expect(getPendingActions).toHaveBeenCalledTimes(2);
  });

  it("fails closed when the Flow contract is invalid", async () => {
    validatePolicy.mockResolvedValue({
      valid: false,
      errors: ["The Flow has no active version."],
    });
    const element = createElement("c-rhc-action-review", {
      is: RhcActionReview,
    });
    document.body.appendChild(element);
    await flushPromises();
    element.shadowRoot.querySelector("lightning-datatable").dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { action: { name: "review" }, row: pending[0] },
      }),
    );
    await flushPromises();
    element.shadowRoot.querySelector("[data-action='run']").click();
    await flushPromises();
    expect(runAction).not.toHaveBeenCalled();
    expect(
      element.shadowRoot.querySelector("[role='alert']").textContent,
    ).toContain("no active version");
  });

  it("rejects a selected action without starting Flow", async () => {
    const element = createElement("c-rhc-action-review", {
      is: RhcActionReview,
    });
    document.body.appendChild(element);
    await flushPromises();
    element.shadowRoot.querySelector("lightning-datatable").dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { action: { name: "review" }, row: pending[0] },
      }),
    );
    await flushPromises();
    element.shadowRoot.querySelector("[data-action='reject']").click();
    await flushPromises();
    expect(rejectAction).toHaveBeenCalledWith({
      pendingActionId: pending[0].Id,
    });
    expect(runAction).not.toHaveBeenCalled();
  });
});
