# Screen guidance and card-style decision guide

This document is the proposed content and interaction specification for RHC Builder. It describes
what each screen should say, where just-in-time guidance should appear, and how administrators
should choose the Record Health Check card behavior that best fits their users.

> Current-source status: Builder implements the three-screen path, guided Check creation,
> validation, saving, publication, and monitoring. The Design screen now includes the five
> contract-backed card-experience choices, Custom behavior controls, dependent warnings, and the
> generated selection explanation on Design and Review. It also includes the interactive
> before-run, running, and completed example preview; field-level decision guidance; readable
> complete-version review; stale-validation invalidation; and publication/operation guidance
> described below.

## Design principles

1. Ask in business language and show the metadata value only in secondary text.
2. Explain the user-visible consequence before asking for a choice.
3. Preselect the safest broadly useful choice and say why it is recommended.
4. Keep advanced controls available without making a first-time administrator understand every
   field.
5. Never describe a display setting as changing evaluation order or results when it changes only
   presentation.
6. Repeat consequential choices on the review screen before an immutable version is saved.

## Screen map

| Screen or state | User's question | Primary outcome |
| --- | --- | --- |
| Access/loading/error | Can I use Builder, and what should I do if it cannot start? | A clear next action rather than a dead end |
| 1. Design — purpose and card behavior | What is this Check Set for, and how should users experience it? | A target object, meaningful card text, and an intentional card style |
| 1. Design — Checks | What must be true for this record to be healthy? | One or more understandable, actionable Checks |
| 2. Validate and save | Is the complete version technically valid and is it the design I intended? | A reviewed, immutable Check Set Version |
| 3. Publish and monitor | How do I release this safely and know when Salesforce is finished? | Inactive publication, deliberate activation, and observable operations |

## Global states

### Loading

- Spinner alternative text: **Loading RHC Builder**.
- Supporting text after a noticeable delay: **Loading Builder permissions, supported fields, and
  saved versions. Nothing is being changed in Salesforce.**
- Do not display empty form controls while the contract is unavailable.

### Missing author access

- Heading: **Builder authoring access is required**.
- Body: **Ask a Salesforce administrator to assign the Record Health Check Builder Admin
  permission set, then reload this page.**
- Tip: **This access allows Check Set authoring and publication. It does not grant access to records
  the user could not otherwise read.**

### Core incompatibility or startup error

- Heading: **Builder could not start**.
- Body: show the safe user message returned by Builder.
- Next action: **Copy the diagnostic code and contact your Salesforce administrator. No draft was
  saved or published.**
- Offer **Try again** only for a retryable error. Do not imply that retrying repairs an incompatible
  core installation.

## Screen 1A: purpose and target

Heading: **Design the Check Set**

Introductory text: **Start with the business outcome. Builder keeps the Check Set and every Check
together as one version.**

| Control | Just-in-time tip | Decision consequence |
| --- | --- | --- |
| **Check Set name** | **Use a short business outcome, such as “Opportunity deal readiness.” This becomes the card title users see.** | A recognizable name helps users understand why the card is on the record page. |
| **Qualified API Name** | **Builder generates this stable identity from the name. Change it only when a release design requires an exact subscriber or namespaced identity. Do not add `__mdt`, `__c`, or a guessed namespace.** | References and future versions depend on this exact identity; Builder does not rewrite it. |
| **Target Salesforce object** | **Choose the object whose record page will contain the card. After the first Check is added, remove all Checks before changing this object.** | Guided fields, relationships, formulas, and queries are generated for this object. |
| **Short explanation** | **Tell record-page users when or why to run the checks. Keep it to one sentence. Example: “Review before submitting this Opportunity for approval.”** | This appears below the card title and should orient the end user, not document implementation details. |

Inline callout after object selection:

> **Design for the people using the record page.** Choose automatic checks only when the result is
> useful on most page visits and the expected evaluation cost is acceptable. Otherwise let the user
> decide when to run.

## Screen 1B: choose the card experience

Section heading: **How should the health-check card work?**

Section introduction: **Choose the experience that best matches the record-page task. These options
change when results run and how they are presented; they do not change what a Check evaluates or
whether it passes.**

Use a single-select card group. Each card must be a real radio option with the entire visible card as
its label. Do not implement selection as an unlabelled clickable `div`.

### Selection card 1: User-controlled review — Recommended

**Best for:** approval readiness, handoffs, occasional quality reviews, or expensive checks.

**What users experience:** The card waits. The user selects a clearly labelled **Run Checks** action,
then all result rows update in place. Passed and skipped rows remain visible, comparison detail is
available when needed, and the summary follows the result list.

**Why choose it:** It avoids work on every page visit, makes the run intentional, and gives users
enough detail to understand the result.

**Tradeoff:** Results are not current until someone selects Run.

| Metadata field | Value |
| --- | --- |
| `CardRunMode__c` | `RUN_ON_REQUEST` |
| `RunButtonDisplay__c` | `LABEL_AND_ICON` |
| `RunButtonLabel__c` | `Run Checks` |
| `RerunButtonLabel__c` | `Run Again` |
| `RunButtonIcon__c` | `utility:check` |
| `CardRevealMode__c` | `ALL_AT_ONCE` |
| `FoundExpectedDisplay__c` | `ON_DEMAND` |
| `PassedChecksDisplay__c` | `SHOW_EACH_CHECK` |
| `SkippedChecksDisplay__c` | `SHOW_EACH_CHECK` |
| `SummaryDisplay__c` | `BOTTOM` |

### Selection card 2: Automatic status

**Best for:** lightweight checks whose result is useful on nearly every record-page visit.

**What users experience:** Checks begin when the page opens. All rows appear as pending and fill in
as results arrive. A visible **Run Again** action remains after completion.

**Why choose it:** Users get a current status without remembering to start a run.

**Tradeoff:** Every page visit invokes evaluation. Review query, Apex, callout, and event behavior
before selecting this experience; automatic convenience can increase transaction and integration
load.

| Metadata field | Value |
| --- | --- |
| `CardRunMode__c` | `RUN_ON_LOAD` |
| `RunButtonDisplay__c` | `LABEL_AND_ICON` |
| `RunButtonLabel__c` | `Run Checks` |
| `RerunButtonLabel__c` | `Run Again` |
| `RunButtonIcon__c` | `utility:check` |
| `CardRevealMode__c` | `ALL_AT_ONCE` |
| `FoundExpectedDisplay__c` | `ON_DEMAND` |
| `PassedChecksDisplay__c` | `SHOW_EACH_CHECK` |
| `SkippedChecksDisplay__c` | `SHOW_EACH_CHECK` |
| `SummaryDisplay__c` | `BOTTOM` |

### Selection card 3: Guided walkthrough

**Best for:** training, complex readiness reviews, or a process where users benefit from seeing the
Checks resolve progressively.

**What users experience:** The user starts the run. Each Check appears when evaluation reaches it;
resolved rows remain visible. This affects reveal only, not evaluation order or outcome.

**Why choose it:** Progressive disclosure focuses attention on the Check currently being evaluated.

**Tradeoff:** It can feel slower for a routine Check Set, even when total execution time is the same.

| Metadata field | Value |
| --- | --- |
| `CardRunMode__c` | `RUN_ON_REQUEST` |
| `RunButtonDisplay__c` | `LABEL_AND_ICON` |
| `RunButtonLabel__c` | `Run Checks` |
| `RerunButtonLabel__c` | `Run Again` |
| `RunButtonIcon__c` | `utility:check` |
| `CardRevealMode__c` | `ONE_BY_ONE` |
| `FoundExpectedDisplay__c` | `ON_DEMAND` |
| `PassedChecksDisplay__c` | `SHOW_EACH_CHECK` |
| `SkippedChecksDisplay__c` | `SHOW_EACH_CHECK` |
| `SummaryDisplay__c` | `BOTTOM` |

### Selection card 4: Compact exception view

**Best for:** mature Check Sets with many rows where users mainly act on failures and want totals at
a glance.

**What users experience:** The user starts the run. Summary counts appear above the list. Individual
passed and skipped rows are hidden after resolution, while failures remain visible and their
Found/Expected values appear inline when available.

**Why choose it:** It reduces noise and brings exceptions to the foreground.

**Tradeoff:** Users cannot inspect individual passed or skipped rows on the card. Use it only after
the Check labels, failure messages, and remediation have been validated with end users.

| Metadata field | Value |
| --- | --- |
| `CardRunMode__c` | `RUN_ON_REQUEST` |
| `RunButtonDisplay__c` | `LABEL_AND_ICON` |
| `RunButtonLabel__c` | `Run Checks` |
| `RerunButtonLabel__c` | `Run Again` |
| `RunButtonIcon__c` | `utility:check` |
| `CardRevealMode__c` | `ALL_AT_ONCE` |
| `FoundExpectedDisplay__c` | `FAILURES_ONLY` |
| `PassedChecksDisplay__c` | `SHOW_COUNT_ONLY` |
| `SkippedChecksDisplay__c` | `SHOW_COUNT_ONLY` |
| `SummaryDisplay__c` | `TOP` |

### Selection card 5: Custom

**Best for:** administrators who can explain why the preset experiences do not fit.

**What users experience:** Determined by the individual controls below.

**Why choose it:** It exposes every supported card behavior without inventing a new runtime mode.

**Tradeoff:** The administrator owns the usability, accessibility, disclosure, and load implications
of the combination.

When **Custom** is selected, reveal these controls and help text:

| Control and choices | Just-in-time explanation |
| --- | --- |
| **When checks run:** When the page opens / When the user clicks Run | **Page open provides an immediate result but evaluates on every visit. User request avoids automatic work but requires a visible Run action.** |
| **Run action:** Label and icon / Label only / Icon only / Hide | **Label and icon is the most discoverable. Icon only remains accessible through its configured label. Hide is valid only for page-open runs and removes the in-card Rerun action.** |
| **Run label**, **Rerun label**, **Icon** | **Use short verbs that describe the action. The labels are still required as accessible names in icon-only mode. Use an SLDS icon name such as `utility:refresh`.** |
| **Reveal results:** All at once / One by one | **Presentation only. All at once lists pending rows and fills them in; one by one adds a row as evaluation reaches it. Checks, order, and outcomes do not change.** |
| **Found and expected values:** On demand / Failed checks only / Every check | **Show only information that every card user is allowed to see. A setting cannot show a value that a Check did not return.** |
| **Passed checks:** Show each check / Show count only | **Count only removes passed rows after resolution; the passed total remains in the summary.** |
| **Skipped checks:** Show each check / Show count only | **A skipped Check may not apply or may have an unmet prerequisite. Count only hides the reason row while keeping the total.** |
| **Summary position:** Above checks / Below checks | **Above supports at-a-glance status; below lets users read the evidence before the totals. Categories, when configured, use the same position.** |

Blocking validation message for an invalid combination:

> **Keep a Run action visible.** This Check Set waits for the user, so **Run action** cannot be
> **Hide**. Show a label or icon, or change **When checks run** to **When the page opens**.

Advisory warning for an automatic hidden action:

> **Users cannot rerun from this card.** Checks will run when the page opens, but hiding the action
> removes the in-card Run and Rerun control. Page refreshes also do not count as deliberate user-run
> events.

### Decision shortcut

Ask these questions in order:

1. **Should this evaluate on most page visits?** If no or uncertain, choose **User-controlled
   review**. If yes and evaluation is proven lightweight, choose **Automatic status**.
2. **Does the user need to focus on one result at a time?** If yes, choose **Guided walkthrough**.
3. **Are there enough Checks that passing rows obscure the work?** If yes, and the Check Set is
   already proven with users, choose **Compact exception view**.
4. **Does a preset miss a documented requirement?** Choose **Custom** and record the reason in the
   release ticket.

### Preview and selection explanation

Beside or immediately below the selector, show a non-interactive preview with these states:

- before run for a user-controlled style;
- running, including pending or progressive rows;
- completed with one pass, one fail, and one skipped result;
- Found/Expected disclosure and summary in the chosen positions.

The preview must be labelled **Preview — example results** and must never resemble a real execution.
Below it, show a generated explanation:

> **Your selection:** Users start this Check Set themselves. All result rows appear together, passed
> and skipped Checks remain visible, and the summary appears below the evidence. Found and expected
> values are available on demand and appear inline on failures.

Update this explanation immediately when any Custom setting changes. It is also repeated on Screen
2 so the administrator reviews the effect before saving.

## Screen 1C: define the Checks

Section heading: **What must be true for this record to be healthy?**

Section introduction: **Write each Check as a true statement. If the statement is false, tell the
user what happened and what to do next.**

### Check card header

- Title: **Check 1**, **Check 2**, and so on.
- Remove action accessible name: **Remove Check 1: Account name is present** when a label is
  available; otherwise **Remove Check 1**.
- Tip near the first Add action: **Start with one requirement that a record-page user can understand
  and act on. Add separate Checks when failures have different owners or remedies.**

### Common Check fields

| Control | Just-in-time tip |
| --- | --- |
| **What should be true?** | **Write a positive, testable statement such as “Account has a primary Contact.” Users see this text in the result row.** |
| **Qualified API Name** | **This stable identity is generated from the statement. Change it only for an approved integration or migration requirement.** |
| **Evaluation type** | **Choose how Builder will prove the statement. The choices below explain when each type fits.** |
| **Failure severity** | **Use Error when work must stop or data is unsafe, Warning when action is important but work can continue, and Info for helpful improvement. Follow your organization's severity policy.** |
| **Failure message** | **State what is wrong in plain language. Do not repeat technical Formula or query text.** |
| **How to fix it** | **Give a concrete next step and name the field, related record, or team that can resolve it. Do not promise that every user has edit access.** |

### Evaluation-type selection cards

| Choice | Select it when… | Important tip |
| --- | --- | --- |
| **Formula** (`FORMULA`) | The result depends on fields on the current record. | **Use guided Field + “has a value” or “is blank” for simple text-like fields. Advanced Formula is powerful and requires review for syntax, access, and null behavior.** |
| **Related records** (`QUERY`) | The result depends on whether matching child records exist or on a bounded aggregate/comparison. | **The guided path creates a one-row existence query. Advanced SOQL must remain bounded and use the current-record bind; verify object and field access.** |
| **Compare two queries** (`COMPARE_TWO_QUERIES`) | Two independently selected datasets or values must be compared. | **This is one Check with two datasets. Neither side is saved, versioned, or run independently. Review both query limits and comparison fields.** |
| **Apex plugin** (`APEX`) | Logic cannot be expressed safely by the declarative types and an approved core-compatible plugin already exists. | **Builder does not author Apex. Confirm the exact qualified class name, JSON parameter contract, sharing/security behavior, bulk behavior, and package compatibility with a developer.** |

Advanced panels should begin collapsed. Their summary text should include a risk cue:

- **Advanced Formula — reviewed syntax required**
- **Advanced query settings — bounded SOQL required**

Changing evaluation type may preserve typed values in the browser, but only the selected type's
fields belong to the saved version. Show this inline message after a type change:

> **Only [selected type] settings will be saved.** Values entered for other evaluation types remain
> in this browser draft so you can switch back before saving.

## Screen 2: validate, explain, and save

Heading: **Validate and review the complete version**

Introductory text: **Validation covers the Check Set and every Check together. Saving creates one
immutable version; individual Checks cannot be saved or published separately.**

Present a readable review before the advanced JSON:

| Review block | Content |
| --- | --- |
| **Purpose** | Check Set name, target object, subtitle, exact Qualified API Name |
| **Card experience** | Selected preset or **Custom**, followed by the generated plain-language selection explanation |
| **Checks** | Ordered list with statement, evaluation type, severity, failure message, and remediation |
| **Release state** | **Saving does not publish or activate this version.** |

Just-in-time tips:

- Before **Validate complete version**: **This checks the complete metadata contract and current-org
  references. It does not prove that the business rule is correct or that every production user can
  see the same records.**
- Before **Save validated version**: **Saving records an immutable snapshot. To change it later,
  return to Design and save a new version.**
- On validation errors: **Use the bold path to find the Check or field, return to Design, correct it,
  and validate the complete version again.**
- Advanced JSON summary: **Advanced: exact complete-version metadata JSON — read-only**.

Disable **Save validated version** until the current draft fingerprint has passed validation. If the
draft changes after validation, clear the passed state and explain: **The design changed after the
last validation. Validate the complete version again.**

## Screen 3: publish and monitor

Heading: **Publish and monitor**

Introductory text: **Publication applies the complete saved Check Set Version to core metadata. Use
inactive publication first so you can verify the result before users depend on it.**

### Version actions

| Action | Just-in-time tip |
| --- | --- |
| **Review** | **Compare the fingerprint and complete snapshot with the approved release ticket. Validation proves structure, not business approval.** |
| **Publish inactive** | **Recommended first release step. It writes the complete version to core metadata with the Check Set inactive, so it cannot run from the record-page card yet.** |
| **Publish and activate** | **Makes this complete version available to record-page users after Salesforce finishes the operation. Use only after sandbox verification and approval.** |
| **Roll back** | **Republishes a previously saved complete version. It does not reconstruct or partially merge Checks. Confirm the target fingerprint and intended activation state.** |

Confirmation dialogs must name the Check Set, version number, target state, Check count, and exact
Qualified API Name. The primary action should state the consequence, for example **Publish Version
3 inactive**, rather than a generic **Confirm**.

### Operation monitoring

- Accepted message: **Salesforce accepted the operation. The version is not published until status
  is Succeeded.**
- Pending tip: **You can leave this screen and return. Select Refresh status to read Salesforce's
  latest operation state; do not submit the same release under a new operation key.**
- Succeeded tip: **Publication finished. Verify the card with known passing, failing, and skipped
  records before activation or release approval.**
- Failed tip: **Nothing should be assumed active. Open the operation detail, record the diagnostic
  information, correct the source design, and publish a newly validated version when appropriate.**

## Exact choice labels

The guided UI should translate stored values into these labels. Advanced JSON continues to show the
stored value.

| Field | Stored value | User-facing label |
| --- | --- | --- |
| When Checks Run | `RUN_ON_REQUEST` | When the user clicks Run |
| When Checks Run | `RUN_ON_LOAD` | When the page opens |
| Run Button Display | `LABEL_AND_ICON` | Label and icon |
| Run Button Display | `LABEL_ONLY` | Label only |
| Run Button Display | `ICON_ONLY` | Icon only |
| Run Button Display | `HIDE` | Hide |
| Reveal Mode | `ALL_AT_ONCE` | All at once |
| Reveal Mode | `ONE_BY_ONE` | One by one |
| Found/Expected Display | `ON_DEMAND` | On demand |
| Found/Expected Display | `FAILURES_ONLY` | Failed checks only |
| Found/Expected Display | `ALL_ROWS` | Every check |
| Passed Checks | `SHOW_EACH_CHECK` | Show each check |
| Passed Checks | `SHOW_COUNT_ONLY` | Show count only |
| Skipped Checks | `SHOW_EACH_CHECK` | Show each check |
| Skipped Checks | `SHOW_COUNT_ONLY` | Show count only |
| Summary Display | `TOP` | Above Checks |
| Summary Display | `BOTTOM` | Below Checks |

## Accessibility and interaction acceptance criteria

- Each preset is in one labelled radio group and exposes selected, focus, hover, disabled, error,
  and keyboard states.
- Arrow keys move among selection cards; Tab moves to the next control. Focus order follows visual
  order.
- The visible preset name, recommendation, outcome, and tradeoff are included in or associated with
  the radio option's accessible description.
- Help icons supplement visible consequence text; essential warnings are never help-icon-only.
- Color and icons never carry selection or result meaning alone.
- The preview is skipped as decorative or labelled as example content; it must not announce itself
  as a completed real run.
- At narrow widths, selection cards become one column without reordering their content.
- Choosing a preset writes every value in its mapping to the canonical draft.
- Switching from a preset to Custom preserves the preset's values as the starting point.
- Editing an individual value changes the selection to Custom and updates the explanation and
  preview immediately.
- Returning to a preset replaces all Custom card-display values only after a clear selection action.
- A user-request run with a hidden action is blocked both client-side and server-side.
- An automatic run with a hidden action receives the explicit no-rerun warning.
- Review repeats the final effective values and explanation; it does not rely on the administrator
  remembering the selection card.
- Jest tests cover preset mappings, Custom preservation, dependent validation, explanation text,
  keyboard behavior, and responsive rendering. Apex contract tests continue to cover allowed
  values and invalid combinations.

## Scope boundary

These choices configure supported core behavior. They do not choose arbitrary colors, fonts,
themes, card dimensions, evaluation concurrency, Check ordering, record access, or security. Those
are controlled by the core component, Check definitions, Salesforce permissions/sharing, and the
Lightning page. A future implementation must not imply otherwise.

## Source basis

This specification is aligned to:

- Builder's current three-screen LWC and Builder contract defaults;
- Builder's complete Check Set Version lifecycle and server-side validation;
- core's Custom Metadata field definitions and restricted values;
- core's runtime behavior for manual versus automatic runs, Run/Rerun presentation, progressive
  reveal, passed/skipped filtering, Found/Expected disclosure, and summary placement.

An org is still required to usability-test the rendered selector and preview, validate end-user
record visibility, measure real evaluation cost, and confirm the chosen style on representative
Lightning record pages. Those checks cannot be proven by this content specification alone.
