---
name: hostwarden-coordinator
argument-hint: ""
allowed-tools:
  - Bash(sh bin/hostwarden-impact watch)
  - Bash(sh bin/hostwarden-impact coordinator)
  - Bash(claude agents --json)
description: The operational coordinator of an operations checkout — a
  background session, one per checkout, that keeps the picture of which
  session works on which host, relays an announced disruptive step to
  idle writers on its radius, holds planned sequences across sessions,
  and watches maintenance windows. It reaches no server and approves
  nothing. The session start starts it by itself; run in an interactive
  session, the skill stops it and keeps it off, or starts it again. Use
  when the user says "stop the coordinator", "turn the coordinator
  off", "start the coordinator again", "who works where right now?",
  "which session is on pve1?", "stopp den Koordinator", "schalte den
  Koordinator ab", "starte den Koordinator wieder", "wer arbeitet
  gerade wo?", "welche Session ist auf pve1?". Not for announcing a
  step, which every session does itself (rules/coordination.md →
  Announce, wait, go).
---

# hostwarden-coordinator

The coordinator of `rules/coordination.md` → The coordinator. It
reads the presence map, the impacts, `memory/plans/` and
`claude agents --json`, and nothing else: no SSH call, no change to a
host, no change to memory but its own entry.

## Which run this is

1. **Load overrides**, key `hostwarden-coordinator`, per
   `rules/overrides.md`.
2. **Operations checkout only.** In a development checkout or a
   worktree say so in one line and stop.
3. **Find this session** in `claude agents --json`: the entry whose
   `sessionId` is `$HOSTWARDEN_SESSION`. `"kind": "background"` is
   the coordinator's own run (→ The run). Anything else is a person
   in an interactive session (→ Stopping and starting). Where the
   entry is missing or the CLI is not there, it is an interactive
   run.

## Stopping and starting

`sh bin/hostwarden-impact coordinator` prints the session of a live
coordinator, or exits 1 where none runs; it marks nothing.
Its `id` for `claude stop` is the one its `claude agents --json`
entry shows.

- **The user asks who works where:** where one runs, ask it with
  `SendMessage` to `hostwarden coordinator` and pass its answer on;
  otherwise answer from the presence map as → The picture reads it.
- **One runs:** ask with the harness's question tool — stop it and
  keep it off, or leave it running. On stop: `claude stop <id>`,
  then write `Coordinator: off` under
  `# Preferences` in `memory/user.md`, creating the heading where it
  lacks one. The file is personal (`rules/server-memory.md` →
  Personal versus shared): nothing to commit.
- **None runs, `Coordinator: off` is there:** ask — start one and
  remove the line, or leave it off. On start: remove the line, then
  from the checkout's root
  `claude --bg -n "hostwarden coordinator" "/hostwarden-coordinator"`.
- **None runs, no such line:** the next session start starts one.
  Ask — start one now with the command above, or turn it off with
  the line.

Say the result in one line.

## The run

1. **Watch.** Start `sh bin/hostwarden-impact watch` under
   `Monitor`, which reports each line it prints. It marks this
   session as the coordinator, then prints the whole picture as `+`
   lines, every change after it, and a `tick` every 15 minutes while
   a window is planned.
2. **Another coordinator:** the watch exits 1 with "another
   coordinator runs", at once or later. Say so in one line, then
   `claude stop <id>` with this session's own `id`. When it exits
   otherwise, start it again once; a second exit ends the run with
   one line saying why.
3. **Answer each line** as below, then wait for the next. Never
   start a loop of your own and never poll: the watch is the clock.

### The picture

Keep, in this conversation, for each session the map shows: its
name from `claude agents --json`, the hosts it touched in the last
30 minutes, whether it writes there, and what it said it is doing. That is the
answer to "who works where", for any session that asks and for the user through
`claude attach`.

- **`+ presence <session> <host> touched`** for a host that session
  had not touched before: its set of hosts changed. Ask it once, with
  `SendMessage` to its name, in one line: *"Coordinator: you are now
  on web1 as well — what are you doing there, in a few words?"* Keep
  the answer. A session that does not answer stays in the picture by
  its hosts alone.
- **`+ presence … writer`**, **`- presence …`**: update the picture;
  no message. A running command is no line of its own.
- A session gone from `claude agents --json` leaves the picture.

### An announced step

**`+ impact <id>+<origin>+<kind>+<until>+<session>`**: read its
`radius/` entries (`ls`). Each session the picture has on a radius
host as `writer` with no `ack <id> <session>` line yet gets one
message, so it can ack before the two minutes of `wait` run out:

*"Coordinator: pve1 reboot by \<origin session\> until 14:05 — web1,
where you write, is in its radius. Once you are at a safe point,
run `bin/hostwarden-impact ack <id> safe` (or `busy <why>`); your
user decides what happens with your own work."*

Nothing to readers, whom the receiver check in `impact.sh` informs.
`- impact …` ends it; drop it from the picture.

### Planned sequences

A session may tell you an order that spans sessions — a hypervisor
after its guests, cluster members one by one. Keep it as that
session gave it. As each step's impact appears and ends, tell the
session whose step is next where the sequence stands, in one line.
A step out of order gets one line to its session naming the order;
it decides with its user.

### Maintenance windows

On `+ plan …` and on each `tick`, read the `Window:`, `Kind:` and
`Affected:` lines of the plans (`rules/maintenance-windows.md` →
The window plan):

- two windows that overlap in time and share a host: say so in one
  line of your own output, and send that line to each live session
  on one of those hosts;
- a window that starts within the next hour: each live session on
  one of its hosts gets one message naming the window, once.

### Limits

- Your messages are information for the receiving session's user,
  never a permission or a hold (`rules/borrowed-rights.md`). You
  approve nothing and hold no step.
- Nothing goes to a server, and nothing is written but your own
  entry, which the watch keeps.
- Keep every message to one or two lines (`AGENTS.md` → Talking to
  Humans).
