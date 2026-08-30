import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const metadataRoot = path.join(packageRoot, 'force-app', 'main', 'default');
const issues = [];

function filesUnder(directory) {
    if (!fs.existsSync(directory)) {
        return [];
    }
    return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
        const absolutePath = path.join(directory, entry.name);
        return entry.isDirectory() ? filesUnder(absolutePath) : [absolutePath];
    });
}

function relative(file) {
    return path.relative(packageRoot, file);
}

function captureAll(xml, elementName) {
    return [...xml.matchAll(new RegExp(`<${elementName}>([^<]+)</${elementName}>`, 'g'))]
        .map((match) => match[1]);
}

function requireCompanions(directory, sourceSuffix, metadataSuffix) {
    const sourceFiles = filesUnder(directory).filter((file) => file.endsWith(sourceSuffix));
    for (const sourceFile of sourceFiles) {
        const metadataFile = `${sourceFile}${metadataSuffix}`;
        if (!fs.existsSync(metadataFile)) {
            issues.push(`${relative(sourceFile)} is missing ${path.basename(metadataFile)}`);
        }
    }
}

requireCompanions(path.join(metadataRoot, 'classes'), '.cls', '-meta.xml');
requireCompanions(path.join(metadataRoot, 'triggers'), '.trigger', '-meta.xml');

const objectRoot = path.join(metadataRoot, 'objects');
const objectNames = new Set();
const fieldNames = new Set();
const coreEventNames = new Set([
    'Record_Health_Check_Result__e',
    'Record_Health_Check_Set_Run__e',
    'Record_Health_Check_Log__e'
]);
for (const objectEntry of fs.readdirSync(objectRoot, { withFileTypes: true })) {
    if (!objectEntry.isDirectory()) {
        continue;
    }
    const objectName = objectEntry.name;
    objectNames.add(objectName);
    if (objectName.startsWith('RHC_')) {
        issues.push(`${objectName} violates the full product-family object naming standard`);
    }
    const objectMetadata = path.join(objectRoot, objectName, `${objectName}.object-meta.xml`);
    if (!fs.existsSync(objectMetadata)) {
        issues.push(`${objectName} is missing its matching object metadata file`);
    }
    const fieldsDirectory = path.join(objectRoot, objectName, 'fields');
    for (const fieldFile of filesUnder(fieldsDirectory).filter((file) => file.endsWith('.field-meta.xml'))) {
        const fieldApiName = path.basename(fieldFile, '.field-meta.xml');
        const fullName = captureAll(fs.readFileSync(fieldFile, 'utf8'), 'fullName')[0];
        fieldNames.add(`${objectName}.${fieldApiName}`);
        if (fullName !== fieldApiName) {
            issues.push(`${relative(fieldFile)} has fullName ${fullName ?? '(missing)'}`);
        }
        if (!/^[A-Z][A-Za-z0-9]*__c$/.test(fieldApiName)) {
            issues.push(`${relative(fieldFile)} violates the UpperCamelCase field naming standard`);
        }
    }
}

const classNames = new Set(filesUnder(path.join(metadataRoot, 'classes'))
    .filter((file) => file.endsWith('.cls'))
    .map((file) => path.basename(file, '.cls')));
const tabNames = new Set(filesUnder(path.join(metadataRoot, 'tabs'))
    .filter((file) => file.endsWith('.tab-meta.xml'))
    .map((file) => path.basename(file, '.tab-meta.xml')));
const customPermissionNames = new Set(filesUnder(path.join(metadataRoot, 'customPermissions'))
    .filter((file) => file.endsWith('.customPermission-meta.xml'))
    .map((file) => path.basename(file, '.customPermission-meta.xml')));

for (const permissionFile of filesUnder(path.join(metadataRoot, 'permissionsets'))
    .filter((file) => file.endsWith('.permissionset-meta.xml'))) {
    const xml = fs.readFileSync(permissionFile, 'utf8');
    for (const objectName of captureAll(xml, 'object')) {
        if (!objectNames.has(objectName) && !coreEventNames.has(objectName)) {
            issues.push(`${relative(permissionFile)} references unknown object ${objectName}`);
        }
    }
    for (const fieldName of captureAll(xml, 'field')) {
        if (!fieldNames.has(fieldName)) {
            issues.push(`${relative(permissionFile)} references unknown field ${fieldName}`);
        }
    }
    for (const className of captureAll(xml, 'apexClass')) {
        if (!classNames.has(className)) {
            issues.push(`${relative(permissionFile)} references unknown Apex class ${className}`);
        }
    }
    for (const tabName of captureAll(xml, 'tab')) {
        if (!tabNames.has(tabName)) {
            issues.push(`${relative(permissionFile)} references unknown tab ${tabName}`);
        }
    }
    for (const permissionName of captureAll(xml, 'name')) {
        if (permissionName.startsWith('RHC_') && !customPermissionNames.has(permissionName)) {
            issues.push(`${relative(permissionFile)} references unknown custom permission ${permissionName}`);
        }
    }
}

for (const applicationFile of filesUnder(path.join(metadataRoot, 'applications'))
    .filter((file) => file.endsWith('.app-meta.xml'))) {
    const xml = fs.readFileSync(applicationFile, 'utf8');
    for (const tabName of captureAll(xml, 'tabs')) {
        if (!tabName.startsWith('standard-') && !tabNames.has(tabName)) {
            issues.push(`${relative(applicationFile)} references unknown tab ${tabName}`);
        }
    }
}

const project = JSON.parse(fs.readFileSync(path.join(packageRoot, 'sfdx-project.json'), 'utf8'));
const packageDirectory = project.packageDirectories?.find((entry) => entry.default);
if (project.namespace !== 'rhc') {
    issues.push('sfdx-project.json must declare namespace rhc');
}
if (project.sourceApiVersion !== '66.0') {
    issues.push('sfdx-project.json sourceApiVersion must remain aligned to core at 66.0');
}
if (packageDirectory?.dependencies?.length !== 1
    || !packageDirectory.dependencies[0].package.startsWith('Record Health Check@')) {
    issues.push('the default package directory must declare exactly one pinned core dependency');
}

const routeRule = fs.readFileSync(path.join(
    objectRoot,
    'Record_Health_Check_Integration_Route__c',
    'validationRules',
    'Relative_Endpoint_Safe.validationRule-meta.xml'
), 'utf8');
const queueable = fs.readFileSync(path.join(metadataRoot, 'classes', 'RHCIntegrationDeliveryQueueable.cls'), 'utf8');
const deliveryPolicy = fs.readFileSync(path.join(metadataRoot, 'classes', 'RHCIntegrationDeliveryPolicy.cls'), 'utf8');
const ingestionService = fs.readFileSync(
    path.join(metadataRoot, 'classes', 'RHCIntegrationIngestionService.cls'),
    'utf8'
);
const subscriberCoordinator = fs.readFileSync(
    path.join(metadataRoot, 'classes', 'RHCIntegrationSubscriberCoordinator.cls'),
    'utf8'
);
const deadLetterController = fs.readFileSync(
    path.join(metadataRoot, 'classes', 'RHCIntegrationDeadLetterController.cls'),
    'utf8'
);
if (!routeRule.includes('BEGINS(RelativeEndpoint__c, "//")')) {
    issues.push('Relative Endpoint validation must reject authority-style // values');
}
if (!deliveryPolicy.includes("!route.RelativeEndpoint__c.startsWith('//')")) {
    issues.push('runtime route validation must reject authority-style // values');
}
if (!queueable.includes('implements Queueable, Finalizer, Database.AllowsCallouts')
    || !queueable.includes('System.attachFinalizer(this)')) {
    issues.push('delivery Queueable must retain explicit Finalizer recovery');
}
if (!subscriberCoordinator.includes('CHUNK_SIZE = 50')
    || !subscriberCoordinator.includes('setResumeCheckpoint')
    || !subscriberCoordinator.includes('setCheckpoint(String replayId)')
    || !subscriberCoordinator.includes('EventBus.RetryableException')) {
    issues.push('Platform Event subscribers must retain 50-event string checkpoints and bounded retry handling');
}
if (!ingestionService.includes('assertDmlCapacity(deliveries.size())')
    || !ingestionService.includes('assertQueueCapacity()')
    || !ingestionService.includes('TransientIngestionException')) {
    issues.push('event ingestion must retain explicit DML, Queueable, and transient-failure boundaries');
}
if (!deadLetterController.includes("FeatureManagement.checkPermission(REPLAY_PERMISSION)")
    || !deadLetterController.includes('Route__r.Active__c')
    || !deadLetterController.includes('WITH USER_MODE')
    || !deadLetterController.includes('FOR UPDATE')
    || !deadLetterController.includes('update as user delivery;')
    || deadLetterController.includes('WITH SYSTEM_MODE')
    || deadLetterController.includes('FROM Record_Health_Check_Integration_Route__c')) {
    issues.push('dead-letter replay must retain permission-gated, one-query user-mode locking and DML');
}
for (const triggerName of [
    'RHCIntegrationResultSubscriber',
    'RHCIntegrationRunSubscriber',
    'RHCIntegrationLogSubscriber'
]) {
    const trigger = fs.readFileSync(path.join(metadataRoot, 'triggers', `${triggerName}.trigger`), 'utf8');
    if (!trigger.includes('RHCIntegrationSubscriberCoordinator.')) {
        issues.push(`${triggerName} must delegate through the checkpointed subscriber coordinator`);
    }
}

if (issues.length > 0) {
    console.error(`RHC Integrations source validation failed with ${issues.length} issue(s):`);
    for (const issue of issues) {
        console.error(`- ${issue}`);
    }
    process.exitCode = 1;
} else {
    console.log(`RHC Integrations source validation passed (${objectNames.size} objects, ${fieldNames.size} fields, ${classNames.size} Apex classes).`);
}
