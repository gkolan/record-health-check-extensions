# Operations

- The actions are synchronous and run inside the agent's request; a Check Set with many checks
  or expensive queries adds latency to the conversation. Keep agent-facing Check Sets small.
- `EXECUTION` errors mean core threw; investigate with RHC Logs or core diagnostics using the
  correlation ID the agent passed (it becomes core's run ID).
- `ATTENTION` results (`UNABLE_TO_EVALUATE`, `ERROR`) usually indicate a Check definition or
  permission problem, not a data problem.
- No scheduled jobs, no retention, nothing to uninstall beyond the classes and permission set.
