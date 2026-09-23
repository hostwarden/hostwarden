#!/bin/sh
# fleet-read-test.sh — dev-only fixture matrix for
# templates/fleet-read/fleet-read, the forced command of an
# operations host's key. CI runs it through scripts/check.sh; an
# agent session leaves it to CI (.claude/rules/pull-requests.md →
# Checks).
#
# Everything runs under a temp directory: a copy of the wrapper
# pointed at a throwaway allowed_signers file, two throwaway
# signing keys, and a logger stand-in that records its arguments.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-fleet-read-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# The wrapper, with its signers file and PATH moved into $TMP. The
# PATH keeps the system directories, so only logger is replaced.
mkdir -p "$TMP/bin" "$TMP/work"
sed -e "s#^SIGNERS=.*#SIGNERS=$TMP/allowed_signers#" \
  -e "s#^PATH=.*#PATH=$TMP/bin:/usr/sbin:/usr/bin:/sbin:/bin#" \
  "$REPO/templates/fleet-read/fleet-read" >"$TMP/fleet-read"
grep -q "^SIGNERS=$TMP/" "$TMP/fleet-read" \
  && grep -q "^PATH=$TMP/bin:" "$TMP/fleet-read" \
  || { echo "FAIL: the wrapper's SIGNERS or PATH line moved"; exit 1; }
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/logged"\n' "$TMP" \
  >"$TMP/bin/logger"
chmod +x "$TMP/bin/logger"

ssh-keygen -q -t ed25519 -N '' -C good -f "$TMP/good"
ssh-keygen -q -t ed25519 -N '' -C other -f "$TMP/other"
printf 'fleet-read namespaces="fleet-read" %s\n' "$(cat "$TMP/good.pub")" \
  >"$TMP/allowed_signers"

# bundle <file> <valid-until> — a bundle that leaves a mark and
# exits 3, so a run is visible and its exit code checkable.
bundle() {
  {
    echo '#!/bin/sh'
    [ -z "$2" ] || echo "# valid-until: $2"
    echo "echo ran; touch '$TMP/ran'; exit 3"
  } >"$1"
}
# sign <key> <namespace> <file> — writes <file>.sig
sign() {
  rm -f "$3.sig"
  ssh-keygen -q -Y sign -f "$TMP/$1" -n "$2" "$3" >/dev/null 2>&1
}
# collect <input> — the wrapper as sshd starts it for collect.
collect() {
  rm -f "$TMP/ran"
  SSH_ORIGINAL_COMMAND=collect sh "$TMP/fleet-read" ops1 <"$1" \
    >"$TMP/out" 2>"$TMP/err"
}
input() { cat "$1.sig" "$1" >"$TMP/in"; }

B="$TMP/work/b.sh"

# --- collect --------------------------------------------------
bundle "$B" 2999-12-31
sign good fleet-read "$B" && input "$B"
collect "$TMP/in"
rc=$?
[ "$rc" = 3 ] && ok || bad "a signed bundle's exit code was $rc, not 3"
[ -e "$TMP/ran" ] && ok || bad "a signed bundle did not run"
grep -qx ran "$TMP/out" && ok || bad "a signed bundle's output was lost"

# refused <what> — the command just before refused, and nothing
# ran.
refused() {
  rc=$?
  if [ "$rc" = 1 ] && [ ! -e "$TMP/ran" ]; then ok
  else bad "$1 was not refused (rc $rc)"; fi
}

cp "$TMP/in" "$TMP/tampered"
echo 'echo extra' >>"$TMP/tampered"
collect "$TMP/tampered"; refused "a changed bundle"

bundle "$B" 2999-12-31
sign other fleet-read "$B" && input "$B"
collect "$TMP/in"; refused "a bundle signed by an unlisted key"

sign good other-namespace "$B" && input "$B"
collect "$TMP/in"; refused "a signature for another namespace"

collect "$B"; refused "an unsigned bundle"

bundle "$B" 2000-01-01
sign good fleet-read "$B" && input "$B"
collect "$TMP/in"; refused "an expired bundle"
grep -q 'expired' "$TMP/err" && ok || bad "expiry was not named"

bundle "$B" ''
sign good fleet-read "$B" && input "$B"
collect "$TMP/in"; refused "a bundle without valid-until"

bundle "$B" 2999-12-31
sign good fleet-read "$B"
cp "$B.sig" "$TMP/in"
collect "$TMP/in"; refused "a signature without a bundle"
head -n 3 "$B.sig" >"$TMP/in"
cat "$B" >>"$TMP/in"
collect "$TMP/in"; refused "an unterminated signature"

input "$B"
head -c 300000 /dev/zero | tr '\0' '#' >>"$TMP/in"
collect "$TMP/in"; refused "input over the size limit"

# Nothing is left in the temporary directory's parent.
before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)
input "$B"
collect "$TMP/in"
after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)
[ "$before" = "$after" ] && ok || bad "collect left its temporary directory"

# --- the command line -----------------------------------------
input "$B"
for cmd in 'collect x' 'collect;id' 'sh' '' 'log collect'; do
  rm -f "$TMP/ran"
  SSH_ORIGINAL_COMMAND="$cmd" sh "$TMP/fleet-read" ops1 \
    <"$TMP/in" >/dev/null 2>&1
  refused "the command '$cmd'"
done
rm -f "$TMP/ran"
SSH_ORIGINAL_COMMAND=collect sh "$TMP/fleet-read" <"$TMP/in" \
  >/dev/null 2>&1
refused "a key line without a name"
SSH_ORIGINAL_COMMAND=collect sh "$TMP/fleet-read" 'ops1;id' \
  <"$TMP/in" >/dev/null 2>&1
refused "a name with a shell character"
SSH_ORIGINAL_COMMAND=collect sh "$TMP/fleet-read" ops1 extra \
  <"$TMP/in" >/dev/null 2>&1
refused "a second argument"

# --- log ------------------------------------------------------
logline() {
  rm -f "$TMP/logged"
  printf '%b' "$1" | SSH_ORIGINAL_COMMAND=log sh "$TMP/fleet-read" ops1 \
    >/dev/null 2>&1
}
me=$(id -un)
logline 'housekeeping: 1 WARN\n'
[ "$(cat "$TMP/logged" 2>/dev/null)" \
  = "-t hostwarden -- [ops1 as $me] read-only: housekeeping: 1 WARN" ] \
  && ok || bad "log wrote: $(cat "$TMP/logged" 2>/dev/null)"
logline 'a\033[31mb\tc\nsecond line\n'
[ "$(cat "$TMP/logged" 2>/dev/null)" \
  = "-t hostwarden -- [ops1 as $me] read-only: a[31mbc" ] \
  && ok || bad "log kept a control character or a second line"
logline "$(printf '%0300d' 0)"
n=$(sed 's/.*read-only: //' "$TMP/logged" | tr -d '\n' | wc -c)
[ "$n" -eq 250 ] && ok || bad "log kept $n characters, not 250"
logline '\n'
[ ! -e "$TMP/logged" ] && ok || bad "an empty line was logged"

echo "fleet-read: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
