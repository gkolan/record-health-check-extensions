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

function walk(directory) {
    return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
        const entryPath = path.join(directory, entry.name);
        return entry.isDirectory() ? walk(entryPath) : [entryPath];
    });
}

const allSourceFiles = walk(sourceRoot);
const allSourceText = allSourceFiles
    .filter(file => !file.endsWith('.png'))
    .map(file => fs.readFileSync(file, 'utf8'))
    .join('\n');

for (const extension of ['classes', 'triggers']) {
    const directory = path.join(sourceRoot, extension);
    const implementationSuffix = extension === 'classes' ? '.cls' : '.trigger';
    for (const implementation of fs.readdirSync(directory).filter(name => name.endsWith(implementationSuffix))) {
        check(
            fs.existsSync(path.join(directory, `${implementation}-meta.xml`)),
            `Missing metadata companion for ${extension}/${implementation}`
        );
    }
}

const objectNames = fs.readdirSync(path.join(sourceRoot, 'objects'));
for (const objectName of objectNames) {
    check(
        objectName.startsWith('Record_Health_Check_'),
        `Object ${objectName} does not use the suite Record_Health_Check_ prefix`
    );
    const fieldsDirectory = path.join(sourceRoot, 'objects', objectName, 'fields');
    if (!fs.existsSync(fieldsDirectory)) continue;
    for (const fieldFile of fs.readdirSync(fieldsDirectory).filter(name => name.endsWith('.field-meta.xml'))) {
        const apiName = fieldFile.replace('.field-meta.xml', '').replace('__c', '');
        check(!apiName.includes('_'), `Field ${objectName}.${apiName}__c must use PascalCase without underscores`);
    }
}

check(!allSourceText.includes('RHC_Diagnostic_Log__c'), 'Legacy diagnostic object API name remains');
check(!allSourceText.includes('RHC_Logs_Settings__c'), 'Legacy settings object API name remains');
check(!allSourceText.includes('Test.isRunningTest()'), 'Production code must not branch on Test.isRunningTest()');

const suppressionDocumentation = read('docs/CODE-ANALYZER-SUPPRESSIONS.md');
const suppressionCount = (allSourceText.match(/@SuppressWarnings\(/g) ?? []).length;
check(suppressionCount === 10, `Expected 10 reviewed analyzer suppressions; found ${suppressionCount}`);
check(
    suppressionDocumentation.includes('aggregate complexity 52'),
    'Analyzer suppression documentation must record the current Admin complexity'
);
for (const suppressedSource of [
    'RHCLogsIngestionService.cls', 'RHCLogsCleanupService.cls',
    'RHCLogsCleanupScheduler.cls', 'RHCLogsAdminController.cls'
]) {
    check(
        suppressionDocumentation.includes(suppressedSource),
        `Analyzer suppression documentation is missing ${suppressedSource}`
    );
}

const cleanup = read('force-app/main/default/classes/RHCLogsCleanupService.cls');
check(cleanup.includes('MAX_CLEANUP_BATCH_SIZE = 9998'), 'Cleanup must reserve two DML rows for lease/result writes');
check(cleanup.includes('recordOverlapSkip'), 'Cleanup must preserve the active lease when overlap is skipped');

const review = read('force-app/main/default/classes/RHCLogsReviewController.cls');
check(review.includes('cursorOccurredAt') && review.includes('cursorId'), 'Review API must expose a stable keyset cursor');
check(review.includes('rowLimit + 1'), 'Review API must fetch one look-ahead row for hasMore');

const ingestion = read('force-app/main/default/classes/RHCLogsIngestionService.cls');
check(ingestion.includes('EventBus.RetryableException'), 'Transient ingestion failures must request Platform Event retry');
check(ingestion.includes('StatusCode.UNABLE_TO_LOCK_ROW'), 'Lock contention must be classified as retryable');
check(ingestion.includes('LastIngestionErrorCodes__c'), 'Permanent ingestion errors must leave sanitized operator evidence');

const adminPermission = read('force-app/main/default/permissionsets/RHC_Logs_Admin.permissionset-meta.xml');
const coreEventPermission = adminPermission.match(
    /<objectPermissions>(?:(?!<\/objectPermissions>)[\s\S])*<object>Record_Health_Check_Log__e<\/object>(?:(?!<\/objectPermissions>)[\s\S])*<\/objectPermissions>/
)?.[0] ?? '';
check(
    coreEventPermission.includes('<allowRead>true</allowRead>')
        && coreEventPermission.includes('<allowCreate>false</allowCreate>'),
    'Admin must inspect the core Log event without receiving publish permission'
);
check(
    /<customMetadataTypeAccesses>\s*<enabled>true<\/enabled>\s*<name>Record_Health_Check_Set__mdt<\/name>\s*<\/customMetadataTypeAccesses>/.test(adminPermission),
    'Admin must be able to inspect the core Check Set publication configuration'
);
const editableFields = [...adminPermission.matchAll(
    /<fieldPermissions>\s*<editable>true<\/editable>\s*<field>([^<]+)<\/field>/g
)].map(match => match[1]);
const expectedEditableFields = [
    'Record_Health_Check_Log_Settings__c.AutomatedCleanupEnabled__c',
    'Record_Health_Check_Log_Settings__c.CleanupBatchSize__c',
    'Record_Health_Check_Log_Settings__c.RetentionDays__c'
].sort();
check(
    JSON.stringify(editableFields.sort()) === JSON.stringify(expectedEditableFields),
    'Admin may edit only the three retention policy fields; counters and lease state are package-owned'
);
for (const field of ['LastIngestionStatus__c', 'LastIngestionErrorCodes__c', 'CleanupRunToken__c']) {
    check(adminPermission.includes(`Record_Health_Check_Log_Settings__c.${field}`), `Admin read boundary is missing ${field}`);
}
check(
    !adminPermission.includes('Record_Health_Check_Log_Settings__c.SettingsKey__c'),
    'SettingsKey__c is required and must not appear in permission-set fieldPermissions'
);

const viewerPermission = read('force-app/main/default/permissionsets/RHC_Logs_Viewer.permissionset-meta.xml');
for (const restrictedField of ['Message__c', 'StructuredDetails__c', 'RecordId__c', 'RunningUserId__c']) {
    check(!viewerPermission.includes(restrictedField), `Viewer must not receive restricted field ${restrictedField}`);
}

const requiredDiagnosticFields = [
    'ContractVersion__c', 'EventId__c', 'IngestedAt__c',
    'OccurredAt__c', 'RunId__c', 'Severity__c'
];
for (const field of requiredDiagnosticFields) {
    const fieldMetadata = read(
        `force-app/main/default/objects/Record_Health_Check_Diagnostic_Log__c/fields/${field}.field-meta.xml`
    );
    check(fieldMetadata.includes('<required>true</required>'), `${field} must remain required`);
    check(
        !adminPermission.includes(`Record_Health_Check_Diagnostic_Log__c.${field}`)
            && !viewerPermission.includes(`Record_Health_Check_Diagnostic_Log__c.${field}`),
        `${field} is required and must not appear in permission-set fieldPermissions`
    );
}

const project = JSON.parse(read('sfdx-project.json'));
check(project.namespace === 'rhc', 'Package namespace configuration must remain rhc');
check(
    project.packageDirectories?.[0]?.dependencies?.[0]?.package === 'Record Health Check@2.0.4-2',
    'Package dependency must remain pinned to promoted core 2.0.4-2'
);

const packageManifest = JSON.parse(read('package.json'));
check(
    packageManifest.scripts?.['release:check-candidate-unlock'] ===
        'node scripts/check-candidate-unlock.mjs',
    'Package candidate creation must remain protected by the machine-enforced unlock check'
);
check(
    read('docs/RELEASE-GATES.md').includes('npm run release:check-candidate-unlock'),
    'Release ledger must require the machine-enforced candidate unlock check'
);

for (const markdownFile of walk(packageRoot).filter(file =>
    file.endsWith('.md') && !file.includes(`${path.sep}node_modules${path.sep}`)
)) {
    const contents = fs.readFileSync(markdownFile, 'utf8');
    for (const match of contents.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
        const target = match[1].split('#')[0];
        if (!target || /^(https?:|mailto:)/.test(target)) continue;
        check(fs.existsSync(path.resolve(path.dirname(markdownFile), target)), `Broken local link ${target} in ${path.relative(packageRoot, markdownFile)}`);
    }
}

if (failures.length > 0) {
    console.error(`RHC Logs source validation failed (${failures.length}):`);
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
}

console.log('RHC Logs source validation passed.');
