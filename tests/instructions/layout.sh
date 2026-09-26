# tests/instructions/layout.sh — wrapping, shared texts, CI jobs,
# appliance and platform files, ignore rules. Sourced by
# tests/instructions.sh, in its order, into the one shell every part
# shares; never run on its own.
# shellcheck shell=sh

# --- every .md wraps at 80 -------------------------------------
# .claude/rules/instruction-authoring.md → Layout: a URL or a
# command line that cannot be broken may exceed it. What counts as
# a character and which lines are exempt is bin/hostwarden-wrap's
# --check, the measure its rewrap fills to: were they two, the
# wrap would leave lines this test fails, or move lines it passes.
# A file it cannot read is named on stderr, which is kept apart:
# xargs reports a finding and that failure with the same status.
WRAPERR=$(mktemp)
WRAP=$(corpus_files | grep '\.md$' | tr '\n' '\0' \
  | xargs -0 sh "$ROOT/bin/hostwarden-wrap" --check 2> "$WRAPERR")
if [ -s "$WRAPERR" ]; then
  bad "bin/hostwarden-wrap --check: $(cat "$WRAPERR")"
fi
rm -f "$WRAPERR"
report "$(printf '%s\n' "$WRAP" | sed '/^$/d' \
  | CORPUS_ROOT="$CORPUS_ROOT/" awk '{ n = $0; r = ENVIRON["CORPUS_ROOT"]
      if (index(n, r) == 1) n = substr(n, length(r) + 1)
      print n }')" "wrapped at 80 characters"
[ -z "$WRAP" ] || echo "  sh bin/hostwarden-wrap <file> rewraps a paragraph;" \
  "a heading, a table row or front matter is shortened by hand"

# --- the firewall listing filter has one text -------------------
# rules/secrets.md -> Commands That Leak holds the filter that shows
# a rule's comment as `...`; the probes that run as one call carry a
# copy of it. A copy that drifts withholds less, and nothing in the
# output says so. A copy ends at its closing quote, wherever on the
# line that stands, and one that never closes is a finding too.
report "$(corpus_files | grep '\.md$' | tr '\n' '\0' \
  | xargs -0 awk -v root="$CORPUS_ROOT/" -v ref="$ROOT/rules/secrets.md" '
  function take(l) { sub(/^[ \t]+/, "", l); return l "\n" }
  function closes(l, first) {
    if (first) sub(/^[ \t]*fc=\047/, "", l)
    return index(l, "\047") > 0
  }
  function rel(n) {
    if (index(n, root) == 1) n = substr(n, length(root) + 1)
    return n
  }
  BEGIN {
    while ((getline l < ref) > 0) {
      first = 0
      if (!in_ref && l ~ /^[ \t]*fc=\047/) in_ref = first = 1
      if (in_ref) { want = want take(l); if (closes(l, first)) break }
    }
    close(ref)
    if (want == "") print "rules/secrets.md: no fc filter to compare with"
  }
  FNR == 1 && on { print rel(pf) ":" at ": fc never closes"; on = 0 }
  { pf = FILENAME; first = 0 }
  !on && /^[ \t]*fc=\047/ { on = first = 1; got = ""; at = FNR }
  on { got = got take($0)
    if (closes($0, first)) {
      on = 0
      if (got != want) print rel(FILENAME) ":" at ": fc differs from rules/secrets.md"
    } }
  END { if (on) print rel(pf) ":" at ": fc never closes" }')" \
  "one firewall listing filter"

# --- every required check is a CI job ---------------------------
# The ruleset names the checks a pull request waits for, the
# workflows name the jobs that report them. Rename one without the
# other and every pull request waits for a check that never comes.
# So does a job in a workflow that lacks a pull request trigger
# (pull_request or pull_request_target) or merge_group: it never reports on the pull request, or
# never in the queue. A trigger's branches or types filter is not
# read.
RULESET="$ROOT/.github/rulesets/main.json"
CONTEXTS=$(sed -n 's/.*"context": *"\([^"]*\)".*/\1/p' "$RULESET" 2>/dev/null)
if [ -z "$CONTEXTS" ]; then
  bad "main.json requires no check -- the ruleset is gone or this" \
      "check stopped matching"
else
  # What GitHub reports is a job's `name:` if it has one, else its
  # key; and only under jobs: -- `on:` has two-space keys too.
  JOBS=$(awk 'FNR == 1 { j = o = 0; k = "" }
      { sub(/[ \t]*#.*/, "") }
      # An event is a key under on:, or an item of on: [a, b].
      /^on:/ { o = 1; t = $0; sub(/^on:/, "", t); gsub(/[][ \t]/, "", t)
               n = split(t, e, ",")
               for (i = 1; i <= n; i++) EV[FILENAME, e[i]] = 1 }
      o && /^[^ ]/ && !/^on:/ { o = 0 }
      o && /^  [a-z_]+:/ { t = $1; sub(/:$/, "", t); EV[FILENAME, t] = 1 }
      /^jobs:/ { j = 1; next }
      j && /^[^ ]/ { j = 0 }
      j && /^  [A-Za-z0-9_-]+:/ { k = $1; sub(/:$/, "", k)
                                 ctx[FILENAME, k] = k }
      j && k && /^    name:/ { n = $0; sub(/^    name: */, "", n)
                              gsub(/["\047]/, "", n); ctx[FILENAME, k] = n }
      END { for (x in ctx) { split(x, f, SUBSEP)
                             if ((f[1], "merge_group") in EV \
                                 && ((f[1], "pull_request") in EV \
                                     || (f[1], "pull_request_target") in EV))
                               print ctx[x] } }' \
      "$ROOT"/.github/workflows/*.yml)
  # One context per line: a job name may hold spaces.
  while IFS= read -r ctx; do
    if printf '%s\n' "$JOBS" | grep -qxF "$ctx"; then
      ok
    else
      bad "main.json requires check '$ctx', which no job in a" \
        "workflow on pull requests and merge_group reports"
    fi
  done <<EOF
$CONTEXTS
EOF
fi

# --- appliance files hold to their contract ---------------------
# An appliance file is read on top of its family file the way an
# override is (rules/os-detection.md -> Layers). A `Replace:` or
# `Remove:` that names nothing in the base takes nothing out, and the
# family's advice then stands where it is wrong; detection reaches
# only the files the marker table of rules/first-detection.md
# lists. Whether the Base file exists is the pointer check's job
# above.
report "$(awk -v root="$ROOT/" -v table="$ROOT/rules/first-detection.md" \
  "$LOAD_AWK"'
  function done() {
    if (rel == "") return
    if (!based) print rel ": no Base line"
    else if (!hw) print rel ": no Hardware: vendor or any line under Base"
    if (!ha) print rel ": no ## Housekeeping and Audits section"
  }
  function body(p, sec,   l, h, on, t) {
    if ((p, sec) in BODY) return BODY[p, sec]
    while ((getline l < p) > 0) {
      if (l ~ /^## /) { h = l; sub(/^## +/, "", h); on = (h == sec); continue }
      if (on) t = t "\n" l
    }
    close(p); return BODY[p, sec] = t
  }
  function text(p,   l, t) {
    if (p in RAW) return RAW[p]
    while ((getline l < p) > 0) t = t "\n" l
    close(p); return RAW[p] = t
  }
  FNR == 1 {
    done(); FM = ""; based = ha = hw = hwline = 0; base = ""
    rel = substr(FILENAME, length(root) + 1)
    if (!index(text(table), "`" rel "`"))
      print rel ": not in the marker table of rules/first-detection.md"
  }
  fenced($0) { next }
  FNR == hwline && /^Hardware: (vendor|any)$/ { hw = 1 }
  /^Base: / {
    based = 1; hwline = FNR + 1; b = $2; gsub(/`/, "", b)
    if (b == "none") next
    if (b !~ /^rules\/os\/[a-z0-9-]+\.md$/) print rel ": Base " b " is no family file"
    else base = root b
    next
  }
  $0 == "## Housekeeping and Audits" { ha = 1 }
  /^## (Replace|Remove): / {
    sec = $0; sub(/^## [A-Za-z]+: */, "", sec); entry = ""
    if ((i = index(sec, " > "))) { entry = substr(sec, i + 3); sec = substr(sec, 1, i - 1) }
    if (base == "") { print rel ": " sec " has no base to take it from"; next }
    fm = FM; ok = load(base); FM = fm
    if (!ok) next
    for (i = 1; i <= NH[base]; i++) if (H[base, i] == sec) break
    if (i > NH[base]) print rel ": " sec " is no section of " substr(base, length(root) + 1)
    else if (entry != "" && !index(body(base, sec), entry))
      print rel ": " entry " is no entry of " sec
  }
  END { done() }' "$ROOT"/rules/appliance/*.md)" \
  "an appliance file that fits its base"

# --- platform files hold to theirs -------------------------------
# A platform file applies to whichever family detection found
# (rules/os-detection.md -> Layers), so a `Replace:` or `Remove:`
# may only name a section that every family file has; one only some
# have takes nothing out on the others, silently.
# The family list goes in through the environment: awk -v rejects a
# value with a newline in it.
report "$(FAMILIES="$(printf '%s\n' "$ROOT"/rules/os/*.md)" \
  awk -v root="$ROOT/" -v table="$ROOT/rules/first-detection.md" "$LOAD_AWK"'
  function done() {
    if (rel == "") return
    if (based) print rel ": a Base line, but it has no fixed base"
    if (!ha) print rel ": no ## Housekeeping and Audits section"
  }
  BEGIN {
    nfam = split(ENVIRON["FAMILIES"], F, "\n")
    for (f = 1; f <= nfam; f++)
      if (load(F[f])) for (i = 1; i <= NH[F[f]]; i++)
        if (!((F[f], H[F[f], i]) in SEEN)) { SEEN[F[f], H[F[f], i]]; N[H[F[f], i]]++ }
    while ((getline l < table) > 0) t = t "\n" l
    close(table)
  }
  FNR == 1 {
    done(); FM = ""; based = ha = 0
    rel = substr(FILENAME, length(root) + 1)
    if (!index(t, "`" rel "`"))
      print rel ": not in the marker table of rules/first-detection.md"
  }
  fenced($0) { next }
  /^Base: / { based = 1 }
  $0 == "## Housekeeping and Audits" { ha = 1 }
  /^## (Replace|Remove): / {
    sec = $0; sub(/^## [A-Za-z]+: */, "", sec)
    if ((i = index(sec, " > "))) sec = substr(sec, 1, i - 1)
    if (N[sec] != nfam) print rel ": " sec " is not a section of every family file"
  }
  END { done() }' "$ROOT"/rules/platform/*.md)" \
  "a platform file that fits every family"

# --- the ignore rules keep personal files out, and only those -----
# .gitignore ignores all of .claude/ but the shared configuration.
# Both directions fail silently otherwise: a tracked file the rules
# match is shared configuration someone forgot to un-ignore, and a
# personal file that stops matching is one `git add` from a public
# repo.
# The repository's own .gitignore files only: --exclude-standard
# would add .git/info/exclude and the contributor's global excludes,
# and a personal `.claude/` there must not fail this check.
TRACKED_IGNORED=$(git -C "$ROOT" ls-files -ci \
  --exclude-per-directory=.gitignore)
report "$TRACKED_IGNORED" "a tracked file, yet the ignore rules match it"
# The other direction the same way. check-ignore always reads
# info/exclude and the global excludes, where the same `.claude/`
# would stand in for a rule .gitignore has lost, so it asks an
# empty repository holding nothing but .gitignore.
IGN=$(mktemp -d)
git init -q --template= "$IGN" && cp "$ROOT/.gitignore" "$IGN/"
for p in .claude/settings.local.json .claude/worktrees/x \
         .claude/scheduled_tasks.json .claude/agent-memory-local/x \
         .claude/x.lock CLAUDE.local.md memory/user.md; do
  if git -C "$IGN" -c core.excludesFile=/dev/null check-ignore -q "$p"; then
    ok
  else
    bad ".gitignore no longer ignores $p"
  fi
done
rm -rf "$IGN"
