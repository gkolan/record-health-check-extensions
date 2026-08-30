# Official Salesforce UI references

Last checked: **August 25, 2026**.

Use these Salesforce-owned sources when revalidating the administrator runbooks after a Salesforce
release. Package-specific labels and API names come from this repository's metadata, not from public
Salesforce documentation.

## Permission Set assignment

[Manage Permission Set Assignments](https://help.salesforce.com/s/articleView?id=perm_sets_assignment_summary.htm&language=en_US&type=5)

Source type: Salesforce Help article.

The article confirms both supported paths used in the runbooks:

- Setup → Permission Sets → Permission Set → Manage Assignments → Add Assignments; and
- Setup → Users → User → Permission Set Assignments.

Recheck this source when Salesforce changes User Access Summary or Setup with Agentforce behavior.

## No-trigger autolaunched Flow and variables

[Create the Autolaunched Flow and Set Up the Action](https://help.salesforce.com/s/articleView?id=platform.automate_flow_build_screen_action_create_autolaunched_flow.htm&language=en_US&type=5)

Source type: Salesforce Help article.

The article confirms selection of **Autolaunched Flow (No Trigger)** and creation of variables
through Toolbox → New Resource, including **Available for input** and **Available for output**.

[Flow Types](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_type.htm&language=en_US&type=5)

Source type: Salesforce Help reference.

The reference distinguishes an Autolaunched No Trigger Flow from screen, record-triggered,
schedule-triggered, and approval-process Flow types.

## Flow interview GUID

[$Flow Global Variables Resource](https://help.salesforce.com/s/articleView?id=sf.flow_ref_resources_system_variables.htm&language=en_US&type=5)

Source type: Salesforce Help reference.

The reference defines `$Flow.InterviewGuid` as the system-provided Text identifier for a running
Flow interview.

## Platform Event subscriber running user

[Configure the User and Batch Size for Your Platform Event Trigger](https://help.salesforce.com/s/articleView?id=release-notes.rn_messaging_trigger_config.htm&language=en_US&release=230&type=5)

Source type: Salesforce Help/official release documentation.

The article states that Platform Event Apex triggers run as Automated Process by default and that a
different user and batch size are configured with `PlatformEventSubscriberConfig` through Metadata
API or Tooling API. This is why the automatic-execution runbook contains a release-engineer handoff
instead of pretending Setup offers a complete click-only configuration.

## Revalidation procedure

At each Salesforce major release:

1. open every source above;
2. confirm the exact concepts still appear in the article body;
3. perform the runbooks in a sandbox using the supported Lightning experience;
4. compare every package label to source metadata;
5. update the **Last checked** date only after the walkthrough succeeds; and
6. document any UI variation by release, locale, edition, or Setup experience without changing
   package API names.
