/* eslint-disable @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = path.join(packageRoot, 'force-app', 'main', 'default');
const failures = [];
const check = (condition, message) => condition || failures.push(message);

for (const folder of ['classes', 'triggers']) {
    const directory = path.join(sourceRoot, folder);
    for (const file of fs.readdirSync(directory).filter(name => /\.(cls|trigger)$/.test(name))) {
        const metaPath = path.join(directory, `${file}-meta.xml`);
        check(fs.existsSync(metaPath), `Missing metadata companion for ${folder}/${file}`);
        if (fs.existsSync(metaPath)) {
            check(fs.readFileSync(metaPath, 'utf8').includes('<apiVersion>66.0</apiVersion>'), `${file} must declare API 66.0`);
        }
        if (!file.endsWith('.cls')) continue;
        const source = fs.readFileSync(path.join(directory, file), 'utf8');
        const isTest = /^\s*@IsTest/m.test(source);
        const declaration = source.match(/^(?:global|public|private)\s+(?:(with|without|inherited)\s+sharing\s+)?(?:abstract\s+|virtual\s+)?class\s/m);
        check(declaration !== null, `${file} has no top-level class declaration`);
        check(isTest || declaration?.[1], `${file} must declare with, inherited, or without sharing explicitly`);
        check(declaration?.[1] !== 'without', `${file} must not use without sharing`);
        check(!/System\.assert(Equals|NotEquals)?\(/.test(source), `${file} must use the Assert class`);
    }
}

if (failures.length) {
    console.error(failures.map(failure => `- ${failure}`).join('\n'));
    process.exit(1);
}
console.log('RHC Change Monitor source validation passed.');
