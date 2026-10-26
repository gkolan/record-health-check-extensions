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
Also run source-contract validation against promoted 2.0.11.4:

    npm run validate:core-contract -- --core-ref 5905f999dfee391bd4ff029611023f157e60e8ee

Subscriber-source runtime validation against installed core 2.0.11.4 passed 34/34 tests at 95.15%
coverage. Use the temporary namespace adaptation described in [Runtime verification](RUNTIME-VERIFICATION.md);
unchanged package source is not portable into a namespace-null subscriber. Artifact install
acceptance is a separate pending check.

Validate CRUD, sharing, FLS, restricted personas, 251-event ingestion, duplicates, text bounding,
optional fields, identities, retention boundary/scope, overlap/retry, setup findings, schedule, and
Jest behavior. Create a 2GP version with code coverage only in the authorized Dev Hub. Record a 0Ho
as a container only. Install the generated 04t into a clean subscriber containing only core, perform
administrator acceptance, disable cleanup, and test uninstall/data loss.

## Evidence ledger

- Package container (0Ho): not created / not recorded.
- Subscriber package version (04t): not created / not validated.
- Apex test count and coverage: 34 source test methods across four classes. Subscriber-source
  validation against core 2.0.11.4 passed 34/34 tests and 471/495 lines (95.15%) on 2026-10-13,
  job `0AfcU00000B5e6XSAR`. Namespaced and minimum-core current-source gates remain pending.
  Historical no-namespace evidence passed 32 methods on 2026-08-30.
- Jest: 25 tests passed across 2 suites; 100% lines, statements, and functions, and 93.47% branches
  on 2026-10-13. The enforced thresholds match the core posture: 98% lines/statements/functions and
  75% branches.
- Package source validation: passed on 2026-10-13, covering metadata companions, API naming,
  cleanup DML budget, keyset pagination, ingestion retry evidence, permission boundaries, dependency
  pinning, and local documentation links.
- Minimum-core contract: passed locally against core commit
  `74fe1d6022f819397fc879c076f4f4dd2093cfab` (`74fe1d6`), confirming API 66.0,
  namespace `rhc`, the promoted 2.0.4.2 alias/04t, canonical Log event fields and behavior,
  default-off publication, and publisher permission.
- Code Analyzer: the final Recommended scan completed on 2026-10-13 with zero findings at every
  severity. An unsuppressed temporary-copy audit contract records exactly the 31 reviewed findings
  documented in `CODE-ANALYZER-SUPPRESSIONS.md`. Evidence files are local and ignored by Git. CI
  now blocks any unsuppressed severity 1–5 finding.
- Dependency audit, 2026-10-13: the full audit reports 0 vulnerabilities, including development
  dependencies. Nonbreaking updates cover brace-expansion, postcss-selector-parser, and source-map-js.
  Two exact overrides resolve the remaining root findings: braces uses the source-reviewed
  `@dieub/braces-depth-guard@3.0.3-pn.3` derivative, and the NYC config loader uses js-yaml 4.3.2,
  removing sprintf-js. The Salesforce Jest adapter remains unchanged. Registry signatures verify
  for all 524 installed packages, with 129 verified attestations. Four dependency-security tests
  run with `npm test` and coverage, checking normal glob behavior, string/AST depth rejection, and
  YAML config compatibility. See [Security](SECURITY.md#development-dependencies).
- Metadata XML: all files passed local XML parsing; Salesforce source-to-Metadata-API conversion
  succeeded locally on 2026-10-13.
- Namespaced minimum-core source compile/tests: pending authorized org work.
- No-namespace minimum-core source compile/tests: pending for current source; historical evidence
  is recorded in `release-evidence/prepackage/no-namespace.json` and the release gate ledger.
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
