# tests/hooks/guard-taboos/instruction-blocks.sh — every code block
# the instruction layer ships. Sourced by
# tests/hooks/guard-taboos.sh, in its order, into the one shell
# every part shares; never run on its own.
# shellcheck shell=sh

# --- every code block the instruction layer ships passes -------
# The corpus is every place an instruction can carry a command, so
# a block stays covered when it moves between mechanisms. It is
# defined in tests/corpus.sh, shared with tests/instructions.sh, because
# two lists in one directory drift apart.
# A taboo word used as data in a documented probe is denied like
# the command itself and cancels the whole parallel batch. The
# security skill once skipped inert login shells by a regex of
# their names; the deny pins why that shape was retired. A block
# meant to be denied says so after the language on its fence:
# `operator` (the user runs it, Hostwarden never does) or `guard-off`
# (Hostwarden runs it only after the user relaunched with the
# override, so its file must say how). The file name in each
# block path keeps names unique when find starts awk twice.
check deny "awk -F: '(\$7 ~ /(nologin|false|sync|shutdown|halt)\$/)' /etc/passwd"

# shellcheck source=../../corpus.sh
. "$REPO/tests/corpus.sh"

BLOCKS=$(mktemp -d)
# CHANGELOG.md is scanned for identifiers but not for blocks: it
# records what a release changed, so a command it quotes is
# history, not something a session is told to run. Running it
# through the guard would fail CI for describing a past mistake
# accurately.
#
# Blocks are found by fenced() from tests/corpus.sh, the parser the layout
# test uses: both fence characters, and a close only on a run at
# least as long as the opener. A prohibited command in a ~~~ block
# was once invisible to this matrix, which is the one place that
# cannot have a blind spot, and a ~~~~ block closed by nothing
# would sweep the next ordinary block into its exemption.
corpus_files | grep '\.md$' | grep -v '/CHANGELOG\.md$' \
  | tr '\n' '\0' | xargs -0 \
  awk -v dir="$BLOCKS" "$FENCE_AWK"'
  FNR == 1             { FM = ""; out = "" }
  { was = FM }
  !fenced($0)          { next }
  was == ""            { if (/[ \t](operator|guard-off)[ \t]*$/) next
                         f = FILENAME; gsub(/\//, "_", f); n++
                         # A long checkout path would pass the
                         # 255-byte limit on one file name.
                         if (length(f) > 150) f = substr(f, length(f) - 149)
                         out = dir "/" f "." n; next }
  FM == ""             { if (out) close(out); out = ""; next }
  out                  { print > out }
'
NBLOCKS=0
for blk in "$BLOCKS"/*; do
  [ -f "$blk" ] || continue
  NBLOCKS=$((NBLOCKS + 1))
  check pass "$(cat "$blk")"
done
rm -rf "$BLOCKS"
if [ "$NBLOCKS" -eq 0 ]; then
  FAIL=$((FAIL + 1))
  echo "FAIL: no code blocks found in the instruction corpus"
fi

# The OS-install references carry guard-off blocks by design, so
# finding none means the search broke, not that all is well.
NGUARDOFF=0
while read -r md; do
  [ -n "$md" ] || continue
  NGUARDOFF=$((NGUARDOFF + 1))
  if grep -q 'HOSTWARDEN_GUARD_DISABLE' "$md"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $md has guard-off blocks but never names" \
      "HOSTWARDEN_GUARD_DISABLE"
  fi
done <<EOF
$(corpus_files | grep '\.md$' | grep -v '/CHANGELOG\.md$' \
  | tr '\n' '\0' | xargs -0 grep -lE \
  '^[[:space:]]*(```|~~~).*[[:space:]]guard-off[[:space:]]*$')
EOF
if [ "$NGUARDOFF" -eq 0 ]; then
  FAIL=$((FAIL + 1))
  echo "FAIL: no guard-off blocks found in the instruction corpus"
fi
