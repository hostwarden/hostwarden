# tests/bin/hostwarden-wrap/hook.sh — the hook, in a checkout of
# each mode, and hostwarden-sync commit. Sourced by
# tests/bin/hostwarden-wrap.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the hook ----------------------------------------------------
# A checkout of each mode, the hook sitting in it: the mode is a
# property of the tree the hook finds its root from.
checkout() {
  c="$TMP/$1"
  mkdir -p "$c/.claude/hooks" "$c/bin" "$c/lib" "$c/rules"
  cp .claude/hooks/wrap-markdown.sh "$c/.claude/hooks/"
  cp lib/json.sh lib/mode.sh "$c/lib/"
  cp bin/hostwarden-wrap "$c/bin/"
  cp lib/markdown-blocks.awk "$c/lib/"
  printf '/memory/\n' > "$c/.gitignore"
  printf '%s\n' "$LONG" > "$c/rules/shipped.md"
  git -C "$c" init -q
  git -C "$c" add -A
  git -C "$c" -c user.name=alice -c user.email=alice@example.com \
    commit -q -m init
}
checkout dev
checkout ops
mkdir -p "$TMP/ops/memory/machines"
git -C "$TMP/ops/memory" init -q
: > "$TMP/ops/memory/.hostwarden-workspace"
ln -s ../rules "$TMP/ops/memory/linked"
ln -s ../rules/shipped.md "$TMP/ops/memory/link.md"
DEV=$(cd "$TMP/dev" && pwd -P)
OPS=$(cd "$TMP/ops" && pwd -P)

# hook <checkout> <file> <wanted: wrapped|left> <what>
hook() {
  c=$1 file=$2
  [ -e "$file" ] || printf '%s\n' "$LONG" > "$file"
  before=$(cat "$file")
  out=$(printf '{"session_id":"t","tool_name":"Edit","tool_input":{"file_path":"%s"}}' \
    "$file" | sh "$c/.claude/hooks/wrap-markdown.sh")
  if [ "$(cat "$file")" != "$before" ]; then got=wrapped; else got=left; fi
  if [ "$got" != "$3" ]; then
    bad "hook: $4 ($got)"
  elif [ "$got" = wrapped ]; then
    case $out in
      *'"hookEventName":"PostToolUse"'*'rewrapped'*) ok ;;
      *) bad "hook: $4 says nothing: $out" ;;
    esac
  else
    ok
  fi
}
hook "$DEV" "$DEV/rules/shipped.md" wrapped "development rewraps a shipped file"
hook "$DEV" "$DEV/notes.txt" left "a file that is no .md"
hook "$DEV" "$TMP/outside.md" left "a file outside the checkout"
hook "$OPS" "$OPS/memory/machines/web1.example.com.md" wrapped \
  "operations rewraps a file under memory/"
hook "$OPS" "$OPS/rules/shipped.md" left "operations leaves a shipped file"
hook "$OPS" "$OPS/memory/link.md" left \
  "operations leaves a link into a shipped file"
hook "$OPS" "$OPS/memory/linked/shipped.md" left \
  "operations leaves a shipped file behind a directory link"
printf '# %s\n' "$LONG" > "$DEV/head.md"
out=$(printf '{"tool_input":{"file_path":"%s"}}' "$DEV/head.md" \
  | sh "$DEV/.claude/hooks/wrap-markdown.sh")
case $out in
  *'Still over 80'*'head.md:1 (85)'*) ok ;;
  *) bad "hook: a heading over 80 is not named: $out" ;;
esac
out=$(printf '{"tool_input":{"file_path":"%s"}}' "$DEV/rules/shipped.md" \
  | sh "$DEV/.claude/hooks/wrap-markdown.sh")
[ -z "$out" ] && ok || bad "hook: a file that fits gets a message: $out"

# After a shell command, which names no file: what git sees as
# changed or new, in the checkout in development and in memory/
# alone in operations.
bash_hook() {
  printf '{"tool_name":"Bash","tool_input":{"command":"true"}}' \
    | sh "$1/.claude/hooks/wrap-markdown.sh"
}
mkdir "$DEV/docs"
printf '%s\n' "$LONG" > "$DEV/docs/shell.md"
out=$(bash_hook "$DEV")
case $out in
  *'rewrapped docs/shell.md at 80'*'Still over 80'*'head.md:1 (85)'*) ok ;;
  *) bad "hook after a command in development: $out" ;;
esac
printf '%s\n' "$LONG" > "$OPS/memory/machines/db1.example.com.md"
printf '%s\n' "$LONG" >> "$OPS/rules/shipped.md"
out=$(bash_hook "$OPS")
case $out in
  *'rewrapped memory/machines/db1.example.com.md at 80'*) ok ;;
  *) bad "hook after a command in operations: $out" ;;
esac
[ "$(wc -l < "$OPS/rules/shipped.md")" -eq 2 ] && ok \
  || bad "hook after a command rewrapped a shipped file in operations"

# --- hostwarden-sync commit --------------------------------------
# Whatever wrote it, a workspace commit takes Markdown wrapped.
cp bin/hostwarden-sync "$OPS/bin/"
git -C "$OPS/memory" config user.name alice
git -C "$OPS/memory" config user.email alice@example.com
printf '%s\n' "$LONG" > "$OPS/memory/machines/web2.example.com.md"
(cd "$OPS" && sh bin/hostwarden-sync commit "Test" \
  memory/machines/web2.example.com.md) || bad "hostwarden-sync commit failed"
got=$(git -C "$OPS/memory" show HEAD:machines/web2.example.com.md 2>/dev/null)
[ "$got" = "$(printf '%s\n%s' "${LONG% words}" words)" ] && ok \
  || bad "hostwarden-sync commit took Markdown unwrapped: $got"
[ -z "$(git -C "$OPS/memory" status --porcelain -- machines/web2.example.com.md)" ] \
  && ok || bad "hostwarden-sync commit left a change behind"
