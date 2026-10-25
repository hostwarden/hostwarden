# shellcheck shell=sh
# lib/hostwarden-tofu/tests.sh — which test files of a stack apply.
# A stage of bin/hostwarden-tofu, sourced into its shell after
# plan.sh; never run on its own.

# applying_tests — the test files whose run blocks apply: more run
# blocks than command = plan, and not every provider the tree requires
# or uses mocked in the file (a resource type's prefix names the
# provider it uses, declared or not). A tree that names no provider, or a file that
# mocks none, counts as applying; so does a test whose providers
# cannot be read.
applying_tests() {
  at_req=$(find "$INFRA_TREE" -name '*.tf' -not -path '*/.terraform/*' \
      -exec awk '
        /required_providers[[:space:]]*\{/ { on = 1; depth = 0 }
        on {
          line = $0
          if (depth == 1 && match(line, /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=/)) {
            nm = substr(line, RSTART, RLENGTH)
            sub(/^[[:space:]]*/, "", nm); sub(/[[:space:]]*=$/, "", nm)
            print nm
          }
          depth += gsub(/\{/, "{", line) - gsub(/\}/, "}", line)
          if (depth <= 0) on = 0
        }
        # A provisioner runs a command for real, whatever is mocked:
        # a tree that has one leaves every apply test to the user.
        /^[[:space:]]*provisioner[[:space:]]+"/ { print "__provisioner__" }
        # A provider a resource uses without declaring it: the
        # prefix of its type; terraform is the built-in provider
        # of OpenTofu itself, which no test mocks.
        match($0, /^[[:space:]]*(resource|data)[[:space:]]+"[a-z0-9]+_/) {
          p = substr($0, RSTART, RLENGTH); sub(/^[^"]*"/, "", p); sub(/_$/, "", p)
          if (p != "terraform") print p
        }' {} + 2>/dev/null | sort -u | tr '\n' ' ')
  find "$INFRA_TREE" -maxdepth 2 \
      \( -name '*.tftest.hcl' -o -name '*.tofutest.hcl' \) -type f \
      2>/dev/null | while IFS= read -r tf; do
    awk -v req="$at_req" '
      /^[[:space:]]*run[[:space:]]+"/ { runs++ }
      /^[[:space:]]*command[[:space:]]*=[[:space:]]*plan/ { plans++ }
      # A provider block of the file, or a run block that maps
      # providers, selects configurations by name; which of them is
      # real cannot be told from here.
      /^[[:space:]]*provider[[:space:]]+"/ { sel = 1 }
      /^[[:space:]]*providers[[:space:]]*=/ { sel = 1 }
      match($0, /^[[:space:]]*mock_provider[[:space:]]+"[^"]+"/) {
        cur = substr($0, RSTART, RLENGTH); sub(/^[^"]*"/, "", cur); sub(/"$/, "", cur)
        inmock = 1; nm++; depth = 0
      }
      # An aliased mock is a second configuration beside the default
      # one: the name no longer says the default is mocked. The block
      # ends where its braces do, an alias after a nested block
      # included.
      inmock {
        if ($0 ~ /alias[[:space:]]*=/) aliased[cur] = 1
        t = $0
        depth += gsub(/\{/, "{", t) - gsub(/\}/, "}", t)
        if (depth <= 0) {
          if (!(cur in aliased)) mocked[cur] = 1
          inmock = 0
        }
      }
      END {
        if (runs <= plans) exit 1
        if (sel) exit 0
        if (index(" " req " ", " __provisioner__ ")) exit 0
        n = split(req, r, " ")
        if (nm == 0 || n == 0) exit 0
        for (i = 1; i <= n; i++) if (!(r[i] in mocked)) exit 0
        exit 1
      }' "$tf" && printf '%s\n' "$tf"
  done
}
