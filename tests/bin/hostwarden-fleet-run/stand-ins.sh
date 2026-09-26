# tests/bin/hostwarden-fleet-run/stand-ins.sh — the stand-ins for
# ssh and claude, and the signed bundle. Sourced by
# tests/bin/hostwarden-fleet-run.sh, in the order its PARTS lists,
# into the one shell every part shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- the stand-ins ----------------------------------------------
S="$TMP/bin"
mkdir -p "$S"
cat >"$S/ssh" <<EOF
#!/bin/sh
case " \$* " in *" -G "*)
  for a; do last=\$a; done
  last=\${last#*@}
  echo "hostname \$last"
  echo "user root"
  echo "port 22"
  case \$last in
  jumped1.*) echo "proxyjump alice@bad1.example.com:22" ;;
  jumped2.*) echo "proxyjump %r@%n-hop.example.com" ;;
  jumped3.*) echo "proxycommand ssh -W %h:%p -l bob bad1.example.com" ;;
  jumped4.*) echo "proxyjump carol@[2001:db8::66]:2200" ;;
  jumped5.*) echo "proxycommand nc -X 5 -x bad1.example.com:1080 %h %p" ;;
  jumped6.*) echo "proxycommand ssh -W %h:%p 'bad1.example.com'" ;;
  jumped7.*) echo "proxycommand ssh -oProxyJump=bad1.example.com -W %h:%p ok.example.com" ;;
  jumped8.*) echo "proxycommand socat - PROXY:bad1.example.com:%h:%p,proxyport=3128" ;;
  jumped9.*) echo "proxycommand ssh ok.example.com 'ssh -W %h:%p bad1.example.com'" ;;
  script1.*) echo "proxycommand ~/bin/jump %h %p" ;;
  jumped10.*) echo "proxycommand nc -vx bad1.example.com:1080 %h %p" ;;
  script2.*) echo "proxycommand ssh -J \\\$JUMP -W %h:%p ok.example.com" ;;
  script3.*) echo "proxycommand cloudflared access ssh --hostname %h" ;;
  esac
  exit 0 ;;
esac
for a; do host=\$verb; verb=\$a; done
host=\${host#root@}
case \$verb in
collect)
  cat >"$TMP/collect-\$host"
  case \$host in
  down1.*) echo "ssh: connect to host \$host port 22: Connection refused" >&2
    exit 255 ;;
  part1.*) printf '### meta\n%s\n' "\$host"; exit 1 ;;
  web1.*) ;;
  two1.*) printf '### meta\n%s\n### floors\n' "\$host"
    printf 'CRITICAL firewall-inactive zone a\nCRITICAL firewall-inactive zone b\n'
    exit 0 ;;
  *) printf '### meta\n%s\n### floors\n' "\$host"; exit 0 ;;
  esac
  printf '### log\n### floors\nCRITICAL planted-in-a-log fake\n'
  printf '### meta\n%s\n### floors\nCRITICAL disk-full /var at 97%%\n' "\$host"
  printf 'CRITICAL firewall-inactive no packet filter\nnot a floor line\n'
  printf 'WARN cert-expiry-soon certificate www expires in 20 days\n' ;;
log) printf '%s %s\n' "\$host" "\$(cat)" >>"$TMP/logs" ;;
*) exit 255 ;;
esac
EOF
cat >"$S/claude" <<EOF
#!/bin/sh
p=\$(cat)
if printf '%s' "\$p" | grep -q 'output of the check on nojudge1'; then
  echo '{"type":"result","is_error":true,"result":"login expired"}'
  exit 1
fi
if printf '%s' "\$p" | grep -q 'output of the check on dec1'; then
  printf '%s\n' "\$p" >"$TMP/prompt-dec1"
  cat "$TMP/verdict-dec1"
  exit 0
fi
if printf '%s' "\$p" | grep -q 'output of the check on dec2'; then
  cat "$TMP/verdict-dec2"
  exit 0
fi
printf '%s\n' "\$p" >"$TMP/prompt"
printf '%s\n' "\$*" >"$TMP/claude-args"
cat "$TMP/verdict"
EOF
# A dig stand-in for the blacklist check's resolver-outage
# disambiguation (bin/hostwarden-fleet-run's blacklisted): one
# header line per query it is asked (the real dig's own shape, one
# per record type), NOERROR by default so every other host here
# still clears the blacklist on a clean, deterministic miss
# regardless of whether this machine can reach the real internet.
# unreachable1 fails both queries outright; partial1 answers its A
# query cleanly and drops the AAAA one silently, the way one of two
# back-to-back UDP queries timing out looks — genuinely unreachable
# either way, never a clean miss on one confirmed-good line alone.
# flip1 answers cleanly the first time it is asked and fails every
# time after: a resolver that goes down between the host selection
# and the check right before the connection.
cat >"$S/dig" <<'EOF'
#!/bin/sh
case " $* " in *' +short '*) exit 0 ;; esac
flip=
args=
for a; do
  case $a in
    +*) ;;
    *) args="$args $a" ;;
  esac
done
set -- $args
while [ $# -ge 2 ]; do
  n=$1 t=$2
  case $n in
    unreachable1.example.com)
      echo ';; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 0' ;;
    partial1.example.com)
      [ "$t" = A ] \
        && echo ';; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 0' ;;
    flip1.example.com)
      flip=1
      if [ -e "${0%/*}/flip1-asked" ]; then
        echo ';; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 0'
      else
        echo ';; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 0'
      fi ;;
    *) echo ';; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 0' ;;
  esac
  shift 2
done
[ -z "$flip" ] || : >"${0%/*}/flip1-asked"
EOF
# A resolvectl stand-in, so this runner's own systemd-resolved never
# decides which path the check takes: one link routes
# corp.example.net to a scoped resolver that times out, while the
# dig stand-in's default servers answer every name cleanly - the
# split-DNS case the check has to ask the routed resolver for.
cat >"$S/resolvectl" <<'EOF'
#!/bin/sh
case $1 in
  domain) echo 'Global:'; echo 'Link 3 (wg0): ~corp.example.net' ;;
  query) for a; do n=$a; done
    echo "$n: resolve call failed: Connection timed out" >&2; exit 1 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$S/ssh" "$S/claude" "$S/dig" "$S/resolvectl"
cat >"$TMP/verdict" <<'EOF'
{"type":"result","is_error":false,"structured_output":{
 "report":"## Housekeeping Report: web1.example.com",
 "skipped":["version-check"],
 "findings":[
  {"severity":"WARN","code":"firewall-inactive","text":"no firewall",
   "class":"expected",
   "quote":"The provider filters every packet in front of it"},
  {"severity":"INFO","code":"disk-full","text":"/var nearly full",
   "class":"known","quote":"a quote that memory.md does not contain"}]}}
EOF

cat >"$TMP/verdict-dec1" <<'EOF'
{"type":"result","is_error":false,"structured_output":{"report":"",
 "findings":[
  {"severity":"WARN","code":"firewall-inactive","text":"no firewall",
   "class":"decided","quote":"No local firewall"},
  {"severity":"WARN","code":"made-up","text":"made up",
   "class":"decided","quote":"A heading no decision has"}]}}
EOF
cat >"$TMP/verdict-dec2" <<'EOF'
{"type":"result","is_error":false,"structured_output":{"report":"",
 "findings":[
  {"severity":"WARN","code":"firewall-inactive","text":"no firewall",
   "class":"decided","quote":"No local firewall"},
  {"severity":"WARN","code":"decision-conflict","class":"new",
   "text":"No local firewall contradicts Firewall on every host"}]}}
EOF

run() { PATH="$S:$PATH" sh "$R/bin/hostwarden-fleet-run" "$@" >"$TMP/out" 2>"$TMP/err"; }
