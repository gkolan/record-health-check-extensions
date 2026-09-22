/* eslint-disable @lwc/lwc-platform/no-aura-libs, @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const packageRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);
const verifier = path.join(packageRoot, "scripts/verify-prepackage-gates.mjs");
const temporaryRoot = fs.mkdtempSync(
  path.join(os.tmpdir(), "rhc-alerts-lock-test-")
);

function invoke(args) {
  return spawnSync(process.execPath, [verifier, ...args], {
    cwd: packageRoot,
    encoding: "utf8"
  });
}

function passedOrg(orgShape, orgId) {
  return {
    status: "PASSED",
    orgShape,
    sourceCommit: "f".repeat(40),
    completedAt: "2026-08-30T12:00:00.000Z",
    evidenceUrl: "https://example.invalid/release-evidence",
    orgId,
    dryRunJobId: "0Af000000000000",
    apexTestRunId: "707000000000000",
    testsPassed: 55,
    testsFailed: 0,
    packageCoverage: 75,
    resultTriggerCoverage: 1,
    setRunTriggerCoverage: 1,
    platformEventAcceptance: true,
    permissionAcceptance: true
  };
}

try {
  const missingArgument = invoke(["--evidence"]);
  assert.equal(missingArgument.status, 2);
  assert.match(missingArgument.stderr, /requires a path/);

  const pending = invoke([
    "--evidence",
    path.join(packageRoot, "release-evidence/prepackage.template.json")
  ]);
  assert.equal(pending.status, 1);
  assert.match(pending.stderr, /pre-package lock remains CLOSED/);
  assert.match(pending.stderr, /Namespaced source: status must be PASSED/);
  assert.match(pending.stderr, /No-namespace source: status must be PASSED/);

  const analyzerPath = path.join(temporaryRoot, "code-analyzer.json");
  const analyzerBytes = Buffer.from(
    `${JSON.stringify({ violationCounts: { total: 0 }, violations: [] }, null, 2)}\n`
  );
  fs.writeFileSync(analyzerPath, analyzerBytes);
  const analyzerSha256 = crypto
    .createHash("sha256")
    .update(analyzerBytes)
    .digest("hex");

  const counterfeit = {
    schemaVersion: 1,
    packageName: "RHC Alerts",
    sourceCommit: "f".repeat(40),
    local: {
      status: "PASSED",
      completedAt: "2026-08-30T12:00:00.000Z",
      repositoryContracts: "PASSED",
      packageContracts: "PASSED",
      formatting: "PASSED",
      minimumCoreContract: "PASSED",
      metadataXml: "PASSED",
      sourceConversion: "PASSED",
      lwc: {
        status: "PASSED",
        testsPassed: 19,
        statements: 90,
        branches: 80,
        functions: 90,
        lines: 90
      },
      slds: { status: "PASSED", violations: 0 },
      codeAnalyzer: {
        status: "PASSED",
        findings: 0,
        resultFile: analyzerPath,
        resultSha256: analyzerSha256
      },
      dependencyAudit: { status: "PASSED", highVulnerabilities: 0 }
    },
    ci: {
      status: "PASSED",
      commit: "f".repeat(40),
      runUrl: "https://example.invalid/ci"
    },
    namespacedSource: passedOrg("NAMESPACED", "00D000000000000"),
    noNamespaceSource: passedOrg("NO_NAMESPACE", "00D000000000001")
  };
  const counterfeitPath = path.join(temporaryRoot, "counterfeit.json");
  fs.writeFileSync(
    counterfeitPath,
    `${JSON.stringify(counterfeit, null, 2)}\n`
  );

  const counterfeitResult = invoke(["--evidence", counterfeitPath]);
  assert.equal(counterfeitResult.status, 1);
  assert.match(counterfeitResult.stderr, /pre-package lock remains CLOSED/);
  assert.match(
    counterfeitResult.stderr,
    /Repository has no Git HEAD|sourceCommit must equal the current Git HEAD/
  );

  const underCounted = structuredClone(counterfeit);
  underCounted.local.lwc.testsPassed = 18;
  underCounted.namespacedSource.testsPassed = 54;
  const underCountedPath = path.join(temporaryRoot, "under-counted.json");
  fs.writeFileSync(
    underCountedPath,
    `${JSON.stringify(underCounted, null, 2)}\n`
  );
  const underCountedResult = invoke(["--evidence", underCountedPath]);
  assert.equal(underCountedResult.status, 1);
  assert.match(underCountedResult.stderr, /At least 19 LWC tests must pass/);
  assert.match(
    underCountedResult.stderr,
    /Namespaced source: at least 55 Apex test methods must pass/
  );

  console.log("RHC Alerts pre-package lock integration tests passed.");
} finally {
  fs.rmSync(temporaryRoot, { recursive: true, force: true });
}
