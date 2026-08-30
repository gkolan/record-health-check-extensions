import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(projectRoot, "force-app/main/default");
const header = '<?xml version="1.0" encoding="UTF-8"?>\n';
const ns = ' xmlns="http://soap.sforce.com/2006/04/metadata"';
const checkOnly = process.argv.includes("--check");
const drift = [];
const escapeXml = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
const write = (relative, body) => {
  const target = path.join(root, relative);
  const expected = header + body.trim() + "\n";
  if (checkOnly) {
    if (!fs.existsSync(target) || fs.readFileSync(target, "utf8") !== expected)
      drift.push(relative);
    return;
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, expected);
};
const values = (items, defaultFirst = true) =>
  `<valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>${items.map((item, index) => `<value><fullName>${item}</fullName><default>${defaultFirst && index === 0}</default><label>${escapeXml(item.replaceAll("_", " "))}</label></value>`).join("")}</valueSetDefinition></valueSet>`;
const fieldXml = (field) => {
  const common = `<fullName>${field.name}</fullName><label>${escapeXml(field.label)}</label><description>${escapeXml(field.description)}</description><inlineHelpText>${escapeXml(field.help ?? field.description)}</inlineHelpText>`;
  if (field.type === "Text")
    return `${common}<length>${field.length ?? 255}</length>${field.external ? "<externalId>true</externalId>" : ""}${field.unique ? "<unique>true</unique>" : ""}<type>Text</type>`;
  if (field.type === "LongTextArea")
    return `${common}<length>${field.length ?? 32768}</length><visibleLines>${field.lines ?? 5}</visibleLines><type>LongTextArea</type>`;
  if (field.type === "Number")
    return `${common}<precision>${field.precision ?? 9}</precision><scale>0</scale><type>Number</type>`;
  if (field.type === "Checkbox")
    return `${common}<defaultValue>${field.defaultValue ?? false}</defaultValue><type>Checkbox</type>`;
  if (field.type === "DateTime") return `${common}<type>DateTime</type>`;
  if (field.type === "Picklist")
    return `${common}<type>Picklist</type>${values(field.values, field.defaultFirst !== false)}`;
  if (field.type === "Lookup")
    return `${common}<deleteConstraint>SetNull</deleteConstraint><referenceTo>${field.referenceTo}</referenceTo><relationshipLabel>${field.relationshipLabel}</relationshipLabel><relationshipName>${field.relationshipName}</relationshipName><required>false</required><type>Lookup</type>`;
  throw new Error(`Unsupported field type ${field.type}`);
};

const objects = [
  {
    api: "Record_Health_Check_Alert_Policy__c",
    label: "Record Health Check Alert Policy",
    plural: "Record Health Check Alert Policies",
    format: "RHC-AP-{000000}",
    description:
      "The Record Health Check Alert Policy object stores administrator-approved human notification criteria, recipients, channels, and per-record cooldowns for canonical core outcomes. Commonly used to route selected health-check failures without changing checked business records.",
    fields: [
      {
        name: "DisplayName__c",
        label: "Name",
        type: "Text",
        length: 80,
        description: "Administrator-facing policy name."
      },
      {
        name: "Active__c",
        label: "Active",
        type: "Checkbox",
        defaultValue: true,
        description:
          "Controls whether the event subscriber evaluates this policy."
      },
      {
        name: "SelectionType__c",
        label: "Selection Type",
        type: "Picklist",
        values: ["CHECK_SET", "CHECK"],
        description:
          "Identifies whether Qualified API Name is an exact Check Set or Check identity."
      },
      {
        name: "QualifiedApiName__c",
        label: "Qualified API Name",
        type: "Text",
        length: 120,
        description:
          "Exact core QualifiedApiName, including any namespace prefix."
      },
      {
        name: "MatchingStatuses__c",
        label: "Matching Statuses",
        type: "Text",
        length: 255,
        description:
          "Semicolon-delimited canonical statuses selected by the administrator."
      },
      {
        name: "MinimumSeverity__c",
        label: "Minimum Severity",
        type: "Picklist",
        values: ["INFO", "WARNING", "CRITICAL"],
        description: "Lowest canonical failure severity that can notify."
      },
      {
        name: "RecipientType__c",
        label: "Recipient Type",
        type: "Picklist",
        values: ["USER", "PUBLIC_GROUP"],
        description: "Human Salesforce recipient kind."
      },
      {
        name: "RecipientId__c",
        label: "Recipient ID",
        type: "Text",
        length: 18,
        description:
          "Exact User or public Group ID selected by the administrator."
      },
      {
        name: "RecipientLabel__c",
        label: "Recipient",
        type: "Text",
        length: 255,
        description:
          "Non-authoritative recipient label shown in administration views."
      },
      {
        name: "NotificationChannel__c",
        label: "Notification Channel",
        type: "Picklist",
        values: ["CUSTOM_NOTIFICATION", "EMAIL"],
        description: "Approved human delivery channel."
      },
      {
        name: "CooldownMinutes__c",
        label: "Cooldown Minutes",
        type: "Number",
        precision: 7,
        description:
          "Minimum minutes between successful deliveries for this policy and checked record."
      }
    ]
  },
  {
    api: "Record_Health_Check_Alert_Delivery__c",
    label: "Record Health Check Alert Delivery",
    plural: "Record Health Check Alert Deliveries",
    format: "RHC-AD-{000000}",
    description:
      "The Record Health Check Alert Delivery object records bounded notification attempts, successful delivery, suppression, duplicate detection, and sanitized failures. It retains operational alert evidence only, never general result history, restricted payloads, or stack traces.",
    fields: [
      {
        name: "Policy__c",
        label: "Alert Policy",
        type: "Lookup",
        referenceTo: "Record_Health_Check_Alert_Policy__c",
        relationshipLabel: "Alert Deliveries",
        relationshipName: "AlertDeliveries",
        description: "Policy evaluated for this event."
      },
      {
        name: "DeliveryKey__c",
        label: "Delivery Key",
        type: "Text",
        length: 64,
        external: true,
        unique: true,
        description:
          "SHA-256 event and policy claim that enforces idempotent processing."
      },
      {
        name: "EventId__c",
        label: "Event ID",
        type: "Text",
        length: 80,
        external: true,
        description: "Canonical core Event ID."
      },
      {
        name: "EventType__c",
        label: "Event Type",
        type: "Picklist",
        values: ["RESULT", "SET_RUN"],
        description:
          "Canonical core event contract that produced this ledger entry."
      },
      {
        name: "RunId__c",
        label: "Run ID",
        type: "Text",
        length: 120,
        description: "Canonical core run correlation ID."
      },
      {
        name: "CheckSetQualifiedApiName__c",
        label: "Check Set Qualified API Name",
        type: "Text",
        length: 120,
        description: "Exact Check Set Qualified API Name from core."
      },
      {
        name: "CheckQualifiedApiName__c",
        label: "Check Qualified API Name",
        type: "Text",
        length: 120,
        description: "Exact Check Qualified API Name from core when present."
      },
      {
        name: "RecordId__c",
        label: "Record ID",
        type: "Text",
        length: 18,
        description: "Checked Salesforce record ID when present."
      },
      {
        name: "Status__c",
        label: "Status",
        type: "Text",
        length: 30,
        description: "Canonical status used for policy evaluation."
      },
      {
        name: "Severity__c",
        label: "Severity",
        type: "Text",
        length: 20,
        description:
          "Canonical severity used for policy evaluation when present."
      },
      {
        name: "Outcome__c",
        label: "Outcome",
        type: "Picklist",
        values: ["PENDING", "DELIVERED", "SUPPRESSED", "FAILED", "DUPLICATE"],
        description: "Distinct operational result of this delivery attempt."
      },
      {
        name: "SuppressionReason__c",
        label: "Suppression Reason",
        type: "Picklist",
        values: [
          "COOLDOWN",
          "RUN_CONTRACT_INSUFFICIENT",
          "NO_RECIPIENTS",
          "POLICY_INACTIVE"
        ],
        defaultFirst: false,
        description: "Bounded reason why no human message was sent."
      },
      {
        name: "FailureClass__c",
        label: "Failure Class",
        type: "Picklist",
        values: ["TRANSIENT", "PERMANENT", "LIMIT", "CONFIGURATION"],
        defaultFirst: false,
        description:
          "Bounded retry and administrator classification; never an exception detail."
      },
      {
        name: "ErrorCode__c",
        label: "Error Code",
        type: "Text",
        length: 80,
        description:
          "Sanitized package error code without payload or stack trace."
      },
      {
        name: "AttemptCount__c",
        label: "Attempt Count",
        type: "Number",
        precision: 2,
        description: "Number of bounded delivery attempts."
      },
      {
        name: "RecipientCount__c",
        label: "Recipient Count",
        type: "Number",
        precision: 5,
        description: "Resolved human recipients for the attempt."
      },
      {
        name: "OccurredAt__c",
        label: "Occurred At",
        type: "DateTime",
        description: "Canonical event occurrence time."
      },
      {
        name: "AttemptedAt__c",
        label: "Attempted At",
        type: "DateTime",
        description: "Most recent delivery attempt time."
      },
      {
        name: "DeliveredAt__c",
        label: "Delivered At",
        type: "DateTime",
        description: "Successful human delivery time."
      },
      {
        name: "NextRetryAt__c",
        label: "Next Retry At",
        type: "DateTime",
        description: "Earliest scheduled retry time for a transient failure."
      },
      {
        name: "CooldownKey__c",
        label: "Cooldown Key",
        type: "Text",
        length: 64,
        external: true,
        description:
          "SHA-256 policy and checked-record key used for cooldown queries."
      }
    ]
  }
];

for (const object of objects) {
  write(
    `objects/${object.api}/${object.api}.object-meta.xml`,
    `<CustomObject${ns}><label>${object.label}</label><pluralLabel>${object.plural}</pluralLabel><description>${escapeXml(object.description)}</description><deploymentStatus>Deployed</deploymentStatus><enableReports>true</enableReports><enableSearch>true</enableSearch><nameField><label>${object.label} Number</label><type>AutoNumber</type><displayFormat>${object.format}</displayFormat><startingNumber>1</startingNumber></nameField><sharingModel>Private</sharingModel><visibility>Public</visibility></CustomObject>`
  );
  for (const field of object.fields)
    write(
      `objects/${object.api}/fields/${field.name}.field-meta.xml`,
      `<CustomField${ns}>${fieldXml(field)}</CustomField>`
    );
  write(
    `tabs/${object.api}.tab-meta.xml`,
    `<CustomTab${ns}><customObject>true</customObject><motif>Custom25: Alarm clock</motif></CustomTab>`
  );
}

const policyValidationRules = [
  {
    name: "RHC_Policy_Required_Values",
    formula:
      "OR(ISBLANK(DisplayName__c), ISBLANK(TEXT(SelectionType__c)), ISBLANK(QualifiedApiName__c), ISBLANK(MatchingStatuses__c), ISBLANK(TEXT(MinimumSeverity__c)), ISBLANK(TEXT(RecipientType__c)), ISBLANK(RecipientId__c), ISBLANK(TEXT(NotificationChannel__c)), ISBLANK(CooldownMinutes__c))",
    message: "Complete every policy field before saving."
  },
  {
    name: "RHC_Policy_Statuses_Canonical",
    formula:
      'AND(NOT(ISBLANK(MatchingStatuses__c)), NOT(REGEX(MatchingStatuses__c, "^(PASS|FAIL|SKIPPED|UNABLE_TO_EVALUATE|ERROR)(;(PASS|FAIL|SKIPPED|UNABLE_TO_EVALUATE|ERROR))*$")))',
    message:
      "Matching Statuses must be a semicolon-delimited list of canonical status values without spaces."
  },
  {
    name: "RHC_Policy_Recipient_Id_Type",
    formula:
      'AND(NOT(ISBLANK(RecipientId__c)), OR(NOT(OR(LEN(RecipientId__c) = 15, LEN(RecipientId__c) = 18)), AND(ISPICKVAL(RecipientType__c, "USER"), NOT(BEGINS(RecipientId__c, "005"))), AND(ISPICKVAL(RecipientType__c, "PUBLIC_GROUP"), NOT(BEGINS(RecipientId__c, "00G")))))',
    message:
      "Recipient ID must be a 15- or 18-character User or Group ID matching Recipient Type."
  },
  {
    name: "RHC_Policy_Cooldown_Nonnegative",
    formula: "AND(NOT(ISBLANK(CooldownMinutes__c)), CooldownMinutes__c < 0)",
    message: "Cooldown Minutes must be zero or greater."
  }
];
for (const rule of policyValidationRules) {
  write(
    `objects/Record_Health_Check_Alert_Policy__c/validationRules/${rule.name}.validationRule-meta.xml`,
    `<ValidationRule${ns}><fullName>${rule.name}</fullName><active>true</active><errorConditionFormula>${escapeXml(rule.formula)}</errorConditionFormula><errorMessage>${escapeXml(rule.message)}</errorMessage></ValidationRule>`
  );
}

write(
  "notificationtypes/RHC_Alert.notiftype-meta.xml",
  `<CustomNotificationType${ns}><customNotifTypeName>RHC Alert</customNotifTypeName><desktop>true</desktop><masterLabel>RHC Alert</masterLabel><mobile>true</mobile></CustomNotificationType>`
);
write(
  "tabs/RHC_Alerts_Admin.tab-meta.xml",
  `<CustomTab${ns}><label>RHC Alerts Administration</label><lwcComponent>rhcAlertsAdmin</lwcComponent><motif>Custom25: Alarm clock</motif></CustomTab>`
);
write(
  "tabs/RHC_Alerts_Delivery_History.tab-meta.xml",
  `<CustomTab${ns}><label>RHC Alerts Delivery History</label><lwcComponent>rhcAlertsDeliveryHistory</lwcComponent><motif>Custom53: Bell</motif></CustomTab>`
);
write(
  "applications/RHC_Alerts.app-meta.xml",
  `<CustomApplication${ns}><description>Configure RHC Alerts and review bounded delivery history.</description><formFactors>Large</formFactors><isNavAutoTempTabsDisabled>false</isNavAutoTempTabsDisabled><isNavPersonalizationDisabled>false</isNavPersonalizationDisabled><label>RHC Alerts</label><navType>Standard</navType><tabs>RHC_Alerts_Admin</tabs><tabs>RHC_Alerts_Delivery_History</tabs><tabs>Record_Health_Check_Alert_Policy__c</tabs><tabs>Record_Health_Check_Alert_Delivery__c</tabs><uiType>Lightning</uiType></CustomApplication>`
);

const classes = [
  "RHCAlertsAdminController",
  "RHCAlertsAdminControllerTest",
  "RHCAlertsCoreMetadataGateway",
  "RHCAlertsCoverageAnalyzer",
  "RHCAlertsCoverageAnalyzerTest",
  "RHCAlertsDeliveryFailure",
  "RHCAlertsDeliveryFailureTest",
  "RHCAlertsDeliveryQueueable",
  "RHCAlertsDeliveryService",
  "RHCAlertsDeliveryServiceTest",
  "RHCAlertsEventCandidateBuilder",
  "RHCAlertsEventCandidateBuilderTest",
  "RHCAlertsEventService",
  "RHCAlertsEventServiceTest",
  "RHCAlertsNotificationSender",
  "RHCAlertsNotificationSenderTest",
  "RHCAlertsPolicyValidator",
  "RHCAlertsPolicyValidatorTest",
  "RHCAlertsRecipientResolver",
  "RHCAlertsResultPolicyMatcher",
  "RHCAlertsResultPolicyMatcherTest",
  "RHCAlertsTestDataFactory",
  "RHCAlertsViewerController",
  "RHCAlertsViewerControllerTest"
];
const adminClasses = ["RHCAlertsAdminController", "RHCAlertsViewerController"];
const viewerFields = new Set([
  "Record_Health_Check_Alert_Policy__c.DisplayName__c",
  "Record_Health_Check_Alert_Delivery__c.Policy__c",
  "Record_Health_Check_Alert_Delivery__c.EventId__c",
  "Record_Health_Check_Alert_Delivery__c.EventType__c",
  "Record_Health_Check_Alert_Delivery__c.CheckSetQualifiedApiName__c",
  "Record_Health_Check_Alert_Delivery__c.CheckQualifiedApiName__c",
  "Record_Health_Check_Alert_Delivery__c.Status__c",
  "Record_Health_Check_Alert_Delivery__c.Severity__c",
  "Record_Health_Check_Alert_Delivery__c.Outcome__c",
  "Record_Health_Check_Alert_Delivery__c.SuppressionReason__c",
  "Record_Health_Check_Alert_Delivery__c.FailureClass__c",
  "Record_Health_Check_Alert_Delivery__c.ErrorCode__c",
  "Record_Health_Check_Alert_Delivery__c.AttemptCount__c",
  "Record_Health_Check_Alert_Delivery__c.RecipientCount__c",
  "Record_Health_Check_Alert_Delivery__c.OccurredAt__c",
  "Record_Health_Check_Alert_Delivery__c.AttemptedAt__c",
  "Record_Health_Check_Alert_Delivery__c.DeliveredAt__c"
]);
const permission = (admin) => {
  const parts = [];
  parts.push(
    `<applicationVisibilities><application>RHC_Alerts</application><visible>true</visible></applicationVisibilities>`
  );
  const allowedClasses = admin ? adminClasses : ["RHCAlertsViewerController"];
  for (const className of allowedClasses)
    parts.push(
      `<classAccesses><apexClass>${className}</apexClass><enabled>true</enabled></classAccesses>`
    );
  parts.push(
    `<description>${admin ? "Configure policies, inspect delivery history, and run setup coverage checks." : "Least-privilege read-only access to inspect delivery outcomes."}</description>`
  );
  for (const object of objects) {
    const editable = admin && object.api.endsWith("Policy__c");
    for (const field of object.fields) {
      const fieldName = `${object.api}.${field.name}`;
      if (admin || viewerFields.has(fieldName)) {
        parts.push(
          `<fieldPermissions><editable>${editable}</editable><field>${fieldName}</field><readable>true</readable></fieldPermissions>`
        );
      }
    }
  }
  parts.push(
    `<hasActivationRequired>false</hasActivationRequired><label>RHC Alerts ${admin ? "Admin" : "Viewer Runtime"}</label>`
  );
  for (const object of objects) {
    const editable = admin && object.api.endsWith("Policy__c");
    parts.push(
      `<objectPermissions><allowCreate>${editable}</allowCreate><allowDelete>${editable}</allowDelete><allowEdit>${editable}</allowEdit><allowRead>true</allowRead><modifyAllRecords>${editable}</modifyAllRecords><object>${object.api}</object><viewAllRecords>true</viewAllRecords></objectPermissions>`
    );
  }
  parts.push(
    `<tabSettings><tab>RHC_Alerts_Admin</tab><visibility>${admin ? "Visible" : "None"}</visibility></tabSettings>`
  );
  parts.push(
    `<tabSettings><tab>RHC_Alerts_Delivery_History</tab><visibility>Visible</visibility></tabSettings>`
  );
  for (const object of objects)
    parts.push(
      `<tabSettings><tab>${object.api}</tab><visibility>${admin ? "Visible" : "None"}</visibility></tabSettings>`
    );
  return `<PermissionSet${ns}>${parts.join("")}</PermissionSet>`;
};
write(
  "permissionsets/RHC_Alerts_Admin.permissionset-meta.xml",
  permission(true)
);
write(
  "permissionsets/RHC_Alerts_Viewer_Runtime.permissionset-meta.xml",
  permission(false)
);

for (const className of classes)
  write(
    `classes/${className}.cls-meta.xml`,
    `<ApexClass${ns}><apiVersion>66.0</apiVersion><status>Active</status></ApexClass>`
  );
for (const triggerName of [
  "RHCAlertsResultSubscriber",
  "RHCAlertsSetRunSubscriber"
])
  write(
    `triggers/${triggerName}.trigger-meta.xml`,
    `<ApexTrigger${ns}><apiVersion>66.0</apiVersion><status>Active</status></ApexTrigger>`
  );

if (checkOnly) {
  if (drift.length > 0) {
    process.stderr.write(
      `Generated metadata drift detected:\n${drift.map((file) => `- ${file}`).join("\n")}\n`
    );
    process.exitCode = 1;
  } else {
    process.stdout.write("Generated RHC Alerts metadata is current.\n");
  }
}
