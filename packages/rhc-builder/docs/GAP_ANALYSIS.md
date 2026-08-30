# RHC Builder boundary review

## Decision

RHC Builder owns every guided-authoring concern. Core remains the runtime package and has no Builder
class, object, permission, tab, screen, documentation, or Builder-specific API.

## Ownership

| Area                                                              | Owner       |
| ----------------------------------------------------------------- | ----------- |
| Runtime Custom Metadata and record evaluation                     | Core        |
| Builder screen and administrator guidance                         | RHC Builder |
| Drafts, complete saved versions, and Check copies                 | RHC Builder |
| Authoring choices and complete-version validation                 | RHC Builder |
| Metadata publication, activation, rollback, and operation history | RHC Builder |

## Builder contract

`RecordHealthCheckBuilderContract` now ships in this package. The Builder controller calls it
directly; it is not resolved from core.

The contract:

1. Returns the authoring choices, defaults, field lists, and Check limit supported by this Builder
   release.
2. Validates one complete Check Set Version, including exact field names, required answers, supported
   evaluation types, severity, Check Set references, unique names, and evaluation order.
3. Produces a publication plan containing only the pinned core Custom Metadata types and allow-listed
   fields.
4. Uses Salesforce describe information to preserve the installed namespace on metadata type and
   field API names.
5. Makes inactive publication, activation, and rollback deliberate whole-version operations.

## Release responsibility

Builder depends on a pinned core package because it publishes that package's Custom Metadata. Every
Builder release must be tested against that exact core version. When core adds or changes a metadata
field or runtime choice, Builder must update its field inventory, contract version, validation,
documentation, and compatibility tests before supporting the new core version.

This is an intentional release dependency, not a Builder dependency inside core.

## Guided-authoring extraction reconciliation

The former core `guided-authoring` design folder was reconciled on 2026-08-30. Its durable decisions
now live in this package's `SPEC.md`, administrator guidance, field mapping, implementation, Apex
tests, and Jest suites. The historical implementation-evidence file referred to an earlier core
prototype and is not release evidence for the current extension source.

The reconciliation retained the one-decision workflow, complete-version semantics, inactive-first
publication, idempotent retries, optimistic concurrency, honest unsupported-path handoff, and
accessibility/responsive requirements. Activation and rollback are now implemented as deliberate
whole-version operations. A production-equivalent Check Tester remains outside Builder's implied
scope and requires its own authorization contract if adopted.
