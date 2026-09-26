# tests/instructions/skills.sh — skills, the override migration and
# references/ pointers. Sourced by tests/instructions.sh, in its
# order, into the one shell every part shares; never run on its own.
# shellcheck shell=sh

# --- skills resolve through .claude/skills ---------------------
# The skills live in .agents/skills/, which OpenCode and other
# AGENTS-style tools read directly. Claude Code does NOT search
# .agents/, so the .claude/skills link is load-bearing: a
# checkout that turns it into a plain file loses every skill,
# including the security audit. Fail loudly instead.
if [ ! -L "$CLAUDE_DIR/skills" ]; then
  bad ".claude/skills is not a symlink -- Claude Code does not" \
      "search .agents/, so no skill is visible to it"
elif [ ! -d "$CLAUDE_DIR/skills" ]; then
  bad ".claude/skills is a symlink that does not resolve"
elif [ "$(cd "$CLAUDE_DIR/skills" && pwd -P)" \
       != "$(cd "$ROOT/.agents/skills" && pwd -P)" ]; then
  bad ".claude/skills resolves somewhere other than" \
      ".agents/skills/"
else
  ok
fi

# --- every skill is a skill ------------------------------------
# A directory without a SKILL.md is invisible to every tool, so
# it is a skill nobody loads rather than a skill.
NSKILLS=0
for d in "$ROOT"/.agents/skills/*/; do
  [ -d "$d" ] || continue
  NSKILLS=$((NSKILLS + 1))
  if [ -f "$d/SKILL.md" ]; then
    ok
  else
    bad ".agents/skills/$(basename "$d") has no SKILL.md"
  fi
done

if [ "$NSKILLS" -eq 0 ]; then
  bad "no skills found under .agents/skills/ -- the search broke"
fi

# --- every override the migration moves has somewhere to land ---
# bin/hostwarden-migrate carries a table of topics that changed
# address, and moves a user's override to the new one. A row whose
# destination does not exist relocates an override to a path
# nothing reads -- the exact failure the table exists to prevent.
MIGRATE="$ROOT/bin/hostwarden-migrate"
if [ -f "$MIGRATE" ]; then
  map_rows() {
    sed -n "/^MAP='/,/'\$/p" "$MIGRATE" | sed "s/^MAP='//; s/'\$//"
  }

  # The other direction, and the one that costs a user their
  # override rather than misplacing it: a row moves
  # `memory/custom-rules/<old>.md` away, which is right only while
  # nothing ships under that key any more. Ship a rule file named
  # after a row's left column again and the migration relocates a
  # live override on the next pull, silently, because that move
  # looks exactly like the intended one.
  BAD_SRC=$(
    map_rows \
      | while read -r old new; do
          [ -n "$old" ] && [ -n "$new" ] || continue
          if [ -f "$ROOT/rules/$old.md" ] \
            || [ -d "$ROOT/.agents/skills/$old" ]; then
            echo "bin/hostwarden-migrate: $old"
          fi
        done
  )
  report "$BAD_SRC" "a topic that has actually moved away"

  BAD_MAP=$(
    map_rows \
      | while read -r old new; do
          # Only a wholly blank row is nothing. A row that names a
          # topic and no destination makes the script move the
          # override onto memory/custom-rules/ itself.
          [ -n "$old" ] || continue
          if [ -z "$new" ]; then
            echo "bin/hostwarden-migrate: '$old' with no destination"
            continue
          fi
          # The destination is a file name, and the override lookup
          # reads .md. Without it the move lands somewhere nothing
          # reads, which is the failure this table exists to stop.
          case "$new" in
            (*.md) ;;
            (*) echo "bin/hostwarden-migrate: $new (no .md suffix)"
                continue ;;
          esac
          skill="${new%%/*}"
          leaf="${new##*/}"
          if [ "$skill" = "$new" ]; then
            # a bare name is a skill's own SKILL.md
            [ -f "$ROOT/.agents/skills/${new%.md}/SKILL.md" ] && continue
          else
            [ -f "$ROOT/.agents/skills/$skill/references/$leaf" ] && continue
          fi
          [ -f "$ROOT/rules/$new" ] && continue
          echo "bin/hostwarden-migrate: $new"
        done
  )
  report "$BAD_MAP" "a path anything ships"
fi

# --- a references/ pointer resolves ----------------------------
# Two shapes, because `references/x.md` means "inside the skill
# that wrote this". A skill may use it; anywhere else it resolves
# against nothing, so a cross-skill pointer spells the path out
# from the repo root -- longer, and unambiguous.
#
# Both are checked here, at any depth, wherever they are written:
# a full path is a pointer no matter which file names it, and the
# whole point of rewriting one is that it can then be verified.
#
# What is not checked: a relative pointer in a file outside
# `.agents/skills/`. In `rules/overrides.md` and
# website/docs/running-it/tailoring/overrides.md that shape appears in a
# table *describing* the mirror scheme, and no pattern separates
# an example of a path from a use of one. Those two files
# document; they do not route.
REF_RE='`(\.agents/skills/[a-z0-9-]+/)?references/[a-z0-9._/-]+\.md`'
BAD_REFS=$(
  scan | tag "$REF_RE" \
    | tr -d '`' \
    | while IFS=' ' read -r f r; do
        fp="${f%:}"
        case "$r" in
          (.agents/skills/*)
            [ -f "$ROOT/$r" ] || echo "$f $r" ;;
          (*)
            case "$fp" in
              (.agents/skills/*)
                sk=$(printf '%s' "$fp" | cut -d/ -f1-3)
                [ -f "$ROOT/$sk/$r" ] || echo "$f $r" ;;
            esac ;;
        esac
      done
)
NREFS=$(scan | tag "$REF_RE" | grep -c . || true)
report "$BAD_REFS" "a reference that resolves"
if [ "$NREFS" -lt 5 ]; then
  bad "only $NREFS references/ pointers found -- the search broke"
fi
