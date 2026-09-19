import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
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
import cancelBatchRun from "@salesforce/apex/RHCRunManagerAdminController.cancelBatchRun";
import saveSchedule from "@salesforce/apex/RHCRunManagerAdminController.saveSchedule";
import pauseSchedule from "@salesforce/apex/RHCRunManagerAdminController.pauseSchedule";

const DEFAULT_FORM = Object.freeze({ id: null, displayName: "", active: true, selectionType: "CHECK_SET", qualifiedApiName: "", populationMode: "ALL_ACCESSIBLE", batchSize: 100, captureMode: "FAIL", coalesceDelayMinutes: 1 });
const DEFAULT_SCHEDULE = Object.freeze({ id: null, runDefinitionId: "", active: true, frequency: "DAILY", preferredStartTime: "02:00", dayOfWeek: "MON", startDate: null, endDate: null });

export default class RhcRunManager extends LightningElement {
  definitions = []; selections = []; schedules = []; batchRuns = []; runs = []; results = [];
  targetFieldOptions = []; filters = []; form = { ...DEFAULT_FORM }; schedule = { ...DEFAULT_SCHEDULE };
  newFilter = { field: "", operator: "EQ", value: "" };
  resolvedTarget = ""; selectedBatchName = ""; selectedRunName = ""; isLoading = false;

  definitionColumns = [
    { label: "Name", fieldName: "DisplayName__c" }, { label: "Selection", fieldName: "QualifiedApiName__c" },
    { label: "Target", fieldName: "TargetObjectApiName__c" }, { label: "Population", fieldName: "PopulationMode__c" }, { label: "Capture", fieldName: "CaptureMode__c" },
    { type: "action", typeAttributes: { rowActions: [{ label: "Edit", name: "edit" }, { label: "Run now", name: "run" }] } },
  ];
  filterColumns = [{ label: "Field", fieldName: "field" }, { label: "Operator", fieldName: "operator" }, { label: "Value", fieldName: "value" }, { type: "action", typeAttributes: { rowActions: [{ label: "Remove", name: "remove" }] } }];
  scheduleColumns = [{ label: "Definition", fieldName: "definitionName" }, { label: "Frequency", fieldName: "Frequency__c" }, { label: "Start time", fieldName: "PreferredStartTime__c" }, { label: "First date", fieldName: "StartDate__c", type: "date-local" }, { label: "Last date", fieldName: "EndDate__c", type: "date-local" }, { label: "Active", fieldName: "Active__c", type: "boolean" }, { type: "action", typeAttributes: { rowActions: [{ label: "Edit", name: "edit" }, { label: "Pause", name: "pause" }] } }];
  // Cancel is offered only while the owned platform job can still be aborted.
  batchRunActions = (row, doneCallback) => {
    const actions = [{ label: "View scopes", name: "scopes" }];
    if (row.Status__c === "QUEUED" || row.Status__c === "PROCESSING") actions.push({ label: "Cancel", name: "cancel" });
    doneCallback(actions);
  };
  batchRunColumns = [{ label: "Batch run", fieldName: "Name" }, { label: "Source", fieldName: "Source__c" }, { label: "Status", fieldName: "Status__c" }, { label: "Submitted", fieldName: "SubmittedRecordCount__c", type: "number" }, { label: "Processed", fieldName: "ProcessedRecordCount__c", type: "number" }, { label: "Failed scopes", fieldName: "FailedScopeCount__c", type: "number" }, { label: "Pass", fieldName: "PassedCount__c", type: "number" }, { label: "Fail", fieldName: "FailedCount__c", type: "number" }, { label: "Unable", fieldName: "UnableCount__c", type: "number" }, { label: "Error", fieldName: "SystemErrorCount__c", type: "number" }, { type: "action", typeAttributes: { rowActions: this.batchRunActions } }];
  runColumns = [{ label: "Scope", fieldName: "ScopeNumber__c", type: "number" }, { label: "Status", fieldName: "Status__c" }, { label: "Records", fieldName: "RecordCount__c", type: "number" }, { label: "Pass", fieldName: "PassedCount__c", type: "number" }, { label: "Fail", fieldName: "FailedCount__c", type: "number" }, { label: "Skipped", fieldName: "SkippedCount__c", type: "number" }, { label: "Unable", fieldName: "UnableCount__c", type: "number" }, { label: "Errors", fieldName: "SystemErrorCount__c", type: "number" }, { type: "action", typeAttributes: { rowActions: [{ label: "View retained results", name: "results" }] } }];
  resultColumns = [{ label: "Record ID", fieldName: "RecordId__c" }, { label: "Check", fieldName: "CheckQualifiedApiName__c" }, { label: "Status", fieldName: "Status__c" }, { label: "Severity", fieldName: "Severity__c" }, { label: "Reason", fieldName: "ReasonCode__c" }, { label: "Summary", fieldName: "DiagnosticSummary__c", wrapText: true }];

  selectionTypeOptions = this.options(["CHECK_SET", "CHECK"]); populationModeOptions = this.options(["ALL_ACCESSIBLE", "GUIDED_FILTERED", "SUPPLIED_IDS"]); captureModeOptions = this.options(["FAIL", "PASS", "BOTH"]);
  operatorOptions = this.options(["EQ", "NE", "GT", "GTE", "LT", "LTE", "CONTAINS", "STARTS_WITH", "IS_NULL"]); frequencyOptions = this.options(["DAILY", "WEEKDAYS", "WEEKLY"]); dayOptions = this.options(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]);

  connectedCallback() { this.loadData(); this.loadSelections(); }
  get isGuidedFiltered() { return this.form.populationMode === "GUIDED_FILTERED"; }
  get isSuppliedIds() { return this.form.populationMode === "SUPPLIED_IDS"; }
  get isWeekly() { return this.schedule.frequency === "WEEKLY"; }
  get hasRuns() { return this.runs.length > 0; }
  get hasResults() { return this.results.length > 0; }
  get selectionOptions() { return this.selections.map((item) => ({ label: item.label, value: item.value })); }
  get definitionOptions() { return this.definitions.filter((item) => item.Active__c && item.PopulationMode__c !== "SUPPLIED_IDS").map((item) => ({ label: item.DisplayName__c, value: item.Id })); }

  async loadData() {
    this.isLoading = true;
    try { const [definitions, schedules, batchRuns] = await Promise.all([getDefinitions(), getSchedules(), getBatchRuns()]); this.definitions = definitions; this.schedules = schedules.map((item) => ({ ...item, definitionName: item.RunDefinition__r?.DisplayName__c || "" })); this.batchRuns = batchRuns; }
    catch (error) { this.toast("Couldn’t load Run Manager", this.errorMessage(error), "error"); } finally { this.isLoading = false; }
  }
  async loadSelections() { try { this.selections = await getSelections({ selectionType: this.form.selectionType }); } catch (error) { this.toast("Couldn’t load core selections", this.errorMessage(error), "error"); } }
  async resolveCurrentSelection() {
    if (!this.form.qualifiedApiName) return;
    const input = { selectionType: this.form.selectionType, qualifiedApiName: this.form.qualifiedApiName };
    const [resolved, fields] = await Promise.all([resolveSelection(input), getTargetFields(input)]);
    this.resolvedTarget = `Target object: ${resolved.targetObjectApiName}`; this.targetFieldOptions = fields.map((field) => ({ label: field.label, value: field.value, dataType: field.dataType }));
  }
  async handleFormChange(event) {
    const field = event.target.dataset.field; const value = event.target.type === "checkbox" ? event.target.checked : (event.detail?.value ?? event.target.value); this.form = { ...this.form, [field]: value };
    if (field === "selectionType") { this.form = { ...this.form, qualifiedApiName: "" }; this.resolvedTarget = ""; this.targetFieldOptions = []; await this.loadSelections(); }
    if (field === "qualifiedApiName") { this.isLoading = true; try { await this.resolveCurrentSelection(); } catch (error) { this.toast("Selection unavailable", this.errorMessage(error), "error"); } finally { this.isLoading = false; } }
  }
  handleFilterChange(event) { const field = event.target.dataset.filterField; this.newFilter = { ...this.newFilter, [field]: event.detail?.value ?? event.target.value }; }
  handleAddFilter() {
    if (!this.newFilter.field || !this.newFilter.operator) { this.toast("Filter incomplete", "Choose a field and operator.", "error"); return; }
    if (this.newFilter.operator !== "IS_NULL" && !this.newFilter.value) { this.toast("Filter incomplete", "Enter a value for this operator.", "error"); return; }
    this.filters = [...this.filters, { ...this.newFilter, key: `${Date.now()}-${this.filters.length}` }]; this.newFilter = { field: "", operator: "EQ", value: "" };
  }
  handleFilterRowAction(event) { if (event.detail.action.name === "remove") this.filters = this.filters.filter((item) => item.key !== event.detail.row.key); }
  async handleSave() {
    if (!this.validateInputs("[data-field]")) return; this.isLoading = true;
    try { const filterJson = this.isGuidedFiltered ? JSON.stringify(this.filters.map(({ field, operator, value }) => ({ field, operator, value }))) : null; await saveDefinition({ input: { ...this.form, filterJson } }); this.toast("Run definition saved", `${this.form.displayName} is ready to use.`, "success"); this.form = { ...DEFAULT_FORM }; this.filters = []; this.resolvedTarget = ""; await Promise.all([this.loadSelections(), this.loadData()]); }
    catch (error) { this.toast("Couldn’t save run definition", this.errorMessage(error), "error"); } finally { this.isLoading = false; }
  }
  async handleDefinitionAction(event) {
    const { action, row } = event.detail;
    if (action.name === "edit") { this.form = { id: row.Id, displayName: row.DisplayName__c, active: row.Active__c, selectionType: row.SelectionType__c, qualifiedApiName: row.QualifiedApiName__c, populationMode: row.PopulationMode__c, batchSize: row.BatchSize__c, captureMode: row.CaptureMode__c, coalesceDelayMinutes: row.CoalesceDelayMinutes__c || 1 }; this.filters = row.FilterJson__c ? JSON.parse(row.FilterJson__c).map((filter, index) => ({ ...filter, key: `existing-${index}` })) : []; await this.loadSelections(); await this.resolveCurrentSelection(); return; }
    if (row.PopulationMode__c === "SUPPLIED_IDS") { this.toast("Use Flow to supply record IDs", "This definition waits for the packaged ‘Submit Record IDs’ Flow action, which deduplicates and coalesces IDs before running.", "info"); return; }
    this.isLoading = true; try { await runNow({ definitionId: row.Id }); this.toast("Run queued", `${row.DisplayName__c} was queued.`, "success"); await this.loadData(); } catch (error) { this.toast("Couldn’t start run", this.errorMessage(error), "error"); } finally { this.isLoading = false; }
  }
  handleScheduleChange(event) { const field = event.target.dataset.scheduleField; const value = event.target.type === "checkbox" ? event.target.checked : (event.detail?.value ?? event.target.value); this.schedule = { ...this.schedule, [field]: value }; }
  async handleSaveSchedule() { if (!this.validateInputs("[data-schedule-field]")) return; this.isLoading = true; try { await saveSchedule({ input: this.schedule }); this.toast("Schedule saved", "The managed schedule is active with the selected recurrence.", "success"); this.schedule = { ...DEFAULT_SCHEDULE }; await this.loadData(); } catch (error) { this.toast("Couldn’t save schedule", this.errorMessage(error), "error"); } finally { this.isLoading = false; } }
  async handleScheduleAction(event) {
    const { action, row } = event.detail;
    if (action.name === "edit") { this.schedule = { id: row.Id, runDefinitionId: row.RunDefinition__c, active: row.Active__c, frequency: row.Frequency__c, preferredStartTime: row.PreferredStartTime__c, dayOfWeek: row.DayOfWeek__c || "MON", startDate: row.StartDate__c || null, endDate: row.EndDate__c || null }; return; }
    this.isLoading = true; try { await pauseSchedule({ scheduleId: row.Id }); this.toast("Schedule paused", "Its owned Salesforce scheduled job was safely removed.", "success"); await this.loadData(); } catch (error) { this.toast("Couldn’t pause schedule", this.errorMessage(error), "error"); } finally { this.isLoading = false; }
  }
  async handleCancelBatchRun(row) {
    this.isLoading = true;
    try { await cancelBatchRun({ batchRunId: row.Id }); this.toast("Batch run cancelled", `${row.Name} was cancelled.`, "success"); await this.loadData(); }
    catch (error) { this.toast("Couldn’t cancel batch run", this.errorMessage(error), "error"); } finally { this.isLoading = false; }
  }
  async handleBatchAction(event) {
    if (event.detail.action.name === "cancel") { await this.handleCancelBatchRun(event.detail.row); return; }
    if (event.detail.action.name !== "scopes") return; this.isLoading = true; this.results = []; this.selectedRunName = ""; try { this.runs = await getRuns({ batchRunId: event.detail.row.Id }); this.selectedBatchName = event.detail.row.Name; } catch (error) { this.toast("Couldn’t load scopes", this.errorMessage(error), "error"); } finally { this.isLoading = false; } }
  async handleRunAction(event) { if (event.detail.action.name !== "results") return; this.isLoading = true; try { this.results = await getResults({ runId: event.detail.row.Id }); this.selectedRunName = `Scope ${event.detail.row.ScopeNumber__c}`; } catch (error) { this.toast("Couldn’t load retained results", this.errorMessage(error), "error"); } finally { this.isLoading = false; } }
  validateInputs(selector) { return [...this.template.querySelectorAll(selector)].reduce((valid, input) => input.reportValidity() && valid, true); }
  options(values) { return values.map((value) => ({ label: value.replaceAll("_", " ").toLowerCase().replace(/(^|\s)\S/g, (letter) => letter.toUpperCase()), value })); }
  errorMessage(error) { return error?.body?.message || error?.message || "An unexpected error occurred."; }
  toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
}
