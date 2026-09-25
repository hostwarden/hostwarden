### Fixed

- **A quoted `&&` or `;` inside a remote command no longer lets a
  disruptive step slip past coordination.** `ssh host "true &&
  systemctl restart nginx"` used to split into two pieces, leaving
  the actual restart with no destination of its own, so the origin
  check never weighed it against a live session on that host. A
  separator inside the remote command's own quotes now stays part
  of the segment the destination is read from.
- **A session's own run marker no longer reads as busy long after
  the command actually ended.** A crashed or denied command whose
  cleanup step never ran used to be seen as still running until an
  unrelated housekeeping sweep happened to clear it; it now stops
  counting once it is older than that sweep's own six-hour window.
  Two commands running on the same host at once no longer risk this
  either: the one that finishes first now always clears its own
  oldest marker rather than an arbitrary one, so a still-running
  command's own fresher marker is never the one removed by mistake.
