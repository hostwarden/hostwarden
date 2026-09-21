# shellcheck shell=sh
# follow.sh — the release line a checkout follows, defined once.
#
# Sourced, never executed, by bin/hostwarden-update and
# check-updates.sh, from the top of the checkout.
#
# The line is `hostwarden.follow` in the checkout's own git
# config: a major ("1") or a major.minor ("1.2"). Never a shipped
# file — an update would carry it to every install, and a
# checkout at a tag could not change it. No line and no pin means
# the checkout follows main.
#
# Expects nothing. Defines:
#   hostwarden_follow          — prints the line, or nothing
#   hostwarden_follow_valid L  — true when L is a major or a
#                                major.minor
#   hostwarden_follow_tag L    — prints the highest vX.Y.Z tag on
#                                line L this clone knows, or
#                                nothing; fetch the tags first

hostwarden_follow() {
  git config --get hostwarden.follow 2>/dev/null || true
}

hostwarden_follow_valid() {
  case $1 in
  '' | *[!0-9.]* | .* | *. | *..* | *.*.*) return 1 ;;
  esac
}

# v1.* never matches v10.0.0, and v1.2.* never v1.20.0: the dot
# ends the number. A pre-release (v1.3.0-rc1) is no release.
hostwarden_follow_tag() {
  git tag -l "v$1.*" --sort=-v:refname |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1
}
