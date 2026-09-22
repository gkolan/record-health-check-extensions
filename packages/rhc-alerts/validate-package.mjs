/* eslint-disable @lwc/lwc-platform/no-aura-libs, @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const exists = (relative) => fs.existsSync(path.join(root, relative));
const failures = [];
const assert = (condition, message) => {
  if (!condition) failures.push(message);
};

const project = JSON.parse(read("sfdx-project.json"));
const nodePackage = JSON.parse(read("package.json"));
const packageDirectory = project.packageDirectories?.[0];
assert(project.namespace === "rhc", "Namespace must remain rhc.");
assert(
  project.sourceApiVersion === "66.0",
  "Salesforce API version must remain 66.0."
);
assert(
  packageDirectory?.path === "force-app",
  "The package source root must remain force-app."
);
assert(
  packageDirectory?.versionNumber === "0.1.0.NEXT",
  "The unreleased source line must remain 0.1.0.NEXT."
);
assert(
  JSON.stringify(packageDirectory?.dependencies) ===
    JSON.stringify([{ package: "Record Health Check@2.0.4-2" }]),
  "RHC Alerts must depend on exactly Record Health Check@2.0.4-2."
);
assert(
  /^04t[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$/.test(
    project.packageAliases?.["Record Health Check@2.0.4-2"] ?? ""
  ),
  "The core dependency alias must resolve to a 04t package version."
);
assert(
  nodePackage.scripts?.["verify:prepackage"] ===
    "node scripts/verify-prepackage-gates.mjs",
  "The read-only pre-package lock must remain available."
);
assert(
  nodePackage.scripts?.["validate:slds"] ===
    "slds-linter lint force-app/main/default/lwc",
  "The pinned SLDS gate must remain available."
);
assert(
  nodePackage.scripts?.["format:check"]?.startsWith("prettier --check"),
  "The package formatting gate must remain available."
);
assert(
  nodePackage.scripts?.["preflight:local"] ===
    "node scripts/run-local-preflight.mjs",
  "The aggregate local preflight must remain available."
);
assert(
  nodePackage.scripts?.["test:prepackage-lock"] ===
    "node scripts/test-prepackage-lock.mjs",
  "The pre-package lock integration test must remain available."
);
const prepackageVerifier = read("scripts/verify-prepackage-gates.mjs");
assert(
  prepackageVerifier.includes("evidence?.testsPassed >= 55") &&
    prepackageVerifier.includes("local.lwc?.testsPassed >= 19"),
  "The pre-package lock must enforce the current 55 Apex and 19 Jest test contracts."
);
const releaseGates = read("docs/RELEASE-GATES.md");
assert(
  releaseGates.includes("all current 55 Apex test methods") &&
    releaseGates.includes("| 19 tests and thresholds 90/80/90/90"),
  "Release gates must document the current 55 Apex and 19 Jest test contracts."
);
assert(
  nodePackage.devDependencies?.["@salesforce-ux/slds-linter"] === "1.2.1",
  "The SLDS linter must remain exactly pinned to 1.2.1."
);
assert(
  nodePackage.devDependencies?.["@salesforce/sfdx-lwc-jest"] === "8.0.0",
  "The LWC Jest runner must remain exactly pinned to 8.0.0."
);
assert(
  nodePackage.devDependencies?.prettier === "3.8.4",
  "Prettier must remain exactly pinned to 3.8.4."
);
assert(
  nodePackage.devDependencies?.["prettier-plugin-apex"] === "2.2.6",
  "The Apex formatter must remain exactly pinned to 2.2.6."
);
assert(
  exists("release-evidence/prepackage.template.json"),
  "The tracked pre-package evidence template must remain present."
);
const suiteIgnore = fs.readFileSync(
  path.resolve(root, "../..", ".gitignore"),
  "utf8"
);
assert(
  suiteIgnore.split(/\r?\n/).includes(".release-evidence/"),
  "Mutable release evidence must remain excluded from Git."
);
for (const [name, command] of Object.entries(nodePackage.scripts ?? {})) {
  assert(
    !/\bsf\s+package(?:\s+version)?\s+create\b/.test(command),
    `Package creation command must not be exposed through npm script ${name}.`
  );
}

const viewer = read(
  "force-app/main/default/permissionsets/RHC_Alerts_Viewer_Runtime.permissionset-meta.xml"
);
const admin = read(
  "force-app/main/default/permissionsets/RHC_Alerts_Admin.permissionset-meta.xml"
);
const viewerAllowedFields = new Set([
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
const actualViewerFields = new Set(
  [...viewer.matchAll(/<field>([^<]+)<\/field>/g)].map((match) => match[1])
);
assert(
  actualViewerFields.size === viewerAllowedFields.size &&
    [...actualViewerFields].every((field) => viewerAllowedFields.has(field)),
  "Viewer field access must match the reviewed history-only allow list."
);
assert(
  !viewer.includes("<editable>true</editable>"),
  "Viewer must not have editable field access."
);
assert(
  viewer.includes("<apexClass>RHCAlertsViewerController</apexClass>"),
  "Viewer must have the bounded history controller."
);
assert(
  !viewer.includes("<apexClass>RHCAlertsAdminController</apexClass>"),
  "Viewer must not have administration or recipient-directory Apex access."
);
assert(
  !viewer.includes("<allowCreate>true</allowCreate>") &&
    !viewer.includes("<allowEdit>true</allowEdit>") &&
    !viewer.includes("<allowDelete>true</allowDelete>"),
  "Viewer must not mutate package records."
);
assert(
  viewer.includes(
    "<tab>Record_Health_Check_Alert_Policy__c</tab><visibility>None</visibility>"
  ),
  "Viewer policy object tab must be hidden."
);
assert(
  viewer.includes(
    "<tab>Record_Health_Check_Alert_Delivery__c</tab><visibility>None</visibility>"
  ),
  "Viewer delivery object tab must be hidden in favor of bounded history."
);
const adminClasses = [...admin.matchAll(/<apexClass>([^<]+)<\/apexClass>/g)]
  .map((match) => match[1])
  .sort();
assert(
  JSON.stringify(adminClasses) ===
    JSON.stringify(["RHCAlertsAdminController", "RHCAlertsViewerController"]),
  "Admin Apex access must expose only the two user-facing controllers."
);
assert(
  !admin.includes("<apexClass>RHCAlertsEventService</apexClass>") &&
    !admin.includes("<apexClass>RHCAlertsDeliveryService</apexClass>"),
  "Permission sets must not expose internal event or delivery services as user entry points."
);
assert(
  !viewer.includes("Record_Health_Check_Alert_Setting__c"),
  "Viewer access must not expose administrator-only retention settings."
);
assert(
  admin.includes(
    "<allowCreate>false</allowCreate><allowDelete>true</allowDelete><allowEdit>true</allowEdit><allowRead>true</allowRead><modifyAllRecords>true</modifyAllRecords><object>Record_Health_Check_Alert_Delivery__c</object>"
  ),
  "Admin access must satisfy Salesforce's Edit dependency for bounded delivery cleanup."
);
assert(
  admin.includes(
    "<allowCreate>true</allowCreate><allowDelete>false</allowDelete><allowEdit>true</allowEdit><allowRead>true</allowRead><modifyAllRecords>false</modifyAllRecords><object>Record_Health_Check_Alert_Setting__c</object><viewAllRecords>false</viewAllRecords>"
  ),
  "Admin access must permit retention configuration without generic setting deletion."
);

for (const rule of [
  "RHC_Policy_Required_Values",
  "RHC_Policy_Statuses_Canonical",
  "RHC_Policy_Recipient_Id_Type",
  "RHC_Policy_Cooldown_Nonnegative"
]) {
  const relative = `force-app/main/default/objects/Record_Health_Check_Alert_Policy__c/validationRules/${rule}.validationRule-meta.xml`;
  assert(exists(relative), `Missing policy validation rule ${rule}.`);
  if (exists(relative))
    assert(
      read(relative).includes("<active>true</active>"),
      `Policy validation rule ${rule} must be active.`
    );
}
for (const rule of ["RHC_Setting_Retention_Range", "RHC_Setting_Identity"]) {
  const relative = `force-app/main/default/objects/Record_Health_Check_Alert_Setting__c/validationRules/${rule}.validationRule-meta.xml`;
  assert(exists(relative), `Missing alert-setting validation rule ${rule}.`);
  if (exists(relative))
    assert(
      read(relative).includes("<active>true</active>"),
      `Alert-setting validation rule ${rule} must be active.`
    );
}

const eventService = read(
  "force-app/main/default/classes/RHCAlertsEventService.cls"
);
const eventCandidateBuilder = read(
  "force-app/main/default/classes/RHCAlertsEventCandidateBuilder.cls"
);
const queueable = read(
  "force-app/main/default/classes/RHCAlertsDeliveryQueueable.cls"
);
const deliveryService = read(
  "force-app/main/default/classes/RHCAlertsDeliveryService.cls"
);
const deliveryFailure = read(
  "force-app/main/default/classes/RHCAlertsDeliveryFailure.cls"
);
const notificationSender = read(
  "force-app/main/default/classes/RHCAlertsNotificationSender.cls"
);
const adminController = read(
  "force-app/main/default/classes/RHCAlertsAdminController.cls"
);
const policyAdminService = read(
  "force-app/main/default/classes/RHCAlertsPolicyAdminService.cls"
);
const retentionService = read(
  "force-app/main/default/classes/RHCAlertsRetentionService.cls"
);
const coreMetadataGateway = read(
  "force-app/main/default/classes/RHCAlertsCoreMetadataGateway.cls"
);
const coverageAnalyzer = read(
  "force-app/main/default/classes/RHCAlertsCoverageAnalyzer.cls"
);
const policyValidator = read(
  "force-app/main/default/classes/RHCAlertsPolicyValidator.cls"
);
assert(
  adminController.includes("RHCAlertsPolicyAdminService.savePolicy(policy)") &&
    policyAdminService.includes(
      "RHCAlertsPolicyValidator.validationError(policy)"
    ),
  "Admin saves must delegate to the canonical policy validator."
);
assert(
  adminController.includes("RHCAlertsRetentionService.purgeDeliveries()") &&
    retentionService.includes("MAX_PURGE_ROWS = 1000") &&
    retentionService.includes("Outcome__c IN :TERMINAL_OUTCOMES") &&
    retentionService.includes("CreatedDate < :cutoff"),
  "Delivery cleanup must remain bounded to old terminal rows."
);
assert(
  policyValidator.includes("CANONICAL_STATUSES") &&
    policyValidator.includes("NOTIFICATION_CHANNELS"),
  "Policy validator must enforce canonical statuses and notification channels."
);
assert(
  coreMetadataGateway.includes("RHCAlertsCoverageAnalyzer.analyzeCoverage()"),
  "Core metadata coverage checks must delegate to the focused analyzer."
);
assert(
  coverageAnalyzer.includes("WITH USER_MODE"),
  "Policy coverage analysis must retain user-mode policy access."
);
assert(
  eventService.includes("MAX_CLAIMS_PER_BATCH = 2000"),
  "Platform Event policy fan-out must remain bounded at 2,000 claims."
);
assert(
  eventService.includes("RHCAlertsEventCandidateBuilder.resultCandidates") &&
    eventService.includes("RHCAlertsEventCandidateBuilder.setRunCandidates"),
  "Event orchestration must delegate bounded candidate construction."
);
assert(
  eventCandidateBuilder.includes("ErrorCode__c = 'EVENT_POLICY_FANOUT_LIMIT'"),
  "Fan-out overflow must create durable bounded evidence."
);
assert(
  eventService.includes("ErrorCode__c = 'QUEUE_ENQUEUE_FAILED'"),
  "Queue dispatch failure must create durable bounded evidence."
);
assert(
  queueable.includes("implements Queueable, Finalizer"),
  "Delivery Queueable must retain Finalizer recovery."
);
assert(
  queueable.includes("ErrorCode__c = 'QUEUEABLE_UNHANDLED_FAILURE'"),
  "Unhandled Queueable failures must leave terminal evidence."
);
assert(
  deliveryService.includes("RHCAlertsNotificationSender.send"),
  "Delivery orchestration must delegate notification transport."
);
assert(
  deliveryService.includes("RHCAlertsDeliveryFailure.fromCode") &&
    deliveryFailure.includes("'UNABLE_TO_LOCK_ROW'"),
  "Delivery failures must use bounded centralized retry classification."
);
assert(
  notificationSender.includes("Messaging.sendEmail(messages, true)"),
  "Email audience submission must remain atomic."
);
assert(
  deliveryService.includes(
    "throw new DeliveryException('LEDGER_UPDATE_FAILED')"
  ),
  "Partial ledger update failures must not be ignored."
);
assert(
  deliveryService.includes(
    "failTerminal(row, 'CONFIGURATION', 'POLICY_UNAVAILABLE')"
  ),
  "Deleted policies must terminally disposition claimed rows."
);

const ignoredPartialDml = [
  ...eventService.matchAll(
    /Database\.(?:insert|update|upsert|delete)\([^;]+,\s*false\s*\);/g
  )
].filter(
  (match) =>
    !eventService
      .slice(Math.max(0, match.index - 80), match.index)
      .includes("=")
);
assert(
  ignoredPartialDml.length === 0,
  "Partial-success DML results in the event service must be inspected."
);

if (failures.length > 0) {
  process.stderr.write(
    `RHC Alerts validation failed:\n${failures.map((failure) => `- ${failure}`).join("\n")}\n`
  );
  process.exitCode = 1;
} else {
  process.stdout.write("RHC Alerts local package contracts passed.\n");
}
