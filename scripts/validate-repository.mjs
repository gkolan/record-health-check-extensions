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

let sharedApiVersion;
let sharedCoreDependency;

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
            assert(
                project.packageAliases?.[dependency.package]?.startsWith('04t'),
                `${packageName} must alias ${dependency.package} to a subscriber package version`
            );
        }
    }

    assert(fs.existsSync(path.join(packageDirectory, 'README.md')), `${packageName} is missing README.md`);

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
console.log(`Shared contract: Salesforce API ${sharedApiVersion}; ${sharedCoreDependency}.`);
