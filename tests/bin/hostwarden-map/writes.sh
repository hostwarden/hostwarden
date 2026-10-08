# tests/bin/hostwarden-map/writes.sh — a map that cannot be written
# fails the run, is named on stderr, and leaves no truncated file.
# Sourced by tests/bin/hostwarden-map.sh, in the order its PARTS
# lists, into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

R4="$TMP/repo4"
checkout "$R4"
M4="$R4/memory"
cat >"$M4/topology.md" <<TOPO
## Sites

- muc (user, $FRESH)
- ber (user, $FRESH)

## Ranges

- 192.0.2.0/24 — site muc · VLAN untagged · DHCP on · suffix not
  known · no gateway seen — from web9; $FRESH
TOPO

# A first run draws everything; the second finds a directory where
# the map of muc belongs, which no mv or redirect can replace.
( cd "$R4" && sh bin/hostwarden-map ) >/dev/null 2>&1 \
  && ok || bad "hostwarden-map failed on a workspace it can write"
cp "$M4/maps/sites/ber.md" "$TMP/repo4.ber.before"
rm -f "$M4/maps/sites/muc.md"
mkdir "$M4/maps/sites/muc.md"
( cd "$R4" && sh bin/hostwarden-map ) >"$TMP/repo4.out" 2>"$TMP/repo4.err" \
  && bad "hostwarden-map exited 0 with a map it could not write" || ok
haspart "$TMP/repo4.err" "hostwarden-map: cannot write memory/maps/sites/muc.md" \
  "the unwritable map is not named on stderr"
cmp -s "$TMP/repo4.ber.before" "$M4/maps/sites/ber.md" && ok \
  || bad "a map that could be written changed or was truncated"
# Neither a temporary file nor a file moved into the directory stays.
if [ -n "$(ls -A "$M4/maps/sites/muc.md")" ] \
    || [ -n "$(find "$M4/maps" -name '.hwmap.*')" ]; then
  bad "a failed write left a file behind:"; find "$M4/maps" -name '.hwmap.*'
else ok
fi

# Where permissions can stop a write (not as root), the index and the
# overview page fail the same way and keep their old content.
if [ "$(id -u)" != 0 ]; then
  rmdir "$M4/maps/sites/muc.md"
  ( cd "$R4" && sh bin/hostwarden-map ) >/dev/null 2>&1 \
    && ok || bad "hostwarden-map failed once the directory was gone"
  cp "$M4/maps/README.md" "$TMP/repo4.index.before"
  cp "$M4/README.md" "$TMP/repo4.ov.before"
  chmod 555 "$M4/maps" "$M4"
  ( cd "$R4" && sh bin/hostwarden-map ) >"$TMP/repo4.out" 2>"$TMP/repo4.err" \
    && bad "hostwarden-map exited 0 with a read-only maps directory" || ok
  chmod 755 "$M4/maps" "$M4"
  haspart "$TMP/repo4.err" "hostwarden-map: cannot write memory/maps/README.md" \
    "the unwritable index is not named on stderr"
  # A restrictive mode survives a rewrite; a read-only map is not replaced.
  chmod 600 "$M4/maps/wan.md"
  ( cd "$R4" && sh bin/hostwarden-map ) >/dev/null 2>&1
  [ "$(ls -l "$M4/maps/wan.md" | cut -c1-10)" = "-rw-------" ] && ok \
    || bad "a rewritten map lost its mode"
  chmod 444 "$M4/maps/wan.md"
  ( cd "$R4" && sh bin/hostwarden-map ) >/dev/null 2>"$TMP/repo4.err" \
    && bad "a read-only map was replaced and the run exited 0" || ok
  haspart "$TMP/repo4.err" "hostwarden-map: cannot write memory/maps/wan.md" \
    "the read-only map is not named on stderr"
  chmod 644 "$M4/maps/wan.md"
  cmp -s "$TMP/repo4.index.before" "$M4/maps/README.md" \
    && cmp -s "$TMP/repo4.ov.before" "$M4/README.md" && ok \
    || bad "a failed write truncated the index or the overview"
fi
