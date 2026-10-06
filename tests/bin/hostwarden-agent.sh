#!/bin/sh
# Local-only fixtures: no server connections and no real agent identities.
cd "$(dirname "$0")/../.." || exit 2
REPO=$(pwd -P)
. "$REPO/tests/helpers.sh"
test_tmp agent
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p "$TMP/ops space/bin" "$TMP/ops space/lib" "$TMP/ops space/memory" "$TMP/tools"
cp bin/hostwarden-agent "$TMP/ops space/bin/"
cp lib/ssh-agent.sh lib/mode.sh "$TMP/ops space/lib/"
cp bin/hostwarden-sync bin/hostwarden-ssh-config "$TMP/ops space/bin/"
HW_AGENT_ROOT="$TMP/ops space"
export HW_AGENT_ROOT
. "$REPO/lib/ssh-agent.sh"
cat > "$TMP/tools/ssh" <<'SH'
#!/bin/sh
[ "$1" = -G ] || exit 99
[ "$2" = git.example.com ] && { echo 'identityagent /host-specific.sock'; exit; }
[ "${MOCK_SSH_FAIL:-0}" = 0 ] || exit 1
[ -z "${MOCK_AGENT:-}" ] || printf 'identityagent %s\n' "$MOCK_AGENT"
exit 0
SH
cat > "$TMP/tools/ssh-add" <<'SH'
#!/bin/sh
[ "${MOCK_ADD_REAL:-0}" = 0 ] || exec "$ORIGINAL_ADD" "$@"
[ "$1" = -l ] || exit 99
[ "$SSH_AUTH_SOCK" = "$EXPECTED_SOCKET" ] || exit 99
exit "${MOCK_ADD_RC:-0}"
SH
chmod +x "$TMP/tools/ssh" "$TMP/tools/ssh-add"
ORIGINAL_ADD=$(command -v ssh-add)
export ORIGINAL_ADD
PATH=$TMP/tools:$PATH
export PATH
SSH_AUTH_SOCK=/inherited.sock
export SSH_AUTH_SOCK
resolve() { sh "$TMP/ops space/bin/hostwarden-agent" "$@" --socket; }
expect() {
  got=$(resolve "$@") && [ "$got" = "$want" ] && ok || bad "expected $want, got $got"
}
contains_upstream() {
  git -C "$HW_AGENT_ROOT/memory" merge-base --is-ancestor \
    "$(git -C "$1" rev-parse HEAD)" HEAD
}
want=/inherited.sock; expect
MOCK_AGENT='/config with spaces.sock'; export MOCK_AGENT
want=$MOCK_AGENT; expect
want=/host-specific.sock; expect --host git.example.com
printf 'SSH agent socket: ~/agent with spaces.sock\n' > "$HW_AGENT_ROOT/memory/user.md"
want=$HOME/'agent with spaces.sock'; expect --host git.example.com
printf 'SSH agent socket: /trimmed.sock \t\n' > "$HW_AGENT_ROOT/memory/user.md"
want=/trimmed.sock; expect
printf 'SSH agent socket: none\n' > "$HW_AGENT_ROOT/memory/user.md"
want=; expect
printf 'SSH agent socket: SSH_AUTH_SOCK\n' > "$HW_AGENT_ROOT/memory/user.md"
want=$SSH_AUTH_SOCK; expect
printf 'SSH agent socket: /one\nSSH agent socket: /two\n' > "$HW_AGENT_ROOT/memory/user.md"
resolve 2>/dev/null && bad duplicate || ok
printf 'SSH agent socket:\n' > "$HW_AGENT_ROOT/memory/user.md"
resolve 2>/dev/null && bad empty || ok
printf 'SSH agent socket: $(touch /should-not-exist)\n' > "$HW_AGENT_ROOT/memory/user.md"
resolve 2>/dev/null && bad expression || ok
rm "$HW_AGENT_ROOT/memory/user.md"
MOCK_AGENT=none; want=; expect
MOCK_AGENT=SSH_AUTH_SOCK; want=$SSH_AUTH_SOCK; expect
MOCK_AGENT='$SSH_AUTH_SOCK'; expect
# shellcheck disable=SC2088 # fixture is deliberately an unexpanded tilde
MOCK_AGENT='~/config socket'; want=$HOME/'config socket'; expect
MOCK_AGENT='%d/socket'; resolve 2>/dev/null && bad tokens || ok
MOCK_AGENT=; MOCK_SSH_FAIL=1; export MOCK_SSH_FAIL
resolve 2>/dev/null && bad 'config failure fell back' || ok
MOCK_SSH_FAIL=0
MOCK_AGENT=/missing.sock
sh "$TMP/ops space/bin/hostwarden-agent" --check 2>/dev/null && bad missing || ok
# A real Unix socket proves the file-type check; mock only the agent protocol.
EXPECTED_SOCKET=$TMP/'agent socket'
export EXPECTED_SOCKET
TEST_AGENT_PID=$(ssh-agent -a "$EXPECTED_SOCKET" |
  sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p')
MOCK_AGENT=$EXPECTED_SOCKET
sh "$TMP/ops space/bin/hostwarden-agent" --check && ok || bad ready
# Preserve the command's argv, socket and exit status; never evaluate output.
got=$(sh "$TMP/ops space/bin/hostwarden-agent" --exec sh -c \
  'printf "%s|%s" "$SSH_AUTH_SOCK" "$1"' - 'literal $value')
[ "$got" = "$EXPECTED_SOCKET|literal \$value" ] && ok || bad argv
MOCK_ADD_RC=1; export MOCK_ADD_RC
sh "$TMP/ops space/bin/hostwarden-agent" --check 2>/dev/null && bad locked || ok
MOCK_ADD_RC=2
sh "$TMP/ops space/bin/hostwarden-agent" --check 2>/dev/null && bad unavailable || ok
[ -z "$TEST_AGENT_PID" ] || kill "$TEST_AGENT_PID"
# Exercise ssh-keygen through Git with a real disposable agent and key.
(
  eval "$(ssh-agent -s)" >/dev/null
  REAL_SOCKET=$SSH_AUTH_SOCK
  trap 'SSH_AUTH_SOCK=$REAL_SOCKET ssh-agent -k >/dev/null' EXIT
  ssh-keygen -q -t ed25519 -N '' -f "$TMP/private-signing-key" || exit 1
  "$ORIGINAL_ADD" "$TMP/private-signing-key" >/dev/null 2>&1 || exit 1
  # Keep the private key away from its public companion: ssh-keygen can
  # otherwise find that file and sign without the agent under test.
  cp "$TMP/private-signing-key.pub" "$TMP/signing-key.pub" || exit 1
  printf 'SSH agent socket: %s\n' "$SSH_AUTH_SOCK" > "$HW_AGENT_ROOT/memory/user.md"
  # Prove that the saved agent wins over an inherited wrong socket.
  SSH_AUTH_SOCK=/wrong.sock
  export SSH_AUTH_SOCK
  MOCK_ADD_REAL=1; export MOCK_ADD_REAL
  git init -q "$TMP/git"
  git -C "$TMP/git" config user.name Alice
  git -C "$TMP/git" config user.email alice@example.com
  git -C "$TMP/git" config gpg.format ssh
  git -C "$TMP/git" config user.signingkey "$TMP/signing-key.pub"
  git -C "$TMP/git" config commit.gpgsign true
  sh "$TMP/ops space/bin/hostwarden-agent" --exec \
    git -C "$TMP/git" commit -q --allow-empty -m 'Fixture signature' || exit 1
  printf 'alice@example.com %s\n' "$(cat "$TMP/signing-key.pub")" > "$TMP/signers"
  git -C "$TMP/git" -c gpg.ssh.allowedSignersFile="$TMP/signers" \
    verify-commit HEAD >/dev/null 2>&1 || exit 1
  mkdir "$HW_AGENT_ROOT/.git"
  : > "$HW_AGENT_ROOT/memory/.hostwarden-workspace"
  printf '/user.md\n' > "$HW_AGENT_ROOT/memory/.gitignore"
  git init -q "$HW_AGENT_ROOT/memory"
  for key in user.name user.email gpg.format user.signingkey commit.gpgsign; do
    git -C "$HW_AGENT_ROOT/memory" config "$key" "$(git -C "$TMP/git" config "$key")"
  done
  # Map and wrapping are unrelated to selecting a signing agent.
  printf '#!/bin/sh\nexit 0\n' > "$HW_AGENT_ROOT/bin/hostwarden-map"
  printf '#!/bin/sh\nexit 0\n' > "$HW_AGENT_ROOT/bin/hostwarden-wrap"
  echo fixture > "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Signed workspace fixture' || exit 1
  git -C "$HW_AGENT_ROOT/memory" -c gpg.ssh.allowedSignersFile="$TMP/signers" \
    verify-commit HEAD >/dev/null 2>&1 || exit 1
  # Rebase a signed local commit onto a local fixture remote, never a server.
  git clone -q "$HW_AGENT_ROOT/memory" "$TMP/upstream" || exit 1
  git -C "$TMP/upstream" config user.name Alice
  git -C "$TMP/upstream" config user.email alice@example.com
  git -C "$TMP/upstream" config commit.gpgsign false
  branch=$(git -C "$HW_AGENT_ROOT/memory" branch --show-current)
  git -C "$HW_AGENT_ROOT/memory" remote add origin "$TMP/upstream"
  git -C "$HW_AGENT_ROOT/memory" fetch -q origin || exit 1
  git -C "$HW_AGENT_ROOT/memory" branch -q --set-upstream-to="origin/$branch"
  echo upstream > "$TMP/upstream/upstream.md"
  git -C "$TMP/upstream" add upstream.md
  git -C "$TMP/upstream" commit -q -m 'Upstream fixture' || exit 1
  cat > "$TMP/custom signer" <<'SH'
#!/bin/sh
case "$1:$2" in
  -Y:sign) [ "$SSH_AUTH_SOCK" = "$SIGNING_SOCKET" ] || exit 92 ;;
esac
exec ssh-keygen "$@"
SH
  chmod +x "$TMP/custom signer"
  SIGNING_SOCKET=$REAL_SOCKET
  export SIGNING_SOCKET
  git -C "$HW_AGENT_ROOT/memory" config gpg.ssh.program "$TMP/custom signer"
  echo local >> "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Local signed fixture' || exit 1
  # Simulate SSH authentication against a local repository. The transport
  # requires the inherited socket; the signer requires the saved real agent.
  cat > "$TMP/auth-transport" <<'SH'
#!/bin/sh
[ "$SSH_AUTH_SOCK" = /wrong.sock ] || exit 91
printf 'authenticated\n' >> "$AUTH_TRANSPORT_LOG"
exec git-upload-pack "$AUTH_UPSTREAM"
SH
  chmod +x "$TMP/auth-transport"
  AUTH_UPSTREAM=$TMP/upstream
  AUTH_TRANSPORT_LOG=$TMP/auth-transport.log
  export AUTH_UPSTREAM AUTH_TRANSPORT_LOG
  git -C "$HW_AGENT_ROOT/memory" remote set-url origin ssh://fixture.invalid/repo
  GIT_SSH_COMMAND=$TMP/auth-transport
  GIT_SSH_VARIANT=ssh
  export GIT_SSH_COMMAND GIT_SSH_VARIANT
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" pull || exit 1
  contains_upstream "$TMP/upstream" || exit 1
  [ -s "$AUTH_TRANSPORT_LOG" ] || exit 1
  [ "$SSH_AUTH_SOCK" = /wrong.sock ] || exit 1
  [ -f "$HW_AGENT_ROOT/memory/upstream.md" ] || exit 1
  git -C "$HW_AGENT_ROOT/memory" -c gpg.ssh.allowedSignersFile="$TMP/signers" \
    verify-commit HEAD >/dev/null 2>&1 || exit 1
  # Automatic selection must also leave the transport's inherited socket.
  rm "$HW_AGENT_ROOT/memory/user.md"
  MOCK_AGENT=$REAL_SOCKET
  echo automatic >> "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Automatic signed fixture' || exit 1
  echo upstream >> "$TMP/upstream/upstream.md"
  git -C "$TMP/upstream" commit -qam 'Another upstream fixture' || exit 1
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" pull || exit 1
  contains_upstream "$TMP/upstream" || exit 1
  git -C "$HW_AGENT_ROOT/memory" -c gpg.ssh.allowedSignersFile="$TMP/signers" \
    verify-commit HEAD >/dev/null 2>&1 || exit 1
  [ "$(git -C "$HW_AGENT_ROOT/memory" config gpg.ssh.program)" = \
    "$TMP/custom signer" ] || exit 1
  # Git's default key command is a separate consumer of the signing agent.
  git -C "$HW_AGENT_ROOT/memory" config --unset user.signingkey
  cat > "$TMP/default key" <<'SH'
#!/bin/sh
[ "$#" = 4 ] && [ "$1" = literal ] && [ "$2" = '$value' ] \
  && [ "$3" = ';' ] && [ "$4" = '|' ] || exit 94
printf 'key::'
ssh-add -L
SH
  chmod +x "$TMP/default key"
  DEFAULT_KEY_COMMAND="'$TMP/default key' literal \$value ; |"
  git -C "$HW_AGENT_ROOT/memory" config gpg.ssh.defaultKeyCommand "$DEFAULT_KEY_COMMAND"
  echo default-key >> "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Default agent key fixture' || exit 1
  echo upstream >> "$TMP/upstream/upstream.md"
  git -C "$TMP/upstream" commit -qam 'Default key upstream fixture' || exit 1
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" pull || exit 1
  contains_upstream "$TMP/upstream" || exit 1
  git -C "$HW_AGENT_ROOT/memory" -c gpg.ssh.allowedSignersFile="$TMP/signers" \
    verify-commit HEAD >/dev/null 2>&1 || exit 1
  [ "$(git -C "$HW_AGENT_ROOT/memory" config gpg.ssh.defaultKeyCommand)" = \
    "$DEFAULT_KEY_COMMAND" ] || exit 1
  git -C "$HW_AGENT_ROOT/memory" config --unset gpg.ssh.defaultKeyCommand
  git -C "$HW_AGENT_ROOT/memory" config user.signingkey "$TMP/signing-key.pub"
  unset GIT_SSH_COMMAND GIT_SSH_VARIANT
  git -C "$HW_AGENT_ROOT/memory" config --unset gpg.ssh.program
  # A disabled choice must not use the live inherited agent to sign.
  printf 'SSH agent socket: none\n' > "$HW_AGENT_ROOT/memory/user.md"
  echo 'agent needed fixture' >> "$HW_AGENT_ROOT/memory/fixture.md"
  if sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Must fail' >/dev/null 2>&1; then
    echo "disabled agent unexpectedly signed a public-only key" >&2
    exit 1
  fi
  # A configured private key signs without requiring an agent socket.
  git -C "$HW_AGENT_ROOT/memory" config user.signingkey "$TMP/private-signing-key"
  echo 'private signing key fixture' >> "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Private key signature' || exit 1
  git -C "$HW_AGENT_ROOT/memory" -c gpg.ssh.allowedSignersFile="$TMP/signers" \
    verify-commit HEAD >/dev/null 2>&1 || exit 1
  # A sandbox denying automatic discovery still permits agent-independent
  # signing. The generic wrapper stays strict; only workspace signing adapts.
  rm "$HW_AGENT_ROOT/memory/user.md"
  MOCK_SSH_FAIL=1
  echo private-query-denied >> "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Private key without query' \
    > "$TMP/query-failure" 2>&1 || exit 1
  grep -q 'signing without an agent, no fallback' "$TMP/query-failure" || exit 1
  cat > "$TMP/independent signer" <<'SH'
#!/bin/sh
case "$1:$2" in
  -Y:sign) [ -z "$SSH_AUTH_SOCK" ] || exit 95 ;;
esac
exec ssh-keygen "$@"
SH
  chmod +x "$TMP/independent signer"
  git -C "$HW_AGENT_ROOT/memory" config gpg.ssh.program "$TMP/independent signer"
  echo independent >> "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Independent signer without query' \
    > "$TMP/query-failure" 2>&1 || exit 1
  git -C "$HW_AGENT_ROOT/memory" remote set-url origin "$TMP/upstream"
  echo upstream >> "$TMP/upstream/upstream.md"
  git -C "$TMP/upstream" commit -qam 'Private key upstream fixture' || exit 1
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" pull > "$TMP/query-failure" 2>&1 || exit 1
  contains_upstream "$TMP/upstream" || exit 1
  grep -q 'signing without an agent, no fallback' "$TMP/query-failure" || exit 1
  git -C "$HW_AGENT_ROOT/memory" -c gpg.ssh.allowedSignersFile="$TMP/signers" \
    verify-commit HEAD >/dev/null 2>&1 || exit 1
  git -C "$HW_AGENT_ROOT/memory" config --unset gpg.ssh.program
  # A live inherited agent must not become a fallback after a denied query.
  SSH_AUTH_SOCK=$REAL_SOCKET
  git -C "$HW_AGENT_ROOT/memory" config user.signingkey "$TMP/signing-key.pub"
  echo agent-required >> "$HW_AGENT_ROOT/memory/fixture.md"
  if sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Must not fall back' \
      > "$TMP/query-failure" 2>&1; then exit 1; fi
  grep -q 'signing without an agent, no fallback' "$TMP/query-failure" || exit 1
  # Malformed saved selections remain fatal even for private-file signing.
  printf 'SSH agent socket:\n' > "$HW_AGENT_ROOT/memory/user.md"
  git -C "$HW_AGENT_ROOT/memory" config user.signingkey "$TMP/private-signing-key"
  if sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Malformed choice' \
      > "$TMP/query-failure" 2>&1; then exit 1; fi
  grep -q 'one nonempty SSH agent socket' "$TMP/query-failure" || exit 1
  exit 0
) && ok || bad 'real Git SSH signature'
# Real OpenPGP signatures use an isolated, disposable GnuPG home. A broken
# personal SSH selection must not affect either default or explicit OpenPGP.
(
  GNUPGHOME=$TMP/gnupg
  mkdir -m 700 "$GNUPGHOME"
  export GNUPGHOME
  trap 'gpgconf --kill gpg-agent >/dev/null 2>&1' EXIT
  gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key \
    'Alice <alice@example.com>' ed25519 sign 0 >/dev/null 2>&1 || exit 1
  printf 'SSH agent socket:\nSSH agent socket: /invalid\n' > "$HW_AGENT_ROOT/memory/user.md"
  MOCK_SSH_FAIL=1
  SSH_AUTH_SOCK=/wrong.sock
  export MOCK_SSH_FAIL SSH_AUTH_SOCK
  cat > "$TMP/custom gpg" <<'SH'
#!/bin/sh
[ "$SSH_AUTH_SOCK" = /wrong.sock ] || exit 93
if [ "${GPG_SIGN_FAIL:-0}" = 1 ]; then
  echo 'fixture-unlock-required' >&2
  exit 23
fi
exec gpg "$@"
SH
  chmod +x "$TMP/custom gpg"
  git -C "$HW_AGENT_ROOT/memory" config --unset gpg.format
  git -C "$HW_AGENT_ROOT/memory" config user.signingkey alice@example.com
  git -C "$HW_AGENT_ROOT/memory" config gpg.program "$TMP/custom gpg"
  echo default-openpgp >> "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Default OpenPGP fixture' || exit 1
  git -C "$HW_AGENT_ROOT/memory" verify-commit HEAD >/dev/null 2>&1 || exit 1
  git -C "$HW_AGENT_ROOT/memory" config gpg.format openpgp
  git -C "$HW_AGENT_ROOT/memory" config gpg.openpgp.program "$TMP/custom gpg"
  git clone -q "$HW_AGENT_ROOT/memory" "$TMP/pgp-upstream" || exit 1
  git -C "$TMP/pgp-upstream" config user.name Alice
  git -C "$TMP/pgp-upstream" config user.email alice@example.com
  git -C "$TMP/pgp-upstream" config commit.gpgsign false
  git -C "$HW_AGENT_ROOT/memory" remote set-url origin "$TMP/pgp-upstream"
  git -C "$HW_AGENT_ROOT/memory" fetch -q origin || exit 1
  echo upstream > "$TMP/pgp-upstream/pgp.md"
  git -C "$TMP/pgp-upstream" add pgp.md
  git -C "$TMP/pgp-upstream" commit -q -m 'OpenPGP upstream fixture' || exit 1
  echo explicit-openpgp >> "$HW_AGENT_ROOT/memory/fixture.md"
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Explicit OpenPGP fixture' || exit 1
  AUTH_UPSTREAM=$TMP/pgp-upstream
  AUTH_TRANSPORT_LOG=$TMP/pgp-auth.log
  GIT_SSH_COMMAND=$TMP/auth-transport
  GIT_SSH_VARIANT=ssh
  export AUTH_UPSTREAM AUTH_TRANSPORT_LOG GIT_SSH_COMMAND GIT_SSH_VARIANT
  git -C "$HW_AGENT_ROOT/memory" remote set-url origin ssh://fixture.invalid/repo
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" pull || exit 1
  contains_upstream "$TMP/pgp-upstream" || exit 1
  [ -s "$AUTH_TRANSPORT_LOG" ] && [ -f "$HW_AGENT_ROOT/memory/pgp.md" ] || exit 1
  git -C "$HW_AGENT_ROOT/memory" verify-commit HEAD >/dev/null 2>&1 || exit 1
  [ "$(git -C "$HW_AGENT_ROOT/memory" config gpg.program)" = "$TMP/custom gpg" ] || exit 1
  [ "$(git -C "$HW_AGENT_ROOT/memory" config gpg.openpgp.program)" = "$TMP/custom gpg" ] || exit 1
  # OpenPGP and X.509 failures retain their signer's error, without fallback.
  GPG_SIGN_FAIL=1
  export GPG_SIGN_FAIL
  git -C "$HW_AGENT_ROOT/memory" config gpg.x509.program "$TMP/custom gpg"
  for format in openpgp x509; do
    git -C "$HW_AGENT_ROOT/memory" config gpg.format "$format"
    echo signer-failure >> "$HW_AGENT_ROOT/memory/fixture.md"
    if sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Signer failure fixture' \
        > "$TMP/gpg-failure" 2>&1; then exit 1; fi
    grep -q fixture-unlock-required "$TMP/gpg-failure" || exit 1
  done
  # Unsigned SSH commits must not query or validate any agent either.
  git -C "$HW_AGENT_ROOT/memory" config gpg.format ssh
  git -C "$HW_AGENT_ROOT/memory" config commit.gpgsign false
  sh "$HW_AGENT_ROOT/bin/hostwarden-sync" commit 'Unsigned fixture' || exit 1
  git -C "$HW_AGENT_ROOT/memory" cat-file commit HEAD | grep -q '^gpgsig ' && exit 1
  exit 0
) && ok || bad 'OpenPGP and non-SSH signing isolation'
finish agent
