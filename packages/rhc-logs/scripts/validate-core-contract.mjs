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
        failures.push(`Cannot read minimum-core evidence ${relativePath} at ${coreRef}: ${result.stderr.trim()}`);
        return '';
    }
    return result.stdout;
}

function tagValue(xml, tagName) {
    return xml.match(new RegExp(`<${tagName}>([^<]+)</${tagName}>`))?.[1] ?? null;
}

function validateFieldMetadata(label, xml, expected) {
    check(tagValue(xml, 'fullName') === expected.fullName, `${label} has the wrong API name`);
    check(tagValue(xml, 'type') === expected.type, `${label} must remain ${expected.type}`);
    if (expected.length !== undefined) {
        check(Number(tagValue(xml, 'length')) === expected.length, `${label} must remain length ${expected.length}`);
    }
    const required = tagValue(xml, 'required') === 'true';
    check(required === expected.required, `${label} requiredness changed`);
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
    'Extension minimum-core alias must resolve to the promoted 2.0.4.2 subscriber version'
);
check(
    coreProject.packageAliases?.['Record Health Check@2.0.4-2'] === '04tak000000cZBFAA2',
    'Minimum-core source evidence must resolve 2.0.4.2 to the expected subscriber version'
);

const eventRoot = 'force-app/main/default/objects/Record_Health_Check_Log__e';
const eventObject = coreAt(`${eventRoot}/Record_Health_Check_Log__e.object-meta.xml`);
check(eventObject.includes('<eventType>HighVolume</eventType>'), 'Core Log event must remain high volume');
check(eventObject.includes('<publishBehavior>PublishImmediately</publishBehavior>'), 'Core Log event must publish immediately');

const eventFields = {
    EventId__c: { type: 'Text', length: 80, required: true },
    RunId__c: { type: 'Text', length: 120, required: true },
    OccurredAt__c: { type: 'DateTime', required: true },
    ContractVersion__c: { type: 'Text', length: 10, required: true },
    FrameworkVersion__c: { type: 'Text', length: 20, required: false },
    Level__c: { type: 'Text', length: 10, required: true },
    Code__c: { type: 'Text', length: 120, required: false },
    Message__c: { type: 'LongTextArea', length: 32768, required: false },
    DetailsJson__c: { type: 'LongTextArea', length: 32768, required: false },
    ExceptionType__c: { type: 'Text', length: 120, required: false },
    RecordId__c: { type: 'Text', length: 18, required: false },
    CheckSetDeveloperName__c: { type: 'Text', length: 120, required: false },
    CheckDeveloperName__c: { type: 'Text', length: 120, required: false },
    UserId__c: { type: 'Text', length: 18, required: false }
};
for (const [field, expected] of Object.entries(eventFields)) {
    const metadata = coreAt(`${eventRoot}/fields/${field}.field-meta.xml`);
    validateFieldMetadata(`Core Log field ${field}`, metadata, { fullName: field, ...expected });
}

const destinationMappings = {
    EventId__c: { source: 'EventId__c', type: 'Text', length: 80, required: true },
    RunId__c: { source: 'RunId__c', type: 'Text', length: 120, required: true },
    OccurredAt__c: { source: 'OccurredAt__c', type: 'DateTime', required: true },
    ContractVersion__c: { source: 'ContractVersion__c', type: 'Text', length: 10, required: true },
    FrameworkVersion__c: { source: 'FrameworkVersion__c', type: 'Text', length: 20, required: false },
    Severity__c: { source: 'Level__c', type: 'Text', length: 10, required: true },
    Code__c: { source: 'Code__c', type: 'Text', length: 120, required: false },
    Message__c: { source: 'Message__c', type: 'LongTextArea', length: 8000, required: false },
    StructuredDetails__c: { source: 'DetailsJson__c', type: 'LongTextArea', length: 8000, required: false },
    ExceptionType__c: { source: 'ExceptionType__c', type: 'Text', length: 120, required: false },
    RecordId__c: { source: 'RecordId__c', type: 'Text', length: 18, required: false },
    CheckSetDeveloperName__c: { source: 'CheckSetDeveloperName__c', type: 'Text', length: 120, required: false },
    CheckDeveloperName__c: { source: 'CheckDeveloperName__c', type: 'Text', length: 120, required: false },
    RunningUserId__c: { source: 'UserId__c', type: 'Text', length: 18, required: false }
};
const destinationRoot = 'force-app/main/default/objects/Record_Health_Check_Diagnostic_Log__c/fields';
const ingestionSource = read('force-app/main/default/classes/RHCLogsIngestionService.cls');
for (const [destinationField, expected] of Object.entries(destinationMappings)) {
    const destinationMetadata = read(`${destinationRoot}/${destinationField}.field-meta.xml`);
    validateFieldMetadata(`Destination field ${destinationField}`, destinationMetadata, {
        fullName: destinationField,
        type: expected.type,
        length: expected.length,
        required: expected.required
    });
    const sourceContract = eventFields[expected.source];
    if (expected.length !== undefined) {
        check(
            expected.length <= sourceContract.length,
            `${destinationField} cannot be wider than core ${expected.source}`
        );
    }
    check(
        ingestionSource.includes(`${destinationField} = bound(sourceEvent.${expected.source},`)
            || ingestionSource.includes(`${destinationField} = sourceEvent.${expected.source}`),
        `Ingestion mapping is missing ${expected.source} -> ${destinationField}`
    );
}

const ingestedAtMetadata = read(`${destinationRoot}/IngestedAt__c.field-meta.xml`);
validateFieldMetadata('Destination field IngestedAt__c', ingestedAtMetadata, {
    fullName: 'IngestedAt__c', type: 'DateTime', required: true
});
check(ingestionSource.includes('IngestedAt__c = System.now()'), 'Ingestion time must be package generated');
const eventIdMetadata = read(`${destinationRoot}/EventId__c.field-meta.xml`);
check(tagValue(eventIdMetadata, 'externalId') === 'true', 'Destination EventId__c must remain an external ID');
check(tagValue(eventIdMetadata, 'unique') === 'true', 'Destination EventId__c must remain unique');

const publicationControl = coreAt(
    'force-app/main/default/objects/Record_Health_Check_Set__mdt/fields/PublishErrorLogEvent__c.field-meta.xml'
);
check(tagValue(publicationControl, 'type') === 'Checkbox', 'Core Log publication control must remain a checkbox');
check(publicationControl.includes('<defaultValue>false</defaultValue>'), 'Core Log publication must remain default-off');

const publisherPermission = coreAt(
    'force-app/main/default/permissionsets/Record_Health_Check_Error_Log_Publisher.permissionset-meta.xml'
);
check(publisherPermission.includes('<allowCreate>true</allowCreate>'), 'Core publisher permission must grant event create');
check(publisherPermission.includes('<allowRead>true</allowRead>'), 'Core publisher permission must grant required event read');
check(publisherPermission.includes('<object>Record_Health_Check_Log__e</object>'), 'Core publisher permission must target the canonical Log event');

const coreLogger = coreAt('force-app/main/default/classes/RecordHealthCheckLogger.cls');
check(
    coreLogger.includes("LOG_CONTRACT_VERSION = '1.0'"),
    'Minimum core must publish Log contract version 1.0'
);
for (const field of Object.keys(eventFields)) {
    check(
        coreLogger.includes(`${field} =`),
        `Minimum-core logger does not populate canonical field ${field}`
    );
}

const apexAndTriggerText = [
    ...fs.readdirSync(path.join(packageRoot, 'force-app/main/default/classes'))
        .filter(name => name.endsWith('.cls'))
        .map(name => read(`force-app/main/default/classes/${name}`)),
    ...fs.readdirSync(path.join(packageRoot, 'force-app/main/default/triggers'))
        .filter(name => name.endsWith('.trigger'))
        .map(name => read(`force-app/main/default/triggers/${name}`))
].join('\n');
check(!apexAndTriggerText.includes('rhc__'), 'Apex and trigger source must not hard-code the rhc namespace');

if (failures.length > 0) {
    console.error(`RHC Logs minimum-core contract validation failed (${failures.length}):`);
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
}

console.log(
    `RHC Logs minimum-core contract validation passed against core ${coreRef.slice(0, 7)} `
    + '(Record Health Check 2.0.4.2 / 04tak000000cZBFAA2).'
);
