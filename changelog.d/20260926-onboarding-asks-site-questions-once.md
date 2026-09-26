### Changed

- **Onboarding several hosts asks what belongs to a site once per
  site.** The questions wait until every host of the run is probed;
  the site, its uplink, what filters in front of the hosts, how a
  machine is reached when SSH is gone and a backup the hosts cannot
  see are then asked once for the hosts of a site, naming each, and
  every host's memory records the answer. Hosts that share a range
  are asked their site together.
