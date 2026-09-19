import { createElement } from "lwc";
import RhcChangeMonitorConsole from "c/rhcChangeMonitorConsole";
import getStatus from "@salesforce/apex/RHCChangeMonitorAdminController.getStatus";
import retryFailed from "@salesforce/apex/RHCChangeMonitorAdminController.retryFailed";
import purgeEvaluations from "@salesforce/apex/RHCChangeMonitorAdminController.purgeEvaluations";

jest.mock("@salesforce/apex/RHCChangeMonitorAdminController.getStatus", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCChangeMonitorAdminController.retryFailed", () => ({ default: jest.fn() }), { virtual: true });
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
    retryFailed.mockResolvedValue(2);
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

  it("purges with the entered retention and surfaces errors", async () => {
    const element = await mount();
    element.shadowRoot.querySelector("[data-action='purge']").click();
    await flushPromises();
    expect(purgeEvaluations).toHaveBeenCalledWith({ olderThanDays: 90 });
    expect(getStatus).toHaveBeenCalledTimes(2);

    purgeEvaluations.mockRejectedValue({ body: { message: "Retention days must be from 1 through 3650." } });
    const input = element.shadowRoot.querySelector("lightning-input");
    input.dispatchEvent(new CustomEvent("change", { detail: { value: "0" } }));
    element.shadowRoot.querySelector("[data-action='purge']").click();
    await flushPromises();
    expect(purgeEvaluations).toHaveBeenLastCalledWith({ olderThanDays: 0 });
    expect(element.shadowRoot.querySelector("[role='alert']").textContent).toContain("Retention days");
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
