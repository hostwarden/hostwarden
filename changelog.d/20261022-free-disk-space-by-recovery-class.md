### Added

- **Freeing disk space sorts every candidate by what it takes to get
  it back.** The agent measures first and reports sizes per class.
  Package caches go as one group with one question. Build caches
  are proposed with their cost. User data, volumes, log files and mail
  are never proposed for deletion. Snapshots, old kernels and
  journal history are each a question of their own, because
  removing them closes a rollback or an audit trail.
