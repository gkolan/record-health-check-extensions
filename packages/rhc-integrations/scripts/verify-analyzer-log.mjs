/* eslint-disable @lwc/lwc-platform/no-aura-libs, @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
import fs from 'node:fs';

const [logFile, requiredEngine] = process.argv.slice(2);
if (!logFile || !requiredEngine) {
    console.error('Usage: node scripts/verify-analyzer-log.mjs <log-file> <required-engine>');
    process.exit(2);
}

const log = fs.readFileSync(logFile, 'utf8');
const failureMarkers = [
    'Internal execution error',
    'Engine execution failed',
    'Failed to execute',
    "Error: Engine '"
];
const foundFailure = failureMarkers.find((marker) => log.includes(marker));
if (foundFailure) {
    console.error(`Analyzer log is incomplete because it contains: ${foundFailure}`);
    process.exit(1);
}

const executedRulesLine = log.split(/\r?\n/).find((line) => line.includes('Executed rules from'));
if (!executedRulesLine || !executedRulesLine.includes(requiredEngine)) {
    console.error(`Analyzer log does not prove execution of required engine: ${requiredEngine}`);
    process.exit(1);
}

if (requiredEngine === 'sfge') {
    const identifiedMatches = [...log.matchAll(/Identified (\d+) path entry point\(s\)/g)];
    const analyzedMatches = [...log.matchAll(
        /Overall, analyzed (\d+) path\(s\) from (\d+) entry point\(s\)/g
    )];
    if (identifiedMatches.length === 0 || analyzedMatches.length === 0) {
        console.error('Analyzer log does not contain SFGE entry-point completion counts');
        process.exit(1);
    }
    const identifiedCount = Number(identifiedMatches.at(-1)[1]);
    const analyzedPathCount = Number(analyzedMatches.at(-1)[1]);
    const analyzedEntryPointCount = Number(analyzedMatches.at(-1)[2]);
    if (analyzedPathCount !== identifiedCount || analyzedEntryPointCount !== identifiedCount) {
        console.error(
            `SFGE analysis is incomplete: identified ${identifiedCount}, analyzed `
            + `${analyzedPathCount} paths from ${analyzedEntryPointCount} entry points`
        );
        process.exit(1);
    }
}

console.log(`Analyzer log is complete and includes required engine: ${requiredEngine}`);
