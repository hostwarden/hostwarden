### Added

- **Housekeeping names vendor repositories that automatic updates
  skip.** On Debian and Ubuntu, unattended-upgrades installs only
  from the origins it is given, so Docker CE, NetBird, Grafana or a
  PPA waited for a manual upgrade unnoticed. Each enabled vendor
  repository is now listed with whether an origin covers it and
  which of its packages wait: a warning when updates are pending
  outside the origins, a note when none are yet, and a line marked
  decided where a decision keeps the repository out. A pattern that does not
  name an origin, a site and a component, or holds a wildcard in any value, is
  flagged too, whether or not it takes a repository yet. The baseline adds a
  missing origin as a drop-in per vendor, built from the repository's own
  Release fields with its site always named; on a host under
  configuration management it goes into the playbook instead.
- **Docker engine upgrades are checked for what they restart.**
  An upgrade of `docker-ce` restarts the engine and, without
  `live-restore`, every container. Housekeeping now notes a Docker
  host that upgrades its engine unattended without `live-restore`,
  and warns about a container meant to run that went down with the
  engine's last stop and did not come back, whatever its exit
  code.

### Fixed

- **Pending updates include those that need a new package.** The count
  came from a plain upgrade simulation, which holds back an upgrade
  that pulls in a new dependency, so such an update never showed.
