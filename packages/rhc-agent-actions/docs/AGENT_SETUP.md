# Adding the actions to an Agentforce agent

1. Assign **RHC Agent Actions User** and core **Record Health Check User** to the agent user
   (the user the agent runs as).
2. In Agent Builder, open or create a topic such as **Record health**. Suggested classification
   description: *Answers questions about whether a Salesforce record is healthy, which health
   checks failed, and how to fix them.*
3. Add two actions from the **Apex** reference action type:
   - **List Record Health Check Sets for Agentforce** — instruction: *Use first when the user
     names an object or record and you do not know which Check Sets apply. Pass the record ID
     when you have one.*
   - **Explain Record Health for Agentforce** — instruction: *Use when the user asks what is
     wrong with a record, why it is unhealthy, or how to fix it. Pass the record ID from the
     conversation. Leave Check Set blank unless the user named one. Read `Summary Text` to the
     user; offer the `Fix` text as the next step. Never say the record was changed.*
4. Topic instruction: *`FAIL` is a business finding. `ATTENTION` means something could not be
   evaluated; tell the user to contact an administrator rather than guessing.*

## Sample dialogue

> **User:** What's wrong with the Acme account?
> **Agent:** 2 checks failed, 4 passed. No business phone is recorded — confirm the main number
> and add it to Acme. No company website is recorded — verify the official site before adding it.

## Agent Script

If the org authors agents with Agent Script, reference the actions by their Apex class names;
inputs and outputs match the `@InvocableVariable` labels above.
