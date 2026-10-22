import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const classesRoot = path.join(packageRoot, 'force-app', 'main', 'default', 'classes');
const failures = [];

function check(condition, message) {
    if (!condition) failures.push(message);
}

function read(relativePath) {
    return fs.readFileSync(path.join(packageRoot, relativePath), 'utf8');
}

const project = JSON.parse(read('sfdx-project.json'));
check(project.namespace === 'rhc', 'Package namespace must remain rhc');
check(project.sourceApiVersion === '66.0', 'Package must remain on Salesforce API 66.0');
check(
    project.packageDirectories?.[0]?.dependencies?.[0]?.package === 'Record Health Check@2.0.11-4',
    'Package dependency must remain pinned to promoted core 2.0.11-4'
);
check(
    project.packageAliases?.['Record Health Check@2.0.11-4'] === '04tak000000nGjZAAU',
    'Core alias must resolve to promoted subscriber version 04tak000000nGjZAAU'
);

const classNames = fs.readdirSync(classesRoot).filter(name => name.endsWith('.cls'));
const productionClassNames = classNames.filter(name => !name.endsWith('Test.cls'));
for (const className of classNames) {
    const metadataPath = path.join(classesRoot, `${className}-meta.xml`);
    check(
        fs.existsSync(metadataPath) &&
            fs.readFileSync(metadataPath, 'utf8').includes('<apiVersion>66.0</apiVersion>'),
        `classes/${className} needs a metadata companion declaring apiVersion 66.0`
    );
}
for (const className of productionClassNames) {
    const source = fs.readFileSync(path.join(classesRoot, className), 'utf8');
    check(
        /\b(with|without|inherited)\s+sharing\s+class\b/.test(source),
        `classes/${className} must declare explicit sharing`
    );
    check(!source.includes('rhc__'), `classes/${className} must not hard-code the rhc__ namespace`);
}

// The agent actions are pure callers of core APIs: the permission set may grant Apex access only.
const permissionSet = read(
    'force-app/main/default/permissionsets/RHC_Agent_Actions_User.permissionset-meta.xml'
);
for (const forbidden of [
    'objectPermissions',
    'fieldPermissions',
    'customPermissions',
    'userPermissions'
]) {
    check(
        !permissionSet.includes(`<${forbidden}>`),
        `Agent Actions User must not grant ${forbidden}; core permission sets own data access`
    );
}
const grantedClasses = [...permissionSet.matchAll(/<apexClass>([^<]+)<\/apexClass>/g)]
    .map(match => `${match[1]}.cls`)
    .sort();
check(
    grantedClasses.join() === [...productionClassNames].sort().join(),
    `Agent Actions User must grant exactly the production classes, not ${grantedClasses.join(', ')}`
);

if (failures.length > 0) {
    console.error(`RHC Agent Actions source validation failed (${failures.length}):`);
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
}

console.log(`RHC Agent Actions source validation passed (${classNames.length} Apex classes).`);
