import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repositoryRoot = path.resolve(packageRoot, '../..');
const evidenceRoot = path.join(packageRoot, 'release-evidence', 'prepackage');
const coreCommit = '74fe1d6022f819397fc879c076f4f4dd2093cfab';
const requiredTestMethods = 29;
const minimumCoverage = 95;
const failures = [];

function check(condition, message) {
    if (!condition) failures.push(message);
}

function walk(directory) {
    return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
        const entryPath = path.join(directory, entry.name);
        return entry.isDirectory() ? walk(entryPath) : [entryPath];
    });
}

function sourceFiles() {
    const roots = [
        path.join(packageRoot, 'force-app'),
        path.join(packageRoot, 'config'),
        path.join(packageRoot, 'scripts')
    ];
    const files = roots.flatMap(root => walk(root));
    files.push(
        path.join(packageRoot, 'package.json'),
        path.join(packageRoot, 'package-lock.json'),
        path.join(packageRoot, 'sfdx-project.json'),
        path.join(packageRoot, 'SPEC.md'),
        path.join(repositoryRoot, '.github', 'workflows', 'validate.yml')
    );
    return files.sort((left, right) => left.localeCompare(right));
}

function sourceDigest() {
    const hash = crypto.createHash('sha256');
    for (const file of sourceFiles()) {
        const relativePath = path.relative(repositoryRoot, file).split(path.sep).join('/');
        hash.update(relativePath);
        hash.update('\0');
        hash.update(fs.readFileSync(file));
        hash.update('\0');
    }
    return `sha256:${hash.digest('hex')}`;
}

function readEvidence(fileName) {
    const evidencePath = path.join(evidenceRoot, fileName);
    if (!fs.existsSync(evidencePath)) {
        failures.push(`Missing pre-package evidence: release-evidence/prepackage/${fileName}`);
        return null;
    }
    try {
        return JSON.parse(fs.readFileSync(evidencePath, 'utf8'));
    } catch (error) {
        failures.push(`Invalid JSON in ${fileName}: ${error.message}`);
        return null;
    }
}

function validateShapeEvidence(fileName, expectedShape, digest) {
    const evidence = readEvidence(fileName);
    if (!evidence) return;
    check(evidence.schemaVersion === 1, `${fileName}: schemaVersion must be 1`);
    check(evidence.sourceDigest === digest, `${fileName}: source digest does not match current package source`);
    check(evidence.coreCommit === coreCommit, `${fileName}: minimum-core commit does not match 2.0.4.2`);
    check(evidence.shape === expectedShape, `${fileName}: expected shape ${expectedShape}`);
    check(evidence.deploy?.status === 'Succeeded', `${fileName}: combined source deployment did not succeed`);
    check(/^0Af[a-zA-Z0-9]{12,15}$/.test(evidence.deploy?.jobId ?? ''), `${fileName}: missing Salesforce deploy job ID`);
    check(evidence.tests?.outcome === 'Passed', `${fileName}: Apex tests did not pass`);
    check(evidence.tests?.methods >= requiredTestMethods, `${fileName}: fewer than ${requiredTestMethods} Apex tests ran`);
    check(
        evidence.tests?.coveragePercent >= minimumCoverage,
        `${fileName}: package Apex coverage is below ${minimumCoverage}%`
    );
    check(/^707[a-zA-Z0-9]{12,15}$/.test(evidence.tests?.runId ?? ''), `${fileName}: missing Apex test run ID`);
    for (const scenario of [
        'platformEventBulk', 'duplicateIdempotency', 'malformedEvent',
        'unsupportedContract', 'restrictedPersonas', 'scheduleLifecycle',
        'cleanupBoundary', 'cleanupOverlap'
    ]) {
        check(evidence.scenarios?.[scenario] === true, `${fileName}: scenario ${scenario} is not proven`);
    }
}

function validateCiEvidence(digest) {
    const evidence = readEvidence('ci.json');
    if (!evidence) return;
    check(evidence.schemaVersion === 1, 'ci.json: schemaVersion must be 1');
    check(evidence.sourceDigest === digest, 'ci.json: source digest does not match current package source');
    check(evidence.workflow === 'Validate', 'ci.json: expected the Validate workflow');
    check(evidence.conclusion === 'success', 'ci.json: workflow conclusion must be success');
    check(/^[0-9a-f]{40}$/.test(evidence.commit ?? ''), 'ci.json: commit must be a full Git SHA');
    check(
        /^https:\/\/github\.com\/.+\/actions\/runs\/\d+$/.test(evidence.runUrl ?? ''),
        'ci.json: runUrl must identify a GitHub Actions run'
    );
}

function validateCommittedBaseline() {
    const head = spawnSync('git', ['rev-parse', '--verify', 'HEAD'], {
        cwd: repositoryRoot,
        encoding: 'utf8'
    });
    check(head.status === 0, 'Repository has no committed HEAD');
    if (head.status !== 0) return;

    const status = spawnSync(
        'git',
        ['status', '--porcelain', '--', '.github/workflows/validate.yml', 'packages/rhc-logs'],
        { cwd: repositoryRoot, encoding: 'utf8' }
    );
    check(status.status === 0, 'Could not inspect the RHC Logs git baseline');
    check(status.stdout.trim() === '', 'RHC Logs source or workflow differs from committed HEAD');
}

const digest = sourceDigest();
validateCommittedBaseline();
validateShapeEvidence('namespaced.json', 'namespaced', digest);
validateShapeEvidence('no-namespace.json', 'no-namespace', digest);
validateCiEvidence(digest);

if (failures.length > 0) {
    console.error(`RHC Logs candidate creation remains locked (${failures.length} gate(s)):`);
    for (const failure of failures) console.error(`- ${failure}`);
    console.error(`Current source digest: ${digest}`);
    process.exit(1);
}

console.log(`RHC Logs pre-package gates passed for ${digest}. Candidate creation may be separately authorized.`);
