# RHC Builder specification

## Why this project exists

Core Record Health Check configuration is stored in `Record_Health_Check_Set__mdt` and
`Record_Health_Check__mdt`. Setup exposes those records as individual technical forms. That is
workable for an expert, but a junior administrator can easily choose incompatible fields, mistype a
Qualified API Name, publish only part of a Check Set, or activate invalid configuration.

RHC Builder provides one guided, no-code authoring experience for a complete Check Set and its
Checks. It validates, versions, reviews, and publishes configuration; it never evaluates business
records.

## User value

A junior administrator can:

- choose a target Salesforce object through describe-backed selection;
- create Checks using the exact core terminology and allowed values;
- see conditional guidance for Formula, Query, Compare Two Queries, and Apex Checks;
- validate before publication and receive screen-addressable errors;
- save one immutable version of the complete Check Set and all Checks;
- review the exact metadata that will change;
- publish deliberately; and
- roll back by republishing a previously validated Check Set Version.

## Dependency on core

RHC Builder depends only on the pinned Record Health Check package. Core remains the authority for:

- the Check Set and Check Custom Metadata schemas;
- runtime interpretation of published configuration.

Builder owns the choices shown by its screen, its complete-version validation, and its publication
plan. Its draft fields map one-to-one to an allow-listed inventory of core fields. Each Builder
release pins and tests one compatible core version so changes cannot silently drift. Core works
normally when Builder is absent and contains no Builder-specific API.

## Owned data and behavior

| Object                                  | Responsibility                                                |
| --------------------------------------- | ------------------------------------------------------------- |
| `Record_Health_Check_Set_Draft__c`      | Stable authoring identity and target object for one Check Set |
| `Record_Health_Check_Set_Version__c`    | Immutable snapshot of the entire Check Set                    |
| `Record_Health_Check_Draft__c`          | Ordered Check snapshot owned by one Check Set Version         |
| `Record_Health_Check_Set_Deployment__c` | Validation and publication ledger                             |

There is no Check Version. Editing any Check contributes to the next complete Check Set Version.
Fingerprinting, validation, publication, activation, and rollback apply to the complete version.

## Example

Maya, a junior administrator, needs an Account Readiness Check Set.

1. She selects `Account` and names the Check Set **Account Readiness**.
2. She creates **Account Name Is Present** as a Formula Check.
3. She creates **Account Has a Primary Contact** through the guided Query form.
4. Builder validates the complete version and points to one invalid query field.
5. Maya corrects it, saves **Check Set Version 1**, and reviews the generated metadata.
6. She publishes Version 1 inactive, completes a sandbox test, and activates it.
7. A later edit creates Version 2 containing the Set and all Checks. No Check receives its own
   version number.
8. If Version 2 is unsuitable, Maya republishes the already validated Version 1.

Without Builder, Maya would manage multiple related Custom Metadata records manually and would need
to understand which fields apply to each evaluation type.

## Constraints it cannot escape

- Salesforce metadata deployment is asynchronous and can fail after a request is accepted.
- Builder can publish only configuration the running user is authorized to manage.
- Package-owned protected metadata cannot be treated like subscriber-owned configuration.
- Qualified API Names are exact and namespace-sensitive; Builder cannot safely guess or rewrite them.
- Salesforce object and field availability varies by org, installed packages, features, and user access.
- Apex Checks still require a developer-owned class and tests; Builder can configure but cannot
  manufacture safe custom Apex logic.
- A rollback is another metadata deployment, not a transactional database rollback.
- Builder cannot guarantee that a configuration is correct for the business. It checks the supported
  authoring structure and values; representative runtime behavior still needs sandbox testing.

## Boundaries

Builder does not schedule or run Checks, store runtime results, generate reports, send alerts,
execute corrective Flows, or call external systems. It never reads another extension's objects.

## Guided-authoring experience contract

The former core guided-authoring prototype has been reconciled into this package. Builder owns the
only exposed authoring LWC and the complete workflow around it. Core must not ship a parallel Builder
screen, draft schema, deployment ledger, or Builder-specific Apex API.

The supported experience must:

- guide one business decision at a time and use Check Set and Check terminology consistently;
- use describe-backed object, field, and relationship choices instead of requiring API-name recall;
- preserve a complete Check Set Version, including ordered Checks and prerequisites, as one unit;
- validate locally before server validation, then display screen-addressable errors without exposing
  internal exceptions;
- make inactive publication, activation, and rollback separate deliberate operations;
- use idempotency keys and optimistic concurrency so retries and stale browser state cannot create or
  overwrite an unintended version;
- expose durable validation/publication status instead of describing queued Metadata API work as
  complete;
- hand unsupported or developer-owned configuration paths off honestly instead of presenting controls
  that cannot save their meaning; and
- remain keyboard operable, responsive at narrow widths and zoom, screen-reader understandable, and
  compatible with supported SLDS themes without styling base-component internals.

Presentation preview and validation are read-only. Testing a draft against business records is a
separately authorized product decision and is not implied by the authoring workflow.

## Acceptance criteria

1. It installs with core and without another extension.
2. Every draft field maps to a documented core field or is authoring-only ledger data.
3. It supports subscriber-owned and namespaced Qualified API Names without prefix manipulation.
4. A Check cannot be versioned or published independently of its Check Set Version.
5. Validation and publication retries are idempotent.
6. Removing Builder leaves already published core metadata and core runtime behavior intact.
7. Core contains no Builder UI, persistence object, deployment ledger, permission, tab, or
   Builder-specific API.
8. Save, publish, activation, and rollback show truthful durable operation state and recover after an
   uncertain client response without duplicating work.
9. A stale source fingerprint cannot overwrite a newer complete version.
10. Unsupported authoring branches preserve no hidden stale fields and provide an explicit handoff.
11. Keyboard, focus, announcement, narrow-width, zoom, forced-colors, and SLDS checks pass for the
    exposed LWC.

