import { createElement } from "lwc";
import RhcChangeMonitorConsole from "c/rhcChangeMonitorConsole";
import getStatus from "@salesforce/apex/RHCChangeMonitorAdminController.getStatus";
import retryFailed from "@salesforce/apex/RHCChangeMonitorAdminController.retryFailed";
import dispatchPending from "@salesforce/apex/RHCChangeMonitorAdminController.dispatchPending";
import getRetentionSettings from "@salesforce/apex/RHCChangeMonitorAdminController.getRetentionSettings";
import saveRetentionSettings from "@salesforce/apex/RHCChangeMonitorAdminController.saveRetentionSettings";
import purgeEvaluations from "@salesforce/apex/RHCChangeMonitorAdminController.purgeEvaluations";

jest.mock("@salesforce/apex/RHCChangeMonitorAdminController.getStatus", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCChangeMonitorAdminController.retryFailed", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCChangeMonitorAdminController.dispatchPending", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCChangeMonitorAdminController.getRetentionSettings", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCChangeMonitorAdminController.saveRetentionSettings", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCChangeMonitorAdminController.purgeEvaluations", () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
};
const status = {
  lastSevenDays: [{ outcome: "FAILED", reasonCode: "RUNTIME_PERMISSION_MISSING", count: 2 }],
  pendingCount: 0,
  retryableFailedCount: 2,
  dispatcherQueued: false,
  currentUserCanRunCore: true,
  policies: [{ Id: "a01000000000001AAA", DisplayName__c: "CDC Gate Account", Active__c: true }],
  recent: [{ Id: "a02000000000001AAA", Name: "RHC-CE-000001", Outcome__c: "FAILED", Policy__r: { DisplayName__c: "CDC Gate Account" } }]
};

describe("c-rhc-change-monitor-console", () => {
  beforeEach(() => {
    getStatus.mockResolvedValue(status);
    getRetentionSettings.mockResolvedValue({ retentionDays: 90, configured: false, maxDeleteRows: 1000 });
    retryFailed.mockResolvedValue(2);
    dispatchPending.mockResolvedValue(3);
    saveRetentionSettings.mockResolvedValue();
    purgeEvaluations.mockResolvedValue(5);
  });
  afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  async function mount() {
    const element = createElement("c-rhc-change-monitor-console", { is: RhcChangeMonitorConsole });
    document.body.appendChild(element);
    await flushPromises();
    return element;
  }

  it("shows the principal warning when claims failed on the runtime permission", async () => {
    const element = await mount();
    const alerts = [...element.shadowRoot.querySelectorAll("[role='alert']")].map((a) => a.textContent);
    expect(alerts.some((t) => t.includes("PlatformEventSubscriberConfig"))).toBe(true);
    expect(element.shadowRoot.querySelectorAll("lightning-datatable")[2].data[0].policyName).toBe("CDC Gate Account");
  });

  it("retries failed claims and reloads", async () => {
    const element = await mount();
    element.shadowRoot.querySelector("[data-action='retry']").click();
    await flushPromises();
    expect(retryFailed).toHaveBeenCalledTimes(1);
    expect(getStatus).toHaveBeenCalledTimes(2);
  });

  it("requests dispatch for pending claims and reloads", async () => {
    getStatus.mockResolvedValueOnce({ ...status, pendingCount: 3 });
    const element = await mount();
    const button = element.shadowRoot.querySelector("[data-action='dispatch-pending']");
    expect(button.disabled).toBe(false);
    button.click();
    await flushPromises();
    expect(dispatchPending).toHaveBeenCalledTimes(1);
    expect(getStatus).toHaveBeenCalledTimes(2);
  });

  it("disables pending dispatch without work or while a dispatcher is active", async () => {
    const noWorkElement = await mount();
    expect(
      noWorkElement.shadowRoot.querySelector("[data-action='dispatch-pending']").disabled
    ).toBe(true);

    getStatus.mockResolvedValueOnce({
      ...status,
      pendingCount: 3,
      dispatcherQueued: true
    });
    const activeElement = await mount();
    expect(
      activeElement.shadowRoot.querySelector("[data-action='dispatch-pending']").disabled
    ).toBe(true);
  });

  it("surfaces a pending-dispatch rejection", async () => {
    getStatus.mockResolvedValueOnce({ ...status, pendingCount: 3 });
    dispatchPending.mockRejectedValueOnce({
      body: { message: "Pending claims could not be dispatched." }
    });
    const element = await mount();
    element.shadowRoot.querySelector("[data-action='dispatch-pending']").click();
    await flushPromises();
    expect(element.shadowRoot.querySelector("[role='alert']").textContent).toContain(
      "could not be dispatched"
    );
  });

  it("saves a valid retention window and rejects invalid input", async () => {
    const element = await mount();
    const input = element.shadowRoot.querySelector("[data-retention-days]");
    input.reportValidity = jest.fn(() => true);
    input.value = "30";
    input.dispatchEvent(new CustomEvent("change"));
    element.shadowRoot.querySelector("[data-action='save-retention']").click();
    await flushPromises();
    expect(saveRetentionSettings).toHaveBeenCalledWith({ retentionDays: 30 });

    input.reportValidity = jest.fn(() => false);
    element.shadowRoot.querySelector("[data-action='save-retention']").click();
    await flushPromises();
    expect(saveRetentionSettings).toHaveBeenCalledTimes(1);
  });

  it("surfaces a retention-save rejection", async () => {
    saveRetentionSettings.mockRejectedValueOnce({ body: { message: "Retention settings could not be saved." } });
    const element = await mount();
    element.shadowRoot.querySelector("[data-retention-days]").reportValidity = jest.fn(() => true);
    element.shadowRoot.querySelector("[data-action='save-retention']").click();
    await flushPromises();
    const alerts = [...element.shadowRoot.querySelectorAll("[role='alert']")].map((item) => item.textContent);
    expect(alerts.some((message) => message.includes("could not be saved"))).toBe(true);
  });

  it("requires saved settings and explicit confirmation before purging", async () => {
    getRetentionSettings.mockResolvedValueOnce({ retentionDays: 30, configured: true, maxDeleteRows: 1000 });
    const element = await mount();
    const purge = element.shadowRoot.querySelector("[data-action='purge']");
    expect(purge.disabled).toBe(true);

    const confirmation = element.shadowRoot.querySelector("[data-retention-confirm]");
    confirmation.checked = true;
    confirmation.dispatchEvent(new CustomEvent("change"));
    await flushPromises();
    expect(purge.disabled).toBe(false);
    purge.click();
    await flushPromises();
    expect(purgeEvaluations).toHaveBeenCalledWith();
    expect(getStatus).toHaveBeenCalledTimes(2);
    expect(purge.disabled).toBe(true);
  });

  it("requires resaving a changed window and surfaces purge errors", async () => {
    getRetentionSettings.mockResolvedValueOnce({ retentionDays: 30, configured: true, maxDeleteRows: 1000 });
    purgeEvaluations.mockRejectedValueOnce({ body: { message: "Change Evaluations could not be purged." } });
    const element = await mount();
    const input = element.shadowRoot.querySelector("[data-retention-days]");
    input.reportValidity = jest.fn(() => true);
    input.value = "45";
    input.dispatchEvent(new CustomEvent("change"));
    const confirmation = element.shadowRoot.querySelector("[data-retention-confirm]");
    confirmation.checked = true;
    confirmation.dispatchEvent(new CustomEvent("change"));
    await flushPromises();
    const purge = element.shadowRoot.querySelector("[data-action='purge']");
    expect(purge.disabled).toBe(true);

    element.shadowRoot.querySelector("[data-action='save-retention']").click();
    await flushPromises();
    confirmation.checked = true;
    confirmation.dispatchEvent(new CustomEvent("change"));
    purge.click();
    await flushPromises();
    const alerts = [...element.shadowRoot.querySelectorAll("[role='alert']")].map((item) => item.textContent);
    expect(alerts.some((message) => message.includes("could not be purged"))).toBe(true);
  });

  it("shows no principal warning when no runtime failures exist and surfaces load errors", async () => {
    getStatus.mockResolvedValueOnce({ ...status, lastSevenDays: [], retryableFailedCount: 0, recent: [] });
    const element = await mount();
    expect([...element.shadowRoot.querySelectorAll("[role='alert']")].length).toBe(0);
    expect(element.shadowRoot.querySelector("[data-action='retry']").disabled).toBe(false);

    getStatus.mockRejectedValueOnce({ body: { message: "You do not have access to Change Monitor evidence." } });
    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();
    expect(element.shadowRoot.querySelector("[role='alert']").textContent).toContain("do not have access");
  });

  it("surfaces a retry rejection", async () => {
    retryFailed.mockRejectedValueOnce({ message: "boom" });
    const element = await mount();
    element.shadowRoot.querySelector("[data-action='retry']").click();
    await flushPromises();
    expect(element.shadowRoot.querySelector("[role='alert']").textContent).toContain("boom");
  });
});
