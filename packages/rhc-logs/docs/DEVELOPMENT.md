# RHC Logs development, testing, and release

Work from packages/rhc-logs and run:

    npm ci
    npm run validate
    npm run validate:core-contract
    npm run validate:xml
    npm run test:unit:coverage

Run Salesforce Code Analyzer with the Recommended rules against force-app, using a timestamped JSON
output and the required bundled result parser. Dry-run deploy against an org containing only
Record Health Check 2.0.4.2, then run the four RHC Logs Apex test classes.

Validate CRUD, sharing, FLS, restricted personas, 251-event ingestion, duplicates, text bounding,
optional fields, identities, retention boundary/scope, overlap/retry, setup findings, schedule, and
Jest behavior. Create a 2GP version with code coverage only in the authorized Dev Hub. Record a 0Ho
as a container only. Install the generated 04t into a clean subscriber containing only core, perform
administrator acceptance, disable cleanup, and test uninstall/data loss.

## Evidence ledger

- Package container (0Ho): not created / not recorded.
- Subscriber package version (04t): not created / not validated.
- Apex test count and coverage: 29 source test methods across four classes; compilation, execution,
  and coverage remain pending in both org shapes because org creation and source upload were not
  authorized.
- Jest: 16 tests passed across 2 suites; 100% lines, statements, and functions, and 96.15% branches
  on 2026-08-30. The enforced thresholds match the core posture: 98% lines/statements/functions and
  75% branches.
- Package source validation: passed on 2026-08-30, covering metadata companions, API naming,
  cleanup DML budget, keyset pagination, ingestion retry evidence, permission boundaries, dependency
  pinning, and local documentation links.
- Minimum-core contract: passed locally against core commit
  `74fe1d6022f819397fc879c076f4f4dd2093cfab` (`74fe1d6`), confirming API 66.0,
  namespace `rhc`, the promoted 2.0.4.2 alias/04t, canonical Log event fields and behavior,
  default-off publication, and publisher permission.
- Code Analyzer: the final Recommended scan completed on 2026-08-30 with zero findings at every
  severity. An unsuppressed temporary-copy audit reproduced exactly the 30 reviewed findings
  documented in `CODE-ANALYZER-SUPPRESSIONS.md`. Evidence files are local and ignored by Git. CI
  now blocks any unsuppressed severity 1–5 finding.
- Production npm audit: 0 vulnerabilities.
- Metadata XML: all files passed local XML parsing; Salesforce source-to-Metadata-API conversion
  succeeded locally on 2026-08-30.
- Namespaced minimum-core source compile/tests: pending authorized org work.
- No-namespace minimum-core source compile/tests: pending and explicitly **not verified**.
- Clean-subscriber install: pending.
- Administrator acceptance: pending.
- Safe uninstall: documented; execution pending.

The GitHub Actions package gate now runs the source validator, pinned minimum-core contract check,
XML parsing, core-level Jest coverage, npm audit, source conversion, and pinned Code Analyzer with
a retained JSON artifact. Apex compile,
test execution/coverage, Platform Event retry delivery, clean install, upgrade behavior, and
uninstall/data-loss checks remain explicitly org-backed release work.

Never invent evidence or call a container installable.

See the authoritative [release gate ledger](RELEASE-GATES.md) and reviewed
[Code Analyzer suppressions](CODE-ANALYZER-SUPPRESSIONS.md).
