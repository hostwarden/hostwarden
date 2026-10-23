### Added

- **A fault is diagnosed in a fixed order.** A new rule has the
  session show the exact symptom with a read-only command, list
  three to five ranked causes for you to correct before it changes
  anything, test one change at a time with its undo decided first,
  and treat a raised log level as a change that is asked for, tagged
  and removed afterwards. The confirmed cause and its evidence go into
  the changelog entry.
