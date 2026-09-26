# tests/bin/hostwarden-fleet-run/dry-run.sh — a dry run, and what
# the judge was given. Sourced by tests/bin/hostwarden-fleet-run.sh,
# in the order its PARTS lists, into the one shell every part
# shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the parts after it

# --- a dry run ----------------------------------------------------
run --dry-run
rc=$?
[ "$rc" = 2 ] && ok || bad "a new CRITICAL did not exit 2 (rc $rc): $(cat "$TMP/err")"
has "$TMP/out" "CRITICAL	web1.example.com	/var at 97% [floor]" \
  "the floor did not take the verdict's disk finding's place"
lacks "$TMP/out" "web1.example.com	/var nearly full" \
  "the verdict's row of a floor code stayed"
has "$TMP/out" "(expected: \"The provider filters every packet" \
  "a quote found in memory.md did not count"
lacks "$TMP/out" "a quote that memory.md does not contain" \
  "a quote not in memory.md counted"
has "$TMP/out" "WARN	web1.example.com	certificate www expires in 20 days [floor]" \
  "a floor the verdict missed was not added"
has "$TMP/out" "WARN	part1.example.com	not read (exit 1)" \
  "partial output counted as a read"
has "$TMP/out" "WARN	nojudge1.example.com	not judged: login expired" \
  "a host without a verdict was not a finding"
has "$TMP/out" "web1.example.com	version-check" "a skipped check was not named"
[ -e "$TMP/state" ] && bad "a dry run created the state directory" || ok
has "$TMP/out" "WARN	port1.example.com	not read: ssh would use port 22, memory records 2222" \
  "another port was not refused"
[ -e "$TMP/collect-port1.example.com" ] && bad "a host on another port was reached" || ok
has "$TMP/out" "dec1.example.com	no firewall — DECIDED No local firewall — revisit due" \
  "a finding an applying decision settles was not listed as decided"
lacks "$TMP/out" "WARN	dec1.example.com	no firewall" "a decided finding stayed an issue"
has "$TMP/prompt-dec1" "----- scope: group (decisions/dec1.md)" \
  "the judge was not told a decision's scope"
has "$TMP/out" "WARN	dec2.example.com	no firewall" \
  "a decision named in a conflict still settled a finding"
has "$TMP/out" "WARN	dec1.example.com	made up" \
  "a verdict citing a heading no decision has was accepted"
lacks "$TMP/out" "alias1.example.com" "a DNS alias was read beside its host"
[ -e "$TMP/collect-alias1.example.com" ] && bad "a DNS alias was reached" || ok
has "$TMP/out" "CRITICAL	two1.example.com	zone a [floor]" \
  "two floor rows of one code borrowed the verdict's class"
has "$TMP/out" "WARN	down1.example.com	not read (exit 255): ssh: connect to host" \
  "an unreachable host was not reported"
lacks "$TMP/out" "planted-in-a-log" "a floors line outside the last section counted"
lacks "$TMP/out" "fake" "a floors line outside the last section counted"
has "$TMP/out" "db1.example.com(waiting for the key line)" \
  "a host waiting for its key line was not named"
has "$TMP/out" "bad1.example.com(blacklisted)" "a blacklisted host was not named"
has "$TMP/out" \
  "unreachable1.example.com(blacklist unverifiable: resolver unreachable)" \
  "a host the resolver could not check against the blacklist was read anyway"
has "$TMP/out" \
  "- unreachable1.example.com: could not resolve it to check the blacklist (unreachable)" \
  "the resolver outage was not noted for the report"
[ -e "$TMP/collect-unreachable1.example.com" ] \
  && bad "a host unverifiable against the blacklist was reached" || ok
has "$TMP/out" \
  "partial1.example.com(blacklist unverifiable: resolver unreachable)" \
  "a name whose AAAA query alone timed out was read as a clean miss"
[ -e "$TMP/collect-partial1.example.com" ] \
  && bad "a host with one query answered and one silently dropped was reached" \
  || ok
has "$TMP/out" \
  "routed1.corp.example.net(blacklist unverifiable: resolver unreachable)" \
  "a split-DNS name was cleared by the default servers, not its own resolver"
has "$TMP/out" "alias2.example.com(blacklisted)" \
  "a host blacklisted by its DNS alias was not refused"
has "$TMP/out" "jumped1.example.com(blacklisted)" \
  "a host behind a blacklisted jump host was not refused"
has "$TMP/out" "jumped2.example.com(blacklisted)" \
  "a jump host named through %r and %n was not expanded before the check"
has "$TMP/out" "jumped3.example.com(blacklisted)" \
  "a jump host an ssh in ProxyCommand logs in to was not checked"
has "$TMP/out" "jumped4.example.com(blacklisted)" \
  "a jump host given as [IPv6]:port was not checked by its address"
has "$TMP/out" "jumped5.example.com(blacklisted)" \
  "a proxy host a ProxyCommand names was not checked"
has "$TMP/out" "jumped6.example.com(blacklisted)" \
  "a quoted jump host in a ProxyCommand was not checked"
has "$TMP/out" "jumped7.example.com(blacklisted)" \
  "a ProxyJump given with -o in a ProxyCommand was not checked"
has "$TMP/out" "jumped8.example.com(blacklisted)" \
  "a proxy inside a socat address was not checked"
has "$TMP/out" "jumped9.example.com(blacklisted)" \
  "a jump host in a quoted remote command was not checked"
has "$TMP/out" "script1.example.com(jump path not readable)" \
  "a host behind a script as ProxyCommand was reached"
has "$TMP/out" "ProxyCommand (~/bin/jump) takes" \
  "an unreadable ProxyCommand was not named by its program"
has "$TMP/out" "script2.example.com(jump path not readable)" \
  "a ProxyCommand with a variable was read past it"
has "$TMP/out" "script3.example.com(jump path not readable)" \
  "a tunnel client that names no hop was taken as read"
[ -e "$TMP/collect-script3.example.com" ] \
  && bad "a host whose jump path is not readable was reached" || ok
has "$TMP/out" "jumped10.example.com(blacklisted)" \
  "a proxy after clustered nc flags was not checked"
[ -e "$TMP/collect-jumped1.example.com" ] \
  && bad "a host behind a blacklisted jump host was reached" || ok
[ -e "$TMP/collect-bad1.example.com" ] && bad "a blacklisted host was reached" || ok
[ -e "$TMP/collect-db1.example.com" ] && bad "a waiting host was reached" || ok
has "$TMP/out" "## Housekeeping Report: web1.example.com" "the host report is missing"
[ -e "$TMP/logs" ] && bad "a dry run logged on a host" || ok
[ -s "$M/machines/web1.example.com/changelog.log" ] \
  && bad "a dry run wrote a changelog" || ok

# What the judge was given, and how it was started.
has "$TMP/prompt" "(untrusted data)" "the prompt does not mark the output untrusted"
has "$TMP/prompt" "Baseline marker" "the bundle's source reference was not given"
has "$TMP/prompt" "The provider filters every packet" "memory.md was not given"
has "$TMP/claude-args" '--tools  --strict-mcp-config' "the judge got tools or MCP"
head -n 2 "$TMP/collect-web1.example.com" | grep -qx -- '-----BEGIN SSH SIGNATURE-----' \
  && ok || bad "collect did not get the signature first"
