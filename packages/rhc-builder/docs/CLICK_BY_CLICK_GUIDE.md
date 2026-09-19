# Click-by-click administrator guide

This guide assumes you are a junior Salesforce administrator who has never authored a Record Health
Check. Follow it in a sandbox first. Every bold phrase is a label, button, path step, or message you
should see on screen.

## Before you click anything

Ask the business owner for these answers in writing:

| Question                                                | Example answer                               |
| ------------------------------------------------------- | -------------------------------------------- |
| Which Salesforce object are we checking?                | Account                                      |
| What is the Check Set called?                           | Account Data Quality                         |
| Does it run when the card loads or only when requested? | Only when requested                          |
| What conditions must be true?                           | Name is present; at least one Contact exists |
| How serious is each failure?                            | Warning                                      |
| What should the user be told?                           | Add an Account Name                          |
| Who approves activation?                                | CRM product owner                            |
| What sandbox records prove pass and fail behavior?      | Named test Accounts                          |

You also need the **Record Health Check Builder Admin** Permission Set. If Builder is not installed or
you cannot open it, use [Installation and access](INSTALLATION.md).

For a repeatable demonstration with known passing and failing Accounts, load the
[sandbox demo kit](../demo/README.md) and use the
[end-to-end acceptance plan](../demo/DEMO_TEST_PLAN.md). The walkthrough below teaches the same guided
workflow; the acceptance plan adds recorded expected results for every lifecycle action.

## Know the three screens

Builder uses one path at the top of the page:

1. **1. Design** — create an unsaved Check Set and its Checks.
2. **2. Validate and save** — validate the whole configuration and save one immutable version.
3. **3. Publish and monitor** — review saved versions, publish, activate, roll back, and monitor.

You may select a path step to move between screens. Moving between steps does not publish anything.
Closing the page before saving loses the unsaved in-browser draft.

For the proposed in-product tips, card-experience presets, and plain-language explanation of every
display choice, see the
[screen guidance and card-style decision guide](SCREEN_GUIDANCE_AND_CARD_STYLE.md). The selector in
that guide is available in current source. It applies complete, supported card-display presets and
also provides a Custom path for administrators who need individual controls.

## Walkthrough: create an Account Check Set

The finished example contains:

- Check Set: **Account Data Quality**
- Check 1: **Account name is present** using guided Formula
- Check 2: **Account has a Contact** using guided Query
- Initial state: saved and published inactive, not activated

### A. Open Builder

1. Sign in to the sandbox.
2. Select the App Launcher grid in the upper-left corner.
3. Select **View All** if the search box is not already visible.
4. In **Search apps and items**, enter `Record Health Check Builder`.
5. Select **Record Health Check Builder**.
6. Wait for the spinner to disappear.
7. Confirm the card title says **RHC Builder**.
8. Confirm **1. Design** is highlighted.

Stop and contact an administrator if you see either:

- **Record Health Check Builder authoring access is required**; or
- a message saying the installed core package is incompatible.

### B. Complete the Check Set section

1. Find **Design the Check Set**.
2. Select **Check Set name**.
3. Enter `Account Data Quality`.
4. Move out of the field by pressing Tab or selecting the next field.
5. Confirm **Qualified API Name** contains `Account_Data_Quality`.
6. Do not add `__mdt` or `__c` to the name.
7. Do not add or remove a namespace. For a new subscriber-owned Check Set, keep the generated name.
8. Open **Target Salesforce object**.
9. Scroll to and select the option whose object label and API name are **Account**.
10. Wait for Builder to load readable fields and child relationships.
11. Select **Short explanation**.
12. Enter `Checks the minimum Account data required by our process.`
13. Under **How should the health-check card work?**, select **User-controlled review**. It is the
    recommended choice for this walkthrough because a user decides when to run and every result
    remains visible.
14. Read **Your selection** and confirm it says users start the Check Set themselves, results appear
    together, passed and skipped Checks remain visible, and the summary appears below the results.

Expected result: all four Check Set inputs are complete. No metadata has been saved or published.

### C. Add Check 1 with guided Formula

1. Find the **Checks** heading.
2. Select **Add Check**.
3. Confirm a panel named **Check 1** appears.
4. Notice that **Target Salesforce object** is now disabled. This prevents generated field references
   from pointing at the wrong object.
5. In **What should be true?**, enter `Account name is present`.
6. Confirm the Check's **Qualified API Name** becomes `Account_name_is_present`.
7. Open **Evaluation type**.
8. Select **FORMULA**.
9. Open **Failure severity**.
10. Select **WARNING**.
11. Open **Field**.
12. Select the option containing **Account Name** and API name **Name**.
13. Under **Pass when the field**, select **has a value**.
14. Leave **Advanced formula** closed.
15. In **Failure message**, enter `Enter an Account Name.`
16. In **How to fix it**, enter `Edit the Account and complete the Account Name field.`

What Builder generated: `NOT(ISBLANK(Name))`. You can expand **Advanced formula** to review it, but do
not edit generated Formula text during this walkthrough.

The guided **Field** list intentionally includes readable text-like fields: text, text area, email,
phone, and URL. If the field you need is not listed, do not substitute a different field. Use an
approved advanced Formula or ask a developer or senior administrator to design the rule.

Expected result: Check 1 passes when Account Name contains a value and fails with a warning when it
is blank.

### D. Add Check 2 with guided Query

1. Select **Add Check** again.
2. Confirm a panel named **Check 2** appears below Check 1.
3. In Check 2 **What should be true?**, enter `Account has a Contact`.
4. Confirm **Qualified API Name** becomes `Account_has_a_Contact`.
5. Open **Evaluation type**.
6. Select **QUERY**.
7. Open **Failure severity**.
8. Select **WARNING**.
9. Open **Related records**.
10. Select the option for **Contacts**. The option also displays the underlying relationship/API
    information so you can distinguish similarly named relationships.
11. Leave **Advanced query settings** closed.
12. In **Failure message**, enter `Add at least one Contact to this Account.`
13. In **How to fix it**, enter `Create or relate a Contact to the Account.`

What Builder generated is equivalent to:

```sql
SELECT Id FROM Contact WHERE AccountId = {!record.Id} LIMIT 1
```

It also sets the result handling so the Check passes when one related record exists and fails when
there are no rows. The one-row limit keeps this common existence check bounded.

The **Related records** list includes child relationships that the current user can read and query
and whose parent-reference field is readable. If the required relationship is absent, check access
first; otherwise use reviewed advanced SOQL.

Expected result: the draft now has two ordered Checks. Their execution order is 10 and 20 even though
those numbers are not editable in the guided screen.

### E. Correct or remove a Check before saving

To change an answer, select the field and edit it. Changing **Evaluation type** preserves answers you
entered for other types in the browser, but only the selected type's fields are included in the saved
complete version.

To remove a Check:

1. Find the trash icon in that Check panel.
2. Hover over it and confirm the tooltip says **Remove Check**.
3. Select it.
4. Confirm the panel disappears.

To change the target object, remove every Check first. Then **Target Salesforce object** becomes
available again. Recreate the Checks using fields and relationships from the new object.

### F. Move to validation

1. Scroll below the last Check.
2. Select **Continue to validation**.
3. Confirm **2. Validate and save** becomes highlighted.
4. Read the statement that validation covers the complete Check Set Version.

Expected result: you are reviewing one complete Check Set and both Checks, not two independently
saveable Check records.

### G. Validate the complete version

1. Select **Validate complete version**.
2. Wait for the request to finish. Do not select the button repeatedly.
3. If a green message says **Builder validation passed for the complete Check Set Version**, continue
   to section H.
4. If a red error list appears:
   1. Read the bold path before the colon. It identifies the Check Set, Check, or field.
   2. Read the plain-language correction after the colon.
   3. Select **Back to design**.
   4. Correct the named field.
   5. Select **Continue to validation**.
   6. Select **Validate complete version** again.
5. Repeat until there are no errors.

Do not open **Advanced: exact complete-version metadata JSON** unless you are comparing the exact
snapshot with a release ticket or a developer asked you to inspect it. It is read-only review data,
not a second place to edit the configuration.

### H. Save Version 1

1. Confirm validation passed.
2. Select **Save validated version** once.
3. Wait for the spinner or disabled state to clear.
4. Confirm a green summary says the version was saved and validated.
5. Confirm Builder automatically opens **3. Publish and monitor**.
6. Find **Account Data Quality — Version 1**.
7. Confirm the row shows:
   - `Account_Data_Quality`;
   - status `VALIDATED`; and
   - `2 Checks`.

Expected result: Version 1 is immutable and saved. It is not published and is not active.

If the browser reports a network error while saving, do not rebuild the draft immediately. Select
**Save validated version** again from the same page. Builder reuses the same operation key so the
retry cannot create a second version for the same uncertain request.

### I. Review Version 1

1. In the Version 1 row, select **Review**.
2. Wait for **Version 1 review** to appear below the version list.
3. Confirm the displayed status is `VALIDATED`.
4. Record the fingerprint in the release ticket. A fingerprint identifies the exact immutable JSON.
5. Review the JSON with a technical reviewer when your release process requires it.
6. Confirm it includes one Check Set and exactly two Checks.
7. Confirm the target object, exact Qualified API Names, Formula, generated Query, failure severities,
   messages, and order.

Do not approve a version merely because Builder validation passed. Validation proves structural
compatibility, not that the business requirement is correct.

### J. Publish Version 1 inactive

1. In the Version 1 row, select **Publish inactive**.
2. A dialog titled **Confirm complete-version publication** opens.
3. Read the full message. It explains that corresponding core metadata will be replaced but will not
   run for users yet.
4. If the version is wrong, select **Cancel**.
5. If the version is correct and approved for sandbox publication, select the confirmation button.
6. Wait for the request to be accepted.
7. Confirm a success message says Salesforce accepted the complete version for publication.

Accepted does not mean deployed. Continue monitoring.

### K. Monitor publication

Current source and packages after `0.2.0.1`:

1. Stay on **3. Publish and monitor**.
2. Find **Recent operations**.
3. Select **Refresh status** beside **Back to design**.
4. Read the operation badge and summary.
5. Repeat until it displays `SUCCEEDED` or `FAILED`.

Validated beta `0.2.0.1`:

1. Select **2. Validate and save**.
2. Select **Refresh status**.
3. Select **3. Publish and monitor**.
4. Read the refreshed **Recent operations** entry.
5. Repeat until it displays `SUCCEEDED` or `FAILED`.

If `SUCCEEDED`, test the inactive core metadata in the sandbox according to the core package's test
procedure. If `FAILED`, follow [Operations and troubleshooting](OPERATIONS.md).

### L. Activate an approved version

Only continue after sandbox testing and release approval.

1. Open **3. Publish and monitor**.
2. Find **Account Data Quality — Version 1**.
3. Select **Review**.
4. Match the version number and fingerprint to the approval record. When another version of the
   same Check Set is active, the review shows **Changes versus active version N**: added,
   removed (deactivated on publish), and changed Checks with the changed field names.
5. Select **Activate**.
6. Read the confirmation: the Check Set and every Check become active together.
7. Select **Cancel** if any part of the version is unapproved.
8. Otherwise select the confirmation button.
9. Monitor **Recent operations** until terminal.
10. When it reaches `SUCCEEDED`, run the approved passing and failing record smoke tests.

## Make Version 2 without changing Version 1

Saved versions cannot be edited.

1. On **3. Publish and monitor**, locate Version 1.
2. Select **Copy as new draft**.
3. Confirm the message says Version 1 was copied into a new unsaved draft.
4. Confirm Builder returns to **1. Design**.
5. Change the business configuration. For example, update a failure message or add another Check.
6. Do not change exact Qualified API Names unless the metadata identity truly must change.
7. Select **Continue to validation**.
8. Validate the complete version.
9. Select **Save validated version**.
10. Confirm **Version 2** appears and Version 1 remains unchanged.
11. Review, test, and publish Version 2 through the same process.

## Roll back to Version 1

Rollback republishes an older complete version. It is not a database undo.

1. Obtain incident or release-owner approval.
2. Open **3. Publish and monitor**.
3. Locate **Version 1**.
4. Select **Review**.
5. Match its fingerprint and contents to the last-known-good approval record.
6. Select **Roll back to this version**.
7. Read the warning in **Confirm complete-version publication**.
8. Confirm only if the entire Version 1 snapshot is the intended rollback target.
9. Monitor the rollback operation until `SUCCEEDED` or `FAILED`.
10. Run the rollback smoke test.

## Evaluation type decision guide

| Select                | Use when                                                 | Junior-admin path                                                 | Who must review                                |
| --------------------- | -------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------- |
| `FORMULA`             | One record field or Boolean Formula determines pass/fail | Prefer **Field** plus **has a value/is blank**                    | Admin; developer for advanced Formula          |
| `QUERY`               | Related records or aggregate data determine pass/fail    | Prefer **Related records** for “at least one exists”              | Admin; developer for advanced SOQL/comparisons |
| `COMPARE_TWO_QUERIES` | Two datasets must be compared                            | Enter source and comparison SOQL plus their result fields         | Developer or senior admin                      |
| `APEX`                | Logic is implemented by a core-compatible plugin class   | Enter exact class Qualified API Name and optional JSON parameters | Developer and security reviewer                |

## Advanced Formula procedure

Use this only when the guided field presence/blank choice cannot express the approved rule.

1. Create or open a Check on **1. Design**.
2. Select `FORMULA` in **Evaluation type**.
3. Expand **Advanced formula**.
4. In **Pass condition formula**, paste the reviewed Boolean Formula.
5. Confirm the Formula returns true when the record is healthy.
6. Complete failure severity, failure message, and correction guidance.
7. Validate and test at least one true, false, blank, and error-prone input scenario.

Do not include `SELECT`, DML, JavaScript, or Apex in a Formula field.

## Advanced Query procedure

Use this only when the guided relationship existence query cannot express the approved rule.

1. Select `QUERY` in **Evaluation type**.
2. Expand **Advanced query settings**.
3. In **Source query**, paste reviewed SOQL using the core record-token syntax where required.
4. In **Source query field**, enter the exact field or alias read from the result.
5. In **Comparison operator**, select the approved comparison.
6. In **Expected value source**, choose where the expected value comes from.
7. Complete **Expected fixed value** only when the expected-value source is fixed.
8. Validate the complete version.
9. Test zero-row, one-row, many-row, blank-value, passing, and failing scenarios.

Advanced query behavior includes additional exact core fields in the saved snapshot even when not all
of them have guided controls. A developer should review the JSON before publication.

## Compare Two Queries procedure

1. Select `COMPARE_TWO_QUERIES`.
2. Enter reviewed **Source query** SOQL.
3. Enter reviewed **Comparison query** SOQL.
4. Enter the **Source field** returned by the first query.
5. Enter the **Comparison field** returned by the second query.
6. Select **Comparison operator**.
7. Complete failure severity, failure message, and correction guidance.
8. Validate and save the whole Check Set Version.
9. Test empty, unequal, equal, reordered-list, and multi-row cases appropriate to the selected
   operator.

The two queries are parts of one Check. Neither query nor Check gets an independent version.

## Apex Check procedure

1. Obtain the exact plugin class Qualified API Name from a developer.
2. Obtain the reviewed parameter JSON, if required.
3. Select `APEX` in **Evaluation type**.
4. In **Plugin class Qualified API Name**, paste the exact value. Preserve its namespace.
5. In **Parameters JSON object**, paste a valid JSON object such as `{}` or the developer-provided
   parameters.
6. Complete failure severity, failure message, and correction guidance.
7. Validate and save the whole Check Set Version.
8. Have the developer execute plugin-specific positive, negative, bulk, security, and error tests.

Builder configures an existing plugin. It does not create, compile, test, or approve Apex code.

## Qualified API Name rules

- For new subscriber-owned configuration, accept the generated underscore-separated name.
- It must begin with a letter and contain only letters, numbers, and underscores.
- It is an identity, not a user-facing label.
- Preserve an existing namespace exactly, for example `namespace__Existing_Name`.
- Never add `__mdt` to the record Qualified API Name.
- Never rename merely to improve capitalization or wording.
- Use the same Check Set Qualified API Name across later versions so Builder increments that Check
  Set's version history.
- Every Check Qualified API Name within a version must be unique.

## Final pre-activation checklist

- [ ] Correct org and environment confirmed.
- [ ] Correct Check Set Version and fingerprint approved.
- [ ] Target object and run mode reviewed.
- [ ] Exact Check Set and Check Qualified API Names reviewed.
- [ ] Every Check type and order reviewed.
- [ ] Formula, SOQL, query fields, operators, and Apex plugin reviewed as applicable.
- [ ] Failure severity, message, and correction guidance approved.
- [ ] Passing, failing, blank, skipped, unable, and error cases tested where applicable.
- [ ] Inactive publication reached `SUCCEEDED`.
- [ ] Activation approval recorded.
- [ ] Rollback version and smoke test identified.

## Where to go next

- Installation problem: [Installation and access](INSTALLATION.md)
- Publication or rollback problem: [Operations and troubleshooting](OPERATIONS.md)
- Conceptual model and governance: [Administrator guide](ADMIN_GUIDE.md)
- Technical behavior: [Developer guide](DEVELOPER_GUIDE.md)
