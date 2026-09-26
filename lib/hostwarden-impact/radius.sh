# lib/hostwarden-impact/radius.sh — radius: the targets, their jump
# groups, and what a step on them reaches. Sourced by
# bin/hostwarden-impact, in the order its PARTS lists, into the one
# shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the targets ------------------------------------------------

# Each target by the host it names in memory: a directory or an
# alias, else a key only one host carries. A name memory does not
# know stays itself, known by the hostname ssh -G prints for it.
# Two names of one host are one target, under the name given first
# (rules/multi-host.md → Targets).
: >"$WORK/targets"
: >"$WORK/adhoc"
HOSTS=' '
for t in $TARGETS; do
  h=$(awk -F '\t' -v n="$t" '
    BEGIN { n = tolower(n) }
    $1 == "N" && $2 == n { print $3; f = 1; exit }
    $1 == "K" && $3 == n { k[$2] = 1 }
    END { if (!f) { for (x in k) { c++; y = x }; if (c == 1) print y } }' "$IDX")
  if [ -z "$h" ]; then
    h=$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')
    echo "hostwarden-impact: $t has no memory here; matched by its name and ssh -G alone" >&2
    { printf 'K\t%s\t%s\n' "$h" "$h"
      walk "$t" "$(user_for "$t")" '' | facts "$h" self "$t"
    } >>"$WORK/adhoc"
  fi
  case $HOSTS in *" $h "*) continue ;; esac
  HOSTS="$HOSTS$h "
  printf '%s\t%s\n' "$h" "$t" >>"$WORK/targets"
done

# --- jump groups --------------------------------------------------

if [ "$MODE" = jumps ]; then
  # Targets that share a hop, or whose hop is another target, form
  # one group; a via guest's hops are its host and that host's hops,
  # and a Reached as: destination counts as a hop.
  awk -F '\t' '
    function find(x) { while (p[x] != x) x = p[x]; return x }
    function join(a, b) { a = find(a); b = find(b); if (a != b) p[b] = a }
    FNR == NR { t[++n] = $1; given[$1] = $2; p[$1] = $1; next }
    $1 == "K" { key[$2] = key[$2] " " $3 }
    $1 == "N" { key[$3] = key[$3] " " $2 }
    $1 == "J" { hop[$2] = hop[$2] " " $3 }
    # A Reached as: destination is a machine every login passes too.
    $1 == "A" { hop[$2] = hop[$2] " " $3 }
    $1 == "U" { bad[$2] = 1 }
    $1 == "V" { via[$2] = 1 }
    $1 == "R" { ron[$2] = $3 }
    END {
      for (i = 1; i <= n; i++) {
        h = t[i]
        if (via[h] && ron[h] != "") {
          hop[h] = hop[h] " " ron[h] " " hop[ron[h]]
          if (bad[ron[h]]) bad[h] = 1
        }
        m = split(key[h], a, " ")
        for (j = 1; j <= m; j++) owner[a[j]] = owner[a[j]] " " h
      }
      for (i = 1; i <= n; i++) {
        h = t[i]
        if (bad[h]) continue
        m = split(hop[h], a, " ")
        for (j = 1; j <= m; j++) {
          if (a[j] in first) join(first[a[j]], h); else first[a[j]] = h
          k = split(owner[a[j]], o, " ")
          for (l = 1; l <= k; l++) if (!bad[o[l]]) join(o[l], h)
        }
      }
      for (i = 1; i <= n; i++) if (!bad[t[i]]) { r = find(t[i]); g[r] = g[r] " " given[t[i]] }
      for (i = 1; i <= n; i++) if (!bad[t[i]] && find(t[i]) == t[i]) print "group" g[t[i]]
      for (i = 1; i <= n; i++) if (bad[t[i]]) print "unreadable " given[t[i]]
    }' "$WORK/targets" "$IDX" "$WORK/adhoc"
  exit 0
fi

# --- the radius ---------------------------------------------------

UNIT=
# A systemd unit's type suffix goes: ssh.socket is sshd as much as
# ssh.service is.
case $KIND in restart:*) UNIT=${KIND#restart:}; UNIT=${UNIT%.service}; UNIT=${UNIT%.socket} ;; esac
# The service word a unit provides (rules/coordination.md →
# Dependencies), and whether it takes the whole radius: on the SSH
# path, the firewall or the network — hostwarden_coord_kind_whole
# (coord-lib.sh), the one place this list lives, so impact.sh's
# already-announced check reads the exact same list.
WHOLE='' WORD=''
if hostwarden_coord_kind_whole "$KIND"; then
  WHOLE=1
else
  case $UNIT in
    nfs-server | nfs-kernel-server | nfsd | nfs-mountd | rpcbind) WORD=nfs ;;
    smbd | smb | samba | nmbd) WORD=smb ;;
    unbound | named | bind9 | dnsmasq | systemd-resolved | pdns-recursor \
    | kresd* | knot-resolver | pihole-FTL | AdGuardHome) WORD=resolver ;;
    postgresql* | mysql* | mariadb* | mongod | redis* \
    | valkey*) WORD=db ;;
    slapd | 389-ds* | dirsrv*) WORD=ldap ;;
    krb5kdc | kadmin | samba-ad-dc | ipa | keycloak | authentik*) WORD=auth ;;
  esac
fi

# Each line goes out with a sort key: the origins in the order
# given, then the rest by host, then the ways in not readable.
awk -F '\t' -v T="$HOSTS" -v whole="$WHOLE" -v word="$WORD" '
  # isname(k, x) — whether x is known by the key k.
  function isname(k, x) { return index(" " own[k] " ", " " x " ") > 0 }
  function add(h, rel, thr, det) {
    if (h in rel_of) return
    rel_of[h] = rel; thr_of[h] = thr; det_of[h] = det; order[++no] = h
  }
  BEGIN { n = split(T, t, " ") }
  $1 == "N" { own[$2] = own[$2] " " $3 }
  $1 == "K" { own[$3] = own[$3] " " $2 }
  $1 == "R" { nr++; rh[nr] = $2; rt[nr] = $3; rid[nr] = $4 }
  $1 == "G" { ng++; gh[ng] = $2; gt[ng] = $3; gid[ng] = $4 }
  $1 == "V" { via[$2] = 1 }
  $1 == "C" { if (!(($2, $3) in inc)) { inc[$2, $3] = 1; clus[$2] = clus[$2] " " $3; mem[$3] = mem[$3] " " $2 } }
  $1 == "A" { na++; ah[na] = $2; ak[na] = $3 }
  $1 == "J" { nj++; jh[nj] = $2; jk[nj] = $3 }
  $1 == "U" { unread[$2] = 1 }
  $1 == "D" { nd++; dh[nd] = $2; dt[nd] = $3; dw[nd] = $4; dx[nd] = $5 }
  END {
    # An inventory link counts after the Runs on: of the guest, whose
    # ID reads the way the guest knows itself.
    for (i = 1; i <= ng; i++) { nr++; rh[nr] = gh[i]; rt[nr] = gt[i]; rid[nr] = gid[i] }
    for (i = 1; i <= n; i++) { add(t[i], "origin", "-", ""); out[++nout] = t[i] }
    if (whole) {
      # Out: the origin, and whatever goes with it, recursively.
      for (q = 1; q <= nout; q++) {
        x = out[q]
        for (i = 1; i <= nr; i++) {
          if (rt[i] ~ /^cluster:/) hit = index(" " clus[x] " ", " " substr(rt[i], 9) " ") > 0
          else hit = isname(rt[i], x)
          if (hit && !(rh[i] in rel_of)) {
            add(rh[i], via[rh[i]] ? "via" : "guest", x, rid[i]); out[++nout] = rh[i]
          }
        }
        for (i = 1; i <= nj; i++)
          if (isname(jk[i], x) && !(jh[i] in rel_of)) {
            add(jh[i], "behind", x, jk[i]); out[++nout] = jh[i]
          }
        for (i = 1; i <= na; i++)
          if (isname(ak[i], x) && !(ah[i] in rel_of)) {
            add(ah[i], "reached", x, ak[i]); out[++nout] = ah[i]
          }
      }
      # Hit: what depends on a host that is out, and its cluster peers.
      for (q = 1; q <= nout; q++) {
        x = out[q]
        for (i = 1; i <= nd; i++) if (isname(dt[i], x)) add(dh[i], "depends", x, dx[i])
        m = split(clus[x], cs, " ")
        for (j = 1; j <= m; j++) {
          k = split(mem[cs[j]], ps, " ")
          for (l = 1; l <= k; l++) add(ps[l], "cluster", x, cs[j])
        }
      }
      for (h in unread) add(h, "unreadable", "-", "")
    } else {
      # A restart: the entries that name its service, an unknown
      # service or an "other" entry counting for every restart.
      for (q = 1; q <= n; q++)
        for (i = 1; i <= nd; i++)
          if (isname(dt[i], t[q]) && (word == "" || dw[i] == word || dw[i] == "other"))
            add(dh[i], "depends", t[q], dx[i])
    }
    for (i = 1; i <= no; i++) {
      h = order[i]; r = rel_of[h]
      line = h " " r " " thr_of[h] (det_of[h] != "" ? " " det_of[h] : "")
      if (r == "origin") print "0\t" sprintf("%06d", i) "\t" line
      else print (r == "unreadable" ? 2 : 1) "\t" h "\t" line
    }
  }' "$IDX" "$WORK/adhoc" | LC_ALL=C sort -t "$TAB" -k1,1 -k2,2 | cut -f3- >"$WORK/radius"

[ "$MODE" = report ] || { cat "$WORK/radius"; exit 0; }
