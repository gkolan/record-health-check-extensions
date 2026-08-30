import { createElement } from "lwc";
import RhcAlertsAdmin from "c/rhcAlertsAdmin";
import listPolicies from "@salesforce/apex/RHCAlertsAdminController.listPolicies";
import listSelections from "@salesforce/apex/RHCAlertsAdminController.listSelections";
import listRecipients from "@salesforce/apex/RHCAlertsAdminController.listRecipients";
import savePolicy from "@salesforce/apex/RHCAlertsAdminController.savePolicy";
import getLimitInfo from "@salesforce/apex/RHCAlertsAdminController.getLimitInfo";
import analyzeCoverage from "@salesforce/apex/RHCAlertsAdminController.analyzeCoverage";

jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.listPolicies",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.listSelections",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.listRecipients",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.savePolicy",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.analyzeCoverage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.getLimitInfo",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flush = async () => {
  await Promise.resolve();
  await Promise.resolve();
};

describe("c-rhc-alerts-admin", () => {
  beforeEach(() => {
    listPolicies.mockResolvedValue([]);
    listSelections.mockResolvedValue([
      {
        label: "Account readiness — rhc__Account_Readiness",
        value: "rhc__Account_Readiness"
      }
    ]);
    listRecipients.mockResolvedValue([
      { label: "Maya Admin", value: "005000000000001" }
    ]);
    getLimitInfo.mockResolvedValue({
      customNotificationRecipientsPerSend: 500,
      emailRecipientsPerAttempt: 10,
      maxAttempts: 3,
      note: "Limits apply."
    });
    analyzeCoverage.mockResolvedValue([
      {
        severity: "INFO",
        code: "PROGRAMMATIC_CALLER_CHOICE",
        message: "NONE is invisible."
      }
    ]);
    savePolicy.mockResolvedValue("a01000000000001");
  });
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("renders limits and exact qualified identity options", async () => {
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    await flush();
    expect(element.shadowRoot.textContent).toContain("500 recipients per send");
    expect(listSelections).toHaveBeenCalledWith({ selectionType: "CHECK_SET" });
  });

  it("shows setup assistant coverage findings", async () => {
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    await flush();
    element.shadowRoot.querySelectorAll("lightning-button")[1].click();
    await flush();
    expect(element.shadowRoot.textContent).toContain(
      "PROGRAMMATIC_CALLER_CHOICE"
    );
    expect(element.shadowRoot.textContent).toContain("NONE is invisible");
  });

  it("shows explicit empty states for policies and a clean coverage analysis", async () => {
    analyzeCoverage.mockResolvedValueOnce([]);
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    await flush();

    expect(element.shadowRoot.textContent).toContain(
      "No alert policies have been created yet"
    );
    element.shadowRoot.querySelectorAll("lightning-button")[1].click();
    await flush();

    expect(element.shadowRoot.textContent).toContain(
      "Publication coverage analysis found no gaps"
    );
  });

  it("reloads dependent choices and preserves Boolean toggle values", async () => {
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    await flush();

    const selectionType = element.shadowRoot.querySelector(
      '[data-field="SelectionType__c"]'
    );
    selectionType.dispatchEvent(
      new CustomEvent("change", { detail: { value: "CHECK" } })
    );
    const recipientType = element.shadowRoot.querySelector(
      '[data-field="RecipientType__c"]'
    );
    recipientType.dispatchEvent(
      new CustomEvent("change", { detail: { value: "PUBLIC_GROUP" } })
    );
    const active = element.shadowRoot.querySelector('[data-field="Active__c"]');
    active.checked = false;
    active.dispatchEvent(new CustomEvent("change"));
    await flush();

    expect(listSelections).toHaveBeenLastCalledWith({ selectionType: "CHECK" });
    expect(listRecipients).toHaveBeenLastCalledWith({
      recipientType: "PUBLIC_GROUP"
    });
    expect(active.checked).toBe(false);
  });

  it("saves a validated policy with the selected recipient label and resets the form", async () => {
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    await flush();

    const change = (field, value) => {
      element.shadowRoot
        .querySelector(`[data-field="${field}"]`)
        .dispatchEvent(new CustomEvent("change", { detail: { value } }));
    };
    change("DisplayName__c", "Critical account checks");
    change("QualifiedApiName__c", "rhc__Account_Readiness");
    change("RecipientId__c", "005000000000001");
    const active = element.shadowRoot.querySelector('[data-field="Active__c"]');
    active.checked = false;
    active.dispatchEvent(new CustomEvent("change"));
    element.shadowRoot
      .querySelectorAll(
        "lightning-input, lightning-combobox, lightning-dual-listbox"
      )
      .forEach((input) => {
        input.reportValidity = jest.fn(() => true);
      });

    element.shadowRoot.querySelectorAll("lightning-button")[0].click();
    await flush();
    await flush();

    expect(savePolicy).toHaveBeenCalledWith({
      policy: expect.objectContaining({
        DisplayName__c: "Critical account checks",
        QualifiedApiName__c: "rhc__Account_Readiness",
        RecipientId__c: "005000000000001",
        RecipientLabel__c: "Maya Admin",
        Active__c: false
      })
    });
    expect(listPolicies).toHaveBeenCalledTimes(2);
  });

  it("does not save when a visible input is invalid", async () => {
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    await flush();
    const inputs = element.shadowRoot.querySelectorAll(
      "lightning-input, lightning-combobox, lightning-dual-listbox"
    );
    inputs.forEach((input, index) => {
      input.reportValidity = jest.fn(() => index !== 0);
    });

    element.shadowRoot.querySelectorAll("lightning-button")[0].click();
    await flush();

    expect(savePolicy).not.toHaveBeenCalled();
  });

  it("disables actions while a save is pending to prevent duplicate submission", async () => {
    let resolveSave;
    savePolicy.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          resolveSave = resolve;
        })
    );
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    await flush();
    element.shadowRoot
      .querySelectorAll(
        "lightning-input, lightning-combobox, lightning-dual-listbox"
      )
      .forEach((input) => {
        input.reportValidity = jest.fn(() => true);
      });

    const saveButton =
      element.shadowRoot.querySelectorAll("lightning-button")[0];
    saveButton.click();
    await flush();
    expect(saveButton.disabled).toBe(true);
    saveButton.click();
    expect(savePolicy).toHaveBeenCalledTimes(1);

    resolveSave("a01000000000001");
    await flush();
    await flush();
    expect(saveButton.disabled).toBe(false);
  });

  it("surfaces bounded initialization and coverage errors", async () => {
    listPolicies.mockRejectedValueOnce({
      body: { message: "Policy access denied." }
    });
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) =>
      toasts.push(event.detail)
    );
    document.body.appendChild(element);
    await flush();
    await flush();

    analyzeCoverage.mockRejectedValueOnce(new Error("internal detail"));
    element.shadowRoot.querySelectorAll("lightning-button")[1].click();
    await flush();

    expect(toasts[0]).toEqual(
      expect.objectContaining({
        title: "RHC Alerts could not load",
        message: "Policy access denied.",
        variant: "error"
      })
    );
    expect(toasts[1]).toEqual(
      expect.objectContaining({
        title: "Coverage analysis failed",
        message: "Try again or contact your Salesforce administrator.",
        variant: "error"
      })
    );
  });
});
