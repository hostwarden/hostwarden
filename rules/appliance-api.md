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
- **The write account exists only where the user asked for write
  access.** Read access is set up on its own; with `API write:
  none` no privileged account and no long-lived key are created at
  all.
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
  where the appliance needs one, and a cookie jar in a `mktemp` file
  under `umask 077` that the same call removes on exit.
- **Every response carries its own marker and status**, written by
  curl itself so a failed request cannot pass as a missing one:

  ```
  -w '\n{"@": "<name>", "code": %{http_code}}\n'
  ```

  Leave `-f` off when the marker is what reports the failure: `-f`
  drops the body an error explains, and the exit status of one
  request in a batch does not reach the caller. A marker whose
  `code` is not 2xx is a check that did not run.
- **A credential on stdin serves exactly one curl process.** With
  `-H @-` the first request consumes it and every later one would go
  out unauthenticated, so a batch that authenticates by credential
  is **one** curl invocation with several URLs after it; the header
  and `-w` apply to each, and `%{url_effective}` in the marker names
  which response is which. A batch behind a session cookie may use
  one curl per endpoint: only the login reads stdin.
- **The workstation filters before anything reaches the
  conversation**: the filter in `rules/secrets.md` → API
  Credentials on the Workstation, with the appliance's own secret
  fields added to its pattern, then a projection to what the
  question needs. **Read the stream line by line, not as one
  document**: an error page is HTML, and a single `jq -s` over the
  whole stream then aborts on it and loses the markers that say
  which request failed.

  ```
  jq -Rn '[inputs | . as $l | try fromjson
    catch {"not_json": true, "bytes": ($l | length)}]'
  ```

  Each response and each marker is one line, so what survives is an
  array in which every response is followed by its marker. **A body
  that is not JSON is never forwarded**, only counted: an error page
  can echo the request back, and a key-name filter cannot redact a
  secret inside a string. Its marker's `code` is what the report
  names; where the body itself is the question, the user reads it on
  the appliance.
- **A task is only done when every marker it expected came back.**
  `jq` accepts an empty stream, so an SSH login that fails, a
  connection that drops or a shell that never starts would
  otherwise end in a clean-looking empty result. Count the markers
  against the requests sent, run the local pipeline under
  `set -o pipefail` so the transport's exit status is not swallowed
  by `jq`, and report a missing marker as a check that did not run.
- A read that fails is a check that did not run, never a clean
  result: report every marker whose `code` says so, by name. An
  unknown field or a `404` is a fact to report; never guess another
  endpoint or field in its place.

## Writing

- **Only with write access, only after asking**, and only for what
  the user asked for. Show the method, the path and the body, and
  name everything the change reaches. A body that carries a
  credential is shown through the filter in `rules/secrets.md` → API
  Credentials on the Workstation, so the user sees which fields the
  call sets and never their values.
- Look the endpoint and its body up in the API reference for the
  installed version before the call (`AGENTS.md` → Verify Before
  Running).
- **Back up the object first** (`rules/backups.md` → State behind
  an API).
- **The body goes from a file**: `--data @<file>`, never inline.
  **A body that carries a secret** — a Wi-Fi passphrase, a VPN key
  — is written by the user, never by Hostwarden, and goes from the
  workstation, where it never leaves the credential file's
  directory. Over SSH one stdin cannot carry both the credential
  and the body, so such a write takes the workstation path with its
  pin (`rules/tls-pinning.md`) even where memory records
  `API path: ssh`. Without a pin recorded, read one first; where
  the appliance is not reachable from the workstation at all, say
  so and leave the change to the user's UI.
- Over SSH, stdin already carries the credential, so a body without
  a secret in it is copied first with `scp` into a root-only
  scratch directory — `install -d -m 700 /root/hostwarden-scratch`
  and a unique file name, never `/tmp`, where
  `fs.protected_regular` lets a same-named file owned by another
  user make the write fail silently (`rules/secrets.md`). The call
  that follows removes it in an exit trap. **When that call never
  starts** — the login fails, the connection drops — the copy is
  removed in a call of its own before anything else; if that fails
  too, tell the user the path to delete.
- **A change that can touch the way in** — a firewall rule, a
  network or interface setting, the SSH service — falls under
  `rules/ssh-safety-net.md`. An API change applies at once and has
  no timed revert unless the appliance file names one; without one,
  the user applies the change in the UI with a second way in ready,
  and Hostwarden reads the result back.
- Read the object back after the change and compare it with what
  was meant.
