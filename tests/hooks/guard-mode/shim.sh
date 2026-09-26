# tests/hooks/guard-mode/shim.sh — the shim. Sourced by
# tests/hooks/guard-mode.sh, in the order its PARTS lists, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the shim --------------------------------------------------
# One executable script per tool, and exactly the tools the guard
# names.
n=0
for f in "$HOOKS"/shim/*; do
  t=${f##*/} n=$((n + 1))
  [ -x "$f" ] && grep -q '/../shim.sh"$' "$f" && ok \
    || bad "shim/$t does not source shim.sh"
  case "$t" in
  *.exe) grep -q "W = .*[(|]${t%.exe}[|)]" "$HOOKS/guard-mode.sh" ;;
  *) grep -q "T = .*[(|]${t}[|)]" "$HOOKS/guard-mode.sh" ;;
  esac && ok || bad "shim/$t names a tool the guard does not"
done
# And as many as the guard names, counted from its two lists.
nt=$(sed -n 's/^ *T = "^(\([^)]*\))\$"$/\1/p' "$HOOKS/guard-mode.sh" \
  | tr '|' '\n' | grep -c .)
nw=$(sed -n 's/^ *W = "^(\([^)]*\))\[\.\]exe\$"$/\1/p' "$HOOKS/guard-mode.sh" \
  | tr '|' '\n' | grep -c .)
[ "$n" -eq $((nt + nw)) ] && [ "$nt" -gt 0 ] && [ "$nw" -gt 0 ] && ok \
  || bad "shim/ holds $n tools, the guard names $nt and $nw .exe"
# The prefilter in front of T and W lists the tools a third time: a
# path to each one gets past it to the parse, which denies.
for f in "$HOOKS"/shim/*; do
  cmd deny "$DEV" "/opt/x/${f##*/} server1.example.com"
done
drain
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
refused "$DEV" "$ENVF" 'ansible all -m ping'
refused "$DEV" "$ENVF" 'ansible-playbook -i inventory site.yml'
refused "$DEV" "$ENVF" 'ansible-pull -U https://git.example.com/site.git'
refused "$DEV" "$ENVF" 'ansible-console all'
refused "$DEV" "$ENVF" 'bash -c "terraform plan"'
refused "$DEV" "$ENVF" 'tofu apply'
refused "$DEV" "$ENVF" 'ssh.exe server1.example.com'
refused "$DEV" "$ENVF" 'wsl.exe -u root -e id'
refused "$DEV" "$ENVF" 'powershell.exe -Command Get-Service'
refused "$DEV" "$ENVF" 'bash -c "cmd.exe /c ver"'
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
# scripts/check.sh runs the doctor with the shim on PATH, and the
# pre-push hook with it: --dev must not count the refusal as a
# missing tool.
got=$(sh -c '. "$1"; sh "$2/bin/hostwarden-doctor" --dev --quiet' _ \
  "$ENVF" "$REPO" 2>&1)
case "$got" in
*"connection sharing"*) bad "the doctor read the shim as missing: $got" ;;
*) ok ;;
esac
# Nor the shim as the ssh a push needs: with no other ssh on PATH,
# ssh is missing.
mkdir -p "$TMP/nossh"
got=$(PATH="$DEV/.claude/hooks/shim:$TMP/nossh" /bin/sh \
  "$REPO/bin/hostwarden-doctor" --dev --quiet 2>&1)
case "$got" in
"hostwarden: required, missing: ssh,"*) ok ;;
*) bad "the doctor took the shim for ssh: $got" ;;
esac
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
