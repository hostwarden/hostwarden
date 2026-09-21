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
# Run inside a Claude Code session, session-mode.sh would write to
# that session's own env file.
unset CLAUDE_ENV_FILE

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
# fails <message> <command...> — the command must fail.
fails() { m=$1; shift; if "$@" >/dev/null 2>&1; then bad "$m"; else ok; fi; }
# has <text> <needle> <message> — the text contains the needle.
has() { case "$1" in *"$2"*) ok ;; *) bad "$3: $1" ;; esac; }

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
    "$HOOKS/shim.sh" "$HOOKS/git-ssh.sh" "$c/.claude/hooks/"
  cp -R "$HOOKS/shim" "$c/.claude/hooks/"
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
fails "init made a workspace outside a git clone" sh "$ARC/bin/hostwarden-init"

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

# Development: the guard denies what goes past a PATH lookup. A
# bare tool name is the shim's (below), wherever it stands.
cmd deny "$DEV" '/usr/bin/ssh server1.example.com'
cmd deny "$DEV" 'cd /tmp && /usr/bin/scp a.txt server1.example.com:/tmp/'
cmd deny "$DEV" '! /usr/local/bin/mosh server1.example.com'
cmd deny "$DEV" 'FOO=1 /usr/bin/sudo whoami'
cmd deny "$DEV" 'echo $(/usr/bin/ssh server1.example.com hostname)'
cmd deny "$DEV" 'bash -c "true; /usr/bin/sudo whoami"'
cmd deny "$DEV" 'command -p ssh server1.example.com'
cmd deny "$DEV" 'command -p sudo whoami'
cmd deny "$DEV" 'command  -p ssh server1.example.com'
cmd deny "$DEV" "sh -c 'command -p ssh server1.example.com'"
cmd deny "$DEV" 'eval "command -p sudo whoami"'
cmd pass "$DEV" 'command -v ssh-keygen; grep -p x file'
cmd deny "$DEV" 'exec /usr/bin/ssh server1.example.com'
cmd deny "$DEV" 'PATH=/usr/bin:/bin ssh server1.example.com'
cmd deny "$DEV" 'export PATH=/usr/bin:/bin; ssh server1.example.com'
cmd deny "$DEV" 'env -i ssh server1.example.com'
cmd deny "$DEV" 'env PATH=/usr/bin sudo whoami'
cmd deny "$DEV" 'unset PATH; ssh server1.example.com'
cmd deny "$DEV" "PATH=/usr/bin sh -c 'ssh server1.example.com'"
cmd deny "$DEV" 'path=(/usr/bin /bin); ssh server1.example.com'
cmd deny "$DEV" 'true
PATH=/usr/bin ssh server1.example.com'
cmd deny "$DEV" 'true
	path=(/usr/bin); ssh server1.example.com'
cmd deny "$DEV" 'env -u PATH sudo whoami'
cmd deny "$DEV" 'env --unset=PATH ssh server1.example.com'
cmd deny "$DEV" 'env -uPATH ssh server1.example.com'
cmd deny "$DEV" 'env --unset PATH ssh server1.example.com'
cmd deny "$DEV" 'env - ssh server1.example.com'
cmd deny "$DEV" 'env -iv sudo whoami'
cmd pass "$DEV" 'env -u LANG sort file.txt'
cmd deny "$DEV" 'env -u LANG -i ssh server1.example.com'
cmd deny "$DEV" 'env FOO=1 --unset PATH ssh server1.example.com'
cmd pass "$DEV" 'env LANG=C grep -i ssh rules/ssh-user.md'
# rsync talks to a daemon itself; no ssh, so no shim, on the way.
cmd deny "$DEV" 'rsync -a rsync://server1.example.com/mod/ here/'
cmd deny "$DEV" "rsync -a 'rsync://server1.example.com/mod/' here/"
cmd deny "$DEV" 'rsync -av server1.example.com::mod here/'
cmd deny "$DEV" 'rsync -av here/ "server1.example.com::mod/x"'
cmd pass "$DEV" 'rsync -a src/ /tmp/copy/'
cmd pass "$DEV" 'grep -rn "std::string" src/ | rsync -a src/ /tmp/copy/'
cmd pass "$DEV" 'rsync -a src/ /tmp/copy/ && grep -rn "std::string" src/'
# A path elsewhere in the command counts once it is a program.
mkdir -p "$TMP/bin"
printf '#!/bin/sh\n' > "$TMP/bin/ssh"
chmod +x "$TMP/bin/ssh"
cmd deny "$DEV" "rsync -a -e $TMP/bin/ssh src/ server1.example.com:/srv/"
cmd deny "$DEV" "rsync -a -e '$TMP/bin/ssh -p 2222' src/ server1.example.com:/srv/"
cmd deny "$DEV" "git -c core.sshCommand=$TMP/bin/ssh push"
cmd pass "$DEV" "grep -rn Port $TMP/bin/ssh.d/"
cmd pass "$DEV" 'ls /etc/ssh'
# Every path in the command is looked at, not only the first.
cmd deny "$DEV" "ls /etc/ssh && rsync -a -e $TMP/bin/ssh src/ server1.example.com:/srv/"
cmd deny "$DEV" '$GIT_SSH_COMMAND root@server1.example.com uptime'
cmd deny "$DEV" '"${GIT_SSH_COMMAND}" server1.example.com'
cmd deny "$DEV" 'ssh-keygen -lf k.pub; /usr/bin/doas true'
# ...and everything a development session actually does passes.
cmd pass "$DEV" 'ssh root@server1.example.com uptime'
cmd pass "$DEV" 'sudo apt-get update'
cmd pass "$DEV" 'grep -rn ssh rules/'
cmd pass "$DEV" 'git commit -F /tmp/msg.txt'
cmd pass "$DEV" 'git push -u origin feat/28-workspace-mode'
cmd pass "$DEV" 'ssh-keygen -lf key.pub'
cmd pass "$DEV" 'ls -l /etc/ssh/'
cmd pass "$DEV" 'rsync -a templates/ /tmp/copy/'
cmd pass "$DEV" 'sh .claude/hooks/guard-taboos-test.sh'
cmd pass "$DEV" 'git commit -m "ssh: keep one connection per host"'
cmd pass "$DEV" 'command -v ssh'
cmd pass "$DEV" 'command -pv sudo'
cmd pass "$DEV" 'PATH="$PWD/stub:$PATH" sh test.sh'
cmd pass "$DEV" 'PYTHONPATH=lib python3 ssh_check.py'
cmd pass "$DEV" 'grep -n Port rules/ssh-connections.md'
cmd pass "$DEV" 'sed -n 1,20p .claude/hooks/shim/ssh'
cmd pass "$DEV" 'echo "$GIT_SSH_COMMAND"'
cmd pass "$DEV" 'cat > notes.md <<EOF
ssh root@server1.example.com uptime
sudo systemctl reload nginx
EOF'
edit pass "$DEV" "$DEV/rules/backups.md"

# The taboo guard's off switch does not reach the mode guard.
out=$(bash_json '/usr/bin/ssh server1.example.com true' \
  | HOSTWARDEN_GUARD_DISABLE=1 sh "$DEV/.claude/hooks/guard-mode.sh")
case "$out" in
*'"permissionDecision":"deny"'*) ok ;;
*) bad "HOSTWARDEN_GUARD_DISABLE switched the mode guard off" ;;
esac

# Worktree: development, whatever the main checkout is.
cmd deny "$WT" '/usr/bin/ssh root@server1.example.com uptime'
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
# Text that looks like the tool name does not pass for a Bash call.
verdict deny "$OPS" "$(jq -n --arg p "$OPS/rules/x.md" \
  '{tool_name:"Write",tool_input:{file_path:$p,content:"\"tool_name\":\"Bash\""}}')"
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
nojq deny "$DEV" "$(bash_json '/usr/bin/ssh server1.example.com true')"
nojq pass "$DEV" "$(bash_json 'ssh server1.example.com true')"
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
says worktree "$WT" "how: rules/server-check-handoff.md"
out=$(unset CLAUDE_ENV_FILE; sh "$DEV/.claude/hooks/session-mode.sh")
case "$out" in
*"no CLAUDE_ENV_FILE"*) ok ;;
*) bad "session-mode did not say that the shim is missing" ;;
esac

# --- the shim --------------------------------------------------
# One executable script per tool, and exactly the tools the guard
# names.
n=0
for f in "$HOOKS"/shim/*; do
  t=${f##*/} n=$((n + 1))
  [ -x "$f" ] && grep -q '/../shim.sh"$' "$f" && ok \
    || bad "shim/$t does not source shim.sh"
  grep -q "T = .*[(|]${t}[|)]" "$HOOKS/guard-mode.sh" && ok \
    || bad "shim/$t names a tool the guard does not"
done
[ "$n" -eq 8 ] && ok || bad "shim/ holds $n tools, the guard names 8"
# session <checkout> <env file> [VAR=value...] — session-mode.sh
# as Claude Code runs it at session start.
session() {
  c=$1 e=$2
  shift 2
  env "$@" CLAUDE_ENV_FILE="$e" sh "$c/.claude/hooks/session-mode.sh" >/dev/null
}
# refused <checkout> <env file> <command> — the command, run after
# the env file as every Bash call is, prints the refusal. Whether
# it fails is the wrapper's to say: find -exec succeeds anyway.
refused() {
  err=$(cd "$1" && sh -c '. "$1"; eval "$2"' _ "$2" "$3" 2>&1 >/dev/null)
  case "$err" in
  *"hostwarden mode guard: "*" reaches a server"*) ok ;;
  *) bad "the shim did not refuse: $3 ($err)" ;;
  esac
}
ENVF="$TMP/dev.env"
session "$DEV" "$ENVF" -u GIT_SSH_COMMAND -u GIT_SSH
DEV_ERR=$(sh -c '. "$1"; ssh server1.example.com' _ "$ENVF" 2>&1)
[ $? -eq 1 ] && ok || bad "the shim does not exit 1"
# Everything the parser used to have to read reaches the tool
# through PATH, and so the shim.
refused "$DEV" "$ENVF" 'ssh root@server1.example.com uptime'
refused "$DEV" "$ENVF" 'sudo -n true'
refused "$DEV" "$ENVF" 'sudoedit /etc/hosts'
refused "$DEV" "$ENVF" 'pkexec whoami'
refused "$DEV" "$ENVF" 'doas true'
refused "$DEV" "$ENVF" 'scp a.txt server1.example.com:/tmp/'
refused "$DEV" "$ENVF" 'sftp server1.example.com'
refused "$DEV" "$ENVF" 'mosh server1.example.com'
refused "$DEV" "$ENVF" 'bash -c "ssh server1.example.com"'
refused "$DEV" "$ENVF" "sh -ec 'sudo whoami'"
refused "$DEV" "$ENVF" 'eval "ssh server1.example.com"'
refused "$DEV" "$ENVF" 'echo "up: $(ssh server1.example.com uptime)"'
refused "$DEV" "$ENVF" 'env LC_ALL=C ssh server1.example.com'
refused "$DEV" "$ENVF" 'env -S "ssh server1.example.com true"'
refused "$DEV" "$ENVF" 'nohup ssh server1.example.com'
refused "$DEV" "$ENVF" 'echo a | xargs -n 1 ssh server1.example.com'
refused "$DEV" "$ENVF" 'find . -maxdepth 0 -exec ssh server1.example.com true \;'
refused "$DEV" "$ENVF" 'cat <<EOF | sh
ssh server1.example.com
EOF'
# Claude Code runs each command in the user's shell, zsh on macOS:
# the env file and the PATH lookup work there the same.
if command -v zsh >/dev/null 2>&1; then
  err=$(cd "$DEV" && zsh -fc '. "$1"; ssh server1.example.com' _ "$ENVF" 2>&1)
  case "$err" in
  *"hostwarden mode guard: ssh reaches a server"*) ok ;;
  *) bad "the shim did not refuse in zsh: $err" ;;
  esac
fi
if command -v rsync >/dev/null 2>&1; then
  refused "$DEV" "$ENVF" 'rsync -a rules/ server1.example.com:/srv/'
  refused "$DEV" "$ENVF" 'rsync -a -e "ssh -p 2222" rules/ "server1.example.com:/srv/"'
fi
# Written once: a second start (resume, compaction) adds nothing,
# and sourcing the file twice puts the shim on PATH once.
session "$DEV" "$ENVF" -u GIT_SSH_COMMAND -u GIT_SSH
[ "$(grep -c 'hooks/shim' "$ENVF")" -eq 1 ] && ok \
  || bad "a second session start wrote the shim again"
got=$(sh -c '. "$1"; . "$1"; printf %s "$PATH"' _ "$ENVF" \
  | tr ':' '\n' | grep -c 'hooks/shim$')
[ "$got" -eq 1 ] && ok || bad "sourcing the env file twice doubled the shim"
# git push goes through git-ssh.sh to the real binary: the shim
# off PATH, then what the user set, else core.sshCommand, else
# plain ssh. A stand-in ahead on PATH records its arguments.
mkdir -p "$TMP/realssh"
printf '#!/bin/sh\necho "$*" > "%s/ssh.log"\nexit 1\n' "$TMP" > "$TMP/realssh/ssh"
chmod +x "$TMP/realssh/ssh"
# via <env file> <expected> <message> [command...] — the command,
# run after the env file with the stand-in ssh on PATH, reached it
# with <expected> as its arguments.
via() {
  e=$1 want=$2 m=$3
  shift 3
  rm -f "$TMP/ssh.log"
  (cd "$DEV" && PATH="$TMP/realssh:$PATH" sh -c '. "$1"; shift; "$@"' _ "$e" "$@") >/dev/null 2>&1
  got=$(cat "$TMP/ssh.log" 2>/dev/null)
  case "$got" in
  *"$want"*) ok ;;
  *) bad "$m: ssh got '$got'" ;;
  esac
}
via "$ENVF" "server1.example.com git-upload-pack" "git did not reach the real ssh" \
  git ls-remote server1.example.com:repo.git
E2="$TMP/user-ssh.env"
session "$DEV" "$E2" -u GIT_SSH GIT_SSH_COMMAND='ssh -i /tmp/k'
via "$E2" "-i /tmp/k server1.example.com" "a GIT_SSH_COMMAND of the user lost its options" \
  git ls-remote server1.example.com:repo.git
git -C "$DEV" config core.sshCommand 'ssh -p 2222'
via "$ENVF" "-p 2222 server1.example.com" "core.sshCommand was not used" \
  git ls-remote server1.example.com:repo.git
git -C "$DEV" config --unset core.sshCommand
# A session started from inside another inherits its wrapper, which
# must not become the user's own command: it would run itself.
E6="$TMP/nested.env"
session "$DEV" "$E6" -u GIT_SSH GIT_SSH_COMMAND="'$DEV/.claude/hooks/git-ssh.sh'"
grep -q HOSTWARDEN_GIT_SSH_COMMAND "$E6" \
  && bad "a nested session kept git-ssh.sh as the user's command" || ok
# A session started inside another carries both shims on PATH; git
# still reaches the real ssh past the outer one.
mkdir -p "$TMP/outer/.claude/hooks/shim"
printf '#!/bin/sh\necho outer > "%s/ssh.log"\nexit 1\n' "$TMP" \
  > "$TMP/outer/.claude/hooks/shim/ssh"
chmod +x "$TMP/outer/.claude/hooks/shim/ssh"
rm -f "$TMP/ssh.log"
(cd "$DEV" && PATH="$TMP/outer/.claude/hooks/shim:$TMP/realssh:$PATH" \
  sh -c '. "$1"; git ls-remote server1.example.com:repo.git' _ "$ENVF") >/dev/null 2>&1
case "$(cat "$TMP/ssh.log" 2>/dev/null)" in
*server1.example.com*) ok ;;
*) bad "git-ssh.sh left the shim of an outer session on PATH" ;;
esac
# GIT_SSH_COMMAND outranks GIT_SSH: with both set, git runs the
# command, which the wrapper has to carry.
E7="$TMP/both.env"
session "$DEV" "$E7" GIT_SSH=/opt/bin/myssh GIT_SSH_COMMAND='ssh -i /tmp/k'
via "$E7" "-i /tmp/k server1.example.com" "GIT_SSH_COMMAND beside GIT_SSH hit the shim" \
  git ls-remote server1.example.com:repo.git
E3="$TMP/git-ssh.env"
session "$DEV" "$E3" GIT_SSH=/opt/bin/myssh
grep -q GIT_SSH_COMMAND "$E3" && bad "GIT_SSH_COMMAND set over a GIT_SSH of the user" \
  || ok
# A GIT_SSH without a path goes through PATH, so the wrapper carries it.
E8="$TMP/git-ssh-bare.env"
session "$DEV" "$E8" -u GIT_SSH_COMMAND GIT_SSH=ssh
via "$E8" "server1.example.com git-upload-pack" "a GIT_SSH of ssh hit the shim" \
  env GIT_SSH=ssh git ls-remote server1.example.com:repo.git
# A worktree says so; operations gets no shim at all.
E4="$TMP/wt.env"
session "$WT" "$E4" -u GIT_SSH_COMMAND
err=$(cd "$WT" && sh -c '. "$1"; ssh server1.example.com' _ "$E4" 2>&1)
case "$err" in
*"linked git worktree"*) ok ;;
*) bad "the shim in a worktree did not say so: $err" ;;
esac
# The refusal names the next step: in a worktree the main checkout
# to hand the check to, elsewhere the clone to set up, and in both
# the rule that says how.
has "$err" "operations session in the main checkout, $DEV," \
  "the refusal in a worktree did not name the main checkout"
has "$DEV_ERR" "separate clone, set up once with bin/hostwarden-init" \
  "the refusal in development did not name the clone"
# reason <checkout> — the guard's refusal of ssh by its path, read
# back from its JSON, which fails when the JSON is not valid.
reason() {
  bash_json '/usr/bin/ssh server1.example.com' \
    | sh "$1/.claude/hooks/guard-mode.sh" \
    | jq -r .hookSpecificOutput.permissionDecisionReason 2>&1
}
has "$(reason "$DEV")" "how: rules/server-check-handoff.md" \
  "the guard in development did not name the handoff rule"
# A main checkout whose path holds a quote and a backslash is
# named as it is, in valid JSON.
Q=$(checkout 'q"u\o')
git -C "$Q" worktree add --quiet -b feat/q "$TMP/qwt" 2>/dev/null
has "$(reason "$TMP/qwt")" "main checkout, $Q, if" \
  "the guard garbled a main checkout with a quote in its path"
# ...and a shipped file named with a tab and a newline still gets
# a refusal in valid JSON.
has "$(edit_json "$OPS/rules/a	b
c.md" | sh "$OPS/.claude/hooks/guard-mode.sh" \
  | jq -r .hookSpecificOutput.permissionDecision 2>&1)" "deny" \
  "a control character in a path broke the guard's JSON"
E5="$TMP/ops.env"
: > "$E5"
session "$OPS" "$E5" -u GIT_SSH_COMMAND PATH=/usr/bin:/bin
[ -s "$E5" ] && bad "session-mode wrote to the env file in operations" || ok
# Started from inside a development session, operations drops the
# inherited shim and wrapper again, and gives back what the user set.
E9="$TMP/ops-nested.env"
: > "$E9"
session "$OPS" "$E9" PATH="$DEV/.claude/hooks/shim:$TMP/realssh:$PATH" \
  GIT_SSH_COMMAND="'$DEV/.claude/hooks/git-ssh.sh'" \
  HOSTWARDEN_GIT_SSH_COMMAND='ssh -i /tmp/k'
got=$(PATH="$DEV/.claude/hooks/shim:$TMP/realssh:$PATH" \
  GIT_SSH_COMMAND="'$DEV/.claude/hooks/git-ssh.sh'" \
  HOSTWARDEN_GIT_SSH_COMMAND='ssh -i /tmp/k' \
  sh -c '. "$1"; command -v ssh; echo "$GIT_SSH_COMMAND|${HOSTWARDEN_GIT_SSH_COMMAND:-}"' _ "$E9")
case "$got" in
*/hooks/shim/ssh*) bad "operations kept the inherited shim: $got" ;;
*"$TMP/realssh/ssh"*"ssh -i /tmp/k|") ok ;;
*) bad "operations did not restore the user's ssh: $got" ;;
esac

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
fails "init ran beside a pre-push hook of the user's own" sh "$H/bin/hostwarden-init"
mode_is development "$H"
rm "$H/memory/.git/hooks/pre-push"
git -C "$H/memory" config core.hooksPath /tmp/elsewhere
fails "init ran with core.hooksPath pointing elsewhere" sh "$H/bin/hostwarden-init"
mode_is development "$H"
# The override the refusal recommends is accepted.
git -C "$H/memory" config core.hooksPath .git/hooks
sh "$H/bin/hostwarden-init" >/dev/null 2>&1 && ok \
  || bad "init refused core.hooksPath set to the workspace's own hooks"
mode_is operations "$H"
# Never in a worktree.
fails "init ran in a linked worktree" sh "$WT/bin/hostwarden-init"
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
sync_a() { sh "$OPS/bin/hostwarden-sync" "$@"; }
# Outside operations, every verb does nothing.
sh "$DEV/bin/hostwarden-sync" commit x && [ ! -e "$DEV/memory" ] && ok \
  || bad "sync acted in a development checkout"
# Without a remote, pull and push do nothing and succeed.
sync_a pull && sync_a push \
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
  fails "a workspace with a remote committed without a secret scan" sync_a commit probe
  # ...and never pushes unscanned either.
  fails "a workspace pushed without a secret scan" git -C "$OPS/memory" push --quiet probe HEAD:main
  git -C "$OPS/memory" remote remove probe
  git -C "$OPS/memory" reset --quiet
fi
mkdir -p "$TMP/stub"
printf '#!/bin/sh\nexit 0\n' > "$TMP/stub/betterleaks"
chmod +x "$TMP/stub/betterleaks"
PATH="$TMP/stub:$PATH"
sync_a commit "start the workspace" \
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
[ ! -e "$G/memory" ] && [ ! -e "$G/memory.clone" ] && ok \
  || bad "a refused clone was left behind"
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

# Uncommitted edits belong to another session, or to one that
# ended before committing: pull leaves them and the workspace
# alone, says so, and stashes nothing.
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
*"was not brought up to date"*) ok ;;
*) bad "pull ran over uncommitted changes" ;;
esac
grep -q 'Kernel: 5.10' "$B/memory/$MEM" \
  && [ -z "$(git -C "$B/memory" stash list)" ] && ok \
  || bad "pull touched uncommitted changes or stashed them"
git -C "$B/memory" checkout --quiet -- "$MEM"
sync_b pull
# An uncommitted file the remote did not touch does not stop a
# fast-forward past it.
echo 'Kernel: 6.2' > "$OPS/memory/$MEM"
sync_a commit "a: kernel 6.2" "$MEM"
sync_a push
mkdir -p "$B/memory/servers/server3.example.com"
echo 'OS: Alpine' > "$B/memory/servers/server3.example.com/memory.md"
out=$(sync_b pull)
if [ -z "$out" ] && grep -q 'Kernel: 6.2' "$B/memory/$MEM" \
    && [ -e "$B/memory/servers/server3.example.com/memory.md" ]; then ok
else bad "pull did not fast-forward past an untouched uncommitted file: $out"; fi
rm -rf "$B/memory/servers/server3.example.com"

# commit with paths takes only those files — a new one included —
# and leaves another session's changes where they are.
N=servers/server2.example.com/memory.md
mkdir -p "$B/memory/servers/server2.example.com"
echo 'OS: FreeBSD 14' > "$B/memory/$N"
echo 'Kernel: another session' > "$B/memory/$MEM"
sync_b commit "b: server2" "memory/$N"
git -C "$B/memory" log -1 --name-only --format= | grep -qx "$N" \
  && [ -n "$(git -C "$B/memory" status --porcelain -- "$MEM")" ] && ok \
  || bad "commit with a path took more than that path, or missed it"
git -C "$B/memory" checkout --quiet -- "$MEM"
# Another session's git holding the index is waited out.
echo 'OS: FreeBSD 14.1' > "$B/memory/$N"
: > "$B/memory/.git/index.lock"
( sleep 1; rm -f "$B/memory/.git/index.lock" ) &
sync_b commit "b: server2 again" "$N" \
  && git -C "$B/memory" log -1 --format=%s | grep -qx 'b: server2 again' \
  && ok || bad "commit gave up on a held index.lock"
wait
sync_b push
sync_a pull

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
fails "a restore overwrote user data without --force" sh "$R/bin/hostwarden-backup" --restore "$TMP/ws.tgz"
mode_is development "$R"
# An archive that carries the workspace's git internals is refused
# whole: restored, they would replace the hooks that scan commits.
mkdir -p "$TMP/evil/memory/.git/hooks"
printf '#!/bin/sh\nexit 0\n' > "$TMP/evil/memory/.git/hooks/pre-commit"
echo x > "$TMP/evil/memory/network.md"
tar czf "$TMP/evil.tgz" -C "$TMP/evil" memory
R=$(checkout evil)
fails "a restore accepted memory/.git from an archive" \
  sh "$R/bin/hostwarden-backup" --restore "$TMP/evil.tgz"
mode_is development "$R"
R=$(checkout restored)
sh "$R/bin/hostwarden-backup" --restore "$TMP/ws.tgz" >/dev/null
mode_is operations "$R"
[ -f "$R/memory/servers/server1.example.com/memory.md" ] && ok \
  || bad "a restore lost server memory"

echo "guard-mode: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
