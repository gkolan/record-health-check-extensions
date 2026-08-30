import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { readCodeAnalyzerEvidence } from "./lib/code-analyzer-evidence.mjs";
import { readJestEvidence } from "./lib/jest-evidence.mjs";

const packageRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);
const suiteRoot = path.resolve(packageRoot, "../..");
const temporaryRoot = fs.mkdtempSync(
  path.join(os.tmpdir(), "rhc-alerts-preflight-")
);
const convertedSource = path.join(temporaryRoot, "mdapi");
const evidenceArgument = process.argv.indexOf("--evidence-dir");
if (evidenceArgument >= 0 && !process.argv[evidenceArgument + 1]) {
  console.error("The --evidence-dir option requires a path.");
  process.exit(2);
}
const retainedEvidenceDirectory =
  evidenceArgument >= 0
    ? path.resolve(packageRoot, process.argv[evidenceArgument + 1])
    : null;
if (retainedEvidenceDirectory) {
  fs.mkdirSync(retainedEvidenceDirectory, { recursive: true });
}
const analyzerEvidence = path.join(
  retainedEvidenceDirectory ?? temporaryRoot,
  "code-analyzer.json"
);
const jestEvidence = path.join(
  retainedEvidenceDirectory ?? temporaryRoot,
  "jest-results.json"
);
const salesforceEnvironment = {
  ...process.env,
  SF_DISABLE_LOG_FILE: "true"
};

function run(
  label,
  command,
  args,
  cwd = packageRoot,
  environment = process.env
) {
  console.log(`\n=== RHC Alerts local preflight: ${label} ===`);
  const result = spawnSync(command, args, {
    cwd,
    env: environment,
    encoding: "utf8",
    stdio: "inherit"
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${label} failed with exit code ${result.status}`);
  }
}

function git(args) {
  return spawnSync("git", ["-C", suiteRoot, ...args], { encoding: "utf8" });
}

try {
  run(
    "repository contracts",
    "node",
    ["scripts/validate-repository.mjs"],
    suiteRoot
  );
  for (const gate of [
    "generate:check",
    "format:check",
    "validate",
    "validate:core-contract",
    "validate:xml",
    "validate:slds"
  ]) {
    run(gate, "npm", ["run", gate]);
  }
  run("test:coverage", "npm", [
    "run",
    "test:coverage",
    "--",
    "--json",
    `--outputFile=${jestEvidence}`
  ]);
  run("dependency audit", "npm", ["audit", "--audit-level=high"]);
  run(
    "Metadata API source conversion",
    "sf",
    [
      "project",
      "convert",
      "source",
      "--root-dir",
      "force-app",
      "--output-dir",
      convertedSource
    ],
    packageRoot,
    salesforceEnvironment
  );
  run(
    "Recommended Code Analyzer",
    "sf",
    [
      "code-analyzer",
      "run",
      "--rule-selector",
      "Recommended",
      "--target",
      "force-app/main/default",
      "--severity-threshold",
      "5",
      "--output-file",
      analyzerEvidence
    ],
    packageRoot,
    salesforceEnvironment
  );

  const analyzerResult = readCodeAnalyzerEvidence(analyzerEvidence);
  const { findings } = analyzerResult;
  if (findings.length !== 0) {
    throw new Error(
      `Recommended Code Analyzer returned ${findings.length} finding(s)`
    );
  }
  const jestResult = readJestEvidence(jestEvidence);
  const headResult = git(["rev-parse", "--verify", "HEAD"]);
  const statusResult = git(["status", "--porcelain", "--untracked-files=all"]);
  const localSummary = {
    schemaVersion: 1,
    packageName: "RHC Alerts",
    sourceCommit: headResult.status === 0 ? headResult.stdout.trim() : null,
    worktreeClean:
      statusResult.status === 0 && statusResult.stdout.trim().length === 0,
    completedAt: new Date().toISOString(),
    local: {
      status: "PASSED",
      repositoryContracts: "PASSED",
      packageContracts: "PASSED",
      formatting: "PASSED",
      minimumCoreContract: "PASSED",
      metadataXml: "PASSED",
      sourceConversion: "PASSED",
      lwc: {
        status: "PASSED",
        testsPassed: jestResult.testsPassed,
        ...jestResult.coverage
      },
      slds: { status: "PASSED", violations: 0 },
      codeAnalyzer: {
        status: "PASSED",
        findings: analyzerResult.findings.length,
        resultFile: "code-analyzer.json",
        resultSha256: analyzerResult.sha256
      },
      dependencyAudit: { status: "PASSED", highVulnerabilities: 0 }
    }
  };
  if (retainedEvidenceDirectory) {
    fs.writeFileSync(
      path.join(retainedEvidenceDirectory, "local-summary.json"),
      `${JSON.stringify(localSummary, null, 2)}\n`
    );
  }

  console.log(
    "\nRHC Alerts local preflight passed with zero Code Analyzer findings."
  );
  console.log(
    "Git, exact-commit CI, Salesforce org, and package-candidate gates remain separate."
  );
  if (retainedEvidenceDirectory) {
    console.log(`Raw local evidence retained in ${retainedEvidenceDirectory}.`);
  }
} finally {
  fs.rmSync(temporaryRoot, { recursive: true, force: true });
}
