### Added

- **Plan a maintenance window ahead of time.** Hostwarden reads the
  blast radius of a reboot, restart, firewall or network step,
  proposes a window from any pending update and the notice lead
  times inside the radius, and writes it to `memory/plans/` with
  the steps, the affected hosts and the notify-by date — nothing
  runs until a later session is asked to run the plan. Automatic
  reboots and service restarts a host schedules on its own are
  recorded too, so an unplanned slot still shows up as a known
  cause rather than an outage. `hostwarden-impact status` reports a
  planned window that covers the current time too, so losing SSH
  during one reads as a known cause the same way. Session start
  names windows starting within a day and notices that are overdue,
  and Hostwarden can write a short notice for other admins, as chat
  text or an email.
