import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = path.join(packageRoot, 'force-app', 'main', 'default');
const failures = [];

function check(condition, message) {
  if (!condition) failures.push(message);
}

function read(relativePath) {
  return fs.readFileSync(path.join(packageRoot, relativePath), 'utf8');
}

function editableFields(permissionText) {
  return [...permissionText.matchAll(
    /<fieldPermissions>\s*<editable>true<\/editable>\s*<field>([^<]+)<\/field>/g
  )].map(match => match[1]);
}

function objectPermissions(permissionText, objectName) {
  const blocks = [...permissionText.matchAll(/<objectPermissions>([\s\S]*?)<\/objectPermissions>/g)];
  return blocks.map(match => match[1]).find(block =>
    block.includes(`<object>${objectName}</object>`)
  ) ?? '';
}

for (const [directoryName, suffix] of [['classes', '.cls'], ['triggers', '.trigger']]) {
  const directory = path.join(sourceRoot, directoryName);
  for (const implementation of fs.readdirSync(directory).filter(name => name.endsWith(suffix))) {
    check(
      fs.existsSync(path.join(directory, `${implementation}-meta.xml`)),
      `Missing metadata companion for ${directoryName}/${implementation}`
    );
  }
}

const apexText = [
  ...fs.readdirSync(path.join(sourceRoot, 'classes'))
    .filter(name => name.endsWith('.cls'))
    .map(name => read(`force-app/main/default/classes/${name}`)),
  ...fs.readdirSync(path.join(sourceRoot, 'triggers'))
    .filter(name => name.endsWith('.trigger'))
    .map(name => read(`force-app/main/default/triggers/${name}`))
].join('\n');
check(!apexText.includes('rhc__'), 'Apex source must not hard-code the package namespace');
check(!apexText.includes('Test.isRunningTest()'), 'Production Apex must use injectable boundaries, not test branches');

const execution = read('force-app/main/default/classes/RHCActionExecutionService.cls');
for (const invariant of [
  'Policy__r.Active__c',
  "FeatureManagement.checkPermission('RHC_Actions_Approve')",
  "'RHC_Actions_Automatic_Execution'",
  'history.Completed_At__c >= cutoff',
  'AccessLevel.SYSTEM_MODE'
]) {
  check(execution.includes(invariant), `Execution containment invariant is missing: ${invariant}`);
}

const capture = read('force-app/main/default/classes/RHCActionCaptureService.cls');
for (const invariant of [
  'StatusCode.DUPLICATE_VALUE',
  'StatusCode.UNABLE_TO_LOCK_ROW',
  'TransientCaptureException',
  'AccessLevel.USER_MODE',
  'captureFailure'
]) {
  check(capture.includes(invariant), `Capture resilience invariant is missing: ${invariant}`);
}
const subscriber = read('force-app/main/default/classes/RHCActionResultSubscriberHandler.cls');
check(subscriber.includes('setResumeCheckpoint'), 'Platform Event subscriber must set resume checkpoints');
check(subscriber.includes('EventBus.RetryableException'), 'First-chunk transient failures must request bounded retry');

const queueable = read('force-app/main/default/classes/RHCActionExecutionQueueable.cls');
const finalizer = read('force-app/main/default/classes/RHCActionExecutionFinalizer.cls');
check(queueable.includes('System.attachFinalizer'), 'Execution Queueable must attach a recovery finalizer');
for (const invariant of [
  'WITH SYSTEM_MODE',
  'AccessLevel.SYSTEM_MODE',
  'ASYNC_EXECUTION_RETRYABLE',
  'ASYNC_EXECUTION_FAILED',
  'ASYNC_RECOVERY_ENQUEUE_FAILED'
]) {
  check(finalizer.includes(invariant), `Execution finalizer invariant is missing: ${invariant}`);
}

const review = read('force-app/main/default/classes/RHCActionReviewController.cls');
check(review.includes('WITH USER_MODE'), 'Review visibility and locking must remain user-mode');
check(review.includes('AccessLevel.SYSTEM_MODE'), 'Authorized review transitions must use package-state DML');

const permissions = Object.fromEntries(['Admin', 'Approver', 'Runtime', 'Viewer'].map(role => [
  role,
  read(`force-app/main/default/permissionsets/RHC_Actions_${role}.permissionset-meta.xml`)
]));
check(
  editableFields(permissions.Admin).every(field => field.startsWith('RHC_Action_Policy__c.')),
  'Admin may edit policy fields only; pending and history state are package-owned'
);
check(
  !objectPermissions(permissions.Admin, 'RHC_Action_Policy__c').includes('<modifyAllRecords>true</modifyAllRecords>'),
  'Admin must not receive Modify All because Salesforce couples it to delete access'
);
check(editableFields(permissions.Approver).length === 0, 'Approver must have read-only field access');
check(editableFields(permissions.Viewer).length === 0, 'Viewer must have read-only field access');
check(
  editableFields(permissions.Runtime).every(field => field.startsWith('RHC_Pending_Action__c.')),
  'Runtime writable fields must be limited to pending-action capture fields'
);
for (const role of ['Admin', 'Approver', 'Runtime', 'Viewer']) {
  for (const objectName of ['RHC_Action_Policy__c', 'RHC_Pending_Action__c', 'RHC_Action_History__c']) {
    const block = objectPermissions(permissions[role], objectName);
    check(block.includes('<viewAllRecords>true</viewAllRecords>'), `${role} must see cross-owner ${objectName} records`);
  }
}
check(
  !permissions.Admin.includes('<name>RHC_Actions_Automatic_Execution</name>'),
  'Admin must not receive automatic execution permission'
);
check(
  permissions.Runtime.includes('<name>RHC_Actions_Automatic_Execution</name>'),
  'Runtime must carry the automatic execution permission'
);

const project = JSON.parse(read('sfdx-project.json'));
check(project.namespace === 'rhc', 'Package namespace must remain rhc');
check(project.sourceApiVersion === '66.0', 'Package API version must remain 66.0');
check(
  project.packageDirectories?.[0]?.dependencies?.[0]?.package === 'Record Health Check@2.0.4-2',
  'Package dependency must remain pinned to promoted core 2.0.4-2'
);

if (failures.length > 0) {
  console.error(`RHC Actions source validation failed (${failures.length}):`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log('RHC Actions source and least-privilege validation passed.');
