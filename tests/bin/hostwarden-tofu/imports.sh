# shellcheck shell=sh
# tests/bin/hostwarden-tofu/imports.sh — the import and generate checks of
# tests/bin/hostwarden-tofu.sh, split off to keep that file under the
# size limit. Sourced in place; never run on its own.

# --- imports in the plan, and generate ----------------------------
cat > "$TMP/plan-import.json" <<'EOF'
{"resource_changes":[
 {"address":"hcloud_server.web1","change":{"actions":["no-op"],"importing":{"id":"123"}}},
 {"address":"hcloud_firewall.web","change":{"actions":["no-op"],"importing":{"id":"456"}}}]}
EOF
cat > "$TMP/plan-import-update.json" <<'EOF'
{"resource_changes":[
 {"address":"hcloud_server.web1","change":{"actions":["no-op"],"importing":{"id":"123"}}},
 {"address":"hcloud_firewall.web","change":{"actions":["update"],"importing":{"id":"456"}}}]}
EOF
echo plan-import.json > "$TMP/plan-file"
expect_rc 0 "plan of imports" hw web plan
has_out "plan: 0 to add, 0 to change, 0 to destroy, 0 to replace, 2 to import" "import summary"
expect_rc 0 "review of imports" hw web review
has_out "import	hcloud_server.web1" "import listed"
case "$OUT" in *"note: "*) bad "a note on a pure import" ;; *) ok ;; esac
: > "$LOG"
expect_rc 0 "apply of imports only" hw web apply
has_log "tofu apply -input=false -lock-timeout=60s $PLAN" "imports applied"
echo plan-import-update.json > "$TMP/plan-file"
hw web plan >/dev/null 2>&1
expect_rc 0 "review of an import with an update" hw web review
has_out "import/update	hcloud_firewall.web" "import and update listed"
has_out "note: 1 imported resource(s) would also change" "note on a differing import"
rm -f "$PLAN"
echo plan.json > "$TMP/plan-file"
# generate: a new file, a remote state, an import block.
expect_rc 1 "generate without an import block" hw web generate
has_out "no import block" "no import block"
printf 'import {\n  to = hcloud_server.web1\n  id = "123"\n}\n' > "$OPS_TREE/imports.tf"
expect_rc 1 "generate with a state that is not declared remote" hw web generate
has_out "State:" "state line asked for"
printf -- '- State: Local\n' > "$OPS_TREE/hostwarden.md"
expect_rc 1 "generate with a local state" hw web generate
printf -- '- State: s3 example-infra-state/web.tfstate (eu-central-1, use_lockfile)\n' > "$OPS_TREE/hostwarden.md"
: > "$LOG"
expect_rc 0 "generate" hw web generate
has_log "tofu init -input=false" "generate inits"
has_log "tofu plan -input=false -lock-timeout=60s -generate-config-out=$OPS_TREE/generated.tf" "generate plans"
has_out "a draft to read" "generate says what it wrote"
[ -f "$OPS_TREE/generated.tf" ] && ok || bad "generated.tf missing"
expect_rc 1 "generate over an existing file" hw web generate
has_out "writes a new file only" "existing file refused"
rm -f "$OPS_TREE/generated.tf"
expect_rc 1 "generate outside the tree" hw web generate /tmp/gen.tf
expect_rc 1 "generate to a file that is not .tf" hw web generate notes.txt
echo 1 > "$TMP/gen-rc"
expect_rc 1 "generate with errors in the draft" hw web generate draft.tf
has_out "found errors in it" "errors named"
[ -f "$OPS_TREE/draft.tf" ] && ok || bad "the draft with errors is kept"
rm -f "$TMP/gen-rc" "$OPS_TREE/draft.tf" "$OPS_TREE/imports.tf" "$OPS_TREE/hostwarden.md"

