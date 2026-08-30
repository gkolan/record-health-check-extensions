# End-to-end RHC Builder demo and acceptance test

This plan tests the user-visible Builder lifecycle with deterministic demo records. Execute it in a
sandbox or disposable org. Record the tester, date, org ID, core version, Builder version, browser,
and evidence links in the test record.

## Test header

| Item                        | Record before testing             |
| --------------------------- | --------------------------------- |
| Tester                      |                                   |
| Date/time                   |                                   |
| Org alias and org ID        |                                   |
| Sandbox/scratch-org type    |                                   |
| Record Health Check version |                                   |
| RHC Builder version         |                                   |
| Browser and version         |                                   |
| Permission Set assigned     | Record Health Check Builder Admin |

## Prerequisites

- Record Health Check core and RHC Builder are installed as separate packages.
- The current user has **Record Health Check Builder Admin**.
- The four Accounts and two Contacts from [README.md](README.md) are loaded.
- Testing occurs in a non-production org.
- The tester knows how to run a published Check Set using the installed core package.

## Demo configuration

### Check Set

| Builder field            | Value                                                                           |
| ------------------------ | ------------------------------------------------------------------------------- |
| Check Set name           | RHC Builder Demo - Account Quality                                              |
| Qualified API Name       | `RHC_Builder_Demo_Account_Quality`                                              |
| Target Salesforce object | Account                                                                         |
| When the Check Set runs  | `RUN_ON_REQUEST`                                                                |
| Short explanation        | Demonstrates guided Formula and Query authoring against deterministic Accounts. |

### Check 1: guided Formula

| Builder field        | Value                                       |
| -------------------- | ------------------------------------------- |
| What should be true? | Website is present                          |
| Qualified API Name   | `RHC_Builder_Demo_Website_Present`          |
| Evaluation type      | `FORMULA`                                   |
| Failure severity     | `WARNING`                                   |
| Field                | Website (`Website`)                         |
| Pass when the field  | has a value                                 |
| Failure message      | Add the Account website.                    |
| How to fix it        | Edit the Account and enter a valid Website. |

Expected generated Formula: `NOT(ISBLANK(Website))`.

### Check 2: guided Query

| Builder field        | Value                                       |
| -------------------- | ------------------------------------------- |
| What should be true? | Account has a Contact                       |
| Qualified API Name   | `RHC_Builder_Demo_Has_Contact`              |
| Evaluation type      | `QUERY`                                     |
| Failure severity     | `WARNING`                                   |
| Related records      | Contacts (`Contact.AccountId`)              |
| Failure message      | Add at least one Contact to the Account.    |
| How to fix it        | Create or relate a Contact to this Account. |

Expected generated query:

```sql
SELECT Id FROM Contact WHERE AccountId = {!record.Id} LIMIT 1
```

Expected generated handling: source field `Id`, operator `IS_NOT_BLANK`, one-result handling, no rows
fail, empty value fail, and maximum query rows `1`.

## Test 1: installation and authorization

1. Open App Launcher and search for **Record Health Check Builder**.
2. Open the tab.
3. Confirm **RHC Builder** and all three path steps render.
4. Confirm readable objects appear in **Target Salesforce object**.

Expected: assigned authors can open Builder; an unassigned comparison user sees the authoring-access
message and cannot use the authoring endpoints.

## Test 2: local validation and object locking

1. On **1. Design**, leave every field blank.
2. Select **Continue to validation**.
3. Select **Validate complete version**.
4. Confirm errors include naming the Check Set, choosing a target object, and adding at least one
   Check.
5. Select **Back to design**.
6. Enter the Check Set values above.
7. Select **Add Check**.
8. Confirm **Target Salesforce object** becomes disabled.
9. Select the Check trash icon.
10. Confirm the target object becomes editable again.

Expected: incomplete input is rejected locally without a save; target-object references cannot be
silently changed while Checks exist.

## Test 3: generated names and exact identity

1. Enter `RHC Builder Demo - Account Quality` as the Check Set name.
2. Confirm Builder generates an underscore-separated Qualified API Name.
3. Replace it with the exact value in the demo configuration.
4. Add Check 1 and enter its label.
5. Confirm Builder generates its Qualified API Name.
6. Replace it with the exact demo value.
7. Move to validation and confirm Builder preserves the exact values without adding or removing a
   namespace.

Expected: generated names are editable; explicitly edited names remain exact.

## Test 4: guided Formula and type switching

1. Complete Check 1 using the demo configuration.
2. Expand **Advanced formula** and confirm `NOT(ISBLANK(Website))`.
3. Change **Evaluation type** to `QUERY` and then back to `FORMULA`.
4. Confirm the guided Formula answers remain present.
5. Continue to validation and inspect the advanced complete-version JSON.

Expected: the browser preserves entered answers while comparing types, but the canonical Check
contains only Formula-specific fields for the selected `FORMULA` type.

## Test 5: guided Query

1. Add Check 2 using the demo configuration.
2. Expand **Advanced query settings**.
3. Confirm the generated SOQL and source field.
4. Inspect the complete-version JSON on step 2.

Expected: the bounded SOQL and exact result-handling values match the demo configuration above.

## Test 6: duplicate Check identity validation

1. Temporarily change Check 2 Qualified API Name to the same value as Check 1.
2. Continue to validation.
3. Select **Validate complete version**.
4. Confirm validation identifies the duplicate Check Qualified API Name.
5. Return to design and restore `RHC_Builder_Demo_Has_Contact`.

Expected: duplicate Check identities are rejected before save.

## Test 7: complete validation and immutable Version 1

1. Validate the corrected complete version.
2. Confirm the green validation-passed message.
3. Select **Save validated version** once.
4. Confirm Builder opens **3. Publish and monitor**.
5. Confirm Version 1 is `VALIDATED` and contains two Checks.
6. Select **Review** and record the fingerprint.

Expected: one complete immutable version and two ordered child snapshots are saved together.

## Test 8: retry-safe save

This test is safest in an automated Jest/Apex suite because deliberately interrupting a real network
request is unreliable. Confirm the release evidence includes the Jest retry test and Apex idempotency
test. For an optional manual exercise, disconnect the browser only after selecting save, reconnect,
and select save again from the same page.

Expected: the same browser-session operation key is reused and no duplicate version is created for
the uncertain request.

## Test 9: copy and create Version 2

1. On Version 1, select **Copy as new draft**.
2. Confirm Builder returns to **1. Design** with the complete snapshot.
3. Change Check 1 failure message to `Add a public Account website.`
4. Validate and save.
5. Confirm Version 2 exists and Version 1 remains unchanged.
6. Review both fingerprints and confirm they differ.

Expected: saved versions are immutable; editing creates the next complete Check Set Version.

## Test 10: publish inactive and monitor

1. Select **Publish inactive** for Version 1.
2. Confirm the complete-version dialog.
3. Monitor **Recent operations** using **Refresh status**.
4. Confirm the operation reaches `SUCCEEDED`.
5. Confirm Version 1 reaches its deployed state but runtime metadata remains inactive.

Expected: the complete Check Set and both Checks publish together without activation.

## Test 11: activate and verify runtime outcomes

1. Select **Activate** for Version 1 and confirm.
2. Monitor until `SUCCEEDED`.
3. Use Record Health Check core to run `RHC_Builder_Demo_Account_Quality` against each demo Account.
4. Record each Check result.

| Account Number                | Website Check | Contact Check |
| ----------------------------- | ------------- | ------------- |
| RHC-BUILDER-DEMO-HEALTHY      | PASS          | PASS          |
| RHC-BUILDER-DEMO-NO-WEBSITE   | FAIL          | PASS          |
| RHC-BUILDER-DEMO-NO-CONTACT   | PASS          | FAIL          |
| RHC-BUILDER-DEMO-MISSING-BOTH | FAIL          | FAIL          |

Expected: runtime results match the matrix. This verifies core evaluation of Builder-published
metadata; Builder itself does not evaluate the Accounts.

## Test 12: rollback

1. Activate Version 2 and confirm it succeeds.
2. Review Version 1 and match its original fingerprint.
3. Select **Roll back to this version** and confirm.
4. Monitor until `SUCCEEDED`.
5. Run the four Accounts again.
6. Confirm the Version 1 failure message and result matrix are restored.

Expected: rollback is a new complete metadata deployment; Version 1 becomes the deployed selection
without modifying its saved snapshot.

## Test 13: failed/cancelled publication safety

1. Select a publication action.
2. In the confirmation dialog, select **Cancel**.
3. Confirm no new publication operation appears.
4. Use automated Apex tests as evidence that an unvalidated version cannot be published and a failed
   metadata callback records `FAILED` without marking the version deployed.

Expected: cancellation is side-effect free and failed deployments do not report success.

## Test 14: advanced authoring surfaces

These tests verify Builder's authoring UI, validation, and snapshot behavior. Use reviewed business
logic before runtime activation.

### Compare Two Queries

1. Copy Version 1 as a new draft.
2. Add a Check and select `COMPARE_TWO_QUERIES`.
3. Confirm **Source query**, **Comparison query**, **Source field**, **Comparison field**, and
   **Comparison operator** appear.
4. Enter developer-reviewed values, validate, and inspect the canonical JSON.
5. Do not activate unless the queries have a separate runtime test design.

### Apex

1. Add a Check and select `APEX`.
2. Confirm **Plugin class Qualified API Name** and **Parameters JSON object** appear.
3. For a core reference-plugin demonstration, use class `AccountHasRecentActivityCheck` and parameters
   `{"daysBack": 90}` only after confirming that class exists in the installed core version.
4. Create the optional completed Task described in [README.md](README.md).
5. Validate and inspect the canonical JSON.
6. Runtime-test **Healthy** and confirm it passes; test the three Accounts without recent activity and
   confirm they fail.

Expected: only fields belonging to the selected advanced type are saved. Builder does not author or
approve SOQL or Apex.

Compare Two Queries and Apex runtime correctness belongs to core and to the reviewed query/plugin.
This Builder acceptance plan verifies that Builder exposes, validates, snapshots, versions, and
publishes those exact values; it does not treat an unreviewed advanced example as production logic.

## Test 15: cleanup

1. Record any version/publication evidence required by the test ticket.
2. Deactivate or replace the demo Check Set through the approved Builder process.
3. Delete only Accounts whose `AccountNumber` begins with `RHC-BUILDER-DEMO-`.
4. Confirm the four demo Accounts and two Contacts are gone.
5. Do not delete unrelated core metadata or Builder ledger records outside the approved cleanup
   policy.

## Acceptance summary

| Area                | Pass criteria                                              | Result/evidence |
| ------------------- | ---------------------------------------------------------- | --------------- |
| Installation/access | Correct package boundary and permission behavior           |                 |
| Guided design       | Formula and Query values generated correctly               |                 |
| Validation          | Missing, duplicate, and complete versions behave correctly |                 |
| Versioning          | Version 1 immutable; copy produces Version 2               |                 |
| Idempotency         | Automated save/publication retry tests pass                |                 |
| Publication         | Inactive publication reaches success                       |                 |
| Activation          | Complete version activates together                        |                 |
| Runtime matrix      | Four Accounts produce expected outcomes                    |                 |
| Monitoring          | Operation status refreshes to terminal result              |                 |
| Rollback            | Earlier fingerprint is republished successfully            |                 |
| Advanced types      | Conditional UI and canonical fields verified               |                 |
| Security            | Unauthorized user cannot author                            |                 |
| Cleanup             | Demo business records removed safely                       |                 |
