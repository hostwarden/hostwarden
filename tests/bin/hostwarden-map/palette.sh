# tests/bin/hostwarden-map/palette.sh — the palette's contrast,
# pruning, and a second workspace. Sourced by
# tests/bin/hostwarden-map.sh, in the order its PARTS lists, into
# the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the palette: every stroke reaches 3:1 against both GitHub
# canvases, every fill/colour pair 4.5:1 against its own fill -------
awk -v light=1 '
  function lin(c,   v) { v = c / 255; return (v <= 0.03928) ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
  function hexval(h,   i, c, v, d) {
    v = 0
    for (i = 1; i <= length(h); i++) { c = tolower(substr(h, i, 1)); d = index("0123456789abcdef", c) - 1; v = v * 16 + d }
    return v
  }
  function lum(hex,   h) { h = hex; sub(/^#/, "", h); return 0.2126 * lin(hexval(substr(h, 1, 2))) + 0.7152 * lin(hexval(substr(h, 3, 2))) + 0.0722 * lin(hexval(substr(h, 5, 2))) }
  function contrast(h1, h2,   l1, l2, t) {
    l1 = lum(h1); l2 = lum(h2)
    if (l1 < l2) { t = l1; l1 = l2; l2 = t }
    return (l1 + 0.05) / (l2 + 0.05)
  }
  /^  classDef / {
    name = $2; fill = ""; stroke = ""; color = ""
    if (match($0, /fill:#[0-9A-Fa-f]{6}/)) fill = substr($0, RSTART + 5, 7)
    if (match($0, /stroke:#[0-9A-Fa-f]{6}/)) stroke = substr($0, RSTART + 7, 7)
    if (match($0, /color:#[0-9A-Fa-f]{6}/)) color = substr($0, RSTART + 6, 7)
    if (stroke != "") {
      cw = contrast(stroke, "#ffffff"); cd = contrast(stroke, "#0d1117")
      if (cw < 3) { print "FAIL: classDef " name "'"'"'s stroke " stroke " is only " cw ":1 against white"; bad++ }
      if (cd < 3) { print "FAIL: classDef " name "'"'"'s stroke " stroke " is only " cd ":1 against #0d1117"; bad++ }
      if (cw >= 3 && cd >= 3) good++
    }
    if (fill != "" && color != "") {
      cf = contrast(fill, color)
      if (cf < 4.5) { print "FAIL: classDef " name "'"'"'s text " color " on " fill " is only " cf ":1"; bad++ }
      else good++
    }
  }
  END {
    print good " palette checks passed, " (bad + 0) " failed"
    exit (bad + 0 > 0)
  }
' "$MAPS/wan.md" && ok || bad "the palette failed its own contrast rule"

# --- a hypervisor removed from memory loses its stale map ----------
rm -rf "$M/machines/pve3.example.com" "$M/machines/app1.example.com"
( cd "$R" && sh bin/hostwarden-map ) || bad "third run exited non-zero"
absent "$MAPS/hosts/pve3.example.com.md" \
  "pve3 is gone from memory; its old map is not left behind as though it were still current"
exists "$MAPS/wan.md" "wan.md itself is untouched by the prune"

# --- topology.md gone: a transient miss on ITS OWN read must not
# prune the site maps just because every host's own memory.md still
# reads fine -- $HOSTS alone would not have caught this, only
# $SITES actually coming back empty does -------------------------
mv "$M/topology.md" "$TMP/topology.md.aside"
( cd "$R" && sh bin/hostwarden-map ) || bad "fourth run exited non-zero"
exists "$MAPS/sites/home.md" \
  "topology.md going missing must not prune every site map: \$SITES coming back empty is not the same as no sites existing, and \$HOSTS alone can't tell the two apart"
exists "$MAPS/sites/colo-fra.md" \
  "colo-fra's map survives topology.md's absence the same way home's does"

# --- a second, separate workspace: sites declared but zero WAN-
# tagged Topology entries at all, the ordinary state before any
# inter-site link has been profiled. grep -c prints its count even
# on no match, exiting 1 only -- a "|| echo 0" fallback fires on
# that exit and appends a second, stray zero, corrupting link_idx
# and aborting the dashed-fallback loop after its first site -------
R2="$TMP/repo2"
mkdir -p "$R2/bin" "$R2/lib"
cp "$REPO/bin/hostwarden-map" "$R2/bin/"
cp "$REPO/lib/mode.sh" "$R2/lib/"
cp -R "$REPO/lib/hostwarden-map" "$R2/lib/"
cp "$REPO/VERSION" "$R2/VERSION"
git -C "$R2" init --quiet
M2="$R2/memory"
mkdir -p "$M2/machines/a1.example.com" "$M2/machines/b1.example.com"
: >"$M2/.hostwarden-workspace"
cat >"$M2/topology.md" <<EOF
## Sites

- alpha — first site, no WAN link profiled yet (user, $FRESH)
- beta — second site, same (user, $FRESH)
EOF
{
  echo "# a1.example.com"
  printf '%s\n' "- IP: 10.1.0.1
- Site: alpha (user)
- Onboarded: $FRESH
- Housekeeping: $FRESH"
} >"$M2/machines/a1.example.com/memory.md"
{
  echo "# b1.example.com"
  printf '%s\n' "- IP: 10.2.0.1
- Site: beta (user)
- Onboarded: $FRESH
- Housekeeping: $FRESH"
} >"$M2/machines/b1.example.com/memory.md"
( cd "$R2" && sh bin/hostwarden-map ) >"$TMP/repo2.out" 2>"$TMP/repo2.err"
rc2=$?
[ "$rc2" -eq 0 ] && ok || bad "a workspace with sites but zero WAN Topology entries must not fail the run"
[ -s "$TMP/repo2.err" ] && bad "it must not print to stderr either: $(cat "$TMP/repo2.err")" || ok
WAN2="$M2/maps/wan.md"
exists "$WAN2" "the no-WAN-edges workspace still produces wan.md"
has "$WAN2" '  site_alpha -.- inet' \
  "alpha gets its dashed not-known line when there are zero WAN edges at all, not a corrupted linkStyle"
has "$WAN2" '  site_beta -.- inet' \
  "beta gets its own dashed line too -- the corrupted link_idx used to abort the loop after the first site, silently dropping every one after it"
