# RHC Builder sandbox demo kit

This directory contains deterministic, non-production Account and Contact records for demonstrating
RHC Builder. It does not contain Builder draft/version records or core Custom Metadata. Those must be
created through the Builder UI so the demo exercises the real product workflow.

## Safety

- Load this data only into a sandbox, scratch org, or disposable developer org.
- Do not load it into production.
- The example email addresses and websites use reserved `.example` domains and do not represent real
  people or companies.
- The four Accounts use the unique marker `RHC-BUILDER-DEMO-` in `AccountNumber`.
- Rerunning the import creates duplicates; clean up the prior demo first.

## Automated data import

From `packages/rhc-builder`, authenticate the intended demo org and run:

```bash
sf data import tree --files demo/data/Account-Contact.json --target-org <demo-org-alias>
```

Verify the records:

```bash
sf data query --query "SELECT Name, AccountNumber, Website, (SELECT Id FROM Contacts) FROM Account WHERE AccountNumber LIKE 'RHC-BUILDER-DEMO-%' ORDER BY AccountNumber" --target-org <demo-org-alias>
```

Expected result: four Accounts and two Contacts.

### Optional Apex-plugin activity record

To runtime-test core's `AccountHasRecentActivityCheck` reference plugin:

1. Open **RHC Builder Demo - Healthy**.
2. In the activity composer, select **New Task**.
3. Enter subject `RHC Builder Demo - Recent Activity`.
4. Set the due date to today.
5. Select a Task status that is closed in your org, such as **Completed**.
6. Save the Task.

Task status values can be customized, so this record is deliberately created through the UI instead
of the portable JSON fixture. The other three demo Accounts should have no completed Task or Event
inside the plugin's configured look-back window.

## Manual data creation

If Salesforce CLI is unavailable:

1. Open the **Accounts** tab.
2. Select **New**.
3. Create each Account from the table below.
4. Open the first two Accounts and create the listed Contact from the **Contacts** related list.

| Account Name                       | Account Number                | Website                                  | Contact        |
| ---------------------------------- | ----------------------------- | ---------------------------------------- | -------------- |
| RHC Builder Demo - Healthy         | RHC-BUILDER-DEMO-HEALTHY      | `https://healthy.rhc-builder.example`    | Harper Healthy |
| RHC Builder Demo - Missing Website | RHC-BUILDER-DEMO-NO-WEBSITE   | Leave blank                              | Quinn Contact  |
| RHC Builder Demo - Missing Contact | RHC-BUILDER-DEMO-NO-CONTACT   | `https://no-contact.rhc-builder.example` | None           |
| RHC Builder Demo - Missing Both    | RHC-BUILDER-DEMO-MISSING-BOTH | Leave blank                              | None           |

## Demo Checks and expected results

Build the complete version using [DEMO_TEST_PLAN.md](DEMO_TEST_PLAN.md).

| Account         | Website is present | Has a Contact | Overall guided result |
| --------------- | ------------------ | ------------- | --------------------- |
| Healthy         | PASS               | PASS          | 2 pass, 0 fail        |
| Missing Website | FAIL               | PASS          | 1 pass, 1 fail        |
| Missing Contact | PASS               | FAIL          | 1 pass, 1 fail        |
| Missing Both    | FAIL               | FAIL          | 0 pass, 2 fail        |

Builder authors and publishes the configuration; Record Health Check core evaluates these records.

## Cleanup

Delete only the four Accounts whose Account Number begins with `RHC-BUILDER-DEMO-`:

1. Open the **Accounts** tab.
2. Search for `RHC Builder Demo -`.
3. Open each of the four demo Accounts.
4. Confirm its Account Number begins with `RHC-BUILDER-DEMO-`.
5. Select the record action menu, then **Delete**.
6. Confirm deletion. Related demo Contacts are deleted according to normal Salesforce Account/Contact
   behavior.
7. If you created the optional Task, confirm it was removed with its Account or delete it according to
   your org's activity-retention behavior.

Do not delete core Custom Metadata merely to remove business-record test data. Published demo Check
metadata should be deactivated or replaced through Builder according to your test-org cleanup policy.
