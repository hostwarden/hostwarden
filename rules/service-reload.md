# Service Reload & Restart Policy

When the user asks Hostwarden to reload or restart a
service, this rule decides whether to run silently,
ask first, or refuse. The goal is to drop the noise
on truly low-risk operations (mainly
`systemctl reload` on things like nginx) while
keeping user control over anything that can drop
connections, lose state, or fail to come back up.

## Reload vs Restart

- **Reload** (`systemctl reload <svc>`,
  `nginx -s reload`, `service <name> reload`) tells a
  running service to re-read its config without
  dropping active connections or worker state. When
  the service supports it, reload is effectively
  zero-downtime and reversible.
- **Restart** (`systemctl restart <svc>`,
  `service <name> restart`) stops and starts the
  service. Connections drop, in-memory state is lost,
  and the restart can fail halfway (config bug,
  missing dependency, port still bound).

Prefer reload whenever the service supports it.

## Default Behavior

| Action                         | Default                              |
|--------------------------------|--------------------------------------|
| `reload <svc>`                 | auto-proceed                         |
| `restart <svc>`                | ask (with learn-this-choice options) |
| reboot / halt / poweroff       | always ask                           |
| service start (from stopped)   | always ask                           |
| failed reload or restart       | always surface, never auto-retry     |

Auto-proceed on reload requires ALL of:

- the command is `reload` (or
  `reload-or-restart` where only reload will
  execute), not `restart`.
- `<svc>` is NOT in the user's `reload-always-ask`
  list.
- we are not in read-only mode (already blocked by
  `rules/access-control.md`).
- the host is not blacklisted.
- a config test exists for the service and passes —
  see "Config Test Before Reload" below.
- the reload is not part of a firewall, SSH, or
  sshd config change (those always ask; see
  "Always Ask" below).

Auto-proceed on restart requires the service to be
explicitly listed in `restart-auto`. No heuristics.

## Config: `memory/service-policy.md`

Optional. Missing file = defaults apply. The format
mirrors `memory/blacklist.md` / `memory/readonly.md`
— plain markdown, three sections, one service name
per line, lines starting with `#` ignored.

```markdown
# Service Policy

## reload-always-ask
# Claude will ask before `systemctl reload` on these.
- postgresql

## restart-auto
# Claude may `systemctl restart` these without asking.
- nginx
- caddy

## restart-never
# Claude refuses to restart these outright, without
# prompting. Tell the user to do it manually or
# remove the entry.
- mariadb
```

Matching is by systemd unit name without the
`.service` suffix. For templated units, match the
full instance (`nginx@default`). No wildcards in v1.

On FreeBSD and macOS, match the `service` /
`brew services` / `launchctl` service name.

## Prompt Shape When Asking

When Hostwarden has to ask (restart not on
`restart-auto`, or reload on `reload-always-ask`),
offer these four options.

**Preferred (Claude Code):** use the
`AskUserQuestion` tool, so the user gets a real
selectable picker. **Fallback (any tool without
it):** print the ASCII form and wait for `1`, `2`,
`3` or `4` — same wording, same four answers, and
the same writes behind them. Never skip the
question because the picker is missing: this is
the approval step in front of a restart.

    Restart nginx on web1.example.com?
      [1] Yes, just this once
      [2] Yes, always — stop asking for nginx
      [3] No
      [4] No, never ask again for nginx

1. **Yes, just this once** — run the action now.
   Policy file unchanged.
2. **Yes, always (no more asking)** — run now, AND
   add the service to the right list:
   - restart → add to `restart-auto`
   - reload on `reload-always-ask` → remove from
     `reload-always-ask`
3. **No** — abort. Policy file unchanged.
4. **No, never ask again for this service** —
   abort, AND:
   - restart → add to `restart-never` (future
     restart requests for this service are refused
     outright).
   - reload → add to `reload-always-ask` (this option
     only appears if the reload was not already on
     the list).

After a write, confirm in one short line, e.g.
`Added nginx to restart-auto in memory/service-policy.md.`

### Write-Back Rules

- Preserve comments, blank lines, and section order.
- Only edit the specific list the answer affects.
- If `memory/service-policy.md` is missing, create
  it from `templates/memory/service-policy.md.example`
  with the one new entry added (and all commented
  examples intact).
- Deduplicate — never add a service already in the
  list.
- Never reorder or touch other sections.

## Config Test Before Reload

Before auto-proceeding a reload, run the service's
config test if one exists. Refuse the reload and
show the test output if it fails.

| Service        | Test command                       |
|----------------|------------------------------------|
| nginx          | `nginx -t`                         |
| caddy          | `caddy validate --config <file>`   |
| apache / httpd | `apachectl configtest`             |
| postfix        | `postfix check`                    |
| bind / named   | `named-checkconf`                  |
| sshd           | `sshd -t` (but sshd is "always ask" — see below) |
| haproxy        | `haproxy -c -f <file>`             |
| unbound        | `unbound-checkconf`                |
| Home Assistant | per install type, below            |

Home Assistant on a normal Linux host is restarted,
not reloaded, and the same test gates the restart.
The host's `memory.md` names the install type and
the values for the placeholders; where it does not,
ask the user rather than guess them:

```bash
# Container
docker exec <container> python -m homeassistant \
  --script check_config --config /config
# Supervised
ha core check
# Core, as the unit's User=
sudo -u <service-user> <venv>/bin/hass \
  --script check_config --config <config-dir>
```

The Container check is the one the Home Assistant
docs give:
https://www.home-assistant.io/common-tasks/container/#configuration-check

If no config test is known for the service, ask
the user before reloading — auto-proceed requires
a test that exists AND passes (see "Default
Behavior" above). A brief ask is fine; such
services are rare, since most daemons with reload
support ship a test.

## Always Ask (overrides auto-proceed)

Some reloads are too consequential to run silently,
even when the service is not in `reload-always-ask`:

- **sshd / ssh reload or restart.** A broken config
  can lock you out of the server. Always ask, even
  after `sshd -t` passes.
- **Firewall reloads** (`ufw reload`,
  `firewall-cmd --reload`, `pfctl -f`,
  `service pf reload`). A rule error can drop SSH.
  Always ask. Covered by the "firewall changes"
  rule in `AGENTS.md`.
- **Reload as part of a config change Hostwarden is
  making.** If Hostwarden just edited
  `/etc/nginx/...` in the same session, the
  reload is still auto-proceed (the user approved
  the edit; the reload is the natural next step).
  But if Hostwarden is reloading to pick up changes
  from an unknown source, ask first.
- **Starting a stopped service.** Auto-proceed
  only applies to reload/restart of a service that
  is currently active. Starting from stopped is
  "ask".

## On Failure

If an auto-proceeded reload or restart fails:

- Surface the full stderr / journal output.
- Do **not** auto-fallback to `restart` when
  `reload` fails — ask the user. A failed reload
  often means broken config; a blind restart can
  turn a degraded state into a down state.
- Offer to roll back the config file from the
  backup written per `rules/backups.md`.

## When the Agent Harness Blocks the Reload

Everything above is Hostwarden's **policy** layer: what
Hostwarden decides it should do. The agent harness
running Hostwarden has its own, independent
**permission** layer, and that one can refuse a
reload this rule file has already auto-approved.

Tell them apart by who says no:

- **Hostwarden** declines by explaining the policy
  ("nginx is on `reload-always-ask`").
- **The harness** declines with a permission error
  naming the tool call, e.g. Claude Code's
  "denied by the auto mode classifier".

They fail differently, so fix them differently. A
harness refusal is not something a rule file or an
override, global or per server, can lift —
editing `memory/service-policy.md` in response to
one changes nothing at all.

**In Claude Code**, note that `permissions.allow`
does NOT override the auto-mode classifier: a
session can carry `Bash(ssh *)` in its allow list
and still have `systemctl reload nginx` refused.
The classifier has its own key. Add to
`.claude/settings.json`:

```json
"autoMode": {
  "allow": [
    "$defaults",
    "Reloading/restarting services hostwarden administers, over ssh."
  ]
}
```

The literal `"$defaults"` entry is required — it
inherits the built-in rules. Omit it and you
replace the harness's own safety rules with just
your line.

This does not weaken Hostwarden's taboos. Those are
enforced by `.claude/hooks/guard-taboos.sh`, a
PreToolUse hook, and hooks run regardless of
permission mode; `permissions.deny` (halt,
poweroff, mkfs) likewise still wins over any allow.
Nor does it skip the gates above: Hostwarden still
runs the config test, still honours
`reload-always-ask` / `restart-never`, and still
asks before a restart that is not in
`restart-auto`. It only stops the harness blocking
the reload mechanically before Hostwarden's own policy
gets to decide.

**Why this matters more than it looks.** A blocked
reload does not leave the host untouched — it
leaves it *half-changed*. The new config is already
written to disk and the config test has already
passed; only the running process is stale. Any
later restart, a package upgrade, a logrotate
`postrotate`, or a reboot then applies a config
nobody has watched go live. Finishing the reload is
the safer end state than abandoning it, so surface
a harness refusal to the user immediately rather
than quietly moving on to the next task.

## Override Chain

Overrides work as `rules/overrides.md` describes, key
`service-reload`. What is local to this rule: the
policy lists themselves (`reload-always-ask`,
`restart-auto`, `restart-never`) are sections, so a
host can replace one on its own — under the `H1` that
names the subject, as `rules/overrides.md` writes it:

    # service-reload
    ## Replace: reload-always-ask

## Logging

Every auto-proceeded action still goes to the
changelog per `rules/changelog.md`:

```bash
logger -t hostwarden "Reloaded <svc> (auto, policy)"
logger -t hostwarden "Restarted <svc> (auto, policy)"
```

For asked actions, log the user's answer too:

```bash
logger -t hostwarden "Restarted <svc> (user: once)"
logger -t hostwarden "Restarted <svc> (user: always, added to restart-auto)"
```
