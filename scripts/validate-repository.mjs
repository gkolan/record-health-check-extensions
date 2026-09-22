/* eslint-disable @lwc/lwc-platform/no-aura-libs, @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const errors = [];
let markdownCount = 0;
let linkCount = 0;

function relative(file) {
    return path.relative(root, file) || '.';
}

function assert(condition, message) {
    if (!condition) {
        errors.push(message);
    }
}

function readJson(file) {
    try {
        return JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (error) {
        errors.push(`${relative(file)} is not valid JSON: ${error.message}`);
        return null;
    }
}

function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function workflowJob(workflow, jobName) {
    const jobPattern = new RegExp(
        `^  ${escapeRegExp(jobName)}:\\n([\\s\\S]*?)(?=^  [A-Za-z0-9_-]+:\\n|(?![\\s\\S]))`,
        'm'
    );
    return workflow.match(jobPattern)?.[0] ?? '';
}

function walk(directory, predicate = () => true) {
    if (!fs.existsSync(directory)) {
        return [];
    }
    return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
        const entryPath = path.join(directory, entry.name);
        if (entry.isDirectory()) {
            if (entry.name === 'node_modules' || entry.name === '.git' || entry.name === '.standards') {
                return [];
            }
            return walk(entryPath, predicate);
        }
        return predicate(entryPath) ? [entryPath] : [];
    });
}

function validateMarkdownLinks(file) {
    markdownCount += 1;
    const markdown = fs.readFileSync(file, 'utf8');
    assert(
        !/repository has no HEAD|workspace (?:has no|does not currently resolve a) Git `?HEAD`?/i.test(markdown),
        `${relative(file)} contains a stale claim that the current repository has no Git HEAD`
    );
    const linkPattern = /!?\[[^\]]*\]\(([^)]+)\)/g;
    for (const match of markdown.matchAll(linkPattern)) {
        let target = match[1].trim().split(/\s+["']/)[0];
        target = target.replace(/^<|>$/g, '');
        if (!target || target.startsWith('#') || /^[a-z][a-z0-9+.-]*:/i.test(target)) {
            continue;
        }
        target = target.split('#')[0].split('?')[0];
        if (!target || target.includes('<') || target.includes('{')) {
            continue;
        }
        linkCount += 1;
        let decodedTarget;
        try {
            decodedTarget = decodeURIComponent(target);
        } catch {
            errors.push(`${relative(file)} contains an invalid encoded link: ${target}`);
            continue;
        }
        const resolved = decodedTarget.startsWith('/')
            ? path.join(root, decodedTarget.slice(1))
            : path.resolve(path.dirname(file), decodedTarget);
        assert(fs.existsSync(resolved), `${relative(file)} links to missing path: ${target}`);
    }
}

const packagesRoot = path.join(root, 'packages');
assert(fs.existsSync(path.join(root, 'LICENSE')), 'Repository is missing LICENSE');
assert(fs.existsSync(path.join(root, 'NOTICE')), 'Repository is missing NOTICE');
const packageDirectories = fs.readdirSync(packagesRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(packagesRoot, entry.name))
    .filter((directory) => fs.existsSync(path.join(directory, 'sfdx-project.json')))
    .sort();

assert(packageDirectories.length === 9, `Expected 9 package projects; found ${packageDirectories.length}`);

const validationWorkflowFile = path.join(root, '.github', 'workflows', 'validate.yml');
assert(fs.existsSync(validationWorkflowFile), 'Repository is missing .github/workflows/validate.yml');
const validationWorkflow = fs.existsSync(validationWorkflowFile)
    ? fs.readFileSync(validationWorkflowFile, 'utf8')
    : '';
assert(
    validationWorkflow.includes('actionlint_1.7.12_linux_amd64.tar.gz') &&
        validationWorkflow.includes('8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8'),
    'Repository CI must run the pinned, checksum-verified Actionlint 1.7.12 binary'
);
const staticJobByPackage = new Map([
    ['rhc-actions', 'rhc-actions-static'],
    ['rhc-alerts', 'rhc-alerts-code-analyzer'],
    ['rhc-builder', 'builder-static-analysis'],
    ['rhc-change-monitor', 'remaining-salesforce-static'],
    ['rhc-integrations', 'rhc-integrations-static'],
    ['rhc-logs', 'rhc-logs-static'],
    ['rhc-reports', 'rhc-reports-static'],
    ['rhc-run-manager', 'run-manager-static'],
    ['rhc-agent-actions', 'remaining-salesforce-static']
]);
const orgWorkflowByPackage = new Map([
    ['rhc-actions', 'rhc-actions-salesforce-validate.yml'],
    ['rhc-agent-actions', 'remaining-salesforce-validate.yml'],
    ['rhc-alerts', 'remaining-salesforce-validate.yml'],
    ['rhc-builder', 'rhc-builder-salesforce-validate.yml'],
    ['rhc-change-monitor', 'remaining-salesforce-validate.yml'],
    ['rhc-integrations', 'remaining-salesforce-validate.yml'],
    ['rhc-logs', 'remaining-salesforce-validate.yml'],
    ['rhc-reports', 'rhc-reports-salesforce-validate.yml'],
    ['rhc-run-manager', 'remaining-salesforce-validate.yml']
]);
const documentationByPackage = new Map([
    ['rhc-actions', {
        admin: 'ADMIN_GUIDE.md',
        security: 'docs/SECURITY_AND_AUTHORIZATION.md',
        operations: 'docs/OPERATIONS.md',
        release: 'docs/TESTING_AND_VERIFICATION.md'
    }],
    ['rhc-agent-actions', {
        admin: 'ADMIN_GUIDE.md',
        security: 'docs/SECURITY.md',
        operations: 'docs/OPERATIONS.md',
        release: 'RELEASE_EVIDENCE.md'
    }],
    ['rhc-alerts', {
        admin: 'ADMIN_GUIDE.md',
        security: 'docs/SECURITY.md',
        operations: 'docs/OPERATIONS.md',
        release: 'docs/RELEASE-GATES.md'
    }],
    ['rhc-builder', {
        admin: 'docs/ADMIN_GUIDE.md',
        security: 'docs/DEVELOPER_GUIDE.md',
        operations: 'docs/OPERATIONS.md',
        release: 'docs/VERIFICATION.md'
    }],
    ['rhc-change-monitor', {
        admin: 'ADMIN_GUIDE.md',
        security: 'docs/SECURITY.md',
        operations: 'docs/OPERATIONS.md',
        release: 'RELEASE_EVIDENCE.md'
    }],
    ['rhc-integrations', {
        admin: 'docs/JUNIOR-ADMIN-GUIDE.md',
        security: 'docs/SECURITY.md',
        operations: 'docs/OPERATIONS.md',
        release: 'docs/RELEASE-EVIDENCE.md'
    }],
    ['rhc-logs', {
        admin: 'docs/ADMINISTRATION.md',
        security: 'docs/SECURITY.md',
        operations: 'docs/OPERATIONS.md',
        release: 'docs/RELEASE-GATES.md'
    }],
    ['rhc-reports', {
        admin: 'docs/ADMIN_GUIDE.md',
        security: 'docs/OPERATIONS_AND_SECURITY.md',
        operations: 'docs/OPERATIONS_AND_SECURITY.md',
        release: 'docs/PACKAGE_VALIDATION.md'
    }],
    ['rhc-run-manager', {
        admin: 'ADMIN_GUIDE.md',
        security: 'docs/ARCHITECTURE.md',
        operations: 'docs/OPERATIONS.md',
        release: 'RELEASE_EVIDENCE.md'
    }]
]);
const npmPackageNames = [];
const forbiddenValidationCommands = [
    'sf package create',
    'sf package version create',
    'sf package version promote'
];

let sharedApiVersion;
let sharedCoreDependency;
let sharedCoreSubscriberId;

for (const packageDirectory of packageDirectories) {
    const packageName = path.basename(packageDirectory);
    const projectFile = path.join(packageDirectory, 'sfdx-project.json');
    const project = readJson(projectFile);
    if (!project) {
        continue;
    }

    assert(project.namespace === 'rhc', `${packageName} must declare namespace "rhc"`);
    assert(project.sourceApiVersion, `${packageName} must declare sourceApiVersion`);
    sharedApiVersion ??= project.sourceApiVersion;
    assert(
        project.sourceApiVersion === sharedApiVersion,
        `${packageName} uses API ${project.sourceApiVersion}; expected ${sharedApiVersion}`
    );

    const packagePaths = project.packageDirectories ?? [];
    assert(packagePaths.length === 1, `${packageName} must declare exactly one package directory`);
    const packagePath = packagePaths[0];
    if (packagePath) {
        assert(packagePath.default === true, `${packageName} package directory must be the default`);
        assert(packagePath.package, `${packageName} must declare its 2GP package name`);
        assert(packagePath.versionName, `${packageName} must declare versionName`);
        assert(/\.NEXT$/.test(packagePath.versionNumber ?? ''), `${packageName} must use a .NEXT versionNumber`);
        assert(
            fs.existsSync(path.join(packageDirectory, packagePath.path ?? '')),
            `${packageName} package source path does not exist: ${packagePath.path}`
        );
        const dependency = (packagePath.dependencies ?? []).find((item) =>
            item.package?.startsWith('Record Health Check@')
        );
        assert(dependency, `${packageName} must depend on a pinned Record Health Check version`);
        if (dependency) {
            sharedCoreDependency ??= dependency.package;
            assert(
                dependency.package === sharedCoreDependency,
                `${packageName} depends on ${dependency.package}; expected ${sharedCoreDependency}`
            );
            const coreSubscriberId = project.packageAliases?.[dependency.package];
            assert(
                coreSubscriberId?.startsWith('04t'),
                `${packageName} must alias ${dependency.package} to a subscriber package version`
            );
            sharedCoreSubscriberId ??= coreSubscriberId;
            assert(
                coreSubscriberId === sharedCoreSubscriberId,
                `${packageName} aliases ${dependency.package} to ${coreSubscriberId}; expected ${sharedCoreSubscriberId}`
            );
        }
    }

    assert(fs.existsSync(path.join(packageDirectory, 'README.md')), `${packageName} is missing README.md`);
    const documentation = documentationByPackage.get(packageName);
    assert(documentation, `${packageName} is missing its documentation-role contract`);
    for (const [role, documentationPath] of Object.entries(documentation ?? {})) {
        assert(
            fs.existsSync(path.join(packageDirectory, documentationPath)),
            `${packageName} is missing ${role} documentation at ${documentationPath}`
        );
    }
    const scratchDefinitionFile = path.join(packageDirectory, 'config', 'project-scratch-def.json');
    assert(fs.existsSync(scratchDefinitionFile), `${packageName} is missing config/project-scratch-def.json`);
    if (fs.existsSync(scratchDefinitionFile)) {
        const scratchDefinition = readJson(scratchDefinitionFile);
        if (scratchDefinition) {
            assert(scratchDefinition.orgName, `${packageName} scratch definition must declare orgName`);
            assert(scratchDefinition.edition, `${packageName} scratch definition must declare edition`);
        }
    }

    const sourceRoot = path.join(packageDirectory, 'force-app');
    for (const apexFile of walk(sourceRoot, (file) => file.endsWith('.cls') || file.endsWith('.trigger'))) {
        assert(fs.existsSync(`${apexFile}-meta.xml`), `${relative(apexFile)} is missing its metadata companion`);
    }

    const lwcRoot = path.join(sourceRoot, 'main', 'default', 'lwc');
    if (fs.existsSync(lwcRoot)) {
        for (const bundle of fs.readdirSync(lwcRoot, { withFileTypes: true }).filter((entry) => entry.isDirectory())) {
            const bundleRoot = path.join(lwcRoot, bundle.name);
            const controller = path.join(bundleRoot, `${bundle.name}.js`);
            if (fs.existsSync(controller)) {
                assert(
                    fs.existsSync(path.join(bundleRoot, `${bundle.name}.js-meta.xml`)),
                    `${relative(controller)} is missing its LWC metadata companion`
                );
            }
        }
    }

    const packageFile = path.join(packageDirectory, 'package.json');
    const lwcControllers = walk(lwcRoot, (file) => file.endsWith('.js') && !file.includes('__tests__'));
    assert(fs.existsSync(packageFile) || lwcControllers.length === 0, `${packageName} ships LWC code without a test harness`);
    if (fs.existsSync(packageFile)) {
        npmPackageNames.push(packageName);
        const manifest = readJson(packageFile);
        assert(fs.existsSync(path.join(packageDirectory, 'package-lock.json')), `${packageName} is missing package-lock.json`);
        assert(fs.existsSync(path.join(packageDirectory, '.forceignore')), `${packageName} is missing .forceignore`);
        if (manifest) {
            assert(manifest.private === true, `${packageName} must remain private to prevent accidental npm publishing`);
            assert(manifest.license === 'Apache-2.0', `${packageName} must declare Apache-2.0`);
            assert(manifest.scripts?.test, `${packageName} must expose npm test`);
            const jestVersion = manifest.devDependencies?.['@salesforce/sfdx-lwc-jest'];
            assert(/^\^?8\./.test(jestVersion ?? ''), `${packageName} must use sfdx-lwc-jest 8.x`);
        }
    }
}

for (const [packageName, jobName] of staticJobByPackage) {
    const job = workflowJob(validationWorkflow, jobName);
    assert(job, `${packageName} is missing its ${jobName} CI job`);
    assert(job.includes(packageName), `${jobName} does not select ${packageName}`);
    assert(job.includes('sf project convert source'), `${jobName} does not validate source conversion`);
    assert(job.includes('sf code-analyzer run'), `${jobName} does not run Salesforce Code Analyzer`);
}

for (const [packageName, workflowName] of orgWorkflowByPackage) {
    const workflowFile = path.join(root, '.github', 'workflows', workflowName);
    assert(fs.existsSync(workflowFile), `${packageName} is missing its ${workflowName} org-validation workflow`);
    const workflow = fs.existsSync(workflowFile) ? fs.readFileSync(workflowFile, 'utf8') : '';
    assert(workflow.includes(packageName), `${workflowName} does not select ${packageName}`);
    assert(workflow.includes('sf org create scratch'), `${workflowName} does not create a disposable scratch org`);
    assert(
        sharedCoreSubscriberId && workflow.includes(sharedCoreSubscriberId),
        `${workflowName} does not install the pinned core dependency ${sharedCoreSubscriberId}`
    );
    assert(
        workflow.includes('sf project deploy start') && workflow.includes('--dry-run'),
        `${workflowName} does not run a server-side source validation`
    );
    assert(workflow.includes('sf apex run test'), `${workflowName} does not run Apex tests`);
    assert(workflow.includes('sf org delete scratch'), `${workflowName} does not clean up its scratch org`);
}

const remainingOrgWorkflowFile = path.join(root, '.github', 'workflows', 'remaining-salesforce-validate.yml');
const remainingOrgWorkflow = fs.existsSync(remainingOrgWorkflowFile)
    ? fs.readFileSync(remainingOrgWorkflowFile, 'utf8')
    : '';
assert(
    remainingOrgWorkflow.includes('namespace_mode:') && remainingOrgWorkflow.includes('--no-namespace'),
    'The remaining Salesforce org workflow does not validate both namespace modes'
);

for (const workflowFile of walk(path.join(root, '.github', 'workflows'), (file) => file.endsWith('.yml'))) {
    const workflow = fs.readFileSync(workflowFile, 'utf8');
    for (const command of forbiddenValidationCommands) {
        assert(!workflow.includes(command), `${relative(workflowFile)} must not run ${command}`);
    }
}

const lwcJob = workflowJob(validationWorkflow, 'lwc');
for (const packageName of npmPackageNames) {
    assert(lwcJob.includes(`- ${packageName}`), `${packageName} is missing from the npm CI matrix`);
}
assert(lwcJob.includes('npm run test:coverage'), 'The npm CI matrix does not enforce test coverage');
assert(lwcJob.includes('npm audit --audit-level=high'), 'The npm CI matrix does not enforce dependency auditing');
assert(
    lwcJob.includes("matrix.package == 'rhc-change-monitor'") && lwcJob.includes('npm run test:adapter-generator'),
    'The npm CI matrix does not run Change Monitor adapter-generator tests'
);

const remainingStaticJob = workflowJob(validationWorkflow, 'remaining-salesforce-static');
assert(
    remainingStaticJob.includes('npm run metadata:generate -- --check'),
    'The Change Monitor static CI gate does not verify generated metadata'
);

for (const markdownFile of walk(root, (file) => file.endsWith('.md'))) {
    validateMarkdownLinks(markdownFile);
}

if (errors.length > 0) {
    console.error(`Repository validation failed with ${errors.length} issue(s):`);
    for (const error of errors) {
        console.error(`- ${error}`);
    }
    process.exit(1);
}

console.log(
    `Repository validation passed: ${packageDirectories.length} packages, ` +
    `${markdownCount} Markdown files, and ${linkCount} local links checked.`
);
console.log(
    `CI contract: ${staticJobByPackage.size} source projects and ` +
    `${npmPackageNames.length} npm-backed packages covered; ` +
    `${orgWorkflowByPackage.size} org-validation paths configured.`
);
console.log(`Documentation contract: admin, security, operations, and release guidance mapped for all packages.`);
console.log(`Shared contract: Salesforce API ${sharedApiVersion}; ${sharedCoreDependency}.`);
