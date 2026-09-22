# RHC Actions production operations

## Ownership model

| Responsibility                     | Recommended owner              |
| ---------------------------------- | ------------------------------ |
| Policy business approval           | Data owner                     |
| Flow design and side-effect review | Salesforce automation owner    |
| Permission and subscriber identity | Security/release administrator |
| Pending queue monitoring           | RHC Actions administrator      |
| Manual approval                    | Designated approver            |
| Flow failures                      | Flow support team              |
| Package release and uninstall      | Release engineering            |
| Retention approval and operation   | Legal/audit owner and Actions administrator |

## Daily checks

1. Open **RHC Actions → Pending Actions**.
2. Review records in `PENDING_REVIEW`, `QUEUED`, and `RETRY_WAIT`. Up to 50 pending-review rows
   can be approved or rejected in one decision; each policy is re-validated when its Flow runs.
3. Investigate old non-terminal records relative to the org's event and Queueable service levels.
4. Open **Action History** and review `FAILED_RETRYABLE` and `FAILED_FINAL` outcomes.
5. Correlate Event ID and Run ID to core evidence when necessary.
6. Use Flow Interview ID in Salesforce Flow monitoring.

## Queue interpretation

| Observation                           | Meaning                                                                             | Operator action                                                                                        |
| ------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Growing `PENDING_REVIEW` count        | Human review is slower than event arrival                                           | Add approved reviewers or deactivate noisy policies; never switch to automatic merely to clear backlog |
| Long-lived `QUEUED`                   | Queueable has not started                                                           | Check Apex Jobs and org async capacity                                                                 |
| Persisted `RUNNING`                   | Unexpected in Day-1 source because the intermediate value is replaced before commit | Preserve the record and investigate manual edits or future-version behavior                            |
| `RETRY_WAIT`                          | Retryable Flow start failed                                                         | Verify `Available At`, access, and retry limit                                                         |
| `RETRY_WAIT` + `ASYNC_EXECUTION_RETRYABLE` | Queueable ended unexpectedly and its finalizer scheduled recovery              | Check Apex Jobs, async capacity, retry limit, and the one-minute availability time                      |
| `FAILED` with `FLOW_CONTRACT_INVALID` | Active Flow no longer matches policy contract                                       | Correct/activate Flow version, then generate a new controlled event after review                       |
| `FAILED` with `FLOW_START_FAILED`     | Attempts are exhausted                                                              | Fix runtime access or Flow behavior; do not replay by cloning records                                  |
| `FAILED` with `EXECUTION_AUTHORIZATION_REVOKED` | Policy, mode, opt-in, or permission changed after enqueue                | Treat as successful containment; review governance before creating a new action                         |
| `FAILED` with `ASYNC_EXECUTION_FAILED` | Unexpected Queueable failure exhausted retry policy                                | Preserve evidence; inspect Apex Jobs and open a package incident                                       |
| `FAILED` with `ASYNC_RECOVERY_ENQUEUE_FAILED` | Finalizer could not submit recovery                                          | Inspect async capacity immediately; record is terminal and requires controlled replay                  |
| `SUPPRESSED`                          | Recent success exists inside cooldown                                               | Usually expected loop protection; verify cooldown is appropriate                                       |
| `REJECTED`                            | Human declined the proposal                                                         | No Flow attempt history is expected                                                                    |

## Incident containment

When a Flow causes an unexpected side effect:

1. Deactivate the affected Corrective Action Policy.
2. If multiple policies use the Flow, deactivate all of them.
3. Do not run retention cleanup or otherwise delete Pending Action or Action History records.
4. Pause the customer Flow only under the Flow owner's incident procedure.
5. Preserve Event ID, Run ID, Record ID, Policy ID, Pending Action ID, History ID, user, times, and
   Flow Interview ID.
6. Review downstream automation and committed business changes.
7. Correct business records through an approved remediation; Actions cannot roll back the Flow.
8. Re-test in a sandbox before reactivation.

## Permission incident

If unauthorized users can see or act on records:

1. remove the inappropriate packaged Permission Set assignment;
2. review role hierarchy, sharing rules, View All Data, Modify All Data, and administrative access;
3. review the three Custom Permission assignments, including Manage Retention;
4. confirm the Platform Event subscriber configuration user;
5. preserve audit records; and
6. complete the organization's access incident process.

## Capacity and limits

- Capture indexes policies by Check API name, processes Platform Events in chunks of 50, and uses
  partial insert with duplicate idempotency handling.
- A resume checkpoint follows each successful event chunk. Transient first-chunk storage failures
  retry no more than three times; later failures resume after the last checkpoint with fresh limits.
- Review UI returns at most 200 oldest visible `PENDING_REVIEW` records.
- Each Flow attempt consumes asynchronous Apex and Flow resources.
- Retry delay is at least one minute and retries are capped at three.
- Org Platform Event, Apex, Flow, data-storage, and automation limits still apply.

Monitor `EventBusSubscriber`, event delivery, Apex Jobs, failed Flow interviews, package-object
storage, and reviewer backlog according to the org's service levels. Alert on subscriber position
that stops advancing, repeated retries, terminal async error codes, or old non-terminal actions.

## Change procedure

For a policy change:

1. deactivate the policy;
2. document the reason and approved new values;
3. update and sandbox-test the Flow first when its contract or behavior changes;
4. update the policy in manual mode;
5. activate it;
6. generate one controlled matching event;
7. complete manual acceptance; and
8. enable automatic mode only through its separate approval procedure.

## Retention and deletion

The package does not include a scheduled purge, and no packaged role receives direct delete CRUD on
Pending Action or Action History. Define and approve retention with legal, audit, security, storage,
and incident owners first.

To run the guarded cleanup:

1. confirm there is no incident, investigation, legal hold, or required export that needs the
   eligible evidence;
2. open **RHC Actions → RHC Actions Review** as a user assigned **RHC Actions Admin**;
3. under **Action audit retention**, enter a whole number from 1 through 3,650 days and click
   **Save retention settings**; the displayed 365-day value is only a recommendation until saved;
4. verify the saved window and remember that changing it disables purge until it is saved;
5. select the permanent-deletion acknowledgment and click **Purge eligible audit records**; and
6. record the returned History, Pending Action, and total counts in the change ticket. Repeat only
   under the same approved procedure if more eligible rows remain.

Each request deletes at most 1,000 combined rows. It deletes oldest completed Action History first,
then uses remaining capacity for old Pending Actions only in `SUCCEEDED`, `FAILED`, `SUPPRESSED`, or
`REJECTED`. It never selects `PENDING_REVIEW`, `QUEUED`, `RUNNING`, or `RETRY_WAIT`. Deletion is
irreversible in the package UI; use the organization's approved backup/export and restore process.

## Related runbooks

- [Junior-admin monitoring and troubleshooting](admin/MONITOR_AND_TROUBLESHOOT.md)
- [Automatic execution handoff](admin/ENABLE_AUTOMATIC_EXECUTION.md)
- [Disable and uninstall](admin/DISABLE_AND_UNINSTALL.md)
