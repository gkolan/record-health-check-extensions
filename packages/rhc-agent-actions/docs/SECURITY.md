# Security

- **Authorization:** `Record_Health_Check_Run` (core) is checked before any evaluation; the
  package permission set grants Apex access only.
- **Data:** the response contains what core renders for the running user under
  `EVALUATION_WITH_DISPLAY`: message, fix, found/expected display values, action link. These are
  the same strings the user sees on the record page. `adminDetail` is excluded. No raw field
  values other than those display strings, no stack traces.
- **User mode:** Custom Metadata discovery runs `WITH USER_MODE`; evaluation is core's user-mode
  path.
- **Bounds:** 1 record, ≤ 5 Check Sets, ≤ 25 findings, correlation ID ≤ 120 safe characters,
  one request per explain call.
- **No writes:** the package performs no DML and publishes no events. Core may publish its own
  events according to the caller's defaults; the package does not request publication.
