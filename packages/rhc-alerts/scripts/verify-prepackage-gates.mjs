/* eslint-disable @lwc/lwc-platform/no-aura-libs, @lwc/lwc-platform/no-process-env -- Node CLI, not LWC runtime code. */
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { readCodeAnalyzerEvidence } from "./lib/code-analyzer-evidence.mjs";

const packageRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);
const suiteRoot = path.resolve(packageRoot, "../..");
const evidenceArgument = process.argv.indexOf("--evidence");
if (evidenceArgument >= 0 && !process.argv[evidenceArgument + 1]) {
  console.error("The --evidence option requires a path.");
  process.exit(2);
}
const evidencePath = path.resolve(
  packageRoot,
  evidenceArgument >= 0
    ? process.argv[evidenceArgument + 1]
    : ".release-evidence/prepackage.json"
);
const failures = [];

function check(condition, message) {
  if (!condition) failures.push(message);
}

function git(args) {
  return spawnSync("git", ["-C", suiteRoot, ...args], { encoding: "utf8" });
}

function insideSuite(filePath) {
  const relative = path.relative(suiteRoot, filePath);
  return (
    relative !== "" &&
    !relative.startsWith(`..${path.sep}`) &&
    !path.isAbsolute(relative)
  );
}

function ignoredByGit(filePath) {
  return git(["check-ignore", "--quiet", "--no-index", filePath]).status === 0;
}

function passed(value) {
  return value === "PASSED";
}

function validTimestamp(value) {
  return typeof value === "string" && !Number.isNaN(Date.parse(value));
}

function verifyOrgShape(label, expectedShape, evidence, sourceCommit) {
  check(passed(evidence?.status), `${label}: status must be PASSED`);
  check(
    evidence?.orgShape === expectedShape,
    `${label}: orgShape must be ${expectedShape}`
  );
  check(
    /^[0-9a-f]{40}$/.test(evidence?.sourceCommit ?? ""),
    `${label}: sourceCommit must be a full 40-character Git SHA`
  );
  check(
    evidence?.sourceCommit === sourceCommit,
    `${label}: sourceCommit must match the release commit`
  );
  check(
    validTimestamp(evidence?.completedAt),
    `${label}: completedAt must be an ISO timestamp`
  );
  check(
    /^https:\/\//.test(evidence?.evidenceUrl ?? ""),
    `${label}: evidenceUrl must be an HTTPS evidence URL`
  );
  check(
    /^00D[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$/.test(evidence?.orgId ?? ""),
    `${label}: orgId is missing or invalid`
  );
  check(
    /^0Af[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$/.test(evidence?.dryRunJobId ?? ""),
    `${label}: dryRunJobId is missing or invalid`
  );
  check(
    /^707[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$/.test(
      evidence?.apexTestRunId ?? ""
    ),
    `${label}: apexTestRunId is missing or invalid`
  );
  check(
    evidence?.testsPassed >= 55,
    `${label}: at least 55 Apex test methods must pass`
  );
  check(evidence?.testsFailed === 0, `${label}: Apex failures must be zero`);
  check(
    evidence?.packageCoverage >= 75,
    `${label}: package Apex coverage must be at least 75%`
  );
  check(
    evidence?.resultTriggerCoverage > 0,
    `${label}: Result trigger must have coverage`
  );
  check(
    evidence?.setRunTriggerCoverage > 0,
    `${label}: Set Run trigger must have coverage`
  );
  check(
    evidence?.platformEventAcceptance === true,
    `${label}: Platform Event acceptance is incomplete`
  );
  check(
    evidence?.permissionAcceptance === true,
    `${label}: permission/runtime acceptance is incomplete`
  );
}

check(fs.existsSync(evidencePath), `Evidence file not found: ${evidencePath}`);
if (insideSuite(evidencePath)) {
  check(
    ignoredByGit(evidencePath),
    "A populated evidence ledger inside the repository must be ignored by Git"
  );
}
let evidence = {};
if (fs.existsSync(evidencePath)) {
  try {
    evidence = JSON.parse(fs.readFileSync(evidencePath, "utf8"));
  } catch (error) {
    failures.push(`Evidence file is not valid JSON: ${error.message}`);
  }
}

check(evidence.schemaVersion === 1, "schemaVersion must be 1");
check(evidence.packageName === "RHC Alerts", "packageName must be RHC Alerts");

const headResult = git(["rev-parse", "--verify", "HEAD"]);
const head = headResult.status === 0 ? headResult.stdout.trim() : null;
check(
  head !== null,
  "Repository has no Git HEAD; an exact committed source is required"
);
check(
  /^[0-9a-f]{40}$/.test(evidence.sourceCommit ?? ""),
  "sourceCommit must be a full 40-character Git SHA"
);
if (head !== null) {
  check(
    evidence.sourceCommit === head,
    "sourceCommit must equal the current Git HEAD"
  );
  const statusResult = git(["status", "--porcelain", "--untracked-files=all"]);
  check(statusResult.status === 0, "Unable to inspect repository cleanliness");
  check(
    statusResult.stdout.trim() === "",
    "Release worktree must be clean, including untracked files"
  );
}

const local = evidence.local ?? {};
check(passed(local.status), "Local gate status must be PASSED");
check(
  validTimestamp(local.completedAt),
  "Local gate completedAt must be an ISO timestamp"
);
for (const [key, label] of Object.entries({
  repositoryContracts: "repository contracts",
  packageContracts: "package contracts",
  formatting: "package formatting",
  minimumCoreContract: "minimum-core contract",
  metadataXml: "metadata XML",
  sourceConversion: "source conversion"
})) {
  check(passed(local[key]), `Local ${label} must be PASSED`);
}
check(passed(local.lwc?.status), "LWC gate status must be PASSED");
check(local.lwc?.testsPassed >= 19, "At least 19 LWC tests must pass");
check(
  local.lwc?.statements >= 90,
  "LWC statement coverage must be at least 90%"
);
check(local.lwc?.branches >= 80, "LWC branch coverage must be at least 80%");
check(local.lwc?.functions >= 90, "LWC function coverage must be at least 90%");
check(local.lwc?.lines >= 90, "LWC line coverage must be at least 90%");
check(passed(local.slds?.status), "SLDS gate status must be PASSED");
check(local.slds?.violations === 0, "SLDS violations must be zero");
check(
  passed(local.codeAnalyzer?.status),
  "Code Analyzer gate status must be PASSED"
);
check(
  local.codeAnalyzer?.findings === 0,
  "Recommended Code Analyzer findings must be zero"
);
check(
  typeof local.codeAnalyzer?.resultFile === "string" &&
    local.codeAnalyzer.resultFile.endsWith(".json"),
  "Code Analyzer resultFile must identify retained JSON evidence"
);
check(
  /^[0-9a-f]{64}$/.test(local.codeAnalyzer?.resultSha256 ?? ""),
  "Code Analyzer resultSha256 must be a lowercase SHA-256 digest"
);
if (typeof local.codeAnalyzer?.resultFile === "string") {
  const analyzerPath = path.isAbsolute(local.codeAnalyzer.resultFile)
    ? local.codeAnalyzer.resultFile
    : path.resolve(path.dirname(evidencePath), local.codeAnalyzer.resultFile);
  check(
    fs.existsSync(analyzerPath),
    `Code Analyzer evidence file not found: ${analyzerPath}`
  );
  if (insideSuite(analyzerPath)) {
    check(
      ignoredByGit(analyzerPath),
      "Code Analyzer evidence inside the repository must be ignored by Git"
    );
  }
  if (fs.existsSync(analyzerPath)) {
    try {
      const analyzerEvidence = readCodeAnalyzerEvidence(analyzerPath);
      check(
        analyzerEvidence.findings.length === 0,
        "Retained Code Analyzer evidence must contain zero findings"
      );
      check(
        analyzerEvidence.sha256 === local.codeAnalyzer.resultSha256,
        "Code Analyzer evidence SHA-256 does not match resultSha256"
      );
    } catch (error) {
      failures.push(`Code Analyzer evidence is invalid: ${error.message}`);
    }
  }
}
check(
  passed(local.dependencyAudit?.status),
  "Dependency audit status must be PASSED"
);
check(
  local.dependencyAudit?.highVulnerabilities === 0,
  "High dependency vulnerabilities must be zero"
);

check(passed(evidence.ci?.status), "Exact-commit CI status must be PASSED");
check(
  evidence.ci?.commit === evidence.sourceCommit,
  "CI commit must match sourceCommit"
);
check(
  /^https:\/\//.test(evidence.ci?.runUrl ?? ""),
  "CI runUrl must be an HTTPS evidence URL"
);

verifyOrgShape(
  "Namespaced source",
  "NAMESPACED",
  evidence.namespacedSource,
  evidence.sourceCommit
);
verifyOrgShape(
  "No-namespace source",
  "NO_NAMESPACE",
  evidence.noNamespaceSource,
  evidence.sourceCommit
);
if (evidence.namespacedSource?.orgId && evidence.noNamespaceSource?.orgId) {
  check(
    evidence.namespacedSource.orgId !== evidence.noNamespaceSource.orgId,
    "Namespaced and no-namespace evidence must come from different orgs"
  );
}

if (failures.length > 0) {
  console.error(
    `RHC Alerts pre-package lock remains CLOSED (${failures.length} unmet gate(s)):`
  );
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(
  `RHC Alerts pre-package lock is OPEN for exact commit ${evidence.sourceCommit}.`
);
console.log(
  "This authorizes consideration of candidate creation only; it does not create a package version."
);
