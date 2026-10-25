### Fixed

- **A site's map draws a VM that runs at a provider.** A host whose
  `Runs on:` line names a cloud provider, a hypervisor Hostwarden does
  not manage or `unknown` was left off its site's map and its hosts
  table, as if a hypervisor's map drew it; the site's ranges then
  rendered as empty boxes. Only a guest of a hypervisor or cluster in
  memory, which that map draws, stays out of the site map.
- **A range, site, cluster member or hypervisor with nothing drawn
  shows as one box.** The maps drew it as an empty frame, which the
  diagram piled onto the other frames so that their labels
  overlapped; the box now says nothing is drawn there, and the tables
  are unchanged.
