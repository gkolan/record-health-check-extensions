import fs from "node:fs";

function percentage(covered, total) {
  return total === 0 ? 100 : Math.floor((covered / total) * 10000) / 100;
}

function summarizeCounters(counterGroups) {
  const counters = counterGroups.flat();
  return {
    covered: counters.filter((value) => value > 0).length,
    total: counters.length
  };
}

export function readJestEvidence(filePath) {
  const report = JSON.parse(fs.readFileSync(filePath, "utf8"));
  if (report.success !== true || report.numFailedTests !== 0) {
    throw new Error("Jest evidence does not report a successful zero-failure run");
  }

  const files = Object.values(report.coverageMap ?? {});
  if (files.length === 0) throw new Error("Jest evidence has no coverage map");

  const statements = summarizeCounters(files.map((file) => Object.values(file.s ?? {})));
  const functions = summarizeCounters(files.map((file) => Object.values(file.f ?? {})));
  const branches = summarizeCounters(
    files.flatMap((file) => Object.values(file.b ?? {}))
  );
  const lineHits = new Map();
  for (const file of files) {
    for (const [statementId, hits] of Object.entries(file.s ?? {})) {
      const line = file.statementMap?.[statementId]?.start?.line;
      if (Number.isInteger(line)) {
        const key = `${file.path}:${line}`;
        lineHits.set(key, Math.max(lineHits.get(key) ?? 0, hits));
      }
    }
  }
  const lines = summarizeCounters([[...lineHits.values()]]);

  return {
    testsPassed: report.numPassedTests,
    testsFailed: report.numFailedTests,
    suitesPassed: report.numPassedTestSuites,
    coverage: {
      statements: percentage(statements.covered, statements.total),
      branches: percentage(branches.covered, branches.total),
      functions: percentage(functions.covered, functions.total),
      lines: percentage(lines.covered, lines.total)
    }
  };
}
