#!/bin/sh
# guard-mode-test.sh — dev-only fixture matrix for mode.sh,
# guard-mode.sh, session-mode.sh, bin/hostwarden-init and
# bin/hostwarden-sync. Run
# before committing a change to any of them:
#   sh .claude/hooks/guard-mode-test.sh
# Not invoked by Claude Code at runtime.
#
# Each mode gets a throwaway checkout of its own under a temp
# directory, because the mode is a property of the tree the hook
# sits in: the guard finds its root from its own path.

HOOKS="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HOOKS/../.." && pwd)"
PASS=0
FAIL=0
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hostwarden-mode-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# commit <dir> <message> — as alice, whatever git is configured.
commit() {
  git -C "$1" add -A
  git -C "$1" -c user.name=alice -c user.email=alice@example.com \
    commit --quiet -m "$2"
}

# checkout <name> — a minimal tree: the hooks, the init script
# with its workspace skeleton, and a .gitignore like the real one.
checkout() {
  c="$TMP/$1"
  mkdir -p "$c/.claude/hooks" "$c/bin" "$c/rules"
  cp "$HOOKS/mode.sh" "$HOOKS/guard-mode.sh" "$HOOKS/session-mode.sh" \
    "$c/.claude/hooks/"
  cp "$REPO/bin/hostwarden-init" "$REPO/bin/hostwarden-sync" \
    "$REPO/bin/hostwarden-backup" "$c/bin/"
  mkdir -p "$c/templates"
  cp -R "$REPO/templates/workspace" "$c/templates/"
  printf 'memory/\n.claude/settings.local.json\n' > "$c/.gitignore"
  echo '# rule' > "$c/rules/backups.md"
  git -C "$c" init --quiet
  commit "$c" init
  (cd "$c" && pwd -P)
}

DEV=$(checkout dev)
OPS=$(checkout ops)
sh "$OPS/bin/hostwarden-init" >/dev/null
# A worktree checks out the committed hooks, so it needs nothing
# copied in.
WT="$TMP/wt"
git -C "$DEV" worktree add --quiet -b feat/x "$WT" 2>/dev/null

# --- mode.sh ---------------------------------------------------
mode_is() {
  # shellcheck source=mode.sh
  got=$(. "$HOOKS/mode.sh"; hostwarden_mode "$2"; echo "$HOSTWARDEN_MODE")
  if [ "$got" = "$1" ]; then ok; else bad "mode of $2: want $1, got $got"; fi
}
mode_is development "$DEV"
mode_is operations "$OPS"
mode_is worktree "$WT"
# An archive copy, not a clone: never operations, even with a
# workspace in it, and init refuses to make one.
ARC="$TMP/archive"
mkdir -p "$ARC/memory"
cp -R "$DEV/.claude" "$DEV/bin" "$DEV/templates" "$ARC/"
cp "$OPS/memory/.hostwarden-workspace" "$ARC/memory/"
mode_is development "$ARC"
rm "$ARC/memory/.hostwarden-workspace"
if sh "$ARC/bin/hostwarden-init" >/dev/null 2>&1; then
  bad "init made a workspace outside a git clone"
else ok; fi

# --- guard-mode.sh ---------------------------------------------
bash_json() {
  printf '%s' "$1" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}'
}
edit_json() {
  jq -n --arg p "$1" \
    '{tool_name:"Edit",tool_input:{file_path:$p,old_string:"ssh a",new_string:"ssh b"}}'
}
write_json() {
  jq -n --arg p "$1" '{tool_name:"Write",tool_input:{file_path:$p,content:"x"}}'
}

# verdict <expect> <checkout> <json>
verdict() {
  out=$(printf '%s' "$3" | sh "$2/.claude/hooks/guard-mode.sh")
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then
    got=deny
  else
    got=pass
  fi
  if [ "$got" = "$1" ]; then ok; else bad "[$1, got $got] $(basename "$2"): $3"; fi
}
cmd() { verdict "$1" "$2" "$(bash_json "$3")"; }
edit() { verdict "$1" "$2" "$(edit_json "$3")"; }
write() { verdict "$1" "$2" "$(write_json "$3")"; }

# Development: nothing reaches a server, this machine included.
cmd deny "$DEV" 'ssh root@server1.example.com uptime'
cmd deny "$DEV" 'ssh -o BatchMode=yes alice@server1.example.com "df -h"'
cmd deny "$DEV" '/usr/bin/ssh server1.example.com'
cmd deny "$DEV" 'FOO=1 ssh server1.example.com'
cmd deny "$DEV" 'env LC_ALL=C ssh server1.example.com'
cmd deny "$DEV" 'timeout 10 ssh server1.example.com true'
cmd deny "$DEV" 'cd /tmp && scp a.txt server1.example.com:/tmp/'
cmd deny "$DEV" 'sftp server1.example.com'
cmd deny "$DEV" 'bash -c "ssh server1.example.com"'
cmd deny "$DEV" 'echo $(ssh server1.example.com hostname)'
cmd deny "$DEV" 'if ssh server1.example.com true; then echo up; fi'
cmd deny "$DEV" 'sudo apt-get update'
cmd deny "$DEV" 'doas pkg upgrade'
cmd deny "$DEV" 'rsync -av site/ server1.example.com:/srv/site/'
cmd deny "$DEV" 'rsync -av -e "ssh -p 2222" site/ server1.example.com:/srv/'
cmd deny "$DEV" 'rsync -av rsync://server1.example.com/mod/ here/'
cmd deny "$DEV" 'rsync -a site/ "server1.example.com:/srv/"'
cmd deny "$DEV" "rsync -a 'rsync://server1.example.com/mod/' here/"
cmd pass "$DEV" 'rsync -a "my site/" /tmp/copy/'
cmd pass "$DEV" 'rsync -a -e ssh src/ /tmp/copy/'
cmd deny "$DEV" 'if false; then :; elif ssh server1.example.com true; then :; fi'
cmd deny "$DEV" 'env -u FOO ssh server1.example.com'
cmd deny "$DEV" 'timeout -s KILL 5 ssh server1.example.com'
cmd deny "$DEV" 'stdbuf -o L ssh server1.example.com'
cmd deny "$DEV" 'echo a | xargs -n 1 ssh server1.example.com'
cmd deny "$DEV" 'sudoedit /etc/hosts'
cmd deny "$DEV" 'pkexec whoami'
cmd deny "$DEV" 'find . -exec ssh server1.example.com true \;'
cmd deny "$DEV" 'find . -name x -execdir /usr/bin/scp {} server1.example.com: \;'
cmd pass "$DEV" 'find . -name "*.sh" -exec shellcheck {} +'
cmd deny "$DEV" 'find . -exec env ssh server1.example.com true \;'
cmd pass "$DEV" 'find . -name "*.md" -exec rsync -a {} /tmp/copy/ \;'
cmd deny "$DEV" 'find . -exec rsync -a {} server1.example.com:/srv/ \;'
cmd deny "$DEV" "env -S 'ssh server1.example.com true'"
cmd deny "$DEV" 'env --split-string="sudo whoami"'
cmd deny "$DEV" 'env -S ssh server1.example.com'
cmd deny "$DEV" 'find . -ok timeout -s KILL 5 sudo true \;'
cmd deny "$DEV" 'env --unset FOO ssh server1.example.com true'
cmd deny "$DEV" 'timeout --signal KILL 5 ssh server1.example.com'
cmd deny "$DEV" 'stdbuf --output L ssh server1.example.com'
cmd deny "$DEV" 'ssh server1.example.com bash -s <<EOF
uptime
EOF'
# ...and everything a development session actually does passes.
cmd pass "$DEV" 'grep -rn ssh rules/'
cmd pass "$DEV" 'git commit -F /tmp/msg.txt'
cmd pass "$DEV" 'git push -u origin feat/28-workspace-mode'
cmd pass "$DEV" 'ssh-keygen -lf key.pub'
cmd pass "$DEV" 'rsync -a templates/ /tmp/copy/'
cmd pass "$DEV" 'sh .claude/hooks/guard-taboos-test.sh'
cmd pass "$DEV" 'git commit -m "ssh: keep one connection per host"'
cmd pass "$DEV" 'uname -a; df -h'
# Quoted text is data unless something runs it.
cmd pass "$DEV" "grep -rn 'ssh ' rules/"
cmd pass "$DEV" 'grep -nE "(ssh|scp|sudo)" .claude/hooks/guard-mode.sh'
cmd pass "$DEV" "sed -n '/^ssh/p' README.md"
cmd pass "$DEV" 'echo "sudo is blocked here"'
cmd pass "$DEV" 'cat > notes.md <<EOF
ssh root@server1.example.com uptime
sudo systemctl reload nginx
EOF'
cmd pass "$DEV" "tee -a notes.md <<'EOF'
	ssh server1.example.com
EOF"
cmd deny "$DEV" "sh -c 'sudo whoami'"
cmd deny "$DEV" 'eval "ssh server1.example.com"'
cmd deny "$DEV" 'echo "up: $(ssh server1.example.com uptime)"'
cmd deny "$DEV" 'cat > notes.md <<EOF
text
EOF
ssh server1.example.com'
cmd deny "$DEV" 'cat <<EOF | bash
ssh server1.example.com
EOF'
cmd deny "$DEV" "sh -ec 'ssh server1.example.com'"
cmd deny "$DEV" 'bash -xc "sudo whoami"'
cmd deny "$DEV" 'bash -s <<EOF
ssh server1.example.com
EOF'
edit pass "$DEV" "$DEV/rules/backups.md"

# The taboo guard's off switch does not reach the mode guard.
out=$(bash_json 'ssh server1.example.com true' \
  | HOSTWARDEN_GUARD_DISABLE=1 sh "$DEV/.claude/hooks/guard-mode.sh")
case "$out" in
*'"permissionDecision":"deny"'*) ok ;;
*) bad "HOSTWARDEN_GUARD_DISABLE switched the mode guard off" ;;
esac

# Worktree: development, whatever the main checkout is.
cmd deny "$WT" 'ssh root@server1.example.com uptime'
cmd pass "$WT" 'git status'
edit pass "$WT" "$WT/rules/backups.md"

# Operations: servers as usual, shipped files read-only.
cmd pass "$OPS" 'ssh root@server1.example.com uptime'
cmd pass "$OPS" 'sudo -n true'
edit deny "$OPS" "$OPS/rules/backups.md"
edit deny "$OPS" "$OPS/rules/new-rule.md"
edit deny "$OPS" "$OPS/memory/../rules/backups.md"
write deny "$OPS" "$OPS/memory/nosuch/../../rules/backups.md"
write pass "$OPS" "$OPS/memory/nosuch/../../memory/network.md"
edit deny "$OPS" "$OPS/.claude/hooks/guard-mode.sh"
edit pass "$OPS" "$OPS/memory/servers/server1.example.com/memory.md"
edit pass "$OPS" "$OPS/memory/user.md"
edit pass "$OPS" "$OPS/.claude/settings.local.json"
edit pass "$OPS" "$TMP/elsewhere.txt"
write deny "$OPS" "$OPS/rules/x.md"
write pass "$OPS" "$OPS/memory/network.md"
write pass "$OPS" "$OPS/memory/servers/server2.example.com/memory.md"
# A link in memory/ that leads to a shipped file is that file.
ln -s ../rules/backups.md "$OPS/memory/sneaky.md"
edit deny "$OPS" "$OPS/memory/sneaky.md"
rm "$OPS/memory/sneaky.md"
# ...and so is the end of a chain too long to follow.
ln -s ../rules/backups.md "$OPS/memory/l0"
for n in 1 2 3 4 5 6 7 8 9 10 11; do
  ln -s "l$((n - 1))" "$OPS/memory/l$n"
done
edit deny "$OPS" "$OPS/memory/l11"
rm "$OPS"/memory/l*
# A DNS alias links to another host's directory in memory/.
mkdir -p "$OPS/memory/servers/web1.example.com"
ln -s web1.example.com "$OPS/memory/servers/www.example.com"
edit pass "$OPS" "$OPS/memory/servers/www.example.com/memory.md"

# Without jq the guard reads what it can with sed and refuses
# what it cannot, never the other way round. A PATH that holds
# every tool the hook uses except jq.
mkdir -p "$TMP/nojq"
for t in cat sed tr awk git readlink head; do
  ln -s "$(command -v "$t")" "$TMP/nojq/$t"
done
nojq() {
  out=$(printf '%s' "$3" | PATH="$TMP/nojq" /bin/sh "$2/.claude/hooks/guard-mode.sh")
  case "$out" in *'"permissionDecision":"deny"'*) got=deny ;; *) got=pass ;; esac
  if [ "$got" = "$1" ]; then ok; else bad "[$1, got $got] without jq: $3"; fi
}
nojq deny "$DEV" "$(bash_json 'ssh server1.example.com true')"
nojq pass "$DEV" "$(bash_json 'git status')"
nojq pass "$DEV" "$(edit_json "$DEV/rules/backups.md")"
nojq deny "$OPS" "$(edit_json "$OPS/rules/backups.md")"
nojq pass "$OPS" "$(edit_json "$OPS/memory/servers/server1.example.com/memory.md")"
nojq pass "$OPS" "$(bash_json 'ssh server1.example.com true')"

# --- session-mode.sh -------------------------------------------
says() {
  out=$(sh "$2/.claude/hooks/session-mode.sh" 2>&1)
  case "$out" in
  *"$3"*) ok ;;
  *) bad "session-mode in $1 does not say: $3" ;;
  esac
}
says development "$DEV" "development checkout"
# A token in the origin URL never reaches the transcript.
git -C "$DEV" remote add origin https://alice:tok3n@git.example.com/team/fork.git
case "$(sh "$DEV/.claude/hooks/session-mode.sh")" in
*tok3n*) bad "session-mode printed the credentials in origin" ;;
*git.example.com/team/fork*) ok ;;
*) bad "session-mode did not name a non-GitHub origin" ;;
esac
git -C "$DEV" remote remove origin
says operations "$OPS" "operations checkout"
says worktree "$WT" "linked worktree"

# --- bin/hostwarden-init ---------------------------------------
[ -d "$OPS/memory/.git" ] && ok || bad "init made no repository in memory/"
[ -f "$OPS/memory/.hostwarden-workspace" ] && ok || bad "init wrote no marker"
if [ -z "$(git -C "$OPS" status --porcelain)" ]; then ok
else bad "the workspace shows up in the outer repository"; fi
# What a team shares is not ignored, what stays personal is.
mkdir -p "$OPS/memory/servers/server1.example.com"
for f in servers/server1.example.com/memory.md \
    servers/server1.example.com/changelog.log network.md \
    custom-rules/all.md service-policy.md .hostwarden-workspace; do
  if git -C "$OPS/memory" check-ignore -q --no-index -- "$f"; then
    bad "the workspace ignores $f, which a team shares"
  else ok; fi
done
for f in user.md blacklist.md readonly.md opencode.json \
    servers/localhost/memory.md servers/.link-probe.x; do
  if git -C "$OPS/memory" check-ignore -q --no-index -- "$f"; then ok
  else bad "the workspace would share $f, which is personal"; fi
done
# Idempotent, and a repair: a second run fills in what is gone.
rm "$OPS/memory/.gitignore"
sh "$OPS/bin/hostwarden-init" >/dev/null 2>&1 && ok || bad "second init failed"
[ -f "$OPS/memory/.gitignore" ] && ok || bad "second init did not repair .gitignore"
# A hook of the user's own, or a core.hooksPath elsewhere, would
# leave the secret scan out: init refuses before it marks
# anything as a workspace.
H=$(checkout hooks)
git -C "$H" init --quiet memory
printf '#!/bin/sh\nexit 0\n' > "$H/memory/.git/hooks/pre-push"
if sh "$H/bin/hostwarden-init" >/dev/null 2>&1; then
  bad "init ran beside a pre-push hook of the user's own"
else ok; fi
mode_is development "$H"
rm "$H/memory/.git/hooks/pre-push"
git -C "$H/memory" config core.hooksPath /tmp/elsewhere
if sh "$H/bin/hostwarden-init" >/dev/null 2>&1; then
  bad "init ran with core.hooksPath pointing elsewhere"
else ok; fi
mode_is development "$H"
# The override the refusal recommends is accepted.
git -C "$H/memory" config core.hooksPath .git/hooks
sh "$H/bin/hostwarden-init" >/dev/null 2>&1 && ok \
  || bad "init refused core.hooksPath set to the workspace's own hooks"
mode_is operations "$H"
# Never in a worktree.
if sh "$WT/bin/hostwarden-init" >/dev/null 2>&1; then
  bad "init ran in a linked worktree"
else ok; fi
[ -x "$OPS/memory/.git/hooks/pre-commit" ] \
  && [ -x "$OPS/memory/.git/hooks/pre-push" ] && ok \
  || bad "init installed no secret scan in the workspace"

# --- bin/ -------------------------------------------------------
# The rules tell a session to run these by path, not through sh,
# so every one of them has to be committed executable.
git -C "$REPO" ls-files -s -- bin | while read -r m _ _ f; do
  [ "$m" = 100755 ] || echo "$f"
done > "$TMP/modes"
if [ -s "$TMP/modes" ]; then
  bad "committed without the executable bit: $(tr '\n' ' ' < "$TMP/modes")"
else ok; fi

# --- bin/hostwarden-sync ---------------------------------------
# Outside operations, every verb does nothing.
sh "$DEV/bin/hostwarden-sync" commit x && [ ! -e "$DEV/memory" ] && ok \
  || bad "sync acted in a development checkout"
# Without a remote, pull and push do nothing and succeed.
sh "$OPS/bin/hostwarden-sync" pull && sh "$OPS/bin/hostwarden-sync" push \
  && ok || bad "sync without a remote failed"

# Two machines on one private remote. Commits need an identity;
# a real one comes from the user's git config.
export GIT_AUTHOR_NAME=alice GIT_AUTHOR_EMAIL=alice@example.com
export GIT_COMMITTER_NAME=alice GIT_COMMITTER_EMAIL=alice@example.com
# With a remote, the workspace refuses a commit betterleaks has
# not scanned. Where it is missing, prove that; then stand in a
# stub that finds nothing, so the sync tests below can commit.
git init --quiet --bare --initial-branch=main "$TMP/remote.git"
if ! command -v betterleaks >/dev/null 2>&1; then
  git -C "$OPS/memory" remote add probe "$TMP/remote.git"
  echo x > "$OPS/memory/network.md"
  if sh "$OPS/bin/hostwarden-sync" commit probe >/dev/null 2>&1; then
    bad "a workspace with a remote committed without a secret scan"
  else ok; fi
  # ...and never pushes unscanned either.
  if git -C "$OPS/memory" push --quiet probe HEAD:main >/dev/null 2>&1; then
    bad "a workspace pushed without a secret scan"
  else ok; fi
  git -C "$OPS/memory" remote remove probe
  git -C "$OPS/memory" reset --quiet
fi
mkdir -p "$TMP/stub"
printf '#!/bin/sh\nexit 0\n' > "$TMP/stub/betterleaks"
chmod +x "$TMP/stub/betterleaks"
PATH="$TMP/stub:$PATH"
sync_a() { sh "$OPS/bin/hostwarden-sync" "$@"; }
sh "$OPS/bin/hostwarden-sync" commit "start the workspace" \
  && ok || bad "sync commit failed"
git -C "$OPS/memory" remote add origin "$TMP/remote.git"
git -C "$OPS/memory" push --quiet -u origin main
B=$(checkout b)
sh "$B/bin/hostwarden-init" --clone "$TMP/remote.git" >/dev/null
mode_is operations "$B"
sync_b() { sh "$B/bin/hostwarden-sync" "$@"; }
# A GIT_SSH_COMMAND the user set gets the no-prompt options too.
got=$(GIT_SSH_COMMAND='ssh -i /tmp/k' HOME="$TMP" sh -c \
  '. "$1"; hostwarden_git_batch; echo "$GIT_SSH_COMMAND"' _ "$HOOKS/mode.sh")
case "$got" in
"ssh -i /tmp/k -o BatchMode=yes"*ServerAliveInterval=15*) ok ;;
*) bad "an inherited GIT_SSH_COMMAND lost the required options: $got" ;;
esac
# A clone refused for its hooks path is taken back: the marker it
# brought must not make an operations checkout without the scan.
G=$(checkout global-hooks)
if GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath \
    GIT_CONFIG_VALUE_0=/tmp/elsewhere \
    sh "$G/bin/hostwarden-init" --clone "$TMP/remote.git" >/dev/null 2>&1; then
  bad "init --clone ran with core.hooksPath pointing elsewhere"
else ok; fi
mode_is development "$G"
[ ! -e "$G/memory" ] && ok || bad "a refused clone was left behind"
# A clone without symlink support says so.
C=$(checkout c)
out=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.symlinks \
  GIT_CONFIG_VALUE_0=false sh "$C/bin/hostwarden-init" --clone "$TMP/remote.git")
case "$out" in
*"made no symlinks"*) ok ;;
*) bad "a clone without symlinks went unmentioned" ;;
esac
LOG=servers/server1.example.com/changelog.log

# Both machines add to the same changelog; union merge keeps both.
printf '[2026-09-21 10:00] from a\n' > "$OPS/memory/$LOG"
sync_a commit "a: changelog"
sync_a push
mkdir -p "$B/memory/servers/server1.example.com"
printf '[2026-09-21 10:05] from b\n' > "$B/memory/$LOG"
sync_b commit "b: changelog"
out=$(sync_b pull)
if [ -z "$out" ] && grep -q 'from a' "$B/memory/$LOG" \
    && grep -q 'from b' "$B/memory/$LOG"; then ok
else bad "pull did not keep both changelog entries: $out"; fi
sync_b push
sync_a pull
grep -q 'from b' "$OPS/memory/$LOG" && ok \
  || bad "a second machine's push did not arrive"

# Uncommitted edits that clash with what the pull brought: the
# pull succeeds, the clash is reported, and nothing syncs until
# it is resolved — above all no commit of conflict markers.
MEM=servers/server1.example.com/memory.md
echo 'Kernel: 6.0' > "$OPS/memory/$MEM"
sync_a commit "a: base"
sync_a push
sync_b pull
echo 'Kernel: 6.1' > "$OPS/memory/$MEM"
sync_a commit "a: kernel"
sync_a push
echo 'Kernel: 5.10' > "$B/memory/$MEM"
case "$(sync_b pull)" in
*clash*) ok ;;
*) bad "a clash with uncommitted edits went unreported" ;;
esac
case "$(sync_b commit "b: kernel")" in
*"unresolved conflict"*) ok ;;
*) bad "sync committed over an unresolved conflict" ;;
esac
git -C "$B/memory" reset --quiet --hard
git -C "$B/memory" stash drop --quiet

# A real disagreement is aborted, reported and left alone.
echo 'OS: Debian 13' > "$OPS/memory/servers/server1.example.com/memory.md"
sync_a commit "a: os"
sync_a push
echo 'OS: Debian 12' > "$B/memory/servers/server1.example.com/memory.md"
sync_b commit "b: os"
out=$(sync_b pull)
case "$out" in
*"could not be brought up to"*) ok ;;
*) bad "a conflicting pull was not reported: $out" ;;
esac
grep -q 'Debian 12' "$B/memory/servers/server1.example.com/memory.md" \
  && [ ! -d "$B/memory/.git/rebase-merge" ] && ok \
  || bad "a conflicting pull did not leave the workspace as it was"

# A rebase the user is resolving by hand is theirs: sync touches
# nothing, not even with a remote to pull from.
git -C "$B/memory" pull --quiet --rebase >/dev/null 2>&1
[ -d "$B/memory/.git/rebase-merge" ] || bad "fixture: no rebase in progress"
out=$(sync_b pull; sync_b commit "b: mid-rebase")
case "$out" in
*"middle of a rebase"*) ok ;;
*) bad "sync did not refuse during a rebase: $out" ;;
esac
[ -d "$B/memory/.git/rebase-merge" ] && ok \
  || bad "sync aborted a rebase the user was resolving"

# --- bin/hostwarden-backup --restore ---------------------------
# A restore makes an operations install; a refused one leaves the
# checkout exactly as it was.
sh "$OPS/bin/hostwarden-backup" -o "$TMP/ws.tgz" >/dev/null
R=$(checkout refused)
mkdir -p "$R/memory"
echo 'Language: German' > "$R/memory/user.md"
if sh "$R/bin/hostwarden-backup" --restore "$TMP/ws.tgz" >/dev/null 2>&1; then
  bad "a restore overwrote user data without --force"
else ok; fi
mode_is development "$R"
R=$(checkout restored)
sh "$R/bin/hostwarden-backup" --restore "$TMP/ws.tgz" >/dev/null
mode_is operations "$R"
[ -f "$R/memory/servers/server1.example.com/memory.md" ] && ok \
  || bad "a restore lost server memory"

echo "guard-mode: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
