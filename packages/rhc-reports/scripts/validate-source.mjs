/* eslint-disable @lwc/lwc-platform/no-aura-libs, @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
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

for (const [directoryName, suffix] of [['classes', '.cls'], ['triggers', '.trigger']]) {
    const directory = path.join(sourceRoot, directoryName);
    for (const implementation of fs.readdirSync(directory).filter(name => name.endsWith(suffix))) {
        check(
            fs.existsSync(path.join(directory, `${implementation}-meta.xml`)),
            `Missing metadata companion for ${directoryName}/${implementation}`
        );
    }
}

for (const objectName of fs.readdirSync(path.join(sourceRoot, 'objects'))) {
    check(
        objectName.startsWith('Record_Health_Check_'),
        `Object ${objectName} does not use the suite Record_Health_Check_ prefix`
    );
}

const productionApex = walk(path.join(sourceRoot, 'classes'))
    .filter(file => file.endsWith('.cls') && !file.endsWith('Test.cls'))
    .concat(walk(path.join(sourceRoot, 'triggers')).filter(file => file.endsWith('.trigger')))
    .map(file => fs.readFileSync(file, 'utf8'))
    .join('\n');
check(
    !productionApex.includes('Test.isRunningTest()'),
    'Production Apex must not branch on Test.isRunningTest()'
);

const coverageController = read(
    'force-app/main/default/classes/RHCReportsCoverageController.cls'
);
const suppressionDocumentation = read('docs/CODE-ANALYZER-SUPPRESSIONS.md');
check(
    coverageController.match(/@SuppressWarnings\('PMD\.AvoidBooleanMethodParameters'\)/g)?.length === 1
        && coverageController.match(/@SuppressWarnings\('PMD\.AvoidNonRestrictiveQueries'\)/g)?.length === 2,
    'Coverage analyzer suppressions must remain limited to the Aura Boolean DTO and two complete aggregate queries'
);
for (const rationale of [
    'generated Aura property setters',
    'complete grouped fact-table aggregates'
]) {
    check(
        suppressionDocumentation.includes(rationale),
        `Analyzer suppression documentation is missing rationale: ${rationale}`
    );
}

const project = JSON.parse(read('sfdx-project.json'));
check(project.namespace === 'rhc', 'Package namespace configuration must remain rhc');
check(
    project.packageDirectories?.[0]?.dependencies?.[0]?.package === 'Record Health Check@2.0.4-2',
    'Package dependency must remain pinned to promoted core 2.0.4-2'
);

const retentionField = read(
    'force-app/main/default/objects/Record_Health_Check_Report_Setting__c/fields/RetentionCleanupEnabled__c.field-meta.xml'
);
check(
    retentionField.includes('<defaultValue>false</defaultValue>'),
    'Irreversible retention cleanup must default to false'
);
const aggregationStatusField = read(
    'force-app/main/default/objects/Record_Health_Check_Report_Setting__c/fields/LastAggregationStatus__c.field-meta.xml'
);
check(
    aggregationStatusField.includes('<type>Text</type>') &&
        aggregationStatusField.includes('<length>20</length>') &&
        !aggregationStatusField.includes('<valueSet>'),
    'Hierarchy Custom Setting aggregation status must use bounded Text metadata'
);

const setupController = read('force-app/main/default/classes/RHCReportsSetupController.cls');
check(
    /retentionCleanupEnabled\s*=\s*[\s\S]*?\? false\s*:/.test(setupController),
    'Setup DTO must default irreversible retention cleanup to false when no setting exists'
);
check(
    setupController.includes("FeatureManagement.checkPermission('Manage_RHC_Reports')"),
    'Setup mutations must remain protected by Manage_RHC_Reports'
);

const ingestion = read('force-app/main/default/classes/RHCReportsIngestionService.cls');
check(
    ingestion.includes('Database.UpsertResult[]') && ingestion.includes('assertSuccessful'),
    'Ingestion must inspect partial-success upsert results'
);
check(
    ingestion.includes('EventBus.RetryableException') && ingestion.includes('UNABLE_TO_LOCK_ROW'),
    'Transient Platform Event ingestion failures must request redelivery'
);

const retention = read('force-app/main/default/classes/RHCReportsRetentionBatch.cls');
check(
    retention.includes('Database.DeleteResult[]') && retention.includes('nextTargetName'),
    'Retention must inspect delete results and preserve the RESULT to RUN to SNAPSHOT chain'
);
check(
    !/ContinuationMode\s+continuationMode/.test(retention),
    'Retention enum members must not shadow the ContinuationMode type in case-insensitive Apex'
);

const queueable = read('force-app/main/default/classes/RHCReportsDailyAggregationQueueable.cls');
check(
    queueable.includes('implements Queueable, Finalizer') &&
        queueable.includes('getResult()') &&
        queueable.includes('LastAggregationStatus__c'),
    'Aggregation must attach a Finalizer and persist a durable outcome'
);

const viewerPermission = read(
    'force-app/main/default/permissionsets/RHC_Reports_Viewer.permissionset-meta.xml'
);
for (const restrictedField of [
    'RecordId__c',
    'RunId__c',
    'EventId__c',
    'ReasonCode__c',
    'ContractVersion__c',
    'FrameworkVersion__c'
]) {
    check(
        !viewerPermission.includes(restrictedField),
        `Viewer must not receive raw diagnostic field ${restrictedField}`
    );
}
for (const requiredField of [
    'Record_Health_Check_Report_Run__c.CheckSetQualifiedApiName__c',
    'Record_Health_Check_Report_Run__c.OccurredAt__c',
    'Record_Health_Check_Report_Result__c.CheckSetQualifiedApiName__c',
    'Record_Health_Check_Report_Result__c.OccurredAt__c',
    'Record_Health_Check_Report_Result__c.Status__c'
]) {
    check(
        !viewerPermission.includes(`<field>${requiredField}</field>`),
        `Viewer must not declare fieldPermissions for required field ${requiredField}`
    );
}
check(
    viewerPermission.lastIndexOf('</fieldPermissions>') <
        viewerPermission.indexOf('<hasActivationRequired>') &&
        viewerPermission.indexOf('<hasActivationRequired>') <
        viewerPermission.indexOf('<objectPermissions>'),
    'Viewer permission metadata must preserve field, activation/label, then object element order'
);

const weightedReports = [
    'Weekly_Failure_Rate.report-meta.xml',
    'Opportunity_Close_Readiness.report-meta.xml',
    'Recovery_Rate.report-meta.xml'
];
for (const reportName of weightedReports) {
    const report = read(`force-app/main/default/reports/RHC_Reports/${reportName}`);
    check(
        report.includes('<developerName>FORMULA1</developerName>') &&
            report.includes('<column>FORMULA1</column>'),
        `${reportName} must chart a weighted custom summary formula`
    );
    check(
        !/<chartSummaries><aggregate>Average<\/aggregate>[\s\S]*?(FailureRate__c|RecoveryRate__c)/.test(report),
        `${reportName} must not average precomputed rate rows`
    );
}

const hotspotReport = read(
    'force-app/main/default/reports/RHC_Reports/Error_Unable_Hotspots.report-meta.xml'
);
for (const requiredText of [
    '<booleanFilter>1 AND (2 OR 3)</booleanFilter>',
    '<value>ERROR</value>',
    '<value>UNABLE_TO_EVALUATE</value>'
]) {
    check(hotspotReport.includes(requiredText), `Error/Unable Hotspots is missing ${requiredText}`);
}

for (const markdownFile of walk(packageRoot).filter(file =>
    file.endsWith('.md') && !file.includes(`${path.sep}node_modules${path.sep}`)
)) {
    const contents = fs.readFileSync(markdownFile, 'utf8');
    for (const match of contents.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
        const target = match[1].split('#')[0];
        if (!target || /^(https?:|mailto:)/.test(target)) continue;
        check(
            fs.existsSync(path.resolve(path.dirname(markdownFile), target)),
            `Broken local link ${target} in ${path.relative(packageRoot, markdownFile)}`
        );
    }
}

if (failures.length > 0) {
    console.error(`RHC Reports source validation failed (${failures.length}):`);
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
}

console.log('RHC Reports source validation passed.');
