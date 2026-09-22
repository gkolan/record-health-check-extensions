# Record Health Check Extensions — agent instructions

Monorepo of independent Salesforce 2GP packages under `packages/rhc-*`. Each has its own
`sfdx-project.json`, `package.json`, `force-app/`, and docs. Namespace `rhc`, API v66.0.
Every package depends on the `Record Health Check` core package, never on sibling extensions.

## Rules

- Keep a change inside the package that owns it. Suite-wide contracts and docs live at the root.
- Use `sf`, never `sfdx`. Never commit org auth, install keys, `.env`, `node_modules`, coverage,
  or package-version artifacts.
- When behavior or install steps change, update that package's README, ADMIN_GUIDE, and
  security/operations docs in the same change.

## Verification

Root: `node scripts/validate-repository.mjs`

Per changed package (`cd packages/<pkg>`):

```bash
npm ci && npm test && npm run test:coverage && npm audit --audit-level=high
npm run validate   # source validation, where present
```

Apex tests run in a namespaced scratch org. See `CONTRIBUTING.md` and `docs/RELEASING.md`.

## Skills

The `forcedotcom/sf-skills` set is installed globally; these are the ones this repo relies on.
Invoke the matching skill before doing the work, not after.

| Task | Skill |
| --- | --- |
| Apex classes, triggers, review | `platform-apex-generate` |
| Apex test classes / running tests | `platform-apex-test-generate`, `platform-apex-test-run` |
| SOQL authoring or tuning | `platform-soql-query` |
| Any `*-meta.xml` (objects, fields, CMDT, perm sets, flows) | `platform-metadata-api-context-get` **plus** the type-specific generator (`platform-custom-object-generate`, `platform-custom-field-generate`, `platform-custom-metadata-type-generate`, `platform-permission-set-generate`, `automation-flow-generate`) |
| LWC components and Jest | `experience-lwc-generate`, `experience-lwc-security-validate` |
| Platform Events, CDC, Named Credentials | `integration-connectivity-generate`, `integration-eventing-cdc-configure` |
| Deploy / retrieve / validate against an org | `platform-metadata-deploy`, `platform-metadata-retrieve`, `platform-deploy-validate` |
| Scratch orgs and org switching | `dx-org-manage`, `dx-org-switch` |
| Static analysis before a PR | `dx-code-analyzer-run` |
| Well-Architected review of a package | `platform-architecture-analyze` |

## After finishing any task

Run the `ponytail-review` skill (`/ponytail-review`) on the diff before reporting done, and apply
its deletions. Ponytail mode is on for the whole session: shortest working diff, reuse over
reinvention, no speculative abstractions.
