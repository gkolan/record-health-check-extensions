# No-namespace subscriber adapter fixture

This source root is organization-owned feasibility metadata and is deliberately excluded from the
RHC Change Monitor package directory. It enables Account on the standard `ChangeEvents` channel,
deploys the narrow no-namespace Account trigger, and supplies its subscriber contract test.

Do not add `PlatformEventSubscriberConfig` for this change-event trigger. The shared-org experiment
accepted that metadata but real Account CDC deliveries continued to run as Automated Process. That
metadata is a supported running-user control for platform-event Apex triggers, but this experiment
demonstrated that it does not change the principal of this CDC trigger.

Deploy only to the canonical shared no-namespace feasibility org. Removing the trigger and channel
membership must be coordinated with every subscriber that uses Account CDC.
