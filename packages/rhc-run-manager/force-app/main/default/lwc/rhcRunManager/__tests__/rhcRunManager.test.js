import { createElement } from "lwc";
import RhcRunManager from "c/rhcRunManager";
import getDefinitions from "@salesforce/apex/RHCRunManagerAdminController.getDefinitions";
import getSelections from "@salesforce/apex/RHCRunManagerAdminController.getSelections";
import getSchedules from "@salesforce/apex/RHCRunManagerAdminController.getSchedules";
import getBatchRuns from "@salesforce/apex/RHCRunManagerAdminController.getBatchRuns";
import getRuns from "@salesforce/apex/RHCRunManagerAdminController.getRuns";
import getResults from "@salesforce/apex/RHCRunManagerAdminController.getResults";
import getTargetFields from "@salesforce/apex/RHCRunManagerAdminController.getTargetFields";
import resolveSelection from "@salesforce/apex/RHCRunManagerAdminController.resolveSelection";
import saveDefinition from "@salesforce/apex/RHCRunManagerAdminController.saveDefinition";
import runNow from "@salesforce/apex/RHCRunManagerAdminController.runNow";
import saveSchedule from "@salesforce/apex/RHCRunManagerAdminController.saveSchedule";
import pauseSchedule from "@salesforce/apex/RHCRunManagerAdminController.pauseSchedule";
import cancelBatchRun from "@salesforce/apex/RHCRunManagerAdminController.cancelBatchRun";
import getRetentionSettings from "@salesforce/apex/RHCRunManagerAdminController.getRetentionSettings";
import saveRetentionSettings from "@salesforce/apex/RHCRunManagerAdminController.saveRetentionSettings";
import purgeOperationalRecords from "@salesforce/apex/RHCRunManagerAdminController.purgeOperationalRecords";

jest.mock("@salesforce/apex/RHCRunManagerAdminController.getDefinitions", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.cancelBatchRun", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.getSelections", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.getSchedules", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.getBatchRuns", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.getRuns", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.getResults", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.getTargetFields", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.resolveSelection", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.saveDefinition", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.runNow", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.saveSchedule", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.pauseSchedule", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.getRetentionSettings", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.saveRetentionSettings", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/RHCRunManagerAdminController.purgeOperationalRecords", () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = () => Promise.resolve();
const mountComponent = async () => {
  const element = createElement("c-rhc-run-manager", { is: RhcRunManager });
  document.body.appendChild(element);
  await flushPromises();
  await flushPromises();
  return element;
};
const makeInputsValid = (element, selector) => {
  element.shadowRoot.querySelectorAll(selector).forEach((input) => {
    input.reportValidity = jest.fn(() => true);
  });
};
const definitions = [{
  Id: "a00000000000001AAA",
  Name: "RHC-DEF-000001",
  DisplayName__c: "Account health",
  Active__c: true,
  SelectionType__c: "CHECK_SET",
  QualifiedApiName__c: "Account_Health",
  TargetObjectApiName__c: "Account",
  PopulationMode__c: "ALL_ACCESSIBLE",
  BatchSize__c: 100,
  CaptureMode__c: "FAIL",
  CoalesceDelayMinutes__c: 1,
}];

describe("c-rhc-run-manager", () => {
  beforeEach(() => {
    getDefinitions.mockResolvedValue(definitions);
    getSelections.mockResolvedValue([{ label: "Account Health — Account_Health (Account)", value: "Account_Health", targetObjectApiName: "Account" }]);
    getSchedules.mockResolvedValue([]);
    getBatchRuns.mockResolvedValue([{ Id: "a01000000000001AAA", Name: "RHC-BATCH-000001", Status__c: "COMPLETED" }]);
    getRuns.mockResolvedValue([{ Id: "a02000000000001AAA", ScopeNumber__c: 1, Status__c: "COMPLETED" }]);
    getResults.mockResolvedValue([]);
    resolveSelection.mockResolvedValue({ targetObjectApiName: "Account" });
    getTargetFields.mockResolvedValue([{ label: "Account Name (Name)", value: "Name" }]);
    saveDefinition.mockResolvedValue("a00000000000001AAA");
    runNow.mockResolvedValue("a01000000000001AAA");
    saveSchedule.mockResolvedValue("a03000000000001AAA");
    pauseSchedule.mockResolvedValue("a03000000000001AAA");
    cancelBatchRun.mockResolvedValue("a01000000000001AAA");
    getRetentionSettings.mockResolvedValue({ retentionDays: 365, configured: false, maxDeleteRows: 1000, canManage: false });
    saveRetentionSettings.mockResolvedValue({ retentionDays: 30, configured: true, maxDeleteRows: 1000, canManage: true });
    purgeOperationalRecords.mockResolvedValue({ resultsDeleted: 2, runsDeleted: 1, batchRunsDeleted: 1, requestsDeleted: 1, totalDeleted: 5 });
  });

  afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("loads definitions and monitoring rows", async () => {
    const element = createElement("c-rhc-run-manager", { is: RhcRunManager });
    document.body.appendChild(element);
    await flushPromises();
    await flushPromises();

    const tables = element.shadowRoot.querySelectorAll("lightning-datatable");
    expect(getDefinitions).toHaveBeenCalledTimes(1);
    expect(getBatchRuns).toHaveBeenCalledTimes(1);
    expect(getSelections).toHaveBeenCalledWith({ selectionType: "CHECK_SET" });
    expect(tables).toHaveLength(3);
  });

  it("resolves the target and builds structured guided-filter JSON", async () => {
    const element = createElement("c-rhc-run-manager", { is: RhcRunManager });
    document.body.appendChild(element);
    await flushPromises();

    const population = element.shadowRoot.querySelector('[data-field="populationMode"]');
    population.dispatchEvent(new CustomEvent("change", { detail: { value: "GUIDED_FILTERED" } }));
    await flushPromises();
    const selection = element.shadowRoot.querySelector('[data-field="qualifiedApiName"]');
    selection.dispatchEvent(new CustomEvent("change", { detail: { value: "Account_Health" } }));
    await flushPromises();

    const field = element.shadowRoot.querySelector('[data-filter-field="field"]');
    const operator = element.shadowRoot.querySelector('[data-filter-field="operator"]');
    const value = element.shadowRoot.querySelector('[data-filter-field="value"]');
    field.dispatchEvent(new CustomEvent("change", { detail: { value: "Name" } }));
    operator.dispatchEvent(new CustomEvent("change", { detail: { value: "STARTS_WITH" } }));
    value.value = "Acme";
    value.dispatchEvent(new CustomEvent("change"));
    element.shadowRoot.querySelector('[data-action="add-filter"]').click();
    element.shadowRoot.querySelectorAll("[data-field]").forEach((input) => { input.reportValidity = jest.fn(() => true); });
    element.shadowRoot.querySelector('[data-action="save"]').click();
    await flushPromises();

    expect(resolveSelection).toHaveBeenCalled();
    expect(saveDefinition.mock.calls[0][0].input.filterJson).toBe('[{"field":"Name","operator":"STARTS_WITH","value":"Acme"}]');
  });

  it("guides supplied-ID definitions to Flow instead of starting an empty run", async () => {
    const element = createElement("c-rhc-run-manager", { is: RhcRunManager });
    document.body.appendChild(element);
    await flushPromises();
    const supplied = { ...definitions[0], PopulationMode__c: "SUPPLIED_IDS" };
    element.shadowRoot.querySelector("lightning-datatable").dispatchEvent(new CustomEvent("rowaction", { detail: { action: { name: "run" }, row: supplied } }));
    await flushPromises();
    expect(runNow).not.toHaveBeenCalled();
  });

  it("queues Run Now from the definition table", async () => {
    const element = createElement("c-rhc-run-manager", { is: RhcRunManager });
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot.querySelector("lightning-datatable").dispatchEvent(new CustomEvent("rowaction", {
      detail: { action: { name: "run" }, row: definitions[0] },
    }));
    await flushPromises();

    expect(runNow).toHaveBeenCalledWith({ definitionId: definitions[0].Id });
  });

  it("pauses a managed schedule from the schedule table", async () => {
    getSchedules.mockResolvedValue([{ Id: "a03000000000001AAA", RunDefinition__c: definitions[0].Id, RunDefinition__r: { DisplayName__c: "Account health" }, Active__c: true, Frequency__c: "DAILY", PreferredStartTime__c: "02:00" }]);
    const element = createElement("c-rhc-run-manager", { is: RhcRunManager });
    document.body.appendChild(element);
    await flushPromises(); await flushPromises();

    element.shadowRoot.querySelectorAll("lightning-datatable")[1].dispatchEvent(new CustomEvent("rowaction", { detail: { action: { name: "pause" }, row: { Id: "a03000000000001AAA" } } }));
    await flushPromises();

    expect(pauseSchedule).toHaveBeenCalledWith({ scheduleId: "a03000000000001AAA" });
  });

  it("drills from a batch run into its scope runs", async () => {
    const element = createElement("c-rhc-run-manager", { is: RhcRunManager });
    document.body.appendChild(element);
    await flushPromises(); await flushPromises();

    element.shadowRoot.querySelectorAll("lightning-datatable")[2].dispatchEvent(new CustomEvent("rowaction", { detail: { action: { name: "scopes" }, row: { Id: "a01000000000001AAA", Name: "RHC-BATCH-000001" } } }));
    await flushPromises();

    expect(getRuns).toHaveBeenCalledWith({ batchRunId: "a01000000000001AAA" });
  });

  it("offers Cancel only for active batch runs and reloads after cancelling", async () => {
    const element = createElement("c-rhc-run-manager", { is: RhcRunManager });
    document.body.appendChild(element);
    await flushPromises(); await flushPromises();

    const actionsFor = (row) => new Promise((resolve) => element.shadowRoot.querySelectorAll("lightning-datatable")[2].columns.at(-1).typeAttributes.rowActions(row, resolve));
    expect((await actionsFor({ Status__c: "PROCESSING" })).map((a) => a.name)).toEqual(["scopes", "cancel"]);
    expect((await actionsFor({ Status__c: "COMPLETED" })).map((a) => a.name)).toEqual(["scopes"]);

    getBatchRuns.mockClear();
    element.shadowRoot.querySelectorAll("lightning-datatable")[2].dispatchEvent(new CustomEvent("rowaction", { detail: { action: { name: "cancel" }, row: { Id: "a01000000000001AAA", Name: "RHC-BATCH-000001", Status__c: "PROCESSING" } } }));
    await flushPromises(); await flushPromises();

    expect(cancelBatchRun).toHaveBeenCalledWith({ batchRunId: "a01000000000001AAA" });
    expect(getBatchRuns).toHaveBeenCalledTimes(1);
  });

  it("edits an existing guided definition and removes a retained filter", async () => {
    const element = await mountComponent();
    const guided = {
      ...definitions[0],
      PopulationMode__c: "GUIDED_FILTERED",
      FilterJson__c: '[{"field":"Name","operator":"IS_NULL","value":""}]',
      CoalesceDelayMinutes__c: null,
    };

    element.shadowRoot.querySelector("lightning-datatable").dispatchEvent(new CustomEvent("rowaction", {
      detail: { action: { name: "edit" }, row: guided },
    }));
    await flushPromises();
    await flushPromises();

    const filterTable = element.shadowRoot.querySelectorAll("lightning-datatable")[0];
    expect(filterTable.data).toHaveLength(1);
    filterTable.dispatchEvent(new CustomEvent("rowaction", {
      detail: { action: { name: "remove" }, row: filterTable.data[0] },
    }));
    await flushPromises();
    expect(filterTable.data).toHaveLength(0);
    expect(resolveSelection).toHaveBeenCalledWith({ selectionType: "CHECK_SET", qualifiedApiName: "Account_Health" });
  });

  it("accepts an IS_NULL filter without a value and rejects incomplete filters", async () => {
    const element = await mountComponent();
    const population = element.shadowRoot.querySelector('[data-field="populationMode"]');
    population.dispatchEvent(new CustomEvent("change", { detail: { value: "GUIDED_FILTERED" } }));
    await flushPromises();

    const addButton = element.shadowRoot.querySelector('[data-action="add-filter"]');
    addButton.click();
    await flushPromises();
    let filterTable = element.shadowRoot.querySelectorAll("lightning-datatable")[0];
    expect(filterTable.data).toHaveLength(0);

    element.shadowRoot.querySelector('[data-filter-field="field"]').dispatchEvent(new CustomEvent("change", { detail: { value: "Name" } }));
    element.shadowRoot.querySelector('[data-filter-field="operator"]').dispatchEvent(new CustomEvent("change", { detail: { value: "EQ" } }));
    addButton.click();
    await flushPromises();
    expect(filterTable.data).toHaveLength(0);

    element.shadowRoot.querySelector('[data-filter-field="operator"]').dispatchEvent(new CustomEvent("change", { detail: { value: "IS_NULL" } }));
    addButton.click();
    await flushPromises();
    filterTable = element.shadowRoot.querySelectorAll("lightning-datatable")[0];
    expect(filterTable.data).toHaveLength(1);
  });

  it("saves a weekly schedule from changed values", async () => {
    const element = await mountComponent();
    element.shadowRoot.querySelector('[data-schedule-field="runDefinitionId"]').dispatchEvent(new CustomEvent("change", { detail: { value: definitions[0].Id } }));
    element.shadowRoot.querySelector('[data-schedule-field="frequency"]').dispatchEvent(new CustomEvent("change", { detail: { value: "WEEKLY" } }));
    await flushPromises();
    const active = element.shadowRoot.querySelector('[data-schedule-field="active"]');
    active.checked = false;
    active.dispatchEvent(new CustomEvent("change"));
    makeInputsValid(element, "[data-schedule-field]");

    element.shadowRoot.querySelector('[data-action="save-schedule"]').click();
    await flushPromises();

    expect(saveSchedule).toHaveBeenCalledWith({
      input: expect.objectContaining({
        runDefinitionId: definitions[0].Id,
        frequency: "WEEKLY",
        active: false,
      }),
    });
  });

  it("edits a schedule and drills from scope to retained results", async () => {
    const schedule = {
      Id: "a03000000000001AAA",
      RunDefinition__c: definitions[0].Id,
      RunDefinition__r: { DisplayName__c: "Account health" },
      Active__c: true,
      Frequency__c: "WEEKLY",
      PreferredStartTime__c: "02:00",
      DayOfWeek__c: null,
      StartDate__c: null,
      EndDate__c: null,
    };
    getSchedules.mockResolvedValue([schedule]);
    getResults.mockResolvedValue([{ Id: "a04000000000001AAA", Status__c: "FAIL" }]);
    const element = await mountComponent();
    const tables = element.shadowRoot.querySelectorAll("lightning-datatable");
    tables[1].dispatchEvent(new CustomEvent("rowaction", {
      detail: { action: { name: "edit" }, row: schedule },
    }));
    await flushPromises();
    tables[2].dispatchEvent(new CustomEvent("rowaction", {
      detail: { action: { name: "scopes" }, row: { Id: "a01000000000001AAA", Name: "RHC-BATCH-000001" } },
    }));
    await flushPromises();
    await flushPromises();
    const runTable = element.shadowRoot.querySelectorAll("lightning-datatable")[3];
    runTable.dispatchEvent(new CustomEvent("rowaction", {
      detail: { action: { name: "results" }, row: { Id: "a02000000000001AAA", ScopeNumber__c: 1 } },
    }));
    await flushPromises();
    await flushPromises();

    expect(getResults).toHaveBeenCalledWith({ runId: "a02000000000001AAA" });
    expect(element.shadowRoot.querySelectorAll("lightning-datatable")).toHaveLength(5);
  });

  it("does not call save endpoints when base inputs are invalid", async () => {
    const element = await mountComponent();
    element.shadowRoot.querySelectorAll("[data-field]").forEach((input) => {
      input.reportValidity = jest.fn(() => false);
    });
    element.shadowRoot.querySelectorAll("[data-schedule-field]").forEach((input) => {
      input.reportValidity = jest.fn(() => false);
    });

    element.shadowRoot.querySelector('[data-action="save"]').click();
    element.shadowRoot.querySelector('[data-action="save-schedule"]').click();
    await flushPromises();

    expect(saveDefinition).not.toHaveBeenCalled();
    expect(saveSchedule).not.toHaveBeenCalled();
  });

  it("saves retention settings without enabling cleanup until confirmed", async () => {
    getRetentionSettings.mockResolvedValue({ retentionDays: 365, configured: false, maxDeleteRows: 1000, canManage: true });
    const element = await mountComponent();
    const input = element.shadowRoot.querySelector("[data-retention-days]");
    input.reportValidity = jest.fn(() => true);
    input.value = "30";
    input.dispatchEvent(new CustomEvent("change"));
    element.shadowRoot.querySelector("[data-action='save-retention']").click();
    await flushPromises();

    expect(saveRetentionSettings).toHaveBeenCalledWith({ retentionDays: 30 });
    expect(element.shadowRoot.querySelector("[data-action='purge']").disabled).toBe(true);
  });

  it("requires explicit confirmation and runs one bounded purge", async () => {
    getRetentionSettings.mockResolvedValue({ retentionDays: 30, configured: true, maxDeleteRows: 1000, canManage: true });
    const element = await mountComponent();
    const purge = element.shadowRoot.querySelector("[data-action='purge']");
    expect(purge.disabled).toBe(true);
    const confirm = element.shadowRoot.querySelector("[data-retention-confirm]");
    confirm.checked = true;
    confirm.dispatchEvent(new CustomEvent("change"));
    await flushPromises();
    expect(purge.disabled).toBe(false);
    purge.click();
    await flushPromises();
    await flushPromises();

    expect(purgeOperationalRecords).toHaveBeenCalledTimes(1);
    expect(purge.disabled).toBe(true);
  });

  it("hides retention controls without retention-management access", async () => {
    const element = await mountComponent();
    expect(element.shadowRoot.querySelector("[data-retention-days]")).toBeNull();
  });

  it("handles rejected Apex operations without leaking promise failures", async () => {
    runNow.mockRejectedValue({ body: { message: "Run failed" } });
    pauseSchedule.mockRejectedValue(new Error("Pause failed"));
    getRuns.mockRejectedValue({});
    const schedule = { Id: "a03000000000001AAA", RunDefinition__c: definitions[0].Id, RunDefinition__r: { DisplayName__c: "Account health" } };
    getSchedules.mockResolvedValue([schedule]);
    const element = await mountComponent();
    const tables = element.shadowRoot.querySelectorAll("lightning-datatable");

    tables[0].dispatchEvent(new CustomEvent("rowaction", { detail: { action: { name: "run" }, row: definitions[0] } }));
    tables[1].dispatchEvent(new CustomEvent("rowaction", { detail: { action: { name: "pause" }, row: schedule } }));
    tables[2].dispatchEvent(new CustomEvent("rowaction", { detail: { action: { name: "scopes" }, row: { Id: "a01000000000001AAA" } } }));
    await flushPromises();
    await flushPromises();

    expect(runNow).toHaveBeenCalled();
    expect(pauseSchedule).toHaveBeenCalled();
    expect(getRuns).toHaveBeenCalled();
  });
});
