# lib/hostwarden-fleet-run/report.sh — the verdicts counted, the
# report rendered, recorded and sent. Sourced by
# bin/hostwarden-fleet-run, in the order its PARTS lists, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# A host was read when run_host marked it so; anything else, from a
# refused login to a bundle that does not verify, left it unread.
UNREAD=0
for h in $HOSTS; do
  [ -e "$WORK/hosts/$h/read" ] || UNREAD=$((UNREAD + 1))
done

if [ -z "$JUDGE" ]; then
  for h in $HOSTS; do
    printf '\n=== %s (bundle %s)\n' "$h" "$(cat "$WORK/hosts/$h/bundle")"
    cat "$WORK/hosts/$h/raw" 2>/dev/null
    jq -r '.findings[] | "\(.severity) \(.text)"' "$WORK/hosts/$h/result.json"
  done
  [ "$UNREAD" -eq 0 ] || exit 1
  exit 0
fi

jq -s '.' "$WORK"/hosts/*/result.json >"$WORK/all.json"

# Bundles near their date, and new builds nobody signed yet.
for s in "$FR"/src/*.sh; do
  [ -f "$s" ] || continue
  case $s in
    *.next.sh) note "${s##*/} waits for the operator's signature"; continue ;;
  esac
  u=$(sed -n 's/^# valid-until: \([0-9-]*\)$/\1/p' "$s" | head -n 1)
  t=$(date -d "$u" +%s 2>/dev/null || date -j -f %Y-%m-%d "$u" +%s 2>/dev/null) \
    || { note "${s##*/} has no readable valid-until date"; continue; }
  left=$(( (t - $(date +%s)) / 86400 ))
  [ "$left" -lt 30 ] \
    && note "${s##*/} stops running in $left days (valid-until $u); rebuild and sign it"
done

ALARM=$(jq '[.[].findings[] | select(.severity == "CRITICAL" and .class == "new")]
  | length' "$WORK/all.json")
COUNTS=$(jq -r "$JQ_SEV"'[.[].findings[]]
  | "\(count("CRITICAL")) \(count("WARN"))"' "$WORK/all.json")
CRIT=${COUNTS% *}
WARN=${COUNTS#* }
SKIPS=$(jq '[.[].skipped // [] | length] | add // 0' "$WORK/all.json")
UNJUDGED=$(( UNREAD + $(jq '[.[].findings[] | select(.code == "no-verdict")]
  | length' "$WORK/all.json") ))
if [ "$CRIT" -eq 0 ] && [ "$WARN" -eq 0 ] && [ "$SKIPS" -gt 0 ]; then
  SUBJECT="Fleet housekeeping: all ok, $SKIPS checks skipped"
elif [ "$CRIT" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  SUBJECT="Fleet housekeeping: all ok"
else
  SUBJECT="Fleet housekeeping: $CRIT critical, $WARN warning"
fi

# render — the report, from all.json and the notes.
render() {
  echo "# $SUBJECT"
  echo
  echo "$NOW, from $NAME, $(echo "$HOSTS" | wc -w | tr -d ' ') hosts."
  [ -n "$NOTES" ] && printf '\n## Notes\n%s\n' "$NOTES"
  echo
  echo "## Findings"
  echo
  jq -r --arg today "$TODAY" "$JQ_SEV"'[.[] | .host as $h | .findings[]
      | select(.class != "decided") | . + {host: $h}]
    | if length == 0 then "None." else
      sort_by(.severity | rank)[]
      | "\(.severity)\t\(.host)\t\(.text)"
        + (if .class != "new" then " (\(.class): \"\(.quote)\")" else "" end)
        + (if .since != $today then " — since \(.since)" else "" end)
        + (if .floor then " [floor]" else "" end)
      end' "$WORK/all.json"
  jq -r '.[] | select(.judge_error) | "No verdict for \(.host): \(.judge_error)"' \
    "$WORK/all.json"
  # A finding a decision settles is not an issue (rules/decisions.md
  # → Rating findings): it is listed apart, and named when due.
  jq -r '[.[] | .host as $h | .findings[] | select(.class == "decided")
      | . + {host: $h}]
    | if length > 0 then "\n## Decided\n",
        (.[] | "\(.host)\t\(.text) — DECIDED \(.quote)"
          + (if .revisit_due then " — revisit due" else "" end))
      else empty end' "$WORK/all.json"
  [ -n "$SKIPPED" ] && printf '\nNot read:%s\n' "$SKIPPED"
  jq -r '[.[] | select((.skipped // []) | length > 0)]
    | if length > 0 then "\n## Not checked\n",
        (.[] | "\(.host)\t\(.skipped | join("; "))") else empty end' \
    "$WORK/all.json"
  echo
  jq -r '.[] | select(.report != "") | "\n---\n\n\(.report)"' "$WORK/all.json"
}

# finish — the exit status: an alarm first, then a host that was not
# read or not judged, then a report that was not mailed.
UNSENT=
finish() {
  [ "$ALARM" -eq 0 ] || exit 2
  [ "$UNJUDGED" -eq 0 ] || exit 1
  [ -z "$UNSENT" ] || exit 1
  exit 0
}

if [ -n "$DRY" ]; then
  render
  finish
fi

# When each finding was first seen, for "since" in the next report.
jq --slurpfile prev "$PREV" 'reduce .[] as $r ($prev[0];
  .[$r.host] = ($r.findings | map({key: .code, value: .since}) | from_entries))' \
  "$WORK/all.json" >"$STATE/findings.new" \
  && mv "$STATE/findings.new" "$PREV"

# The workspace: the changelog lines of this run, nothing else.
PATHS=
for h in $HOSTS; do PATHS="$PATHS machines/$h/changelog.log"; done
# shellcheck disable=SC2086 # one path per word
sh bin/hostwarden-sync commit \
  "[$NAME as root] read-only: fleet housekeeping, $CRIT critical, $WARN warning" \
  $PATHS || note "the changelog lines were not committed"
if [ "$PUSH" = always ]; then
  sh bin/hostwarden-sync push >"$WORK/push" 2>&1 \
    || note "the workspace was not pushed: $(tail -n 1 "$WORK/push")"
else
  note "committed, not pushed: memory/user.md has no 'Workspace push: always'"
fi

render >"$WORK/report.md"
# A report that was meant to be mailed and was not fails the run:
# nobody would read it in the timer's log.
SENDMAIL=$(command -v sendmail 2>/dev/null || echo /usr/sbin/sendmail)
if [ -n "$MAIL" ] && [ ! -x "$SENDMAIL" ]; then
  echo "hostwarden-fleet-run: no sendmail to mail the report with" >&2
  UNSENT=1
  cat "$WORK/report.md"
elif [ -n "$MAIL" ]; then
  {
    printf 'To: %s\nSubject: %s\n' "$MAIL" "$SUBJECT"
    # The anti-auto-reply headers every Hostwarden mail carries
    # (hostwarden-email skill, references/compose.md).
    printf 'Auto-Submitted: auto-generated\nPrecedence: bulk\n'
    printf 'X-Auto-Response-Suppress: OOF, AutoReply\n'
    printf 'MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\n\n'
    cat "$WORK/report.md"
  } | "$SENDMAIL" -t -oi || {
    echo "hostwarden-fleet-run: the mail was not accepted" >&2
    UNSENT=1
    cat "$WORK/report.md"
  }
else
  cat "$WORK/report.md"
fi

finish
