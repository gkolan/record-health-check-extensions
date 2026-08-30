import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repositoryRoot = path.resolve(packageRoot, '..', '..');
const argumentsList = process.argv.slice(2);

function valuesFor(flag) {
    const values = [];
    for (let index = 0; index < argumentsList.length; index += 1) {
        if (argumentsList[index] === flag && argumentsList[index + 1]) {
            values.push(argumentsList[index + 1]);
            index += 1;
        }
    }
    return values;
}

function git(...argumentsForGit) {
    return execFileSync('git', argumentsForGit, {
        cwd: repositoryRoot,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe']
    }).trim();
}

function command(executable, ...argumentsForCommand) {
    return execFileSync(executable, argumentsForCommand, {
        cwd: packageRoot,
        encoding: 'utf8',
        env: { ...process.env, SF_DISABLE_LOG_FILE: 'true' },
        stdio: ['ignore', 'pipe', 'pipe']
    }).trim();
}

function digest(file) {
    if (!fs.existsSync(file)) {
        return { path: file, exists: false };
    }
    const contents = fs.readFileSync(file);
    return {
        path: file,
        exists: true,
        bytes: contents.length,
        sha256: crypto.createHash('sha256').update(contents).digest('hex')
    };
}

const outputValues = valuesFor('--output');
const outputFile = outputValues[0];
if (!outputFile) {
    console.error('Usage: node scripts/capture-release-evidence.mjs --output <file> --core-ref <sha> --artifact <file> [...]');
    process.exit(2);
}

const errors = [];
let head = null;
let scopedStatus = null;
try {
    head = git('rev-parse', '--verify', 'HEAD');
    scopedStatus = git(
        'status',
        '--porcelain=v1',
        '--untracked-files=all',
        '--',
        'packages/rhc-integrations',
        '.github/workflows/validate.yml'
    );
} catch (error) {
    errors.push(`Git revision identity unavailable: ${error.stderr?.trim() || error.message}`);
}

const ciSha = process.env.GITHUB_SHA ?? null;
if (head && ciSha && head !== ciSha) {
    errors.push(`Git HEAD ${head} does not match GITHUB_SHA ${ciSha}`);
}
if (scopedStatus) {
    errors.push(`Scoped release source is dirty:\n${scopedStatus}`);
}

const artifacts = valuesFor('--artifact').map((file) => digest(path.resolve(file)));
for (const artifact of artifacts) {
    if (!artifact.exists) {
        errors.push(`Required evidence artifact is missing: ${artifact.path}`);
    }
}
if (artifacts.length === 0) {
    errors.push('At least one --artifact value is required');
}
const coreBenchmarkRef = valuesFor('--core-ref')[0] ?? null;
if (!coreBenchmarkRef) {
    errors.push('--core-ref is required');
}

let salesforceCliVersion = null;
let codeAnalyzerVersion = null;
try {
    salesforceCliVersion = command('sf', '--version');
    codeAnalyzerVersion = command('sf', 'plugins', '--core')
        .split(/\r?\n/)
        .find((line) => line.startsWith('code-analyzer ')) ?? null;
    if (!codeAnalyzerVersion) {
        errors.push('The Salesforce Code Analyzer plugin version is unavailable');
    }
} catch (error) {
    errors.push(`Analyzer toolchain identity unavailable: ${error.stderr?.trim() || error.message}`);
}

const packageJson = JSON.parse(fs.readFileSync(path.join(packageRoot, 'package.json'), 'utf8'));
const project = JSON.parse(fs.readFileSync(path.join(packageRoot, 'sfdx-project.json'), 'utf8'));
const manifest = {
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    releaseReadyIdentity: errors.length === 0,
    revision: {
        head,
        ciSha,
        cleanScopedSource: scopedStatus === '',
        workflowRunUrl: process.env.GITHUB_SERVER_URL && process.env.GITHUB_REPOSITORY && process.env.GITHUB_RUN_ID
            ? `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`
            : null,
        workflowRunAttempt: process.env.GITHUB_RUN_ATTEMPT ?? null
    },
    package: {
        name: packageJson.name,
        version: packageJson.version,
        namespace: project.namespace,
        sourceApiVersion: project.sourceApiVersion,
        packageAliases: project.packageAliases,
        dependencies: project.packageDirectories?.find((entry) => entry.default)?.dependencies ?? []
    },
    coreBenchmarkRef,
    toolchain: {
        node: process.version,
        salesforceCli: salesforceCliVersion,
        codeAnalyzer: codeAnalyzerVersion
    },
    artifacts,
    errors
};

fs.mkdirSync(path.dirname(path.resolve(outputFile)), { recursive: true });
fs.writeFileSync(path.resolve(outputFile), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Release evidence manifest written to ${path.resolve(outputFile)}`);
if (errors.length > 0) {
    for (const error of errors) {
        console.error(error);
    }
    process.exitCode = 1;
}
