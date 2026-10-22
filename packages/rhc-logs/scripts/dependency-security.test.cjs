const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { mkdtempSync, rmSync, writeFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const path = require('node:path');
const test = require('node:test');

const braces = createRequire(require.resolve('micromatch'))('braces');

test('brace replacement preserves normal glob expansion and compilation', () => {
    assert.deepEqual(braces.expand('src/{a,b}/{01..02}.js'), [
        'src/a/01.js', 'src/a/02.js', 'src/b/01.js', 'src/b/02.js'
    ]);
    assert.equal(braces.compile('src/{a,b}.js'), 'src/(a|b).js');
    assert.equal(braces.stringify(braces.parse('src/{a,b}.js')), 'src/{a,b}.js');
    assert.deepEqual(require('micromatch')(['src/a.js', 'src/c.js'], 'src/{a,b}.js'), ['src/a.js']);
});

test('nested strings cannot exceed the hard depth limit through any public processor', () => {
    for (const delimiters of [['{', '}'], ['(', ')']]) {
        const pattern = delimiters[0].repeat(2000) + 'x' + delimiters[1].repeat(2000);
        for (const processor of [braces, braces.parse, braces.compile, braces.expand, braces.stringify]) {
            assert.throws(() => processor(pattern, { maxDepth: Infinity }), /exceeds max depth/);
        }
    }
    assert.throws(() => braces.parse('{{x}}', { maxDepth: 1.5 }), /exceeds max depth/);
    assert.throws(() => braces.parse('x'.repeat(10001), { maxLength: NaN }), /maxLength/);
});

test('direct ASTs cannot bypass the depth guard', () => {
    for (const processor of [braces.compile, braces.expand, braces.stringify]) {
        const ast = { type: 'root', nodes: [] };
        let parent = ast;
        for (let index = 0; index < 200; index++) {
            const child = { type: 'paren', nodes: [], parent };
            parent.nodes.push(child);
            parent = child;
        }
        assert.throws(() => processor(ast), /exceeds max depth/);
    }
});

test('coverage configuration still loads YAML without the vulnerable sprintf dependency', async () => {
    const configPath = require.resolve('@istanbuljs/load-nyc-config');
    const coverageRequire = createRequire(configPath);
    assert.equal(coverageRequire('js-yaml/package.json').version, '4.3.2');
    assert.throws(() => coverageRequire.resolve('sprintf-js'), { code: 'MODULE_NOT_FOUND' });
    const directory = mkdtempSync(path.join(tmpdir(), 'rhc-logs-coverage-'));
    try {
        writeFileSync(path.join(directory, 'package.json'), '{}');
        writeFileSync(path.join(directory, '.nycrc.yaml'), 'all: true\ninclude:\n  - "src/**/*.js"\n');
        const config = await require('@istanbuljs/load-nyc-config').loadNycConfig({ cwd: directory });
        assert.equal(config.all, true);
        assert.deepEqual(config.include, ['src/**/*.js']);
    } finally {
        rmSync(directory, { recursive: true, force: true });
    }
});
