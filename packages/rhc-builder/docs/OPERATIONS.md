# Operations and troubleshooting

Use this runbook after a version has been saved or a publication request has been submitted.

## Status meanings

### Check Set Version status

| Status       | Meaning                                                                             | Safe administrator action                            |
| ------------ | ----------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `VALIDATED`  | Immutable version passed Builder validation but is not the current deployed version | Review, publish inactive, or activate after approval |
| `DEPLOYED`   | Metadata deployment succeeded for this version                                      | Perform the approved runtime smoke test              |
| `SUPERSEDED` | Another complete version became the deployed version                                | Keep for audit or choose it for an approved rollback |

`DRAFT` exists in the object lifecycle but ordinary Builder saves create validated immutable
versions. The editable draft is held on screen until it is validated and saved.

`DEPLOYING` and `FAILED` remain reserved picklist values for upgrade compatibility with the beta,
but current source does not write them to a Check Set Version. Publication progress and failures
belong exclusively to the operation ledger. A failed publication preserves the selected version's
prior status, activation flag, and deployed timestamp, so a transport or metadata error cannot
misrepresent the immutable version itself.

### Operation status

| Status       | Meaning                                                     |
| ------------ | ----------------------------------------------------------- |
| `QUEUED`     | Builder recorded the request but work has not started       |
| `VALIDATING` | The complete version is being checked                       |
| `DEPLOYING`  | Salesforce accepted an asynchronous Metadata API deployment |
| `SUCCEEDED`  | The operation reached a successful terminal result          |
| `FAILED`     | The operation reached a failed terminal result              |

## Monitor a publication

1. Open **Record Health Check Builder** from App Launcher.
2. Select **3. Publish and monitor**.
3. Find **Recent operations**.
4. Select **Refresh status**.
5. Read both the status badge and summary.
6. Repeat after a reasonable interval while the status is queued, validating, or deploying.
7. If using beta `0.2.0.1`, select **2. Validate and save**, select **Refresh status**, then return to
   step 3 to read the refreshed operation.
8. If the status is `SUCCEEDED`, execute the release smoke test.
9. If the status is `FAILED`, continue with the failure procedure below.

## Investigate a failed publication

1. Do not repeatedly select Publish, Activate, or Rollback.
2. Record the Check Set label, version number, fingerprint, operation token, operation kind, status,
   metadata request ID, requested/completed times, and result summary from **Recent operations**.
   The result summary lists up to ten rejected components as `<component>: <Salesforce message>`;
   that is usually enough to classify the failure without leaving Builder.
3. In Setup **Quick Find**, enter `Deployment Status`.
4. Select **Deployment Status**.
5. Find the metadata deployment whose request ID and time match the Builder operation.
6. Open its details and record the failed component and Salesforce message.
7. Classify the failure:
   - missing or renamed core field;
   - invalid Formula or SOQL;
   - namespace or Qualified API Name mismatch;
   - protected package-owned metadata;
   - insufficient metadata deployment authority;
   - concurrent metadata deployment; or
   - platform/transient failure.
8. Correct the source business configuration by using **Copy as new draft**. Never edit the saved
   snapshot or ledger records directly.
9. Validate and save a newly numbered complete version.
10. Review its fingerprint, then retry the approved publication action.

Escalate to a developer when the error involves advanced Formula/SOQL, Apex plugins, core schema
compatibility, protected metadata, or a repeated platform failure.

## Recover from an interrupted browser request

Builder retains an idempotency key in the current browser session when a save or publication response
is uncertain. Select the same action again from the same page. Builder reuses the operation token so
the server returns the original operation instead of creating a duplicate.

If the browser was closed, first refresh **Recent operations** and verify whether Salesforce already
accepted or completed the request. Do not assume a timeout means failure.

## Rollback incident procedure

1. Confirm the incident owner has approved rollback.
2. Identify the last known-good complete version and fingerprint.
3. Select **Review** for that version.
4. Compare its complete JSON and business approval evidence.
5. Select **Roll back to this version** and confirm the warning.
6. Monitor until the rollback operation reaches `SUCCEEDED` or `FAILED`.
7. Run passing and failing record smoke tests.
8. Record the new operation ID and outcome in the incident.

Rollback is a new complete Metadata API deployment. It does not undo database transactions or
restore runtime result records.

## Information to collect for support

- Salesforce org ID and environment type, but no credentials.
- Core and Builder installed versions.
- Check Set label and exact Qualified API Name.
- Check Set Version number and fingerprint.
- Operation kind, token, request time, status, and sanitized result summary.
- Metadata deployment request ID and Deployment Status error.
- Reproduction steps and whether the problem affects Formula, Query, Compare Two Queries, or Apex.
- Confirmation that the user has **Record Health Check Builder Admin**.

Never include installation keys, session IDs, access tokens, customer record data, or unrestricted
debug logs in a public issue.
