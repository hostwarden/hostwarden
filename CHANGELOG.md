# Changelog

The notes of this release only. Earlier releases: the `CHANGELOG.md`
at their tag, or
[GitHub Releases](https://github.com/hostwarden/hostwarden/releases).

## 1.1.0 - 2026-09-26

### Added

- **A new workspace is asked once where it lives: on a private remote
  or on this machine only.** `bin/hostwarden-init` asks in a terminal,
  and the first session asks where that was left open: publish to a
  new private repository, join an existing workspace, keep it local,
  or not now. `bin/hostwarden-init --remote <url> --create` refuses a
  repository anyone can read or one that already holds commits,
  creates a missing GitHub repository private with gh or says how to
  create it, then commits and pushes the workspace. `--clone` now also
  takes the place of a workspace nothing has been written to yet, and
  `--local` records `Workspace remote: none`.
- **`bin/hostwarden-group` prints what several hosts returned, each
  answer once.** The hosts that gave the same answer share one
  block, section by section, so a fleet that agrees reads in a few
  lines.
- **Every release tag has a GitHub release.** Its notes link to the
  version's section of CHANGELOG.md at the tag; a checkout still
  updates from the signed tag.

### Changed

- **Work on several hosts runs from the session, every host at
  once.** A question, a change or the fleet audit reaches all hosts
  in one call per round, so a follow-up builds on the last answer,
  and no subagent starts per host. Housekeeping or a security audit
  on more than four hosts still runs in subagents of up to four.
  `Multi-host: agents` in `memory/user.md` sends questions and
  skills to subagents.
- **After an update, the session shows what every release in between
  brought and asks before going on.** The update lists the lead
  clause of each entry, grouped by version, from the `CHANGELOG.md`
  at each release's tag, and the session asks whether to go on
  before any server work; the full text is there on request. A run
  no person answers, such as `claude -p` or the operations host's
  nightly run, asks nothing and goes on; the nightly run writes the
  list to the timer's log.
- **Onboarding several hosts asks what belongs to a site once per
  site.** The questions wait until every host of the run is probed;
  the site, its uplink, what filters in front of the hosts, how a
  machine is reached when SSH is gone and a backup the hosts cannot
  see are then asked once for the hosts of a site, naming each, and
  every host's memory records the answer. Hosts that share a range
  are asked their site together.
- **The multi-host subagent runs on Opus, whatever the session runs
  on.** `hostwarden-host-task`, which carries housekeeping, security
  audits and, where the user asks for it, questions to groups of
  hosts, runs at medium effort. It inherited the session's model and
  effort before.
- **`CHANGELOG.md` holds only the notes of its own release.** An
  earlier release's notes are the `CHANGELOG.md` at its tag, which
  its GitHub release links to; the file's head says so.

### Fixed

- **Coordination sees every line of a multi-line command.** The
  presence and impact hooks read only the first line's host, and
  charged that host with what the later lines did; each line's host
  is now tracked and checked on its own.
- **A reboot piped into the far shell is checked.** A `printf` or
  `echo` piped into `ssh host 'sh -s'` now counts as that host's
  commands, the way a heredoc body already did, so the impact hook
  asks for an announcement before it.
- **The off switch keeps judging the line after a heredoc.** With
  the guard off toward one host, a command on the line after a
  heredoc sent to that host was dropped with it, unjudged; it is
  now judged like any other local command.
- **A Proxmox VE VM's guest agent gets small calls with a
  timeout.** Every `qm guest exec` names its timeout and carries at
  most 2 KiB of script, so a large bundle is split rather than sent
  in one call that could leave the agent answering nothing. A call
  whose timeout ran out is read back instead of sent again, and a VM
  whose agent stops answering is reported, never restarted without
  asking.
- **A workspace commit takes a removed file with the rest.**
  `bin/hostwarden-sync commit` failed when a named path had already
  left the index, by `git rm` or as the old name of a `git mv`, so a
  host's removals needed a commit of their own; they now go in the
  host's one commit, and a path the workspace never held is named
  and skipped.
- **Heinzel's memory, masters and notes keep their bytes.** The
  Markdown rewrap after each command and each workspace commit no
  longer rewraps or lists a host's `heinzel-memory.md`, a master
  under `files/`, its sources under `src/` but their `README.md`, a
  note, or what a Heinzel takeover copied beside `heinzel-memory.md`
  until the host's first connection.
- **A map's host links open in the whole window.** Clicking a node in
  a diagram Forgejo shows loaded the host's memory page inside the
  diagram's frame; the link now replaces the page instead.
