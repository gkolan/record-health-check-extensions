# RHC Integrations junior administrator guide

> Last reviewed: August 25, 2026  
> Package API version: 66.0  
> Minimum Record Health Check core: 2.0.4.2 (`04tak000000cZBFAA2`)

Use this guide to install, configure, test, operate, and safely disable RHC Integrations. It assumes
Lightning Experience and a sandbox-first release process.

Most work is click-by-click in Salesforce Setup. **Step 6 requires VS Code or Salesforce CLI**
because Salesforce doesn't provide an edit screen for a Platform Event trigger's running user.
Ask a Salesforce developer or release manager to perform that step if you don't have deployment
access.

## How to use this guide

Complete the steps in order. Do not skip directly to route creation: the route can save successfully
while the runtime user still lacks credential access. Use the companion
[implementation worksheet](ADMIN-IMPLEMENTATION-WORKSHEET.md) to record names, owners, approvals,
test Event IDs, and evidence. After first-time setup, run the separate
[complete demo-data and functional test guide](DEMO-TESTING.md); it supplies repeatable demo routes,
events, a dead-letter fixture, a real core `ACTIONABLE`/`NONE` comparison, and scoped cleanup.

| Phase | Steps | Typical owner | Exit condition |
| --- | --- | --- | --- |
| Prepare | Prerequisites and 1–2 | Salesforce admin + release owner | Correct org, packages, and dedicated user confirmed |
| Authenticate | 3–6 | Salesforce admin + security/release owner | Runtime permission, credential principal, and all subscribers verified |
| Authorize people | 7 | Salesforce admin | Human roles assigned with least privilege |
| Configure | 8–9 | RHC admin | Exact identity copied and inactive route saved |
| Prove | 10 | Admin + receiver owner | Success, non-match, 503, 400, replay, and dedupe evidence captured |
| Activate | 11 | Change approver | Production checklist signed and route activated |

### Terms a junior administrator must know

| Term | Plain-language meaning | Common mistake |
| --- | --- | --- |
| Core | The Record Health Check package that evaluates Checks and publishes canonical events | Assuming Integrations can run a Check itself |
| Platform Event | A short-lived Salesforce message published after a Check/Check Set run | Treating it as a permanent database record |
| Route | The package record that says which event may go to which Named Credential/path | Entering a secret or full URL in it |
| Qualified API Name | Stable exact identity, including namespace when present | Copying the label or Developer Name instead |
| Named Credential | Salesforce-owned base URL plus connection to an External Credential | Entering `/api/incidents` into both base URL and route |
| External Credential | Salesforce-owned authentication definition and principal | Assuming the packaged Runtime permission grants its principal |
| Principal | The authentication identity allowed to use the External Credential | Assigning it to a human but not the runtime user |
| Subscriber user | Salesforce user under whom the Platform Event Apex trigger runs | Leaving it as Automated Process |
| Event ID | Canonical application identifier sent to the receiver for idempotency | Using Run ID or Replay ID as the duplicate key |
| Queueable | Salesforce background job that performs the post-commit callout | Expecting the HTTP call during the original Check transaction |
| Dead letter | Terminal delivery requiring correction and authorized replay | Replaying before correcting the cause |

### Salesforce screen conventions used below

- **Quick Find** is the search box in the left side of Setup.
- A path such as **Setup → Users → Users** means open Setup, search or expand Users, then select the
  final named page.
- For a multi-select picklist, select a value in **Available**, use the right-arrow button to move it
  to **Chosen/Selected**, and remove unwanted defaults with the left-arrow button.
- **Name** usually means an API/developer name. **Label** is human-facing. When this guide says API
  name, do not copy the label.
- If a button or field is absent, stop and verify permissions and Salesforce release/edition. Do not
  improvise a substitute security setting.

## What you need before you start

Do not start the production installation until every row is complete.

| Item | What to obtain | Owner |
| --- | --- | --- |
| Sandbox | A sandbox where core 2.0.4.2 is already installed and configured | Salesforce admin |
| RHC Integrations installation URL | An installation URL containing the promoted RHC Integrations `04t` ID | Package release owner |
| Integration user | A dedicated active Salesforce user; do not use a person's account | Salesforce security owner |
| External endpoint | Base URL, such as `https://service.example.com` | External-system owner |
| Authentication design | OAuth, basic authentication, token, AWS Signature, or no authentication, as approved by security | Security/integration owner |
| Receiver behavior | Confirmation that the receiver treats the RHC Event ID as an idempotency key | External-system owner |
| Test controls | A safe way for the test receiver to return `2xx`, `503`, and `400` | External-system owner |
| Check identity | Exact Check Set or Check **Qualified API Name** | Record Health Check admin |

The extension package container is `0Hoak0000005Lv3CAE`, but a `0Ho` package ID is **not** an
installation ID. The release owner must supply a promoted `04t` installation URL. At the time this
guide was reviewed, final version creation was waiting for the Dev Hub daily limit to reset.

## Step 1: Install the two packages in the sandbox

**Before clicking:** write the sandbox My Domain and both expected package versions in the worksheet.
If the browser's domain doesn't match that value at any point, stop.

### 1A. Confirm core is installed

1. Sign in to the sandbox as a System Administrator.
2. Select the gear icon, then select **Setup**.
3. In **Quick Find**, enter `Installed Packages`.
4. Select **Installed Packages**.
5. Find **Record Health Check**.
6. Confirm its version is **2.0.4.2** or a later version explicitly certified by the RHC
   Integrations release notes.
7. If it is missing or older, stop and install or upgrade core before continuing.

### 1B. Install RHC Integrations

1. Open a private browser window. This avoids installing into the wrong org when you use several
   Salesforce orgs.
2. Sign in to the intended sandbox.
3. Paste the RHC Integrations installation URL supplied by the release owner into the address bar.
4. On **Install RHC Integrations**, select **Install for Admins Only**. Access is assigned with the
   packaged permission sets later.
5. Select **Install**.
6. If Salesforce displays an approval page for external access, review it against the approved
   endpoint design before continuing. RHC Integrations itself does not package a customer endpoint
   or secret.
7. Wait for the installation-complete message or email.
8. Return to **Setup → Installed Packages** and confirm **RHC Integrations** appears.

Expected result: both packages are installed. No other RHC extension is required.

Evidence to capture: screenshot or exported Installed Packages rows showing package name and version;
never capture session IDs or installation keys.

## Step 2: choose the dedicated runtime user

Use an existing approved integration user when possible. If your organization requires a new user,
follow its license, profile, MFA, ownership, and credential-rotation standards.

1. In Setup, enter `Users` in **Quick Find**.
2. Select **Users → Users**.
3. Open the integration user.
4. Confirm **Active** is selected.
5. Copy the full **Username** into your implementation record. You need the username—not the name,
   alias, email address, or 18-character User ID—in Step 6.
6. Confirm that this account is not shared with a human and has no unnecessary business-data
   permissions.

Expected result: you have one active username dedicated to RHC Integrations runtime work.

Stop if the user is frozen, inactive, shared by people, scheduled for deactivation, or governed by a
profile that prohibits the required Platform Event/callout runtime. Resolve ownership before Step 3.

## Step 3: assign the packaged Runtime permission set

1. In Setup, enter `Permission Sets` in **Quick Find**.
2. Select **Permission Sets**.
3. Select **RHC Integrations Runtime**.
4. Select **Manage Assignments**.
5. Select **Add Assignments**.
6. Select the dedicated integration user.
7. Select **Assign**, then **Done**.

Do not assign **RHC Integrations Admin** to the runtime user. Runtime supplies the package/event
access needed by the subscriber; it does not authorize a person to configure routes or replay dead
letters.

Verification: return to the integration user's detail page, find **Permission Set Assignments**, and
confirm exactly one row named **RHC Integrations Runtime** exists for this package role.

## Step 4: create the External Credential and Named Credential

The following clicks use Salesforce's current extensible Named Credentials. Do not select **New
Legacy**. The exact authentication fields depend on the external service, so use the values approved
by your security or integration owner.

### 4A. Create the External Credential

1. In Setup, enter `Named Credentials` in **Quick Find**.
2. Select **Named Credentials**.
3. Select the **External Credentials** tab.
4. Select **New**.
5. Enter a descriptive **Label**, such as `Service Management Authentication`.
6. Enter a stable **Name**, such as `Service_Management_Authentication`.
7. Select the approved **Authentication Protocol**.
8. Complete only the protocol-specific fields supplied by the security owner.
9. Select **Save**.
10. On the External Credential detail page, find **Principals** and select **New**.
11. Enter a principal name, such as `ServiceManagementPrincipal`.
12. Select the identity type approved by security. For one organization-owned service identity,
    this is normally **Named Principal**.
13. Enter sequence number `1`, then save.
14. Complete the protocol's authentication flow or authentication parameters. Secrets belong here,
    never on an Record Health Check Integration Route.

Authentication is not a guess. Use this decision table and stop when information is missing:

| Endpoint owner says | Select | Ask for before saving |
| --- | --- | --- |
| OAuth client credentials | OAuth 2.0/client-credentials-capable configuration | Token endpoint, client ID, secret/certificate, scopes, expected audience |
| API key or bearer token | Custom | Exact header name and approved protected parameter design |
| Username/password basic auth | Custom | Approved service username, password rotation owner, required header design |
| AWS Signature Version 4 | AWS Signature Version 4 | Region, service, access-key/certificate policy |
| No authentication | Custom/no-auth design | Written security approval and confirmation endpoint is intentionally public |

Do not paste a secret into the Label, Name, route, worksheet, screenshot, ticket, or this repository.

### 4B. Create the Named Credential

1. Return to **Setup → Named Credentials**.
2. Select the **Named Credentials** tab.
3. Select **New**.
4. Enter **Label**: `Service Management`.
5. Enter **Name**: `Service_Management`.
6. Enter the approved base **URL**, for example `https://service.example.com`.
7. Select the External Credential created in Step 4A.
8. Select **Enabled for Callouts** if the page displays that option.
9. Leave route-specific path `/api/incidents` out of this URL; it is entered on the route later.
10. Save.

Expected result: Salesforce owns the authentication configuration and the Named Credential API
name is exactly `Service_Management`. No secret has been entered in an RHC package record.

Verification: reopen the Named Credential and read the URL from the beginning to the end. It must be
only the approved base URL. Confirm **External Credential** points to the record from Step 4A and
**Enabled for Callouts** is on where displayed.

## Step 5: grant the runtime user access to the External Credential principal

Create this permission set in the subscriber org because the package cannot know which credential
or principal an administrator will create after installation.

1. In Setup, enter `Permission Sets` in **Quick Find**.
2. Select **Permission Sets**, then select **New**.
3. Enter **Label**: `RHC Service Management Credential User`.
4. Accept the generated API name.
5. Leave **License** as `--None--` unless your security team specifies a license.
6. Select **Save**.
7. On the permission-set page, select **External Credential Principal Access**.
8. Select **Edit**.
9. Move the principal created in Step 4A from **Available** to **Enabled**.
10. Select **Save**.
11. Return to the permission-set page and select **Manage Assignments**.
12. Select **Add Assignments**.
13. Select the dedicated integration user, then select **Assign → Done**.

Expected result: the runtime user has both **RHC Integrations Runtime** and the org-owned credential
permission set. Human Admin, Operator, and Viewer users do not need credential-principal access.

Verification: open the dedicated user and confirm both permission-set assignment rows. Then reopen
the org-owned credential permission set and confirm the intended External Credential principal is in
Enabled access. A similarly named permission set is not evidence; inspect the actual principal.

## Step 6: set the running user for all three event subscribers

This configuration is required. Without it, Salesforce normally runs Platform Event Apex triggers
as **Automated Process**, which can't use the permission-set assignment you made for the dedicated
integration user.

The package uses these expected trigger names after installation:

- `rhc__RHCIntegrationResultSubscriber`
- `rhc__RHCIntegrationRunSubscriber`
- `rhc__RHCIntegrationLogSubscriber`

First verify the exact installed names:

1. In Setup, enter `Platform Events` in **Quick Find**.
2. Select **Platform Events**.
3. Open **Record Health Check Result**.
4. In **Subscriptions**, copy the RHC Integrations Apex trigger name.
5. Repeat for **Record Health Check Set Run** and **Record Health Check Log**.
6. If a displayed name differs from the expected name above, use the displayed name in the XML.

### Copy/paste deployment with VS Code

1. Install Salesforce CLI, Visual Studio Code, and the Salesforce Extension Pack, or ask your
   release manager to perform this section.
2. Open VS Code.
3. Open the Command Palette:
   - Windows: **Ctrl+Shift+P**
   - macOS: **Command+Shift+P**
4. Run **SFDX: Create Project with Manifest**.
5. Choose **Standard**.
6. Name the project `rhc-integrations-subscriber-config` and choose a working folder.
7. Open the Command Palette again and run **SFDX: Authorize an Org**.
8. Choose the login type for the sandbox, enter alias `rhc-integrations-sandbox`, and complete the
   Salesforce login page.
9. In the VS Code Explorer, under `force-app/main/default`, create a folder named
   `PlatformEventSubscriberConfigs`.
10. Create the following three files in that folder. Replace `INTEGRATION_USER_USERNAME` with the
    exact username copied in Step 2.

`RHCIntegrationResultSubscriberConfig.platformEventSubscriberConfig-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PlatformEventSubscriberConfig xmlns="http://soap.sforce.com/2006/04/metadata">
    <platformEventConsumer>rhc__RHCIntegrationResultSubscriber</platformEventConsumer>
    <batchSize>100</batchSize>
    <masterLabel>RHCIntegrationResultSubscriberConfig</masterLabel>
    <user>INTEGRATION_USER_USERNAME</user>
    <isProtected>false</isProtected>
</PlatformEventSubscriberConfig>
```

`RHCIntegrationRunSubscriberConfig.platformEventSubscriberConfig-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PlatformEventSubscriberConfig xmlns="http://soap.sforce.com/2006/04/metadata">
    <platformEventConsumer>rhc__RHCIntegrationRunSubscriber</platformEventConsumer>
    <batchSize>100</batchSize>
    <masterLabel>RHCIntegrationRunSubscriberConfig</masterLabel>
    <user>INTEGRATION_USER_USERNAME</user>
    <isProtected>false</isProtected>
</PlatformEventSubscriberConfig>
```

`RHCIntegrationLogSubscriberConfig.platformEventSubscriberConfig-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PlatformEventSubscriberConfig xmlns="http://soap.sforce.com/2006/04/metadata">
    <platformEventConsumer>rhc__RHCIntegrationLogSubscriber</platformEventConsumer>
    <batchSize>100</batchSize>
    <masterLabel>RHCIntegrationLogSubscriberConfig</masterLabel>
    <user>INTEGRATION_USER_USERNAME</user>
    <isProtected>false</isProtected>
</PlatformEventSubscriberConfig>
```

11. Save all three files.
12. Right-click the `PlatformEventSubscriberConfigs` folder.
13. Select **SFDX: Deploy Source to Org** or **SFDX: Deploy This Source to Org**, depending on your
    Salesforce extension version.
14. Wait for a success notification for all three components.

Keep batch size `100` for the initial release. Change it only after a developer has load-tested the
org's number of active routes and event volume.

### Verify the subscriber configuration in Setup

1. Return to **Setup → Platform Events**.
2. Open each of the three Record Health Check events again.
3. In **Subscriptions**, confirm the RHC Integrations row shows:
   - **User**: the dedicated integration user
   - **Batch Size**: `100`
4. If an old user still appears, select **Manage** beside the subscription, suspend it, then resume
   it so the new configuration takes effect.
5. Do not activate an outbound route until all three subscriber rows are correct.

Capture one screenshot per event showing Trigger, User, Batch Size, and subscription state. These
three screenshots are required deployment evidence because a later user deactivation or metadata
change can silently break authentication.

## Step 7: assign human permission sets

Use the same assignment clicks from Step 3.

| Packaged permission set | Assign to | What it allows |
| --- | --- | --- |
| RHC Integrations Admin | A small number of configuration owners | Create/change routes, inspect operations, replay dead letters |
| RHC Integrations Operator | Operations team | View sanitized dead-letter information without replay or payload access |
| RHC Integrations Viewer | Audit/read-only users | Read routes and sanitized operational information |
| RHC Integrations Runtime | Dedicated integration user only | Background event, ledger, Queueable, and callout access |

Do not give Runtime or External Credential principal access to every administrator.

For each assignment: **Setup → Permission Sets → select permission set → Manage Assignments → Add
Assignments → select user → Assign → Done**. Log the named owner and backup owner in the worksheet.
Never assign Admin merely so someone can view the app; Viewer or Operator is the intended role.

## Step 8: copy the exact Check Set identity

For the requested example:

1. In Setup, enter `Custom Metadata Types` in **Quick Find**.
2. Select **Custom Metadata Types**.
3. Find **Record Health Check Set** and select **Manage Records**.
4. Open the Check Set whose developer name is `Opportunity_Close_Readiness`.
5. Copy its **Qualified API Name** exactly, including a namespace prefix if Salesforce displays one.
6. Confirm that the Check or execution path can publish a Result event. For a person clicking the
   RHC card, the individual Check must have **Publish User Result Event** selected. For Flow/Apex
   execution, event publication must be **Actionable** or **All**, not **None**.

If publication is **None**, RHC Integrations receives no event and creates no delivery. That is
expected behavior.

Identity checkpoint: paste the copied value into a plain-text scratch area and compare it character
by character with Setup. Check capitalization, underscores, and an `rhc__` or other namespace prefix.
Delete the scratch text after saving the route if local policy requires it.

## Step 9: create the example outbound route

1. Open the App Launcher (the nine-dot grid).
2. Search for and select **RHC Integrations**.
3. Select the **Record Health Check Integration Routes** tab.
4. Select **New**.
5. Enter the following values. For **Event Types** and **Statuses**, move only the listed value to
   Selected; remove any unintended default or prior selection.

| Field | Value to select or enter |
| --- | --- |
| Route Name | `Opportunity Critical Errors to Service Management` |
| Active | Leave cleared while testing configuration |
| Event Types | Move **Result** to Selected |
| Selection Type | **Check Set** |
| Qualified API Name | Paste the exact value copied in Step 8 |
| Statuses | Move **Error** to Selected |
| Minimum Severity | **Critical** |
| Named Credential | `Service_Management` — enter the API Name, not only the label |
| Relative Endpoint | `/api/incidents` |
| Payload Profile | **RHC Error v1** |
| Retry Policy | **Standard** |

6. Select **Save**.
7. Reopen the route and compare every value with the table.
8. Do not enter `https://`, a query string, `#`, backslash, credentials, tokens, or `..` in
   **Relative Endpoint**. The route validation rule rejects unsafe paths.

### What each route value means before you activate it

| Value | Why it is used | What would change its behavior |
| --- | --- | --- |
| Result | Result events contain Check/Check Set identity, status, and severity | Run has no severity; Log lacks canonical qualified identity/severity |
| Check Set | Compare the event's Check Set identity | Choose Check only when routing one exact Check identity |
| Error | Ignore Fail, Unable to Evaluate, Pass, and Skipped | Add statuses only with receiver-owner approval |
| Critical | Reject Warning, Info, and missing severity | Blank accepts all severities; Warning accepts Warning and Critical |
| `Service_Management` | Resolve the administrator-owned Named Credential | Label text or a misspelled API name fails at runtime |
| `/api/incidents` | Append one safe relative path to the base URL | A full URL or query string is prohibited |
| RHC Error v1 | Send only the compiled error profile | It refuses non-ERROR events |
| Standard | Up to three total attempts | No Retry tries once; Aggressive tries five times |

Route-save checkpoint: Active remains off, the record detail page displays every value above, and
the route's field history starts with the approved values. Have a second administrator compare the
saved record with the worksheet before Step 10.

## Step 10: perform sandbox acceptance tests

Coordinate these tests with the external-system owner. Do not send real customer data to a public
echo or request-inspection website.

### 10A. Pre-activation checks

1. Confirm the external receiver accepts `POST` at the Named Credential base URL plus
   `/api/incidents`.
2. Confirm it reads `Idempotency-Key` or `X-RHC-Event-ID` and permanently deduplicates that value.
3. Confirm it can safely return controlled `2xx`, `503`, and `400` responses in the sandbox.
4. Open the route, select **Edit**, select **Active**, then select **Save**.

Write the activation time and activating administrator in the worksheet. This timestamp narrows the
Platform Event, Apex Jobs, receiver, and ledger evidence you inspect next.

### 10B. Successful delivery

1. Run the matching Check Set through the approved Record Health Check card, Flow, or Apex test
   path with event publication enabled.
2. Produce a matching `ERROR` result whose severity is `CRITICAL`.
3. Ask the receiver owner to confirm one request arrived at `/api/incidents`.
4. Confirm the request has the same RHC Event ID in both idempotency headers.
5. In Setup, enter `Apex Jobs` in **Quick Find**, then select **Apex Jobs**.
6. Confirm the recent `RHCIntegrationDeliveryQueueable` job completed.

An HTTP success means only that the receiver returned success. It does not prove that the external
system completed later downstream work.

### 10C. Exact-filter negative tests

Run one case at a time and confirm the receiver gets no request:

1. A different Check Set Qualified API Name.
2. A status other than `ERROR`.
3. Severity `WARNING` while the route minimum is `CRITICAL`.
4. Publication set to `NONE`.
5. The route with **Active** cleared.

### 10D. Retryable `503`

1. Configure the sandbox receiver to return `503` for this request.
2. Publish one matching event.
3. Confirm the first attempt occurs.
4. Keep the receiver on `503` and confirm Standard policy makes no more than three total attempts,
   using delays of approximately 1 and 5 minutes.
5. Before the final attempt in a separate test, return the receiver to `2xx` and confirm delivery
   succeeds.

### 10E. Permanent `400` and replay

1. Configure the sandbox receiver to return `400`.
2. Publish one matching event.
3. Open **App Launcher → RHC Integrations → Dead Letters**.
4. Select **Refresh**.
5. Confirm the delivery appears with a permanent HTTP classification and no response body.
6. Correct the external endpoint or receiver configuration and make it return `2xx`.
7. As a user assigned **RHC Integrations Admin**, open the row action menu and select **Replay**.
8. Confirm the row leaves the dead-letter list after refresh and the receiver sees the original
   Event ID again.
9. Confirm the receiver treats the repeated Event ID as the same logical request.

Expected result: `503` retries within a fixed bound; `400` dead-letters immediately; only an
authorized administrator can replay; replay preserves the Event ID.

### 10F. Permission and information-exposure tests

1. Sign in as or use **Login As** for an Operator test user according to org policy.
2. Open **RHC Integrations → Dead Letters** and confirm sanitized rows are visible.
3. Confirm no Replay action is offered and no Payload value is displayed.
4. Repeat as Viewer; confirm no route edit and no replay capability.
5. Confirm the dedicated Runtime user is not used as a human app user.
6. Inspect the 400 dead-letter row and confirm it contains only status/classification/guidance—not
   the receiver body, token, exception message, or stack trace.
7. Record pass/fail for each role in the worksheet.

### 10G. Test cleanup

1. Clear **Active** on any sandbox-only route that must not keep delivering.
2. Return the test receiver from forced 400/503 mode to normal.
3. Remove temporary test permission assignments.
4. Delete only test ledger rows according to the approved retention policy; do not delete evidence
   needed for release approval.
5. Confirm no Queueable retry remains expected before concluding the test window.

## Step 11: production activation checklist

Repeat Steps 1–10 in production using production-approved credentials and a controlled test record.
Before selecting **Active**, record approval for every item:

- Core and RHC Integrations package versions are approved.
- The Named Credential base URL is the production URL.
- No secret appears on an Record Health Check Integration Route.
- The External Credential principal is assigned only to the dedicated runtime user and other
  explicitly approved users.
- All three subscriber rows show the dedicated user and batch size 100.
- The exact qualified identity includes the correct namespace, if any.
- The external receiver enforces Event ID idempotency.
- The receiver owner understands that delivery is at-least-once.
- Dead-letter ownership and storage-retention periods are documented.
- Salesforce Platform Event, Queueable, callout, and async capacity has been reviewed.

## Daily operations

### Review dead letters

1. Open **App Launcher → RHC Integrations → Dead Letters**.
2. Select **Refresh**.
3. Read the bounded classification and status code.
4. Correct the Named Credential, principal, endpoint, network policy, or receiver first.
5. Replay only after the correction is verified.

The screen intentionally does not display response bodies, exception messages, stack traces, or
the retained request payload.

### Disable outbound delivery quickly

1. Open **RHC Integrations → Record Health Check Integration Routes**.
2. Open the affected route.
3. Select **Edit**.
4. Clear **Active**.
5. Select **Save**.

This prevents new deliveries for that route. It does not cancel an HTTP request already in progress
or undo work already accepted by the external system.

### Rotate a credential without editing the route

1. Coordinate a maintenance window with the receiver owner.
2. Clear **Active** on affected routes when zero new deliveries is required during rotation.
3. Rotate/authenticate the value inside the External Credential according to security policy.
4. Reconfirm the principal permission-set assignment to the runtime user.
5. Run a controlled sandbox/production-safe callout test.
6. Reactivate the route.
7. Never copy the new secret into the route or replay screen.

### Replace a Named Credential base URL

Edit the subscriber-owned Named Credential, not the route, when only the scheme/host/base path
changes. Reconfirm that base URL plus Relative Endpoint produces exactly one intended path. If the
API resource path changes, edit Relative Endpoint separately with route history and approval.

## Troubleshooting

| What you see | What a junior admin should check |
| --- | --- |
| No request arrives | Confirm route Active, event publication isn't `NONE`, event type is Result, identity matches exactly, status is Error, severity is Critical, and profile is RHC Error v1. |
| Apex job fails before callout | Verify the three subscriber rows use the dedicated integration user and that user is active. Escalate the Apex Jobs error to a developer; do not paste raw errors into route records. |
| `401` or `403` | Confirm the dedicated user has the org-owned External Credential principal permission set and the credential authentication is complete. Ask the endpoint owner to verify authorization. |
| Configuration invalid dead letter | Compare Named Credential API Name with `Service_Management`; confirm the endpoint begins with `/` and contains no scheme, query, fragment, backslash, or `..`. |
| `400` dead letter | Treat it as permanent. Correct the endpoint/request contract, then use authorized replay. The response body is intentionally unavailable. |
| `503`, `429`, `408`, or `425` | Wait for the bounded retry policy. Do not manually replay while the delivery is still retrying. |
| Dead Letters is empty | Empty can mean success, no matching event, or a pending retry. Confirm event publication, Apex Jobs, and the receiver's safe request log. |
| Receiver reports duplicates | Confirm it deduplicates the RHC Event ID, not Run ID or Salesforce Replay ID. Salesforce can't guarantee exactly-once cross-system delivery. |
| Route won't save | Read the validation error and remove unsafe Named Credential or relative-endpoint characters. Never work around validation by storing a full URL or secret elsewhere in the route. |
| Platform Event shows Automated Process | Step 6 is incomplete or hasn't taken effect. Deploy all three subscriber configurations, then suspend/resume the affected subscription. |

## Security rules that never change

- Use only administrator-owned Named Credentials and External Credentials for authentication.
- Never enter passwords, tokens, client secrets, cookies, or authorization headers in route fields.
- Never send Log message, details JSON, exception type, stack trace, user ID, or Log record ID.
- Never ask a customer to enter Apex, scripts, expressions, or templates.
- Never add arbitrary Apex class-name configuration.
- Never update the checked business record from this integration.
- Never use the delivery ledger as a general reporting dataset.
- Never assume HTTP success proves completion of downstream work.
- Never promise exactly-once delivery; require receiver-side Event ID idempotency.

## Official Salesforce references

- [Define an External Credential and a Named Credential](https://help.salesforce.com/s/articleView?id=sf.external_services_define_named_credential.htm&language=en_US&type=5) — Salesforce Help article; current extensible credential model.
- [Create, Edit, Delete, and Assign a Permission Set](https://help.salesforce.com/s/articleView?id=Create-a-permission-set&language=en_US&type=1) — Salesforce Help article; Setup navigation and assignment flow.
- [Configure the User and Batch Size for Your Platform Event Trigger](https://help.salesforce.com/s/articleView?id=release-notes.rn_messaging_trigger_config.htm&language=en_US&release=230&type=5) — Salesforce Help page; Metadata/Tooling API requirement and XML shape.
- [Discover Your Apex Trigger Batch Size and User](https://help.salesforce.com/s/articleView?id=release-notes.rn_messaging_trigger_new_col.htm&language=en_US&release=256&type=5) — Salesforce Help page; Setup verification columns.
- [Salesforce Platform: Suspend and Resume Platform Event Subscriptions](https://help.salesforce.com/s/articleView?id=002186624&language=en_US&type=1) — Salesforce Help article; applying changed subscriber configuration.
