import crypto from "node:crypto";
import fs from "node:fs";

export function readCodeAnalyzerEvidence(filePath) {
  const bytes = fs.readFileSync(filePath);
  const report = JSON.parse(bytes.toString("utf8"));
  let findings;

  if (Array.isArray(report.violations)) {
    findings = report.violations;
    if (
      typeof report.violationCounts?.total === "number" &&
      report.violationCounts.total !== findings.length
    ) {
      throw new Error(
        "Code Analyzer total does not match the violations array"
      );
    }
  } else if (Array.isArray(report.runs)) {
    findings = report.runs.flatMap((runResult) => runResult.results ?? []);
  } else {
    throw new Error("Unrecognized Code Analyzer JSON schema");
  }

  return {
    findings,
    sha256: crypto.createHash("sha256").update(bytes).digest("hex")
  };
}
