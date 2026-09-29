#!/bin/sh
# review-tier.sh — the tier of a change, light or full, from the
# files it touches, as .claude/rules/pull-requests.md → The own
# review says. The own review's tier and the review record's fix
# line both read it here. LIGHT below is the rule's light list,
# word for word; tests/scripts/review-record.sh fails when the two
# differ. CRITICAL is the list of the rule's critical files, kept
# here alone.
#
#   sh scripts/review-tier.sh [--critical] <old> [<new>]
#
# What `git diff` takes: a range such as `hostwarden/main...HEAD`
# alone, or two commits, whose trees it compares. Prints `light`,
# or `full` and then each file that made it full, one a line. A
# rename counts both its names, so moving a script into docs/ is
# full. With `--critical` it prints the critical files instead, one
# a line, and nothing where there is none. Exits 0 with the tier or
# the files, 1 when git cannot read the commits, 2 on a usage error.

# A directory ends in `/` and holds everything below it, a new
# file included; an entry with a `*` is a pattern, whose `*` crosses
# `/` as a case pattern's does; any other entry is one file. The
# rule file itself is never light, so a change to the review is
# reviewed in full.
LIGHT='docs/ website/docs/*.md README.md CONTRIBUTING.md SECURITY.md CHANGELOG.md changelog.d/ .claude/rules/'
NEVER=.claude/rules/pull-requests.md

# The files where a defect lets a taboo through, cuts SSH, leaks a
# secret or weakens the review itself: a reviewer of their own reads
# them. None of them is light, so a change with one is full.
CRITICAL='
.claude/hooks/
.claude/settings.json
lib/mode.sh
lib/json.sh
lib/coord-lib.sh
lib/coord-rest.sh
lib/coord-tokenize.sh
tests/hooks/
AGENTS.md
CLAUDE.md
rules/access-control.md
rules/accounts.md
rules/accounts-on-demand.md
rules/dns-aliases.md
rules/first-connection.md
rules/host-rename.md
rules/ssh-ca.md
rules/ssh-config.md
rules/ssh-ca-issuing.md
rules/system-containers.md
rules/anomaly-detection.md
rules/baseline.md
rules/borrowed-rights.md
rules/firewall-changes.md
rules/host-keys.md
rules/privilege-escalation.md
rules/secrets.md
rules/ssh-safety-net.md
rules/storage.md
.agents/skills/hostwarden-baseline/
.agents/skills/hostwarden-deploy-user/
.agents/skills/hostwarden-fleet-read/
.agents/skills/hostwarden-heinzel-takeover/
.agents/skills/hostwarden-new-guest/
.agents/skills/hostwarden-os-install/
templates/fleet-read/
bin/hostwarden-fleet-run
lib/hostwarden-fleet-run/
lib/hops.sh
lib/resolve.sh
bin/hostwarden-heinzel-takeover
lib/hostwarden-heinzel-takeover/
bin/hostwarden-impact
lib/hostwarden-impact/
bin/hostwarden-ssh-config
bin/hostwarden-update
lib/follow.sh
.github/release-signers
.github/workflows/tag-release.yml
.github/workflows/review-record.yml
.github/rulesets/
.claude/rules/pull-requests.md
.claude/agents/hostwarden-reviewer*
scripts/review-record.sh
lib/markdown-blocks.awk
scripts/review-tier.sh
tests/scripts/review-record*
'

usage() {
  echo "usage: sh scripts/review-tier.sh [--critical] <old> [<new>]" >&2
  exit 2
}
want=tier
case ${1-} in --critical) want=critical; shift ;; esac
case $# in 1 | 2) ;; *) usage ;; esac
for a; do case $a in '' | -*) usage ;; esac; done

# The patterns in the lists are for `case`, never for the file
# system.
set -f
# listed <list> <file> -- whether an entry of the list holds the file
listed() {
  for l in $1; do
    # shellcheck disable=SC2254 # a pattern entry is matched as one
    case $l in
      */) case $2 in "$l"*) return 0 ;; esac ;;
      *\**) case $2 in $l) return 0 ;; esac ;;
      "$2") return 0 ;;
    esac
  done
  return 1
}
light() { [ "$1" != "$NEVER" ] && listed "$LIGHT" "$1"; }
# A name git still quotes cannot be held to the list, so it counts.
critical() {
  case $1 in '"'*) return 0 ;; esac
  listed "$CRITICAL" "$1"
}

# Only the names are read: no blob, no diff driver, no textconv.
# A name git still quotes — one with a quote, a backslash or a
# control character — starts with `"` and so counts as full.
files=$(git -c core.quotePath=false diff --no-ext-diff --no-textconv \
  --no-renames --name-only "$@" --) || exit 1

full=
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ "$want" = critical ]; then
    ! critical "$f" || printf '%s\n' "$f"
  else
    light "$f" || full="$full$f
"
  fi
done <<EOF
$files
EOF

if [ "$want" = critical ]; then
  :
elif [ -z "$full" ]; then
  echo light
else
  echo full
  printf '%s' "$full"
fi
