# shellcheck shell=sh
# tests/bin/hostwarden-tofu/stand-ins.sh — the stand-in tools and plan
# fixtures of tests/bin/hostwarden-tofu.sh, split off to keep that file
# under the size limit. Sourced after infra_fixture; never run on
# its own.

# --- stand-ins ----------------------------------------------------
# tofu records every call; plan exits as $TMP/plan-rc says (2 by
# default: changes), show -json prints $TMP/plan.json, and the
# environment it saw goes to $TMP/env.
cat > "$TMP/fake/tofu" <<EOF
#!/bin/sh
echo "tofu \$*" >> "$LOG"
env | grep -E '^(TF_|TG_|AWS_|HCLOUD_|OP_)' | sort > "$TMP/env"
case "\$1 \$2" in
  "show -json") [ -f "$TMP/show-rc" ] && exit "\$(cat "$TMP/show-rc")"; cat "$TMP/\$(cat "$TMP/plan-file")"; exit 0 ;;
esac
gen=''
for a; do
  case \$a in -generate-config-out=*) gen=1; printf '# generated\n' > "\${a#-generate-config-out=}" ;; esac
done
[ -z "\$gen" ] || exit "\$(cat "$TMP/gen-rc" 2>/dev/null || echo 0)"
case \$1 in
  plan) [ -f "$TMP/plan-rc" ] && exit "\$(cat "$TMP/plan-rc")"; exit 2 ;;
  fmt) [ -f "$TMP/fmt-rc" ] && exit "\$(cat "$TMP/fmt-rc")"; exit 0 ;;
esac
exit 0
EOF
cat > "$TMP/fake/terragrunt" <<EOF
#!/bin/sh
echo "terragrunt \$*" >> "$LOG"
env | grep -E '^(TF_|TG_)' | sort > "$TMP/env"
[ "\$1 \$2" = "show -json" ] && { cat "$TMP/\$(cat "$TMP/plan-file")"; exit 0; }
[ "\$1" = plan ] && exit 2
exit 0
EOF
for t in tflint trivy checkov; do
  cat > "$TMP/fake/$t" <<EOF
#!/bin/sh
echo "$t \$*" >> "$LOG"
[ -f "$TMP/$t-rc" ] && exit "\$(cat "$TMP/$t-rc")"
exit 0
EOF
done
# op: vault list names one vault V; run records the env file and runs
# the command after --.
cat > "$TMP/fake/op" <<EOF
#!/bin/sh
echo "op \$*" >> "$LOG"
printf '%s' "\${OP_SERVICE_ACCOUNT_TOKEN:-}" > "$TMP/op-token"
if [ "\$1 \$2" = "vault list" ]; then echo '[{"id":"v1","name":"V"}]'; exit 0; fi
[ "\$1" = run ] || exit 1
shift
while [ "\$1" != -- ]; do shift; done
shift
: > "$TMP/op-ran"
exec "\$@"
EOF
chmod 755 "$TMP"/fake/*

# A plan with one create and one update: nothing destructive.
cat > "$TMP/plan.json" <<'EOF'
{"resource_changes":[
 {"address":"hcloud_server.web2","change":{"actions":["create"]}},
 {"address":"hcloud_firewall.web","change":{"actions":["update"]}},
 {"address":"hcloud_ssh_key.old","change":{"actions":["no-op"]}}]}
EOF
# And one that replaces a server.
cat > "$TMP/plan-replace.json" <<'EOF'
{"resource_changes":[
 {"address":"hcloud_server.web1","change":{"actions":["delete","create"]}}]}
EOF
echo plan.json > "$TMP/plan-file"
