# First-Connection Checklist

The ordered pipeline that runs on **every** remote
connection — and on every local-mode session, with
the remote-only steps skipped — before any
user-requested command.

When the pipeline will visibly delay the answer to a
one-liner, say so up front ("first-contact
onboarding on this host — one moment") rather than
skip it.

The host is the name without a port, a user or a
scheme written with it (`rules/ssh-config.md` → A
Port the User Names).

## Order

A host named without a dot goes through
`rules/dns-aliases.md` → Short Names Matching More
Than One Server before step 1.

1. **Blacklist check.** Refuse if the host or one of
   its jump hosts is listed; ask first where its jump
   path cannot be read. See
   `rules/access-control.md`.
2. **Read-only check.** Switch to read-only mode if
   listed. See `rules/access-control.md`.
3. **SSH user lookup** (first connection only). See
   `rules/ssh-user.md`. It comes before the DNS check
   because the alias comparison reads the port for
   this user. A port the user named for a new host
   goes into `memory/ssh_hosts` first
   (`rules/ssh-config.md` → A Port the User Names),
   so this step's `ssh -G` shows it. Once the user is
   chosen, compare the `hostname` line of its
   `ssh -G` output and the jump hosts it gives
   (`rules/access-control.md` → Server Blacklist)
   with those steps 1–2 read, never with a default
   this step has just written: `%r` alone can change
   a jump host. Where one differs, rerun the
   blacklist check for the target as the chosen user
   and for each hop as its own login user, and the
   read-only check for the target, before any SSH
   call. A port that differs is step 4's.
4. **DNS check.** New hostname (no
   `memory/machines/<hostname>/` yet): run alias
   detection. Known hostname: verify the current IP
   still matches the `- IP:` field in machine memory.
   See `rules/dns-aliases.md` for both. Then, before
   the session's first SSH call to the host, look its
   key up in `memory/known_hosts`, and get it first
   where it is missing: `rules/host-keys.md`. A new
   host whose first call fails without an answer from
   sshd: `rules/ssh-config.md` → Finding the Port.
5. **OS detection.** See `rules/os-detection.md`.
6. **Machine memory file.** Create on first
   connection, read on every subsequent connection.
   See `rules/machine-memory.md`. With it, read the
   user's decisions that apply to the host: its
   `decisions.md`, its cluster's, and each file under
   `memory/decisions/` whose `Applies to:` line
   selects it by the `memory.md` just read or written
   (`grep -sH '^Applies to:' memory/decisions/*.md
   || true` runs beside the `memory.md` read, and
   succeeds silently where there is no such file; the
   cluster file and the matching group files follow in
   one read). Most hosts have none, and their absence
   is never worth a line. Where one applies, read
   `rules/decisions.md` before proposing anything or
   rating a finding. A first connection
   is one to a host with no `memory.md` yet; where
   its directory holds `heinzel-memory.md`, read
   `rules/heinzel-takeover.md` → Heinzel's memory.
7. **Activity check.** Every connection, not just
   the first. See `rules/activity-check.md`; what
   else goes into its call, and on which connection,
   is `rules/activity-check.md` → What rides in this
   call.
8. **Heinzel legacy check.** Only in an installation
   that has something to do with Heinzel: a
   `Taken over from heinzel:` line in `memory/user.md`,
   a `heinzel legacy:` line or an unresolved
   `heinzel-inventory.md` in this host's memory, or
   `heinzel` entries in the activity check above —
   that last one catches a host Heinzel touched even
   though this installation never ran it. Otherwise
   skip the step and read nothing.

   When it does apply: first connection, plus every
   connection while a `deferred` line, an unresolved
   inventory or an unverified entry in the host's or
   its cluster's `deployed.md`
   (`rules/deployed-files.md` → Unverified entries) is
   there, and whenever the
   user asks for it. One batched probe, silent unless
   it finds something, in step 7's call where possible
   (`rules/activity-check.md` → What rides in this
   call). See `rules/heinzel-legacy.md`.
9. **Finishing onboarding.** A guest whose memory has
   `SSH: untested` finishes onboarding on its first
   connection through its own way in
   (`rules/machine-memory.md` → Onboarded and stale
   lines), before the request, whatever it is:
   `hostwarden-onboard` → The first own login. Not
   inside a run of that skill, whose own steps 4 to 6
   do this work.
10. **Then** execute the user's request.

## Local mode

In local mode (`localhost`, the user's own
hostname, and never with a port written after
either: `rules/ssh-config.md` → A Port the User
Names), skip steps 1–4 — blacklist, read-only
list, SSH user, DNS check and host key are
remote-only. Before OS detection, resolve the machine's own name for its memory
directory (`rules/machine-memory.md`), never the word that triggered local mode.
Only once the directory is settled do OS detection, machine memory, activity
check, the Heinzel legacy check and finishing onboarding run — on the
workstation the latter looks at scheduled runs instead of backup directories
(`rules/heinzel-takeover.md`).

Nothing in local mode opens an SSH connection to the machine itself, not even
to see whether it runs its own sshd: that stays a local-only read, like every
other local-mode step here.

## Via-host mode

A system container or VM reached through its
hypervisor host's manager instead of its own SSH.
When it applies: `rules/system-containers.md` →
Reaching It. The guest's `Runs on:` line names the
host to go through, on a cluster the member it was
last on, and the ID to enter, the Incus or LXD
project and, on a host with more than one manager,
the manager included (`rules/hypervisors.md` →
Linking Guest and Host). The command is that
manager's line in `rules/system-containers.md` →
Reaching It. Where `Runs on:` is missing or names no
managed host and ID, do not enter the guest: ask the
user which host and ID it has, and write `Runs on:`
from the answer.

The connection to the host runs this pipeline for
the host. For the guest, check the blacklist and the
read-only list by its own name as well: the guest is
read-only when it or its host is on the read-only
list. Skip steps 3–4, and run the rest inside the
guest, bundled into one call per step
(`rules/ssh-connections.md`):

```bash
ssh … root@pve1.example.com 'pct exec 105 -- sh -s' <<'EOS'
export LC_ALL=C
…
EOS
```

The heredoc needs stdin; for `qm guest exec`, bundle
into one `sh -c 'export LC_ALL=C; …'` argument
instead.

## Why it's mandatory

Skipping steps has caused real incidents: stale
memory files masking ownership changes, activity
checks missing concurrent teammate work, and
blacklisted hosts getting commands they should
never receive. The overhead of a few extra commands
is acceptable; silent skipping is a bug.
