# shellcheck shell=sh
# shellcheck disable=SC2034 # the programs are read by bin/hostwarden-tofu
# lib/hostwarden-tofu/plan.sh — reading a saved plan: the jq programs of
# review and apply, and plan_json. A stage of bin/hostwarden-tofu,
# sourced into its shell; never run on its own.

# plan_json <jq program> — the saved plan as JSON, piped into jq
# alone: nothing of it is written or printed by itself. One tofu
# start per call, so each verb calls it once; with the credentials,
# since an encrypted plan or a terragrunt stack needs them to read.
# Its status is jq's, which an empty input leaves at 0, so a caller
# that decides on the output checks the output.
plan_json() {
  pw_has jq ||
    infra_die "jq is needed to read the plan: bin/hostwarden-doctor says how"
  infra_run "$TOOL" show -json "$PLAN" | jq -r "$1"
}

# The summary line, and after it the changes by action where asked. An
# import is the plan's change.importing, whatever its actions say: a
# pure import is a no-op that brings the object into the state.
# shellcheck disable=SC2016 # jq programs, not shell
SUMMARY='[.resource_changes[]? | .change] as $c
  | [$c[] | .actions] as $a
  | "plan: \($a | map(select(. == ["create"])) | length) to add, "
    + "\($a | map(select(. == ["update"])) | length) to change, "
    + "\($a | map(select(. == ["delete"])) | length) to destroy, "
    + "\($a | map(select(length == 2)) | length) to replace, "
    + "\($c | map(select(.importing != null)) | length) to import"'
# shellcheck disable=SC2016
BY_ACTION='.resource_changes[]?
  | select(.change.actions != ["no-op"] or .change.importing != null)
  | ((if .change.importing != null then ["import"] else [] end)
     + (.change.actions | map(select(. != "no-op")))) as $l
  | "  \($l | join("/"))\t\(.address)"'
# shellcheck disable=SC2016
IMPORT_NOTE='[.resource_changes[]?
    | select(.change.importing != null and .change.actions != ["no-op"])]
  | length as $n
  | if $n > 0 then "note: \($n) imported resource(s) would also change: the code differs from the real resource; fix the code until the plan shows imports only (rules/infra-migration.md)" else empty end'
# shellcheck disable=SC2016
DELETES='[.resource_changes[]? | select(.change.actions | index("delete"))] | length'
