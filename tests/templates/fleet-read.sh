#!/bin/sh
# tests/templates/fleet-read.sh — dev-only fixture matrix for
# templates/fleet-read/fleet-read, the forced command of an
# operations host's key. CI runs it through scripts/check.sh; an
# agent session leaves it to CI (.claude/rules/pull-requests.md →
# Checks).
#
# Everything runs under a temp directory: a copy of the wrapper
# pointed at a throwaway allowed_signers file, two throwaway
# signing keys, and a logger stand-in that records its arguments.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../helpers.sh
. "$REPO/tests/helpers.sh"
test_tmp fleet-read

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
# collect <input> [<suffix>] — the wrapper as sshd starts it for
# collect, <suffix> the section names appended to the verb.
collect() {
  rm -f "$TMP/ran"
  SSH_ORIGINAL_COMMAND="collect${2:-}" sh "$TMP/fleet-read" ops1 <"$1" \
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

# --- collect by section ---------------------------------------
# A bundle laid out as references/bundle.md says: one SECTIONS line
# that the dispatcher runs from and the wrapper reads, one function
# per section, the chosen ones run in the line's order, the floors
# last.
S="$TMP/work/s.sh"
cat >"$S" <<EOF
#!/bin/sh
# valid-until: 2999-12-31
SECTIONS='alpha beta_2'
sec() { printf '\n### %s\n' "\$1"; }
sec_alpha() { sec alpha; echo ran-alpha; touch '$TMP/ran'; }
sec_beta_2() { sec beta; echo ran-beta; touch '$TMP/ran'; }
sec_floors() { sec floors; echo ran-floors; }
WANT=\${*:-\$SECTIONS}
for s in \$SECTIONS; do
  case " \$WANT " in *" \$s "*) "sec_\$s" ;; esac
done
sec_floors
exit 0
EOF
sign good fleet-read "$S" && input "$S"
ran() { grep -o 'ran-[a-z]*' "$TMP/out" | tr '\n' ' '; }
collect "$TMP/in"
rc=$?
[ "$rc" = 0 ] && [ "$(ran)" = 'ran-alpha ran-beta ran-floors ' ] && ok \
  || bad "collect without names ran '$(ran)' (rc $rc)"
collect "$TMP/in" ' beta_2'
rc=$?
[ "$rc" = 0 ] && [ "$(ran)" = 'ran-beta ran-floors ' ] && ok \
  || bad "collect beta_2 ran '$(ran)' (rc $rc)"
collect "$TMP/in" ' beta_2 alpha'
[ "$(ran)" = 'ran-alpha ran-beta ran-floors ' ] && ok \
  || bad "two names did not run in the bundle's order: '$(ran)'"
collect "$TMP/in" '  beta_2  '
[ "$(ran)" = 'ran-beta ran-floors ' ] && ok \
  || bad "extra blanks around a name changed the run: '$(ran)'"
collect "$TMP/in" ' gamma'; refused "a name the bundle does not carry"
grep -q "no section 'gamma'" "$TMP/err" && ok \
  || bad "the missing section was not named: $(cat "$TMP/err")"
collect "$TMP/in" ' alpha gamma'; refused "one bad name among good ones"
collect "$TMP/in" ' Alpha'; refused "an uppercase name"
collect "$TMP/in" ' alpha;id'; refused "a name with a shell character"
collect "$TMP/in" ' al*pha'; refused "a name with a glob character"
collect "$TMP/in" ' beta-2'; refused "a name with a hyphen"
collect "$TMP/in" ' -x'; refused "a name that starts with a hyphen"
collect "$TMP/in" ' _a'; refused "a name that starts with an underscore"
collect "$TMP/in" ' 1a'; refused "a name that starts with a digit"
collect "$TMP/in" ' alpha
beta_2'; refused "a name on a second line"
collect "$TMP/in" " $(printf 'a%.0s' $(seq 41))"
refused "a name over 40 characters"
collect "$TMP/in" " $(printf 'alpha %.0s' $(seq 33))"
refused "more than 32 names"
collect "$TMP/in" 'alpha'; refused "a verb run into a name"
# The plain bundle above has no SECTIONS line: a name is refused
# even where the dispatcher would have ignored it.
input "$B"
collect "$TMP/in" ' alpha'; refused "a name on a bundle without a sections line"
grep -q 'no sections line' "$TMP/err" && ok \
  || bad "the missing sections line was not named: $(cat "$TMP/err")"

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

finish fleet-read
