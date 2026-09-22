import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(projectRoot, "force-app/main/default");
const checkOnly = process.argv.includes("--check");
const drift = [];
const header = '<?xml version="1.0" encoding="UTF-8"?>\n';
const ns = ' xmlns="http://soap.sforce.com/2006/04/metadata"';
const escapeXml = (value) => String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const write = (relative, body) => {
  const target = path.join(root, relative);
  const expected = header + body.trim() + "\n";
  if (checkOnly) {
    if (!fs.existsSync(target) || fs.readFileSync(target, "utf8") !== expected) drift.push(relative);
    return;
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, expected);
};
const picklist = (values) => `<valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>${values.map((value, index) => `<value><fullName>${value}</fullName><default>${index === 0}</default><label>${escapeXml(value.replaceAll("_", " "))}</label></value>`).join("")}</valueSetDefinition></valueSet>`;
const fieldXml = (field) => {
  const common = `<fullName>${field.name}</fullName><label>${escapeXml(field.label)}</label><description>${escapeXml(field.description ?? field.label)}</description><inlineHelpText>${escapeXml(field.help ?? field.description ?? field.label)}</inlineHelpText>`;
  if (field.type === "Text") return `${common}<length>${field.length ?? 255}</length>${field.external ? "<externalId>true</externalId>" : ""}${field.unique ? "<unique>true</unique>" : ""}<type>Text</type>`;
  if (field.type === "LongTextArea") return `${common}<length>${field.length ?? 32768}</length><visibleLines>${field.lines ?? 5}</visibleLines><type>LongTextArea</type>`;
  if (field.type === "Number") return `${common}<precision>${field.precision ?? 9}</precision><scale>0</scale><type>Number</type>`;
  if (field.type === "Checkbox") return `${common}<defaultValue>${field.defaultValue ?? false}</defaultValue><type>Checkbox</type>`;
  if (field.type === "DateTime") return `${common}<type>DateTime</type>`;
  if (field.type === "Date") return `${common}<type>Date</type>`;
  if (field.type === "Picklist") return `${common}<type>Picklist</type>${picklist(field.values)}`;
  if (field.type === "Lookup") return `${common}<deleteConstraint>SetNull</deleteConstraint><referenceTo>${field.referenceTo}</referenceTo><relationshipLabel>${field.relationshipLabel}</relationshipLabel><relationshipName>${field.relationshipName}</relationshipName><required>false</required><type>Lookup</type>`;
  if (field.type === "MasterDetail") return `${common}<referenceTo>${field.referenceTo}</referenceTo><relationshipLabel>${field.relationshipLabel}</relationshipLabel><relationshipName>${field.relationshipName}</relationshipName><relationshipOrder>0</relationshipOrder><reparentableMasterDetail>false</reparentableMasterDetail><type>MasterDetail</type><writeRequiresMasterRead>false</writeRequiresMasterRead>`;
  throw new Error(`Unsupported field type ${field.type}`);
};

const objects = [
  {
    api: "Record_Health_Check_Run_Definition__c", label: "Record Health Check Run Definition", plural: "Record Health Check Run Definitions", format: "RHC-DEF-{000000}", sharing: "Private",
    fields: [
      { name: "DisplayName__c", label: "Name", type: "Text", length: 80, description: "Administrator-facing name that explains the purpose of this definition." },
      { name: "Active__c", label: "Active", type: "Checkbox", defaultValue: true, description: "Controls whether this saved definition can execute." },
      { name: "SelectionType__c", label: "Selection Type", type: "Picklist", values: ["CHECK_SET", "CHECK"], description: "Explicitly identifies whether Qualified API Name is a Check Set or Check." },
      { name: "QualifiedApiName__c", label: "Qualified API Name", type: "Text", length: 120, description: "Exact, opaque core Custom Metadata QualifiedApiName." },
      { name: "TargetObjectApiName__c", label: "Target Object API Name", type: "Text", length: 255, description: "Target object derived from core metadata." },
      { name: "PopulationMode__c", label: "Population Mode", type: "Picklist", values: ["ALL_ACCESSIBLE", "GUIDED_FILTERED", "SUPPLIED_IDS"], description: "How target record IDs are populated." },
      { name: "FilterJson__c", label: "Guided Filter", type: "LongTextArea", description: "Structured filter JSON produced by packaged guided controls; never SOQL." },
      { name: "BatchSize__c", label: "Batch Size", type: "Number", precision: 3, description: "Batch execute scope from 1 through 200." },
      { name: "CaptureMode__c", label: "Capture Mode", type: "Picklist", values: ["FAIL", "PASS", "BOTH"], description: "Controls detailed Result retention and derived core publication." },
      { name: "CoalesceDelayMinutes__c", label: "Coalesce Delay Minutes", type: "Number", precision: 2, description: "Delay used to consolidate supplied IDs across transactions." }
    ]
  },
  {
    api: "Record_Health_Check_Schedule__c", label: "Record Health Check Schedule", plural: "Record Health Check Schedules", format: "RHC-SCH-{000000}", sharing: "Private",
    fields: [
      { name: "RunDefinition__c", label: "Run Definition", type: "Lookup", referenceTo: "Record_Health_Check_Run_Definition__c", relationshipLabel: "Schedules", relationshipName: "Schedules", description: "Saved definition launched by this schedule." },
      { name: "Active__c", label: "Active", type: "Checkbox", defaultValue: true, description: "Whether the schedule should remain registered." },
      { name: "Frequency__c", label: "Frequency", type: "Picklist", values: ["DAILY", "WEEKDAYS", "WEEKLY"], description: "Human recurrence converted to packaged CRON." },
      { name: "PreferredStartTime__c", label: "Preferred Start Time", type: "Text", length: 5, description: "Preferred local start time in HH:mm format." },
      { name: "DayOfWeek__c", label: "Day of Week", type: "Picklist", values: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], description: "Weekly recurrence day." },
      { name: "StartDate__c", label: "Start Date", type: "Date", description: "Optional first local date on which this schedule may launch." },
      { name: "EndDate__c", label: "End Date", type: "Date", description: "Optional last local date on which this schedule may launch." },
      { name: "CronTriggerId__c", label: "Cron Trigger ID", type: "Text", length: 18, unique: true, external: true, description: "Exact CronTrigger owned by this schedule." },
      { name: "LastFiredAt__c", label: "Last Fired At", type: "DateTime", description: "Most recent scheduled launch." }
    ]
  },
  {
    api: "Record_Health_Check_Batch_Run__c", label: "Record Health Check Batch Run", plural: "Record Health Check Batch Runs", format: "RHC-BATCH-{000000}", sharing: "Private",
    fields: [
      { name: "RunDefinition__c", label: "Run Definition", type: "Lookup", referenceTo: "Record_Health_Check_Run_Definition__c", relationshipLabel: "Batch Runs", relationshipName: "BatchRuns", description: "Saved definition used for this execution." },
      { name: "Schedule__c", label: "Schedule", type: "Lookup", referenceTo: "Record_Health_Check_Schedule__c", relationshipLabel: "Batch Runs", relationshipName: "BatchRuns", description: "Optional firing schedule." },
      { name: "AsyncApexJobId__c", label: "Async Apex Job ID", type: "Text", length: 18, description: "Owned Batch AsyncApexJob identity." },
      { name: "Source__c", label: "Source", type: "Picklist", values: ["RUN_NOW", "SCHEDULED", "SUPPLIED_IDS"], description: "Entry path that launched the shared execution service." },
      { name: "Status__c", label: "Status", type: "Picklist", values: ["QUEUED", "PROCESSING", "COMPLETED", "PARTIAL_FAILURE", "ERROR", "CANCELLED"], description: "Operational Batch Run status." },
      { name: "SubmittedRecordCount__c", label: "Submitted Record Count", type: "Number", description: "Records submitted to core across scopes." },
      { name: "ProcessedRecordCount__c", label: "Processed Record Count", type: "Number", description: "Records processed successfully." },
      { name: "FailedScopeCount__c", label: "Failed Scope Count", type: "Number", description: "Scopes that failed while prior scopes remained committed." },
      { name: "PassedCount__c", label: "Passed Count", type: "Number", description: "Total PASS results across completed scopes." },
      { name: "FailedCount__c", label: "Failed Count", type: "Number", description: "Total FAIL results across completed scopes." },
      { name: "UnableCount__c", label: "Unable Count", type: "Number", description: "Total UNABLE_TO_EVALUATE results across completed scopes." },
      { name: "SystemErrorCount__c", label: "System Error Count", type: "Number", description: "Total ERROR results across completed scopes." },
      { name: "StartedAt__c", label: "Started At", type: "DateTime", description: "Execution start." },
      { name: "CompletedAt__c", label: "Completed At", type: "DateTime", description: "Execution completion." },
      { name: "ErrorSummary__c", label: "Error Summary", type: "LongTextArea", length: 32768, description: "Sanitized operational error summary." }
    ]
  },
  {
    api: "Record_Health_Check_Run__c", label: "Record Health Check Run", plural: "Record Health Check Runs", format: "RHC-RUN-{000000}", sharing: "ControlledByParent",
    fields: [
      { name: "BatchRun__c", label: "Batch Run", type: "MasterDetail", referenceTo: "Record_Health_Check_Batch_Run__c", relationshipLabel: "Runs", relationshipName: "Runs", description: "Owning Batch Run." },
      { name: "RunId__c", label: "Run ID", type: "Text", length: 120, unique: true, external: true, description: "Caller correlation ID supplied to core." },
      { name: "ScopeNumber__c", label: "Scope Number", type: "Number", precision: 7, description: "One-based Batch scope sequence." },
      { name: "Status__c", label: "Status", type: "Picklist", values: ["IN_PROGRESS", "COMPLETED", "ERROR"], description: "Framework scope envelope status." },
      { name: "SelectionType__c", label: "Selection Type", type: "Picklist", values: ["CHECK_SET", "CHECK"], description: "Selected core metadata type." },
      { name: "QualifiedApiName__c", label: "Qualified API Name", type: "Text", length: 120, description: "Exact selected identity." },
      { name: "CheckSetQualifiedApiName__c", label: "Check Set Qualified API Name", type: "Text", length: 120, description: "Owning Check Set identity." },
      { name: "RecordCount__c", label: "Record Count", type: "Number", description: "Records in this scope." },
      { name: "PassedCount__c", label: "Passed Count", type: "Number" },
      { name: "FailedCount__c", label: "Failed Count", type: "Number" },
      { name: "SkippedCount__c", label: "Skipped Count", type: "Number" },
      { name: "UnableCount__c", label: "Unable Count", type: "Number" },
      { name: "SystemErrorCount__c", label: "System Error Count", type: "Number" },
      { name: "OccurredAt__c", label: "Occurred At", type: "DateTime" },
      { name: "CompletedAt__c", label: "Completed At", type: "DateTime" },
      { name: "ErrorSummary__c", label: "Error Summary", type: "LongTextArea", description: "Sanitized scope failure." }
    ]
  },
  {
    api: "Record_Health_Check_Run_Result__c", label: "Record Health Check Run Result", plural: "Record Health Check Run Results", format: "RHC-RESULT-{000000}", sharing: "ControlledByParent",
    fields: [
      { name: "Run__c", label: "Run", type: "MasterDetail", referenceTo: "Record_Health_Check_Run__c", relationshipLabel: "Results", relationshipName: "Results", description: "Owning framework Run." },
      { name: "ResultKey__c", label: "Result Key", type: "Text", length: 255, unique: true, external: true, description: "Idempotency key for one Run, record, and Check." },
      { name: "RecordId__c", label: "Record ID", type: "Text", length: 18, description: "Evaluated business record." },
      { name: "CheckQualifiedApiName__c", label: "Check Qualified API Name", type: "Text", length: 120, description: "Exact core Check identity." },
      { name: "Status__c", label: "Status", type: "Picklist", values: ["PASS", "FAIL", "UNABLE_TO_EVALUATE", "ERROR"], description: "Canonical retained core status." },
      { name: "Severity__c", label: "Severity", type: "Text", length: 30 },
      { name: "ReasonCode__c", label: "Reason Code", type: "Text", length: 120 },
      { name: "ComparisonOperator__c", label: "Comparison Operator", type: "Text", length: 40 },
      { name: "FoundValueJson__c", label: "Found Value JSON", type: "LongTextArea", description: "Serialized typed core Found value." },
      { name: "ExpectedValueJson__c", label: "Expected Value JSON", type: "LongTextArea", description: "Serialized typed core Expected value." },
      { name: "DiagnosticId__c", label: "Diagnostic ID", type: "Text", length: 120 },
      { name: "DiagnosticCategory__c", label: "Diagnostic Category", type: "Text", length: 80 },
      { name: "DiagnosticSummary__c", label: "Diagnostic Summary", type: "LongTextArea", description: "Disclosure-safe core diagnostic summary." },
      { name: "RecommendedAction__c", label: "Recommended Action", type: "LongTextArea", description: "Disclosure-safe core corrective action." },
      { name: "OccurredAt__c", label: "Occurred At", type: "DateTime" }
    ]
  },
  {
    api: "Record_Health_Check_Run_Request__c", label: "Record Health Check Run Request", plural: "Record Health Check Run Requests", format: "RHC-REQ-{000000}", sharing: "Private",
    fields: [
      { name: "RunDefinition__c", label: "Run Definition", type: "Lookup", referenceTo: "Record_Health_Check_Run_Definition__c", relationshipLabel: "Run Requests", relationshipName: "RunRequests", description: "Definition receiving this supplied target ID." },
      { name: "RequestKey__c", label: "Request Key", type: "Text", length: 255, unique: true, external: true, description: "Definition and target ID idempotency key." },
      { name: "RecordId__c", label: "Record ID", type: "Text", length: 18, description: "Supplied target record ID." },
      { name: "Status__c", label: "Status", type: "Picklist", values: ["PENDING", "SUBMITTED"], description: "Coalescing state." },
      { name: "RequestedAt__c", label: "Requested At", type: "DateTime", description: "Most recent request time." }
    ]
  },
  {
    api: "Record_Health_Check_Run_Setting__c", label: "Record Health Check Run Setting", plural: "Record Health Check Run Settings", nameType: "Text", sharing: "Private", internal: true,
    fields: [
      { name: "SettingKey__c", label: "Setting Key", type: "Text", length: 80, unique: true, external: true, description: "Stable singleton key for package-owned Run Manager settings." },
      { name: "RetentionDays__c", label: "Retention Days", type: "Number", precision: 4, description: "Whole days to retain completed Run Manager operational records before manual cleanup." }
    ]
  }
];

for (const object of objects) {
  const nameField = object.nameType === "Text"
    ? `<nameField><label>${object.label} Name</label><type>Text</type></nameField>`
    : `<nameField><displayFormat>${object.format}</displayFormat><label>${object.label} Number</label><type>AutoNumber</type></nameField>`;
  const enabled = !object.internal;
  write(`objects/${object.api}/${object.api}.object-meta.xml`, `<CustomObject${ns}><deploymentStatus>Deployed</deploymentStatus><description>Packaged RHC Run Manager operational data.</description><enableHistory>${enabled}</enableHistory><enableReports>${enabled}</enableReports><enableSearch>${enabled}</enableSearch><label>${object.label}</label>${nameField}<pluralLabel>${object.plural}</pluralLabel><sharingModel>${object.sharing}</sharingModel><visibility>Public</visibility></CustomObject>`);
  for (const field of object.fields) write(`objects/${object.api}/fields/${field.name}.field-meta.xml`, `<CustomField${ns}>${fieldXml(field)}</CustomField>`);
  if (!object.internal) write(`objects/${object.api}/listViews/All.listView-meta.xml`, `<ListView${ns}><fullName>All</fullName><filterScope>Everything</filterScope><label>All</label><columns>NAME</columns></ListView>`);
  if (!object.internal) write(`tabs/${object.api}.tab-meta.xml`, `<CustomTab${ns}><customObject>true</customObject><motif>Custom48: Trophy</motif><description>RHC Run Manager ${object.plural}.</description></CustomTab>`);
}

write("objects/Record_Health_Check_Run_Setting__c/validationRules/Retention_Days_Range.validationRule-meta.xml", `<ValidationRule${ns}><fullName>Retention_Days_Range</fullName><active>true</active><description>Requires a whole retention window from 1 through 3650 days.</description><errorConditionFormula>OR(ISBLANK(RetentionDays__c), RetentionDays__c &lt; 1, RetentionDays__c &gt; 3650, MOD(RetentionDays__c, 1) &lt;&gt; 0)</errorConditionFormula><errorDisplayField>RetentionDays__c</errorDisplayField><errorMessage>Retention Days must be a whole number from 1 through 3650.</errorMessage></ValidationRule>`);
write("objects/Record_Health_Check_Run_Setting__c/validationRules/Setting_Identity.validationRule-meta.xml", `<ValidationRule${ns}><fullName>Setting_Identity</fullName><active>true</active><description>Protects the package-owned singleton identity.</description><errorConditionFormula>OR(Name &lt;&gt; &quot;Default&quot;, SettingKey__c &lt;&gt; &quot;Default&quot;)</errorConditionFormula><errorMessage>The package-owned Run Manager setting must use the Default identity.</errorMessage></ValidationRule>`);
write("customPermissions/RHC_Run_Manager_Manage_Retention.customPermission-meta.xml", `<CustomPermission${ns}><description>Allows guarded manual cleanup of eligible Run Manager operational records.</description><label>Manage RHC Run Manager Retention</label></CustomPermission>`);

write("tabs/RHC_Run_Manager.tab-meta.xml", `<CustomTab${ns}><description>Administer and monitor RHC Run Manager.</description><label>RHC Run Manager</label><lwcComponent>rhcRunManager</lwcComponent><motif>Custom48: Trophy</motif></CustomTab>`);
write("applications/RHC_Run_Manager.app-meta.xml", `<CustomApplication${ns}><description>Configure, schedule, and monitor Record Health Check Batch runs.</description><formFactors>Large</formFactors><label>RHC Run Manager</label><navType>Standard</navType><tabs>RHC_Run_Manager</tabs><tabs>Record_Health_Check_Run_Definition__c</tabs><tabs>Record_Health_Check_Schedule__c</tabs><tabs>Record_Health_Check_Batch_Run__c</tabs><tabs>Record_Health_Check_Run__c</tabs><tabs>Record_Health_Check_Run_Result__c</tabs><uiType>Lightning</uiType></CustomApplication>`);

const apexClasses = ["RHCRunManagerAdminCommandService", "RHCRunManagerAdminController", "RHCRunManagerBatch", "RHCRunManagerCaptureService", "RHCRunManagerCoalescerQueueable", "RHCRunManagerCoreMetadataGateway", "RHCRunManagerExecutionService", "RHCRunManagerFilterService", "RHCRunManagerRetentionService", "RHCRunManagerScheduleService", "RHCRunManagerScheduled", "RHCRunManagerSubmitIdsAction"];
for (const apexClass of [...apexClasses, "RHCRunManagerUninstallHandler", "RHCRunManagerTestDataFactory", "RHCRunManagerAdminControllerTest", "RHCRunManagerAsyncTest", "RHCRunManagerCoreMetadataGatewayTest", "RHCRunManagerFilterServiceTest", "RHCRunManagerCaptureServiceTest", "RHCRunManagerExecutionTest", "RHCRunManagerRetentionServiceTest", "RHCRunManagerSubmitIdsActionTest", "RHCRunManagerUninstallHandlerTest"]) {
  write(`classes/${apexClass}.cls-meta.xml`, `<ApexClass${ns}><apiVersion>66.0</apiVersion><status>Active</status></ApexClass>`);
}
const sensitive = new Set(["FoundValueJson__c", "ExpectedValueJson__c"]);
const permissionSet = (name, label, admin, viewAll) => {
  const classAccess = admin ? apexClasses.map((apexClass) => `<classAccesses><apexClass>${apexClass}</apexClass><enabled>true</enabled></classAccesses>`).join("") : `<classAccesses><apexClass>RHCRunManagerAdminController</apexClass><enabled>true</enabled></classAccesses>`;
  const readableObjects = admin ? objects : objects.filter((object) => !object.internal);
  const fieldPermissions = readableObjects.flatMap((object) => object.fields.filter((field) => field.type !== "MasterDetail" && (admin || !sensitive.has(field.name))).map((field) => `<fieldPermissions><editable>${admin}</editable><field>${object.api}.${field.name}</field><readable>true</readable></fieldPermissions>`)).join("");
  const objectPermissions = readableObjects.map((object) => `<objectPermissions><allowCreate>${admin}</allowCreate><allowDelete>${admin}</allowDelete><allowEdit>${admin}</allowEdit><allowRead>true</allowRead><modifyAllRecords>${admin}</modifyAllRecords><object>${object.api}</object><viewAllRecords>${viewAll}</viewAllRecords></objectPermissions>`).join("");
  const tabs = readableObjects.filter((object) => !object.internal).map((object) => `<tabSettings><tab>${object.api}</tab><visibility>Visible</visibility></tabSettings>`).join("");
  const customPermissions = admin ? `<customPermissions><enabled>true</enabled><name>RHC_Run_Manager_Manage_Retention</name></customPermissions>` : "";
  write(`permissionsets/${name}.permissionset-meta.xml`, `<PermissionSet${ns}>${classAccess}${customPermissions}<description>${admin ? "Administer definitions, schedules, execution, retention, and all operational details." : "Read Run Manager operational summaries without restricted details."}</description>${fieldPermissions}<hasActivationRequired>false</hasActivationRequired><label>${label}</label>${objectPermissions}<tabSettings><tab>RHC_Run_Manager</tab><visibility>Visible</visibility></tabSettings>${tabs}</PermissionSet>`);
};
permissionSet("RHC_Run_Manager_Admin", "RHC Run Manager Admin", true, true);
permissionSet("RHC_Run_Manager_Viewer", "RHC Run Manager Viewer", false, true);

const executorObjects = objects.filter((object) => object.api !== "Record_Health_Check_Schedule__c" && !object.internal);
const executorClasses = ["RHCRunManagerSubmitIdsAction"];
const executorClassAccess = executorClasses.map((apexClass) => `<classAccesses><apexClass>${apexClass}</apexClass><enabled>true</enabled></classAccesses>`).join("");
const executorFieldPermissions = executorObjects.flatMap((object) => object.fields.filter((field) => field.type !== "MasterDetail").map((field) => {
  const editable = object.api !== "Record_Health_Check_Run_Definition__c";
  return `<fieldPermissions><editable>${editable}</editable><field>${object.api}.${field.name}</field><readable>true</readable></fieldPermissions>`;
})).join("");
const executorObjectPermissions = executorObjects.map((object) => {
  const writable = object.api !== "Record_Health_Check_Run_Definition__c";
  const viewAll = object.api === "Record_Health_Check_Run_Definition__c";
  return `<objectPermissions><allowCreate>${writable}</allowCreate><allowDelete>false</allowDelete><allowEdit>${writable}</allowEdit><allowRead>true</allowRead><modifyAllRecords>false</modifyAllRecords><object>${object.api}</object><viewAllRecords>${viewAll}</viewAllRecords></objectPermissions>`;
}).join("");
write("permissionsets/RHC_Run_Manager_Executor.permissionset-meta.xml", `<PermissionSet${ns}>${executorClassAccess}<description>Submit supplied target IDs from Flow and allow Run Manager-owned asynchronous capture without configuration or delete access.</description>${executorFieldPermissions}<hasActivationRequired>false</hasActivationRequired><label>RHC Run Manager Executor</label>${executorObjectPermissions}</PermissionSet>`);

if (checkOnly) {
  if (drift.length > 0) {
    console.error(`Generated metadata drift detected in ${drift.length} file(s):`);
    for (const relative of drift) console.error(`- force-app/main/default/${relative}`);
    process.exitCode = 1;
  } else {
    console.log("Generated metadata is current.");
  }
}
