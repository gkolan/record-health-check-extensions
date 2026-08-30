import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const defaultCoreRoot = path.resolve(packageRoot, '../../../record-health-check');
const coreRootArgument = process.argv.indexOf('--core-root');
const coreRoot = path.resolve(
  coreRootArgument >= 0
    ? process.argv[coreRootArgument + 1]
    : process.env.RHC_CORE_ROOT ?? defaultCoreRoot
);
const coreRef = '74fe1d6022f819397fc879c076f4f4dd2093cfab';
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
    failures.push(
      `Cannot read minimum-core evidence ${relativePath} at ${coreRef}: ${result.stderr.trim()}`
    );
    return '';
  }
  return result.stdout;
}

function tagValue(xml, tagName) {
  return xml.match(new RegExp(`<${tagName}\\s*>\\s*([^<]+?)\\s*</${tagName}>`))?.[1]?.trim() ?? null;
}

function validateField(label, xml, apiName, expected) {
  check(tagValue(xml, 'fullName') === apiName, `${label} has the wrong API name`);
  check(tagValue(xml, 'type') === expected.type, `${label} must remain ${expected.type}`);
  if (expected.length !== undefined) {
    check(Number(tagValue(xml, 'length')) === expected.length, `${label} must remain length ${expected.length}`);
  }
  if (expected.precision !== undefined) {
    check(Number(tagValue(xml, 'precision')) === expected.precision, `${label} must remain precision ${expected.precision}`);
    check(Number(tagValue(xml, 'scale')) === 0, `${label} must remain an integer`);
  }
}

function validateDestinationField(label, xml, apiName, sourceContract) {
  check(tagValue(xml, 'fullName') === apiName, `${label} has the wrong API name`);
  check(tagValue(xml, 'type') === sourceContract.type, `${label} must remain ${sourceContract.type}`);
  if (sourceContract.length !== undefined) {
    check(
      Number(tagValue(xml, 'length')) >= sourceContract.length,
      `${label} cannot be narrower than the core source field`
    );
  }
  if (sourceContract.precision !== undefined) {
    check(
      Number(tagValue(xml, 'precision')) >= sourceContract.precision,
      `${label} cannot have less precision than the core source field`
    );
    check(Number(tagValue(xml, 'scale')) === 0, `${label} must remain an integer`);
  }
}

check(fs.existsSync(path.join(coreRoot, '.git')), `Core repository not found at ${coreRoot}`);

const extensionProject = JSON.parse(read('sfdx-project.json'));
const coreProjectText = coreAt('sfdx-project.json');
const coreProject = coreProjectText ? JSON.parse(coreProjectText) : {};
check(extensionProject.namespace === 'rhc', 'Extension namespace must be rhc');
check(coreProject.namespace === extensionProject.namespace, 'Core and extension namespaces must match');
check(coreProject.sourceApiVersion === extensionProject.sourceApiVersion, 'Core and extension API versions must match');
check(
  extensionProject.packageDirectories?.[0]?.dependencies?.[0]?.package === 'Record Health Check@2.0.4-2',
  'Extension dependency must remain pinned to Record Health Check@2.0.4-2'
);
check(
  extensionProject.packageAliases?.['Record Health Check@2.0.4-2'] === '04tak000000cZBFAA2',
  'Extension minimum-core alias must resolve to promoted 2.0.4.2'
);
check(
  coreProject.packageAliases?.['Record Health Check@2.0.4-2'] === '04tak000000cZBFAA2',
  'Minimum-core evidence must resolve the expected subscriber version'
);

const eventContracts = {
  Record_Health_Check_Set_Run__e: {
    ContractVersion__c: { type: 'Text', length: 10 },
    FrameworkVersion__c: { type: 'Text', length: 20 },
    EventId__c: { type: 'Text', length: 80 },
    RunId__c: { type: 'Text', length: 120 },
    Phase__c: { type: 'Text', length: 30 },
    CheckSetQualifiedApiName__c: { type: 'Text', length: 80 },
    RecordId__c: { type: 'Text', length: 18 },
    OccurredAt__c: { type: 'DateTime' },
    Source__c: { type: 'Text', length: 30 },
    SubmittedRecordCount__c: { type: 'Number', precision: 7 },
    ProcessedRecordCount__c: { type: 'Number', precision: 7 },
    EligibleCheckCount__c: { type: 'Number', precision: 5 },
    EvaluatedCheckCount__c: { type: 'Number', precision: 5 },
    PassedCount__c: { type: 'Number', precision: 5 },
    FailedCount__c: { type: 'Number', precision: 5 },
    SkippedCount__c: { type: 'Number', precision: 5 },
    UnableCount__c: { type: 'Number', precision: 5 },
    SystemErrorCount__c: { type: 'Number', precision: 5 }
  },
  Record_Health_Check_Result__e: {
    ContractVersion__c: { type: 'Text', length: 10 },
    FrameworkVersion__c: { type: 'Text', length: 20 },
    EventId__c: { type: 'Text', length: 80 },
    RunId__c: { type: 'Text', length: 120 },
    CheckSetQualifiedApiName__c: { type: 'Text', length: 80 },
    CheckQualifiedApiName__c: { type: 'Text', length: 80 },
    RecordId__c: { type: 'Text', length: 18 },
    Status__c: { type: 'Text', length: 30 },
    Severity__c: { type: 'Text', length: 20 },
    ReasonCode__c: { type: 'Text', length: 80 },
    OccurredAt__c: { type: 'DateTime' },
    Source__c: { type: 'Text', length: 30 },
    ContainsRestrictedDetail__c: { type: 'Checkbox' }
  }
};

const ingestionSource = read('force-app/main/default/classes/RHCReportsIngestionService.cls');
for (const [eventName, fields] of Object.entries(eventContracts)) {
  const eventRoot = `force-app/main/default/objects/${eventName}`;
  const eventObject = coreAt(`${eventRoot}/${eventName}.object-meta.xml`);
  check(eventObject.includes('<eventType>HighVolume</eventType>'), `${eventName} must remain high volume`);
  check(
    eventObject.includes('<publishBehavior>PublishAfterCommit</publishBehavior>'),
    `${eventName} must remain publish-after-commit`
  );
  for (const [fieldName, expected] of Object.entries(fields)) {
    const metadata = coreAt(`${eventRoot}/fields/${fieldName}.field-meta.xml`);
    validateField(`Core ${eventName}.${fieldName}`, metadata, fieldName, expected);
    check(
      ingestionSource.includes(`eventRecord.${fieldName}`),
      `Ingestion no longer consumes ${eventName}.${fieldName}`
    );
  }
}

for (const [fieldName, expected] of Object.entries(eventContracts.Record_Health_Check_Set_Run__e)) {
  const destination = `force-app/main/default/objects/Record_Health_Check_Report_Run__c/fields/${fieldName}.field-meta.xml`;
  validateDestinationField(`Run Fact ${fieldName}`, read(destination), fieldName, expected);
}
for (const [fieldName, expected] of Object.entries(eventContracts.Record_Health_Check_Result__e)) {
  if (fieldName === 'ContainsRestrictedDetail__c') continue;
  const destination = `force-app/main/default/objects/Record_Health_Check_Report_Result__c/fields/${fieldName}.field-meta.xml`;
  validateDestinationField(`Result Fact ${fieldName}`, read(destination), fieldName, expected);
}

check(
  ingestionSource.includes('SUPPORTED_CONTRACT_VERSION = \'1.0\''),
  'Reports must continue consuming lifecycle contract 1.0'
);
check(
  ingestionSource.includes('eventRecord.ContainsRestrictedDetail__c == true'),
  'Restricted Result events must remain excluded from durable facts'
);
const corePublisher = coreAt('force-app/main/default/classes/RecordHealthCheckLifecyclePublisher.cls');
check(
  corePublisher.includes("CONTRACT_VERSION = '1.0'"),
  'Minimum core must publish lifecycle contract 1.0'
);
for (const fields of Object.values(eventContracts)) {
  for (const fieldName of Object.keys(fields)) {
    check(corePublisher.includes(`${fieldName} =`), `Core publisher does not populate ${fieldName}`);
  }
}

const apexAndTriggerText = [
  ...fs.readdirSync(path.join(packageRoot, 'force-app/main/default/classes'))
    .filter(name => name.endsWith('.cls'))
    .map(name => read(`force-app/main/default/classes/${name}`)),
  ...fs.readdirSync(path.join(packageRoot, 'force-app/main/default/triggers'))
    .filter(name => name.endsWith('.trigger'))
    .map(name => read(`force-app/main/default/triggers/${name}`))
].join('\n');
check(!apexAndTriggerText.includes('rhc__'), 'Apex and trigger source must not hard-code the namespace');

if (failures.length > 0) {
  console.error(`RHC Reports minimum-core validation failed (${failures.length}):`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(
  `RHC Reports minimum-core contract validation passed against core ${coreRef.slice(0, 7)} ` +
  '(Record Health Check 2.0.4.2 / 04tak000000cZBFAA2).'
);
