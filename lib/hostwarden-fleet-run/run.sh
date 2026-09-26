# lib/hostwarden-fleet-run/run.sh — one host collected, judged and
# logged, four at a time. Sourced by bin/hostwarden-fleet-run, in
# the order its PARTS lists, into the one shell every part shares;
# never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# run_host <host> — collect, judge and merge into <dir>/result.json;
# on a real run, log the summary on the host and in its changelog.
# still_blacklisted <host> — the blacklist check again, from the file
# as it is now, right before a connection: a host can be listed
# while the run waits for it (rules/access-control.md → Server
# Blacklist, before every connection attempt).
still_blacklisted() {
  BLACK=$(hostwarden_list_entries "$M/blacklist.md")
  blacklisted "$1" 0 root
}

run_host() {
  h=$1
  d=$WORK/hosts/$h
  b=$(cat "$d/bundle")
  : >"$d/floors.jsonl"
  : >"$d/judge.err"
  # What may explain a finding: memory.md, or one of the decisions
  # by its heading, with its Revisit: date (rules/decisions.md).
  decisions "$h" >"$d/decisions"
  awk '/^## / { if (h != "") print h "\t" r; h = substr($0, 4); r = "" }
    /^- Revisit:/ { r = $3 } END { if (h != "") print h "\t" r }' \
    "$d/decisions" | jq -R -s 'split("\n") | map(select(length > 0)
      | split("\t") | {h: .[0], r: (.[1] // "")})' >"$d/decided.json"
  # The host is the one memory knows (rules/dns-aliases.md →
  # Detection): the name ssh connects to resolves to the recorded
  # IP, on the recorded port, since the same address on another
  # port is another machine; and its key is the one in the
  # workspace's known_hosts, which ssh checks itself.
  g=$(ssh -F "$SSHCFG" -G "root@$h" 2>/dev/null)
  ip=$(mem_line "$h" IP)
  now=$(hostwarden_resolve "$(printf '%s\n' "$g" | sed -n 's/^hostname //p')" | tr '\n' ' ')
  port=$(printf '%s\n' "$g" | sed -n 's/^port //p')
  mport=$(mem_line "$h" 'SSH port')
  same=; case " $now" in *" $ip "*) same=1 ;; esac
  if [ -n "$ip" ] && [ -z "$now" ]; then
    finding "$d/floors.jsonl" INFO identity-unchecked \
      "the name did not resolve here; only the host key vouches for it"
  fi
  if [ -n "$ip" ] && [ -n "$now" ] && [ -z "$same" ]; then
    finding "$d/floors.jsonl" WARN unreachable \
      "not read: the name resolves to ${now% }, memory records $ip"
  elif [ -n "$mport" ] && [ -n "$port" ] && [ "$port" != "$mport" ]; then
    finding "$d/floors.jsonl" WARN unreachable \
      "not read: ssh would use port $port, memory records $mport"
  elif [ -z "$b" ] || [ ! -e "$WORK/verified/$b" ]; then
    finding "$d/floors.jsonl" WARN fleet-read-bundle \
      "bundle '${b:-?}' is missing or does not verify against the workspace's signers"
  elif still_blacklisted "$h"; then
    finding "$d/floors.jsonl" WARN unreachable "not read: $BL_WHY"
  else
    # A read counts only when the connection, the wrapper and the
    # bundle all ended well and the bundle's last section, the
    # floors, arrived: partial output would pass for a full check.
    rc=0
    cat "$FR/src/$b.sh.sig" "$FR/src/$b.sh" \
      | fleet_ssh "$h" 300 collect >"$d/raw" 2>"$d/err" || rc=$?
    if [ "$rc" -eq 0 ] && grep -qx '### floors' "$d/raw"; then
      : >"$d/read"
      floors "$d/raw" "$d/floors.jsonl"
      [ -n "$JUDGE" ] && judge "$h" "$d" "$b"
    else
      why=$(LC_ALL=C tr -cd '[:print:]\n' <"$d/err" | grep -v '^$' \
        | tail -n 1 | cut -c 1-160)
      [ "$rc" -eq 0 ] && why="the output ended before the floors section"
      finding "$d/floors.jsonl" WARN unreachable \
        "not read (exit $rc): ${why:-no output}"
    fi
  fi
  [ -f "$d/judge.json" ] || echo '{"report":"","findings":[]}' >"$d/judge.json"
  jq -n --arg h "$h" --arg today "$TODAY" \
    --rawfile mem "$M/machines/$h/memory.md" --rawfile err "$d/judge.err" \
    --slurpfile dh "$d/decided.json" \
    --slurpfile fl "$d/floors.jsonl" \
    --slurpfile prev "$PREV" \
    --slurpfile j "$d/judge.json" "$JQ_SEV"'
    def norm: gsub("\\s+"; " ");
    ($mem | norm) as $m
    # Headings the verdict names as contradicting each other settle
    # nothing (rules/decisions.md: ask before relying on either).
    | ([($j[0].findings // [])[] | objects
        | select(.code == "decision-conflict") | .text // "" | tostring]
       | join("\n")) as $conf
    | ($j[0].findings // [])
    | map(select(type == "object")
        | .severity = (if (.severity | IN("CRITICAL", "WARN", "INFO"))
            then .severity else "INFO" end)
        | .code = ((.code // "other") | tostring | .[0:40])
        | .text = ((.text // "") | tostring | .[0:200])
        | ((.quote // "") | tostring | norm) as $q
        | if .class == "decided" then
            ([$dh[0][] | select((.h | norm) == $q)] | first) as $hit
            | if $hit != null and ($conf | contains($hit.h) | not)
              then .quote = $hit.h
                | .revisit_due = ($hit.r != "" and $hit.r < $today)
              else .class = "new" | .quote = null end
          elif (.class == "known" or .class == "expected")
             and ($q | length) >= 30 and ($m | contains($q))
          then . else .class = "new" | .quote = null end)
    # Every floor row stays, one per resource. Verdict rows of the
    # same code give way to them. Only where one floor row and one
    # verdict row share a code are they the same resource for sure:
    # then the verdict lends its class, quote and any higher
    # severity. Otherwise a known /var would pass as a known /home.
    | ($fl | map(.code) | unique) as $fc
    | map(select(.code as $c | any($fc[]; . == $c))) as $jm
    | map(select(.code as $c | any($fc[]; . == $c) | not))
    + ($fl | map(. as $x
        | [$jm[] | select(.code == $x.code)] as $jr
        | ([$fl[] | select(.code == $x.code)] | length) as $nf
        | (if ($jr | length) == 1 and $nf == 1 then $jr[0] else null end) as $one
        | $x + {floor: true, class: ($one.class // "new"),
                quote: ($one.quote // null),
                revisit_due: ($one.revisit_due // false)}
        | if $one != null and ($one.severity | rank) < ($x.severity | rank)
          then .severity = $one.severity else . end))
    # A host the model did not judge is a finding, not a quiet gap.
    | if $err != "" then . + [{severity: "WARN", code: "no-verdict",
        text: ("not judged: " + $err), class: "new", quote: null}]
      else . end
    | map(.since = ((($prev[0] // {})[$h] // {})[.code] // $today))
    | sort_by(.severity | rank)
    | {host: $h, findings: ., report: ($j[0].report // ""),
       skipped: ($j[0].skipped // [])}
      + (if $err != "" then {judge_error: $err} else {} end)
    ' >"$d/result.json" 2>"$d/merge.err" \
    || jq -n --arg h "$h" \
      '{host: $h, report: "", judge_error: "merge failed",
        findings: [{severity: "WARN", code: "no-verdict", class: "new",
          quote: null, text: "not judged: the verdict could not be merged"}]}' \
      >"$d/result.json"
  jq -r "$JQ_SEV"'.findings | map(select(.class != "decided"))
    | if length == 0 then "housekeeping: no findings"
      else "housekeeping: "
        + ([("CRITICAL", "WARN", "INFO") as $s | count($s) as $n
            | select($n > 0) | "\($n) \($s)"] | join(", "))
        + " — " + (map(.text) | join("; "))
      end' "$d/result.json" | cut -c 1-250 >"$d/summary"
  [ -n "$DRY" ] && return
  # The record: one read-only line in the host's journal, through
  # the wrapper, and the same line in its changelog.
  [ -e "$d/read" ] && ! still_blacklisted "$h" \
    && fleet_ssh "$h" 30 log <"$d/summary" >/dev/null 2>&1
  {
    printf '[%s] [%s as root] read-only: %s\n' "$NOW" "$NAME" "$(cat "$d/summary")"
    printf '  Detail: fleet read from %s, bundle %s.\n' "$NAME" "$b"
  } >>"$M/machines/$h/changelog.log"
}

# Four hosts at a time, the next one started as soon as any ends.
for h in $HOSTS; do
  while [ "$(ls "$WORK/running" | wc -l)" -ge 4 ]; do sleep 1; done
  : >"$WORK/running/$h"
  { run_host "$h"; rm -f "$WORK/running/$h"; } &
done
wait
