# tests/hooks/guard-taboos/session.sh — check-session.sh, a degraded
# awk, and no negated hit. Sourced by tests/hooks/guard-taboos.sh,
# in its order, into the one shell every part shares; never run on
# its own.
# shellcheck shell=sh

# --- check-session.sh: worktree and guard-off notices ----------
# The hook only reads .git files and the commondir they lead to, so
# hand-written ones cover every case: a checkout (a directory), a
# linked worktree with an absolute and with a relative gitdir, one
# whose common git directory is not called .git, and a submodule,
# which is not a worktree.
CSESSION="$CLAUDE_DIR/hooks/check-session.sh"
CSREPO=$(mktemp -d)
for d in main wt rel sep sub; do
  mkdir -p "$CSREPO/$d/.claude/hooks" "$CSREPO/$d/lib"
  cp "$CSESSION" "$CSREPO/$d/.claude/hooks/"
  cp "$REPO/lib/json.sh" "$CSREPO/$d/lib/"
done
for w in wt rel; do
  mkdir -p "$CSREPO/main/.git/worktrees/$w"
  echo ../.. > "$CSREPO/main/.git/worktrees/$w/commondir"
done
mkdir -p "$CSREPO/meta/worktrees/sep" "$CSREPO/main/.git/modules/sub"
echo ../.. > "$CSREPO/meta/worktrees/sep/commondir"
printf 'gitdir: %s/main/.git/worktrees/wt\n' "$CSREPO" > "$CSREPO/wt/.git"
printf 'gitdir: ../main/.git/worktrees/rel\n' > "$CSREPO/rel/.git"
printf 'gitdir: %s/meta/worktrees/sep\n' "$CSREPO" > "$CSREPO/sep/.git"
printf 'gitdir: ../main/.git/modules/sub\n' > "$CSREPO/sub/.git"
session_out() {
  # session_out <dir> [env assignment] [session JSON]
  printf '%s' "${3:-{\}}" \
    | env -u "$V" HOME="$CSREPO/home" ${2:+"$2"} \
      sh "$CSREPO/$1/.claude/hooks/check-session.sh"
}
contains() { case "$1" in *"$2"*) true ;; *) false ;; esac; }
expect "check-session.sh spoke in an ordinary checkout" \
  [ -z "$(session_out main)" ]
# The worktree itself is mode.sh's to detect and session-mode.sh's
# to announce; check-session.sh stays out of it.
mode_of() {
  (. "$REPO/lib/mode.sh"; hostwarden_mode "$CSREPO/$1"
   echo "$HOSTWARDEN_MODE $HOSTWARDEN_MAIN")
}
expect "mode.sh missed a linked worktree or its checkout" \
  [ "$(mode_of wt)" = "worktree $CSREPO/main" ]
expect "mode.sh missed a worktree with a relative gitdir" \
  [ "$(mode_of rel)" = "worktree $CSREPO/main" ]
expect "mode.sh missed a worktree of a separate git dir" \
  contains "$(mode_of sep)" "worktree "
expect "mode.sh took a submodule for a worktree" \
  [ "$(mode_of sub)" = "development " ]
expect "check-session.sh announced a worktree session-mode.sh owns" \
  [ -z "$(session_out wt)" ]
# The record: made at startup with the variable set, never at a
# compaction, and taken away once the variable is gone.
REC="$CSREPO/home/.cache/hostwarden/guard-off-s1"
expect "check-session.sh did not report the guard as off" \
  contains "$(session_out main "$V=1" '{"session_id":"s1","source":"startup"}')" \
  "taboo guard is OFF"
expect "check-session.sh made no record at startup" [ -e "$REC" ]
rm -f "$REC"
expect "check-session.sh did not say a mid-session value stays inert" \
  contains "$(session_out main "$V=1" '{"session_id":"s1","source":"compact"}')" \
  "guard stays ON"
expect "check-session.sh made a record at a compaction" [ ! -e "$REC" ]
session_out main "$V=1" '{"session_id":"s1","source":"startup"}' >/dev/null
session_out main "" '{"session_id":"s1","source":"clear"}' >/dev/null
expect "check-session.sh kept a record once the variable was gone" \
  [ ! -e "$REC" ]
rm -rf "$CSREPO"

# --- degraded awk must fail CLOSED -----------------------------
# hit_without() decides the read-only exemptions via awk. If awk
# is missing or cannot evaluate POSIX classes, the exemption
# cannot be proven, and an unprovable exemption must block, not
# pass. Simulated with an awk shim that only fails.
SHIM=$(mktemp -d)
printf '#!/bin/sh\nexit 2\n' > "$SHIM/awk"
chmod +x "$SHIM/awk"
OUT=$(json_for 'fdisk -l /dev/sda' \
  | env -u HOSTWARDEN_GUARD_DISABLE PATH="$SHIM:$PATH" sh "$HOOK")
if printf '%s' "$OUT" \
  | grep -q '"permissionDecision":"deny"'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: broken awk failed OPEN (read-only fdisk was allowed)"
fi
rm -rf "$SHIM"

# --- no negated hit() may remain -------------------------------
# A rule of the form  hit X && ! hit Y  evaluates Y against the
# whole command string, so any unrelated flag disarms it (issue
# #4). Exemptions belong in hit_without(), which scopes them to
# the invocation. Without this check the shape creeps back in.
if cat "$HOOK" "${HOOK%/*}"/guard-taboos.d/*.sh | grep -q '! *hit '; then
  FAIL=$((FAIL + 1))
  echo "FAIL: guard still uses a negated whole-string hit;" \
    "use hit_without() so the exemption stays scoped"
else
  PASS=$((PASS + 1))
fi
