import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(projectRoot, "force-app/main/default");
const header = '<?xml version="1.0" encoding="UTF-8"?>\n';
const namespace = ' xmlns="http://soap.sforce.com/2006/04/metadata"';
const escapeXml = (value) => String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const write = (relative, body) => {
  const target = path.join(root, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, header + body.trim() + "\n");
};
const picklist = (values) => `<valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>${values.map((value, index) => `<value><fullName>${value}</fullName><default>${index === 0}</default><label>${escapeXml(value.replaceAll("_", " "))}</label></value>`).join("")}</valueSetDefinition></valueSet>`;
const fieldXml = (field) => {
  const common = `<fullName>${field.name}</fullName><label>${escapeXml(field.label)}</label><description>${escapeXml(field.description)}</description><inlineHelpText>${escapeXml(field.description)}</inlineHelpText>`;
  if (field.type === "Text") return `${common}<length>${field.length}</length>${field.external ? "<externalId>true</externalId>" : ""}${field.unique ? "<unique>true</unique>" : ""}<type>Text</type>`;
  if (field.type === "LongTextArea") return `${common}<length>${field.length ?? 32768}</length><visibleLines>${field.lines ?? 5}</visibleLines><type>LongTextArea</type>`;
  if (field.type === "Number") return `${common}<precision>${field.precision ?? 18}</precision><scale>0</scale><type>Number</type>`;
  if (field.type === "Checkbox") return `${common}<defaultValue>${field.defaultValue ?? false}</defaultValue><type>Checkbox</type>`;
  if (field.type === "DateTime") return `${common}<type>DateTime</type>`;
  if (field.type === "Picklist") return `${common}<type>Picklist</type>${picklist(field.values)}`;
  if (field.type === "Lookup") return `${common}<deleteConstraint>SetNull</deleteConstraint><referenceTo>${field.referenceTo}</referenceTo><relationshipLabel>${field.relationshipLabel}</relationshipLabel><relationshipName>${field.relationshipName}</relationshipName><required>false</required><type>Lookup</type>`;
  throw new Error(`Unsupported field type: ${field.type}`);
};

const objects = [
  {
    api: "Record_Health_Check_Change_Policy__c",
    label: "Record Health Check Change Policy",
    plural: "Record Health Check Change Policies",
    format: "RHC-CP-{000000}",
    fields: [
      { name: "DisplayName__c", label: "Display Name", type: "Text", length: 80, description: "Administrator-facing name for this approved CDC route." },
      { name: "Active__c", label: "Active", type: "Checkbox", defaultValue: false, description: "Controls whether new CDC work can be claimed and dispatched." },
      { name: "SourceObjectApiName__c", label: "Source Object API Name", type: "Text", length: 120, description: "Exact source object API name, not the ChangeEvent type." },
      { name: "SelectionType__c", label: "Selection Type", type: "Picklist", values: ["CHECK_SET", "CHECK"], description: "Identifies whether the exact core selection is a Check Set or Check." },
      { name: "QualifiedApiName__c", label: "Qualified API Name", type: "Text", length: 120, description: "Exact opaque core Qualified API Name; namespace text is never rewritten." },
      { name: "ChangeTypes__c", label: "Change Types", type: "Text", length: 255, description: "Closed set of CREATE, UPDATE, and UNDELETE values." },
      { name: "ChangedFields__c", label: "Changed Fields", type: "LongTextArea", length: 32768, lines: 5, description: "Optional newline-delimited exact field API names used only for UPDATE routing." },
      { name: "EventPublication__c", label: "Event Publication", type: "Picklist", values: ["ACTIONABLE", "NONE", "ALL"], description: "Explicit core result-event publication mode." },
      { name: "ActiveAfter__c", label: "Active After", type: "DateTime", description: "Optional event-time boundary that prevents older replayed events from becoming new work." }
    ]
  },
  {
    api: "Record_Health_Check_Change_Evaluation__c",
    label: "Record Health Check Change Evaluation",
    plural: "Record Health Check Change Evaluations",
    format: "RHC-CE-{000000}",
    fields: [
      { name: "Policy__c", label: "Policy", type: "Lookup", referenceTo: "Record_Health_Check_Change_Policy__c", relationshipLabel: "Change Evaluations", relationshipName: "ChangeEvaluations", description: "Policy that accepted or classified the CDC work; policy deletion sets this reference to null." },
      { name: "ClaimKey__c", label: "Claim Key", type: "Text", length: 64, external: true, unique: true, description: "SHA-256 digest of the versioned event-policy-record identity." },
      { name: "SourceObjectApiName__c", label: "Source Object API Name", type: "Text", length: 120, description: "Exact source object identity." },
      { name: "RecordId__c", label: "Record ID", type: "Text", length: 18, description: "Source record correlation stored as text, never a relationship." },
      { name: "ChangeType__c", label: "Change Type", type: "Picklist", values: ["CREATE", "UPDATE", "UNDELETE", "DELETE", "GAP", "UNKNOWN"], description: "Observed supported change type or normalized unsupported category." },
      { name: "TransactionKey__c", label: "Transaction Key", type: "Text", length: 80, description: "Bounded CDC transaction correlation." },
      { name: "SequenceNumber__c", label: "Sequence Number", type: "Number", precision: 18, description: "CDC order evidence within a transaction." },
      { name: "ReplayId__c", label: "Replay ID", type: "Text", length: 80, description: "Opaque stream-position evidence; never used as a business record ID." },
      { name: "RunId__c", label: "Run ID", type: "Text", length: 120, description: "Caller correlation supplied to core after dispatch." },
      { name: "OccurredAt__c", label: "Occurred At", type: "DateTime", description: "CDC commit or event time when available." },
      { name: "AcceptedAt__c", label: "Accepted At", type: "DateTime", description: "Time the package created the durable claim." },
      { name: "CompletedAt__c", label: "Completed At", type: "DateTime", description: "Time the orchestration record reached a terminal state." },
      { name: "Outcome__c", label: "Outcome", type: "Picklist", values: ["PENDING", "EVALUATED", "IGNORED", "FAILED", "DUPLICATE"], description: "Bounded orchestration state; this is not a core health status." },
      { name: "ReasonCode__c", label: "Reason Code", type: "Picklist", values: ["ACCEPTED", "RECORD_DELETED", "GAP_DETECTED", "UNSUPPORTED_CHANGE_TYPE", "CHANGE_TYPE_NOT_SELECTED", "CHANGED_FIELDS_NOT_MATCHED", "POLICY_INACTIVE", "EVENT_BEFORE_ACTIVATION", "RUNTIME_PERMISSION_MISSING", "CORE_CONFIGURATION_INVALID", "SOURCE_RECORD_UNAVAILABLE", "TRANSIENT_RETRY", "RETRY_EXHAUSTED", "DISPATCH_CHAIN_EXHAUSTED"], description: "Package-owned bounded routing or failure reason; raw exception text is never stored." },
      { name: "AttemptCount__c", label: "Attempt Count", type: "Number", precision: 2, description: "Bounded dispatch attempts." },
      { name: "ResultCount__c", label: "Result Count", type: "Number", precision: 9, description: "Count of core evaluation results for this source record." },
      { name: "ActionableCount__c", label: "Actionable Count", type: "Number", precision: 9, description: "Count of FAIL, UNABLE_TO_EVALUATE, and ERROR results." }
    ]
  }
];

for (const object of objects) {
  write(`objects/${object.api}/${object.api}.object-meta.xml`, `<CustomObject${namespace}><deploymentStatus>Deployed</deploymentStatus><description>${escapeXml(object.label)} records owned by RHC Change Monitor.</description><enableActivities>false</enableActivities><enableFeeds>false</enableFeeds><enableHistory>false</enableHistory><enableReports>true</enableReports><label>${object.label}</label><nameField><displayFormat>${object.format}</displayFormat><label>${object.label} Number</label><type>AutoNumber</type></nameField><pluralLabel>${object.plural}</pluralLabel><sharingModel>Private</sharingModel></CustomObject>`);
  for (const field of object.fields) write(`objects/${object.api}/fields/${field.name}.field-meta.xml`, `<CustomField${namespace}>${fieldXml(field)}</CustomField>`);
}

const classes = [
  "RHCChangeMonitorClaimKey",
  "RHCChangeMonitorDispatchSupport",
  "RHCChangeMonitorEventEnvelope",
  "RHCChangeMonitorEventParser",
  "RHCChangeMonitorRoutingService",
  "RHCChangeMonitorIntake",
  "RHCChangeMonitorDispatcherQueueable"
];
// Package-owned dispatch event: the CDC trigger (Automated Process) only claims and publishes;
// the subscriber's PlatformEventSubscriberConfig runs this event's trigger as a named runtime user.
const dispatchEvent = "Record_Health_Check_Change_Dispatch__e";
write(`objects/${dispatchEvent}/${dispatchEvent}.object-meta.xml`, `<CustomObject${namespace}><deploymentStatus>Deployed</deploymentStatus><description>Signals that durable Change Monitor claims are waiting for dispatch. Carries no record data.</description><eventType>HighVolume</eventType><label>Record Health Check Change Dispatch</label><pluralLabel>Record Health Check Change Dispatches</pluralLabel><publishBehavior>PublishAfterCommit</publishBehavior></CustomObject>`);
write(`objects/${dispatchEvent}/fields/ClaimCount__c.field-meta.xml`, `<CustomField${namespace}><fullName>ClaimCount__c</fullName><label>Claim Count</label><description>Number of pending claims persisted by the publishing intake transaction.</description><precision>9</precision><scale>0</scale><type>Number</type></CustomField>`);
const eventAccess = `<objectPermissions><allowCreate>true</allowCreate><allowDelete>false</allowDelete><allowEdit>false</allowEdit><allowRead>true</allowRead><modifyAllRecords>false</modifyAllRecords><object>${dispatchEvent}</object><viewAllRecords>false</viewAllRecords></objectPermissions>`;
const adminClasses = [...classes, "RHCChangeMonitorAdminController"];
const fieldAccess = (editable) => objects.flatMap((object) => object.fields.map((field) => `<fieldPermissions><editable>${editable}</editable><field>${object.api}.${field.name}</field><readable>true</readable></fieldPermissions>`)).join("");
const objectAccess = (admin) => objects.map((object) => `<objectPermissions><allowCreate>${admin}</allowCreate><allowDelete>${admin}</allowDelete><allowEdit>${admin}</allowEdit><allowRead>true</allowRead><modifyAllRecords>${admin}</modifyAllRecords><object>${object.api}</object><viewAllRecords>true</viewAllRecords></objectPermissions>`).join("");
const runtimeFieldAccess = objects.flatMap((object) => object.fields.map((field) => `<fieldPermissions><editable>${object.api === "Record_Health_Check_Change_Evaluation__c"}</editable><field>${object.api}.${field.name}</field><readable>true</readable></fieldPermissions>`)).join("");
const runtimeObjectAccess = objects.map((object) => {
  const evaluation = object.api === "Record_Health_Check_Change_Evaluation__c";
  return `<objectPermissions><allowCreate>${evaluation}</allowCreate><allowDelete>false</allowDelete><allowEdit>${evaluation}</allowEdit><allowRead>true</allowRead><modifyAllRecords>false</modifyAllRecords><object>${object.api}</object><viewAllRecords>true</viewAllRecords></objectPermissions>`;
}).join("");
write("permissionsets/RHC_Change_Monitor_Admin.permissionset-meta.xml", `<PermissionSet${namespace}><applicationVisibilities><application>RHC_Change_Monitor</application><visible>true</visible></applicationVisibilities>${adminClasses.map((name) => `<classAccesses><apexClass>${name}</apexClass><enabled>true</enabled></classAccesses>`).join("")}<description>Administer CDC policies and inspect all bounded Change Monitor operational evidence.</description>${fieldAccess(true)}<hasActivationRequired>false</hasActivationRequired><label>RHC Change Monitor Admin</label>${objectAccess(true)}${eventAccess}<tabSettings><tab>RHC_Change_Monitor</tab><visibility>Visible</visibility></tabSettings></PermissionSet>`);
write("permissionsets/RHC_Change_Monitor_Runtime.permissionset-meta.xml", `<PermissionSet${namespace}>${classes.map((name) => `<classAccesses><apexClass>${name}</apexClass><enabled>true</enabled></classAccesses>`).join("")}<description>Least-privilege data and Apex access for the configured Change Monitor asynchronous runtime principal. Assign together with a core runner permission set.</description>${runtimeFieldAccess}<hasActivationRequired>false</hasActivationRequired><label>RHC Change Monitor Runtime</label>${runtimeObjectAccess}${eventAccess}</PermissionSet>`);
write("permissionsets/RHC_Change_Monitor_Viewer.permissionset-meta.xml", `<PermissionSet${namespace}><description>Read Change Monitor policy and bounded operational evidence without mutation rights.</description>${fieldAccess(false)}<hasActivationRequired>false</hasActivationRequired><label>RHC Change Monitor Viewer</label>${objectAccess(false)}</PermissionSet>`);
