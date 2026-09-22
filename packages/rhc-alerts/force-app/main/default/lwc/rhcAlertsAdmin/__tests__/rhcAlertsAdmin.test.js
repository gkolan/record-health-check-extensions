import { createElement } from "lwc";
import RhcAlertsAdmin from "c/rhcAlertsAdmin";
import listPolicies from "@salesforce/apex/RHCAlertsAdminController.listPolicies";
import listSelections from "@salesforce/apex/RHCAlertsAdminController.listSelections";
import listRecipients from "@salesforce/apex/RHCAlertsAdminController.listRecipients";
import savePolicy from "@salesforce/apex/RHCAlertsAdminController.savePolicy";
import getLimitInfo from "@salesforce/apex/RHCAlertsAdminController.getLimitInfo";
import analyzeCoverage from "@salesforce/apex/RHCAlertsAdminController.analyzeCoverage";
import sendTestAlert from "@salesforce/apex/RHCAlertsAdminController.sendTestAlert";
import getRetentionSettings from "@salesforce/apex/RHCAlertsAdminController.getRetentionSettings";
import saveRetentionSettings from "@salesforce/apex/RHCAlertsAdminController.saveRetentionSettings";
import purgeDeliveries from "@salesforce/apex/RHCAlertsAdminController.purgeDeliveries";

jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.sendTestAlert",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
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
jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.getRetentionSettings",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.saveRetentionSettings",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RHCAlertsAdminController.purgeDeliveries",
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
    getRetentionSettings.mockResolvedValue({
      retentionDays: 90,
      configured: false,
      maxDeleteRows: 1000
    });
    analyzeCoverage.mockResolvedValue([
      {
        severity: "INFO",
        code: "PROGRAMMATIC_CALLER_CHOICE",
        message: "NONE is invisible."
      }
    ]);
    savePolicy.mockResolvedValue("a01000000000001");
    saveRetentionSettings.mockResolvedValue();
    purgeDeliveries.mockResolvedValue(2);
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

  it("surfaces a bounded policy-save error and rejects an unknown recipient label", async () => {
    savePolicy.mockRejectedValueOnce({
      body: { message: "The policy could not be saved." }
    });
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    document.body.appendChild(element);
    await flush();
    await flush();

    element.shadowRoot
      .querySelector('[data-field="RecipientId__c"]')
      .dispatchEvent(
        new CustomEvent("change", {
          detail: { value: "005000000000099" }
        })
      );
    element.shadowRoot
      .querySelectorAll(
        "lightning-input, lightning-combobox, lightning-dual-listbox"
      )
      .forEach((input) => {
        input.reportValidity = jest.fn(() => true);
      });
    element.shadowRoot.querySelectorAll("lightning-button")[0].click();
    await flush();

    expect(savePolicy).toHaveBeenCalledWith({
      policy: expect.objectContaining({ RecipientLabel__c: "" })
    });
    expect(toastHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        detail: expect.objectContaining({
          title: "Policy was not saved",
          message: "The policy could not be saved."
        })
      })
    );
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

  it("sends a test alert for a policy row to the current user", async () => {
    listPolicies.mockResolvedValue([
      {
        Id: "a01000000000001AAA",
        DisplayName__c: "Ops",
        NotificationChannel__c: "EMAIL",
        Active__c: true
      }
    ]);
    sendTestAlert.mockResolvedValue();
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    const table = [
      ...element.shadowRoot.querySelectorAll("lightning-datatable")
    ].find((t) => t.columns.some((c) => c.fieldName === "DisplayName__c"));
    table.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "test" },
          row: { Id: "a01000000000001AAA", NotificationChannel__c: "EMAIL" }
        }
      })
    );
    await flush();
    expect(sendTestAlert).toHaveBeenCalledWith({
      policyId: "a01000000000001AAA"
    });
  });

  it("shows a bounded error when the test alert is rejected and ignores other row actions", async () => {
    listPolicies.mockResolvedValue([
      {
        Id: "a01000000000001AAA",
        DisplayName__c: "Ops",
        NotificationChannel__c: "CUSTOM_NOTIFICATION",
        Active__c: true
      }
    ]);
    sendTestAlert.mockRejectedValue({
      body: {
        message: "Test alert could not be sent: NOTIFICATION_TYPE_UNAVAILABLE"
      }
    });
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    document.body.appendChild(element);
    await flush();
    const table = [
      ...element.shadowRoot.querySelectorAll("lightning-datatable")
    ].find((t) => t.columns.some((c) => c.fieldName === "DisplayName__c"));
    table.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { action: { name: "other" }, row: {} }
      })
    );
    table.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "test" },
          row: {
            Id: "a01000000000001AAA",
            NotificationChannel__c: "CUSTOM_NOTIFICATION"
          }
        }
      })
    );
    await flush();
    expect(sendTestAlert).toHaveBeenCalledTimes(1);
    expect(toastHandler).toHaveBeenCalled();
  });

  it("saves a validated delivery-retention window", async () => {
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    document.body.appendChild(element);
    await flush();
    await flush();

    const input = element.shadowRoot.querySelector("[data-retention-days]");
    input.reportValidity = jest.fn(() => true);
    input.value = "30";
    input.dispatchEvent(new CustomEvent("change"));
    element.shadowRoot.querySelector('[data-action="save-retention"]').click();
    await flush();

    expect(saveRetentionSettings).toHaveBeenCalledWith({ retentionDays: 30 });
    expect(toastHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        detail: expect.objectContaining({
          title: "Retention settings saved",
          variant: "success"
        })
      })
    );
  });

  it("does not save an invalid delivery-retention window", async () => {
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    document.body.appendChild(element);
    await flush();
    await flush();

    const input = element.shadowRoot.querySelector("[data-retention-days]");
    input.reportValidity = jest.fn(() => false);
    element.shadowRoot.querySelector('[data-action="save-retention"]').click();
    await flush();

    expect(saveRetentionSettings).not.toHaveBeenCalled();
  });

  it("surfaces a bounded retention-save error", async () => {
    saveRetentionSettings.mockRejectedValueOnce({
      body: { message: "Retention settings could not be saved." }
    });
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    document.body.appendChild(element);
    await flush();
    await flush();

    const input = element.shadowRoot.querySelector("[data-retention-days]");
    input.reportValidity = jest.fn(() => true);
    element.shadowRoot.querySelector('[data-action="save-retention"]').click();
    await flush();

    expect(toastHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        detail: expect.objectContaining({
          title: "Retention settings were not saved",
          message: "Retention settings could not be saved.",
          variant: "error"
        })
      })
    );
  });

  it("requires confirmation before purging eligible delivery history", async () => {
    getRetentionSettings.mockResolvedValueOnce({
      retentionDays: 30,
      configured: true,
      maxDeleteRows: 1000
    });
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    document.body.appendChild(element);
    await flush();
    await flush();

    const purgeButton = element.shadowRoot.querySelector(
      '[data-action="purge-deliveries"]'
    );
    expect(purgeButton.disabled).toBe(true);
    const confirmation = element.shadowRoot.querySelector(
      "[data-retention-confirm]"
    );
    confirmation.checked = true;
    confirmation.dispatchEvent(new CustomEvent("change"));
    await flush();
    expect(purgeButton.disabled).toBe(false);
    purgeButton.click();
    await flush();

    expect(purgeDeliveries).toHaveBeenCalledTimes(1);
    expect(toastHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        detail: expect.objectContaining({
          title: "Delivery cleanup complete",
          message: "2 terminal delivery record(s) deleted."
        })
      })
    );
    expect(purgeButton.disabled).toBe(true);
  });

  it("surfaces a bounded delivery-cleanup error", async () => {
    getRetentionSettings.mockResolvedValueOnce({
      retentionDays: 30,
      configured: true,
      maxDeleteRows: 1000
    });
    purgeDeliveries.mockRejectedValueOnce({
      body: { message: "Delivery history could not be purged." }
    });
    const element = createElement("c-rhc-alerts-admin", { is: RhcAlertsAdmin });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    document.body.appendChild(element);
    await flush();
    await flush();

    const confirmation = element.shadowRoot.querySelector(
      "[data-retention-confirm]"
    );
    confirmation.checked = true;
    confirmation.dispatchEvent(new CustomEvent("change"));
    await flush();
    element.shadowRoot
      .querySelector('[data-action="purge-deliveries"]')
      .click();
    await flush();

    expect(toastHandler).toHaveBeenCalledWith(
      expect.objectContaining({
        detail: expect.objectContaining({
          title: "Delivery cleanup failed",
          message: "Delivery history could not be purged.",
          variant: "error"
        })
      })
    );
  });
});
