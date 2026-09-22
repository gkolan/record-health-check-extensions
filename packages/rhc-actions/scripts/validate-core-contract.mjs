/* eslint-disable @lwc/lwc-platform/no-aura-libs, @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const defaultCoreRoot = path.resolve(packageRoot, '../../../record-health-check');
const coreRootArgument = process.argv.indexOf('--core-root');
const coreRoot = path.resolve(
  coreRootArgument >= 0 ? process.argv[coreRootArgument + 1] : process.env.RHC_CORE_ROOT ?? defaultCoreRoot
);
const coreRef = '74fe1d6';
const corePackagePath = 'packages/record-health-check';
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
    failures.push(`Cannot read minimum-core evidence ${relativePath} at ${coreRef}: ${result.stderr.trim()}`);
    return '';
  }
  return result.stdout;
}

check(fs.existsSync(path.join(coreRoot, '.git')), `Core repository not found at ${coreRoot}`);
const extensionProject = JSON.parse(read('sfdx-project.json'));
const coreProjectText = coreAt('sfdx-project.json');
const coreProject = coreProjectText ? JSON.parse(coreProjectText) : {};
check(coreProject.namespace === extensionProject.namespace, 'Core and extension namespaces must match');
check(coreProject.sourceApiVersion === extensionProject.sourceApiVersion, 'Core and extension API versions must match');
check(
  extensionProject.packageAliases?.['Record Health Check@2.0.4-2'] === '04tak000000cZBFAA2',
  'Extension minimum-core alias must resolve to promoted 2.0.4.2'
);
check(
  coreProject.packageAliases?.['Record Health Check@2.0.4-2'] === '04tak000000cZBFAA2',
  'Minimum-core evidence must resolve the expected subscriber version'
);

const eventRoot = 'force-app/main/default/objects/Record_Health_Check_Result__e';
const eventObject = coreAt(`${eventRoot}/Record_Health_Check_Result__e.object-meta.xml`);
check(eventObject.includes('<eventType>HighVolume</eventType>'), 'Core Result event must remain high volume');
check(eventObject.includes('<publishBehavior>PublishAfterCommit</publishBehavior>'), 'Core Result event must publish after commit');
for (const field of [
  'ContractVersion__c', 'EventId__c', 'RunId__c',
  'CheckSetQualifiedApiName__c', 'CheckQualifiedApiName__c',
  'Status__c', 'Severity__c', 'ReasonCode__c', 'RecordId__c'
]) {
  const metadata = coreAt(`${eventRoot}/fields/${field}.field-meta.xml`);
  const normalizedMetadata = metadata.replace(/\s+/g, '');
  check(normalizedMetadata.includes(`<fullName>${field}</fullName>`), `Minimum core is missing Result field ${field}`);
}
const constants = read('force-app/main/default/classes/RHCActionConstants.cls');
check(constants.includes("CORE_CONTRACT_VERSION = '1.0'"), 'Actions must consume core Result contract 1.0');

if (failures.length > 0) {
  console.error(`RHC Actions minimum-core validation failed (${failures.length}):`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log('RHC Actions minimum-core contract validation passed against 2.0.4.2.');
