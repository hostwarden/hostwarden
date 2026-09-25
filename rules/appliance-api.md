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
  creates and fills it. Where the appliance splits a write from a
  separate apply, reconfigure or commit call, the role names both:
  scoped to the write alone, the write can succeed while the call
  that makes it take effect is denied, and the appliance keeps
  answering the old state with nothing to say so.
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
  `API write: none` where the user wants read access only. Where the
  read never uses this API at all — an appliance file that reads over
  SSH instead — there is no `API read:` line, only `API write:`; a
  parenthetical after `write` names what the account covers where it
  reaches one function rather than everything the appliance offers,
  e.g. `API write (DNS host overrides): <account> (<role>), <file>`.

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
- **Every answer is followed by its own marker**, a JSON line naming
  the request, how it went, and the call's nonce; a marker printed
  before the request would count a read that never came back as
  done. The workstation draws a new nonce for every call, just
  before it:

  ```
  nonce=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
  ```

  The nonce, the call and the filter below run in one shell
  command: a nonce drawn in an earlier one is empty here, and the
  filter stops on it. It goes into no URL, header or body the API
  receives, so no answer can carry it, and the appliance cannot know
  it before the call.
  It is no secret: an appliance that reads it from its process list
  to forge a marker could as well lie in its answers.
  curl writes the marker, on a failed connection too, with the code
  `000`. The same double-quoted form serves locally and inside the
  single-quoted SSH argument:

  ```
  -w "\n{\"@\": \"<name>\", \"code\": \"%{http_code}\", \"n\": \"$nonce\"}\n"
  ```

  Over SSH the nonce is set by an argument of its own in front of
  the single-quoted command, which the remote shell runs joined to
  it: `ssh … "nonce=$nonce;" '<command>'`. A command on the host
  writes its own marker in a `sh -s` bundle, which takes the nonce
  as its argument, `ssh … sh -s "$nonce" <<'EOF'`, and sets
  `nonce=$1` in its first line; the marker carries the command's
  exit status:

  ```
  <command>; printf '\n{"@": "%s", "code": "%s", "n": "%s"}\n' <name> "$?" "$nonce"
  ```

  `<command>` is the command itself, never a pipeline, whose `$?`
  would be its last stage's. The code is quoted, so `000` stays
  `000` instead of the number 0. The answer goes to stdout as it
  comes, however many lines it takes, and never to a file on the
  appliance, where a response that carries a Wi-Fi key or a VPN
  secret would outlive the call (`rules/secrets.md`).
- Leave `-f` off: it drops the body an error explains, and one
  request's exit status does not reach the caller of a batch.
- **A credential on stdin serves exactly one curl process.** With
  `-H @-` the first request consumes it and every later one would go
  out unauthenticated, so a batch that authenticates by credential
  is **one** curl invocation with several URLs after it: `-w` runs
  for each, and `%{url_effective}` as the marker's name says which
  answer it closes. `-o` cannot split them: its `#1` fills in only
  from a globbed URL.
- **The workstation frames the answers by their markers, not by
  lines**: everything between two markers is one answer, however
  many lines it took, joined before it is parsed. A line is a
  marker only when it is a JSON object whose `n` is this call's
  nonce; a line an answer forges stays part of that answer. `want`
  lists the markers' names in the order the requests go out:

  ```
  jq -Rn --arg n "$nonce" --argjson want '["<name>", …]' '
    if $n | test("^[0-9a-f]{16}$") then . else error("no nonce") end
    | [inputs] as $l
    | [range($l | length) as $i
       | select($l[$i] | startswith("{\"@\"")
           and ((fromjson? | objects | .n == $n) // false))
       | $i] as $m
    | [range($m | length) as $i
       | ($l[(if $i == 0 then 0 else $m[$i-1] + 1 end):$m[$i]]
          | add // "") as $t
       | (if $t == "" then empty else $t | try fromjson
          catch {not_json: true, bytes: ($t | utf8bytelength)} end),
         ($l[$m[$i]] | fromjson
          | if .["@"] == $want[$i] then . else . + {want: $want[$i]} end)]
      + [{missing: $want[$m | length:]} | select(.missing != [])]'
  ```

  It reads the stream once and slices it: an answer rebuilt line by
  line takes minutes once it reaches megabytes. What comes out is
  an array in which every answer is followed by its marker, a
  request whose body was discarded contributes its marker alone,
  and a last `{"missing": [...]}` names every request whose marker
  never came. A marker that carries `want` has another name than
  the request expected in its place: the call was built wrong, and
  the request `want` names counts as missing.
  Then, before anything reaches the conversation, the filter in
  `rules/secrets.md` → API Credentials on the Workstation, with the
  appliance's own secret fields added to its pattern, and a
  projection to what the question needs. **A body that is not JSON
  is never forwarded**, only counted: an error page can echo the
  request back, and a key-name filter cannot redact a secret inside
  a string. Its marker's `code` is what the report names; where the
  body itself is the question, the user reads it on the appliance.
- **A task is only done when every marker it expected came back.**
  `jq` accepts an empty stream, so an SSH login that fails, a
  connection that drops or a shell that never starts would
  otherwise end in a clean-looking empty result. Every name under
  `missing` or in a marker's `want` is a check that did not run,
  and the local pipeline runs under `set -o pipefail` so the
  transport's exit status is not swallowed by `jq`.
- **A read that fails is a check that did not run**, never a clean
  result: a marker whose `code` is not 2xx, or not `0` for a
  command, is reported by name. A failed login means nothing after
  it was read. `401` and `403` are the credential being rejected;
  `429`, a `5xx`, a `404` or `000` are a rate limit, the appliance,
  a wrong path or no connection: report the code as it came, and
  never ask for a new credential over one of those. An unknown
  field or a `404` is a fact to report; never guess another
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
