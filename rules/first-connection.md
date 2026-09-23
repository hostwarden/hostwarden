# First-Connection Checklist

The ordered pipeline that runs on **every** remote
connection — and on every local-mode session, with
the remote-only steps skipped — before any
user-requested command.

When the pipeline will visibly delay the answer to a
one-liner, say so up front ("first-contact
onboarding on this host — one moment") rather than
skip it.

## Order

1. **Blacklist check.** Refuse if listed. See
   `rules/access-control.md`.
2. **Read-only check.** Switch to read-only mode if
   listed. See `rules/access-control.md`.
3. **SSH user lookup** (first connection only). See
   `rules/ssh-user.md`. It comes before the DNS check
   because the alias comparison reads the port for
   this user.
4. **DNS check.** New hostname (no
   `memory/servers/<hostname>/` yet): run alias
   detection. Known hostname: verify the current IP
   still matches the `- IP:` field in server memory.
   See `rules/dns-aliases.md` for both.
5. **OS detection.** See `rules/os-detection.md`.
6. **Server memory file.** Create on first
   connection, read on every subsequent connection.
   See `rules/server-memory.md`. A first connection
   is one to a host with no `memory.md` yet. That
   includes a host adopted from Heinzel, whose
   directory holds Heinzel's `heinzel-memory.md`
   instead: its `memory.md` is written as
   `rules/heinzel-adoption.md` → Heinzel's memory
   says.
7. **Activity check.** Every connection, not just
   the first. See `rules/activity-check.md`; what
   else goes into its call, and on which connection,
   is `rules/activity-check.md` → What rides in this
   call.
8. **Heinzel legacy check.** Only in an installation
   that has something to do with Heinzel: an
   `Adopted from heinzel:` line in `memory/user.md`,
   a `heinzel legacy:` line or an unresolved
   `heinzel-inventory.md` in this host's memory, or
   `heinzel` entries in the activity check above —
   that last one catches a host Heinzel touched even
   though this installation never ran it. Otherwise
   skip the step and read nothing.

   When it does apply: first connection, plus every
   connection while a `deferred` line or an
   unresolved inventory is there, and whenever the
   user asks for it. One batched probe, silent unless
   it finds something, in step 7's call where possible
   (`rules/activity-check.md` → What rides in this
   call). See `rules/heinzel-legacy.md`.
9. **Then** execute the user's request.

## Local mode

In local mode (`localhost`, the user's own
hostname), skip steps 1–4 — blacklist, read-only
list, SSH user and DNS check are remote-only. Still
run OS detection, server memory, activity check, and
the Heinzel legacy check — on the workstation the
latter looks at scheduled runs instead of backup
directories (`rules/heinzel-adoption.md`).

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
…
EOS
```

The heredoc needs stdin; for `qm guest exec`, bundle
into one `sh -c '…'` argument instead.

## Why it's mandatory

Skipping steps has caused real incidents: stale
memory files masking ownership changes, activity
checks missing concurrent teammate work, and
blacklisted hosts getting commands they should
never receive. The overhead of a few extra commands
is acceptable; silent skipping is a bug.
