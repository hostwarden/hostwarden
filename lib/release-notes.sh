# shellcheck shell=sh
# release-notes.sh — what an update brought, by the lead clause of
# each changelog entry (.claude/rules/repo-release.md → CHANGELOG.md).
#
# Sourced, never executed, by bin/hostwarden-update, from the top of
# the checkout.
#
# Expects lib/follow.sh. Defines:
#   hostwarden_notes_leads [plain]
#                          — reads changelog text on stdin, prints
#                            one line per entry: section, lead
#                            clause, the whole entry, tab-separated.
#                            Only entries with a bold lead clause,
#                            unless plain is given: then an entry
#                            without one leads with its first line
#   hostwarden_notes_section V
#                          — reads a CHANGELOG.md on stdin, prints
#                            the body of version V's section
#   hostwarden_release_notes OLD NEW
#                          — prints, newest first, each vX.Y.Z tag
#                            HEAD has and commit OLD has not, and
#                            under it the lead clauses of its
#                            section, read from the CHANGELOG.md at
#                            that tag, so a CHANGELOG.md that keeps
#                            only its own release serves as well as
#                            one that keeps them all. Version NEW
#                            without a tag, main's VERSION ahead of
#                            its tag, comes first, from HEAD's
#                            CHANGELOG.md

hostwarden_notes_leads() {
  awk -v plain="${1:-}" '
    function flush(   i, lead) {
      if (buf == "") return
      if (substr(buf, 1, 2) == "**" && (i = index(substr(buf, 3), "**")))
        lead = substr(buf, 3, i - 1)
      else if (plain) lead = first
      if (lead != "") print sec "\t" lead "\t" buf
      buf = ""
    }
    !NF { flush(); next }
    /^#+ / { flush(); sec = $0; sub(/^#+ /, "", sec); next }
    /^- / { flush(); buf = substr($0, 3); first = buf; next }
    buf != "" { t = $0; sub(/^[ \t]+/, "", t); buf = buf " " t }
    END { flush() }
  '
}

# Match the version heading exactly ("## 2.8.0" must not also match
# "## 2.8.0-rc1"): compare the whole second field, not a prefix.
hostwarden_notes_section() {
  awk -v ver="$1" '
    /^## / { if (insec) exit; insec = ($2 == ver); next }
    insec
  '
}

# hostwarden_notes_version <version> <rev> — the lead clauses of one
# release, from the CHANGELOG.md at <rev>.
hostwarden_notes_version() {
  echo ""
  echo "$1:"
  hn=$(git show "$2:CHANGELOG.md" 2>/dev/null |
    hostwarden_notes_section "$1" | hostwarden_notes_leads plain |
    awk -F '\t' '{ print "  " ($1 == "" ? "" : $1 ": ") $2 }')
  if [ -n "$hn" ]; then
    printf '%s\n' "$hn"
  else
    echo "  (its CHANGELOG.md has no notes for it)"
  fi
}

hostwarden_release_notes() {
  hr=$(hostwarden_follow_between HEAD "$1" -v:refname)
  # main's VERSION can be ahead of its tag, before the tag is pushed
  # or where none is: its notes are HEAD's.
  printf '%s\n' "$hr" | grep -qxF "v$2" ||
    hostwarden_notes_version "$2" HEAD
  for ht in $hr; do hostwarden_notes_version "${ht#v}" "$ht"; done
  echo ""
  echo "The full text of a release: its section of" \
    "'git show vX.Y.Z:CHANGELOG.md', or of HEAD's CHANGELOG.md where" \
    "it has no tag yet."
}
