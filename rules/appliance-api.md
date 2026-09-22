# Appliance API Access

How Hostwarden reads and changes an appliance through its web API.
It is reached through the appliance files that have an API section,
never by detection; the appliance file names its accounts, roles,
menu paths, credential files, endpoints and error texts, and this
file holds the procedure they share. Where the two differ, the
appliance file says so by name.

## Access levels

- **Read** serves every API read, also where write access exists.
- **Write** is optional, the user decides whether it exists at all,
  and it serves only a change the user asked for and approved in
  this session.
- Each is its own account on the appliance, with the narrowest role
  the appliance offers for it, and its own credential file on the
  workstation (`rules/secrets.md` → API Credentials on the
  Workstation). Hostwarden names the file and its format; the user
  creates and fills it.
- The first read confirms each access. A login that fails, or a
  credential that answers `401` or `403`, is reported as such and not
  retried in a loop.
- **Never prove that read access cannot write by trying a write.**
  The role the user set on the appliance is the proof, and the user
  reads it back there.
- Record in server memory, paths and roles only:
  ```
  API read: <account> (<role>), ~/hostwarden-keys/<host>/<file>
  API write: <account> (<role>), ~/hostwarden-keys/<host>/<file>
  API path: ssh
  ```
  `API write: none` where the user wants read access only.

## Reaching the API

- **Over SSH**, where the appliance file allows it: curl runs on the
  appliance against its loopback address, and the workstation feeds
  the credential file to it on stdin. The credential never lands on
  the appliance's disk and never appears in `argv`, and the call
  works whatever the firewall allows towards the web UI. `-k` is
  fine there: the connection never leaves the host. Because stdin
  carries the credential, this is the one call that cannot use the
  `sh -s` bundle (`rules/ssh-connections.md` → Bundle commands): its
  command goes as the SSH argument.
- **From the workstation**: `API path: workstation` in memory, curl
  runs locally against `https://<host>`, with the certificate pinned
  as `rules/tls-pinning.md` describes. A session cookie jar goes in
  the scratch directory with mode 600 and is removed at the end of
  the session.
- An API that answers on plain HTTP only is a stop: the credential
  would cross the network in clear. Say so; the user turns HTTPS on
  in the appliance's settings.

## Reading

- **One call per task.** Everything a task reads — the housekeeping
  reads, the audit reads — goes into a single call, with one login
  where the appliance needs one. Each response is preceded by a
  JSON marker, `echo "{\"@\": \"<name>\"}"`, so the stream stays
  parseable, and a cookie jar lives in a `mktemp` file under
  `umask 077` that the same call removes on exit.
- **The workstation filters before anything reaches the
  conversation**: the filter in `rules/secrets.md` → API
  Credentials on the Workstation, with the appliance's own secret
  fields added to its pattern, then a projection to what the
  question needs. `jq -s` reads the stream as one array in which
  each marker precedes its response.
- A read that fails is a check that did not run, never a clean
  result. An unknown field or a `404` is a fact to report; never
  guess another endpoint or field in its place.

## Writing

- **Only with write access, only after asking**, and only for what
  the user asked for. Show the method, the path and the body, and
  name everything the change reaches.
- Look the endpoint and its body up in the API reference for the
  installed version before the call (`AGENTS.md` → Verify Before
  Running).
- **Back up the object first** (`rules/backups.md` → State behind
  an API).
- **The body goes from a file**: `--data @<file>`, never inline.
  Over SSH, stdin already carries the credential, so the body is
  copied first with `scp` to `/tmp/hostwarden-<object>.json` on the
  host, and the call removes it afterwards. A body that carries a
  secret is written by the user, never by Hostwarden, and goes from
  the workstation.
- **A change that can touch the way in** — a firewall rule, a
  network or interface setting, the SSH service — falls under
  `rules/ssh-safety-net.md`. An API change applies at once and has
  no timed revert unless the appliance file names one; without one,
  the user applies the change in the UI with a second way in ready,
  and Hostwarden reads the result back.
- Read the object back after the change and compare it with what
  was meant.
