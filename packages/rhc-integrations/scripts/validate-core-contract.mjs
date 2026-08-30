import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const defaultCoreRoot = path.resolve(packageRoot, '../../../record-health-check');
const coreRootArgument = process.argv.indexOf('--core-root');
const suppliedCoreRoot = coreRootArgument >= 0 ? process.argv[coreRootArgument + 1] : undefined;
const coreRoot = path.resolve(suppliedCoreRoot ?? process.env.RHC_CORE_ROOT ?? defaultCoreRoot);
const coreRef = '74fe1d6022f819397fc879c076f4f4dd2093cfab';
const corePackagePath = 'packages/record-health-check';
const expectedDependency = 'Record Health Check@2.0.4-2';
const expectedSubscriberVersion = '04tak000000cZBFAA2';
const failures = [];

function check(condition, message) {
  if (!condition) failures.push(message);
}

function read(relativePath) {
  return fs.readFileSync(path.join(packageRoot, relativePath), 'utf8');
}

function coreAt(relativePath) {
  const result = spawnSync(
    'git',
    ['-C', coreRoot, 'show', `${coreRef}:${corePackagePath}/${relativePath}`],
    { encoding: 'utf8' }
  );
  if (result.status !== 0) {
    failures.push(
      `Cannot read minimum-core evidence ${relativePath} at ${coreRef}: ${result.stderr.trim()}`
    );
    return '';
  }
  return result.stdout;
}

function validateEvent(objectName, requiredFields, publishBehavior = 'PublishAfterCommit') {
  const eventRoot = `force-app/main/default/objects/${objectName}`;
  const objectMetadata = coreAt(`${eventRoot}/${objectName}.object-meta.xml`);
  check(
    objectMetadata.includes('<eventType>HighVolume</eventType>'),
    `Core ${objectName} must remain a high-volume Platform Event`
  );
  check(
    objectMetadata.includes(`<publishBehavior>${publishBehavior}</publishBehavior>`),
    `Core ${objectName} must retain ${publishBehavior} behavior`
  );
  for (const field of requiredFields) {
    const metadata = coreAt(`${eventRoot}/fields/${field}.field-meta.xml`);
    check(
      new RegExp(`<fullName\\s*>\\s*${field}\\s*</fullName>`).test(metadata),
      `Minimum core is missing ${objectName}.${field}`
    );
  }
}

check(coreRootArgument < 0 || Boolean(suppliedCoreRoot), '--core-root requires a path value');
check(fs.existsSync(path.join(coreRoot, '.git')), `Core repository not found at ${coreRoot}`);

const extensionProject = JSON.parse(read('sfdx-project.json'));
const coreProjectText = coreAt('sfdx-project.json');
const coreProject = coreProjectText ? JSON.parse(coreProjectText) : {};
check(extensionProject.namespace === 'rhc', 'Extension namespace must be rhc');
check(coreProject.namespace === extensionProject.namespace, 'Core and extension namespaces must match');
check(
  coreProject.sourceApiVersion === extensionProject.sourceApiVersion,
  'Core and extension API versions must match'
);
check(
  extensionProject.packageDirectories?.[0]?.dependencies?.length === 1,
  'Integrations must declare core as its only package dependency'
);
check(
  extensionProject.packageDirectories?.[0]?.dependencies?.[0]?.package === expectedDependency,
  `Extension dependency must remain pinned to ${expectedDependency}`
);
check(
  extensionProject.packageAliases?.[expectedDependency] === expectedSubscriberVersion,
  `Extension dependency alias must resolve to ${expectedSubscriberVersion}`
);
check(
  coreProject.packageAliases?.[expectedDependency] === expectedSubscriberVersion,
  'Minimum-core source evidence must resolve the same promoted subscriber version'
);

validateEvent('Record_Health_Check_Result__e', [
  'ContractVersion__c',
  'EventId__c',
  'RunId__c',
  'CheckSetQualifiedApiName__c',
  'CheckQualifiedApiName__c',
  'RecordId__c',
  'Status__c',
  'Severity__c',
  'ReasonCode__c',
  'OccurredAt__c',
  'Source__c',
  'FrameworkVersion__c',
  'ContainsRestrictedDetail__c'
]);
validateEvent('Record_Health_Check_Set_Run__e', [
  'ContractVersion__c',
  'EventId__c',
  'RunId__c',
  'CheckSetQualifiedApiName__c',
  'RecordId__c',
  'Phase__c',
  'OccurredAt__c',
  'Source__c',
  'FrameworkVersion__c',
  'EligibleCheckCount__c',
  'EvaluatedCheckCount__c',
  'PassedCount__c',
  'FailedCount__c',
  'SkippedCount__c',
  'UnableCount__c',
  'SystemErrorCount__c'
]);
validateEvent('Record_Health_Check_Log__e', [
  'ContractVersion__c',
  'EventId__c',
  'RunId__c',
  'CheckSetDeveloperName__c',
  'CheckDeveloperName__c',
  'Code__c',
  'OccurredAt__c',
  'FrameworkVersion__c',
  'DetailsJson__c',
  'ExceptionType__c',
  'Message__c',
  'StackTrace__c'
], 'PublishImmediately');

const apexAndTriggers = [
  ...fs
    .readdirSync(path.join(packageRoot, 'force-app/main/default/classes'))
    .filter((name) => name.endsWith('.cls'))
    .map((name) => read(`force-app/main/default/classes/${name}`)),
  ...fs
    .readdirSync(path.join(packageRoot, 'force-app/main/default/triggers'))
    .filter((name) => name.endsWith('.trigger'))
    .map((name) => read(`force-app/main/default/triggers/${name}`))
].join('\n');
check(!apexAndTriggers.includes('rhc__'), 'Apex and trigger source must not hard-code the rhc namespace');
for (const eventName of [
  'Record_Health_Check_Result__e',
  'Record_Health_Check_Set_Run__e',
  'Record_Health_Check_Log__e'
]) {
  check(apexAndTriggers.includes(eventName), `${eventName} must remain directly referenced`);
}
for (const restrictedLogField of ['DetailsJson__c', 'ExceptionType__c', 'Message__c', 'StackTrace__c']) {
  check(
    !apexAndTriggers.includes(`sourceEvent.${restrictedLogField}`),
    `Integrations must not ingest restricted log field ${restrictedLogField}`
  );
}

if (failures.length > 0) {
  console.error(`RHC Integrations minimum-core contract validation failed (${failures.length}):`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(
  `RHC Integrations minimum-core contract validation passed against core ${coreRef} ` +
    `(Record Health Check 2.0.4.2 / ${expectedSubscriberVersion}).`
);
