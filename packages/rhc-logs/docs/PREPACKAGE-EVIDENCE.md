# RHC Logs pre-package evidence format

`npm run release:check-candidate-unlock` is the machine-enforced package-creation lock. It computes a
SHA-256 digest over package source, configuration, scripts, dependency locks, specification, and the
suite validation workflow. It then requires a clean committed baseline plus three evidence files
under `release-evidence/prepackage` with that exact digest.

Do not create these files by assertion. Populate them only from retained Salesforce CLI and GitHub
Actions results. The checker does not create an org, deploy source, run tests, or create a package.

## Salesforce source-shape evidence

Create `namespaced.json` and `no-namespace.json` with this structure after the corresponding org run:

```json
{
  "schemaVersion": 1,
  "sourceDigest": "sha256:CURRENT_DIGEST",
  "coreCommit": "74fe1d6022f819397fc879c076f4f4dd2093cfab",
  "shape": "namespaced",
  "deploy": { "status": "Succeeded", "jobId": "0Af..." },
  "tests": {
    "outcome": "Passed",
    "methods": 29,
    "coveragePercent": 95.0,
    "runId": "707..."
  },
  "scenarios": {
    "platformEventBulk": true,
    "duplicateIdempotency": true,
    "malformedEvent": true,
    "unsupportedContract": true,
    "restrictedPersonas": true,
    "scheduleLifecycle": true,
    "cleanupBoundary": true,
    "cleanupOverlap": true
  }
}
```

Use `"shape": "no-namespace"` in `no-namespace.json`. Coverage must be at least 95%, all 29 or
more Apex tests must pass, and the deploy/test IDs must be retained from Salesforce CLI JSON.

## Exact CI evidence

Create `ci.json` only after the suite **Validate** workflow succeeds:

```json
{
  "schemaVersion": 1,
  "sourceDigest": "sha256:CURRENT_DIGEST",
  "workflow": "Validate",
  "conclusion": "success",
  "commit": "FULL_40_CHARACTER_GIT_SHA",
  "runUrl": "https://github.com/OWNER/REPOSITORY/actions/runs/RUN_ID"
}
```

The evidence files are inputs to review, not substitutes for the retained CLI output, test report,
coverage details, or GitHub Actions logs.

