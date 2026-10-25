# shellcheck shell=sh
# tests/bin/infra-fixture.sh — what the two infrastructure-code
# matrices share: an operations checkout of their own under TMP with
# the wrapper named and the libraries it sources, a fake bin first
# on PATH, and the assertions. Sourced by tests/bin/hostwarden-tofu.sh
# and tests/bin/hostwarden-ansible.sh after tests/helpers.sh and
# test_tmp; never run on its own.
#
#   infra_fixture <wrapper>  — builds $OPS with bin/<wrapper>, lib/,
#                              memory/.hostwarden-workspace; sets TMP
#                              (physical), HOME, PATH, LOG; HW runs
#                              the wrapper
#   expect_rc <rc> <label> <command…>
#                            — one check: the command's exit status,
#                              its output in OUT
#   has_out <text> <label>   — OUT holds the text
#   has_log <text> <label>   — a stand-in recorded that call in LOG
#   no_log <text> <label>    — no stand-in did
#   has_env <text> <label>   — $TMP/env, which a stand-in writes,
#                              holds the line

infra_fixture() {
  TMP=$(cd "$TMP" && pwd -P)
  OPS=$TMP/ops
  mkdir -p "$OPS/bin" "$OPS/lib" "$OPS/memory" "$OPS/.git" "$TMP/home" \
    "$TMP/fake"
  cp "$REPO/bin/$1" "$OPS/bin/"
  cp "$REPO/lib/infra.sh" "$REPO/lib/passwords.sh" "$REPO/lib/mode.sh" \
    "$OPS/lib/"
  cp -R "$REPO/lib/passwords" "$OPS/lib/"
  : > "$OPS/memory/.hostwarden-workspace"
  HOME=$TMP/home
  HOSTWARDEN_PASSWORD_STORE='file'
  PATH=$TMP/fake:/usr/bin:/bin
  export HOME HOSTWARDEN_PASSWORD_STORE PATH
  unset OP_SERVICE_ACCOUNT_TOKEN BWS_ACCESS_TOKEN
  LOG=$TMP/calls
  : > "$LOG"
  HW=$OPS/bin/$1
}

hw() { sh "$HW" "$@"; }
expect_rc() {
  want=$1 label=$2
  shift 2
  OUT=$("$@" 2>&1)
  rc=$?
  if [ "$rc" -eq "$want" ]; then ok; else bad "$label: exit $rc, wanted $want: $OUT"; fi
}
has_out() { case "$OUT" in *"$1"*) ok ;; *) bad "$2: output lacks '$1': $OUT" ;; esac; }
has_log() { grep -qF -- "$1" "$LOG" && ok || bad "$2: no call '$1' in $(cat "$LOG")"; }
no_log() { grep -qF -- "$1" "$LOG" && bad "$2: a call '$1' in $(cat "$LOG")" || ok; }
has_env() { grep -qF -- "$1" "$TMP/env" && ok || bad "$2: env lacks '$1': $(cat "$TMP/env")"; }
