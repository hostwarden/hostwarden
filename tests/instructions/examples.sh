# tests/instructions/examples.sh — example identifiers, and the one
# term for an override. Sourced by tests/instructions.sh, in its
# order, into the one shell every part shares; never run on its own.
# shellcheck shell=sh


# --- examples name nobody real ----------------------------------
# .claude/rules/instruction-authoring.md: hostnames from RFC 2606,
# addresses from RFC 5737/3849, people from the Alice-and-Bob
# convention. An example that borrows a real identifier points a
# reader -- or a copied command -- at somebody else's machine.
#
# One pass over the corpus rather than one per check: three
# separate loops each re-read every file and forked a pipeline per
# file, which was over half the runtime of this script.
#
# URLs are stripped first: linking to a project's documentation is
# not the same as pretending to own a name.
# Addresses outside the documentation ranges. Private, shared
# (RFC 6598), loopback, link-local and netmasks are legitimate
# subjects of an example.
report "$(scan \
  | sed -E 's#([[:space:]])[vV]ersion [0-9]+(\.[0-9]+)+#\1#g
            s#([[:space:]])v[0-9]+(\.[0-9]+)+#\1#g' \
  | tag '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' \
  | grep -vE ': (192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)' \
  | grep -vE ': (127\.|10\.|192\.168\.|169\.254\.|0\.0\.0\.0)' \
  | grep -vE ': 172\.(1[6-9]|2[0-9]|3[01])\.' \
  | grep -vE ': 100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.' \
  | grep -vE ': 255\.')" "an RFC 5737 documentation address"

# IPv6. Only 2001:db8::/32 is documentation space for examples
# (RFC 3849). Matching every colon-hex string would catch
# timestamps and MAC addresses, so this looks for the
# global-unicast shape, including the compressed forms that end in
# `::` -- which is why `tag` splits on `: ` and not on a final
# colon. RFC 9637's 3fff::/20 passes only as the bare prefix, which
# rules/network.md names as a range never to find on a host.
report "$(scan \
  | tag_i '\b[23][0-9a-f]{3}:[0-9a-f]*(:[0-9a-f]*)+' \
  | grep -vE ': 2001:0?db8:' \
  | grep -vE ': 3fff::$')" "an RFC 3849 documentation address"

# Mail addresses outside the reserved domains.
#
# openssh.com is exempt only where it does what it does in this
# corpus: suffix an algorithm name (umac-64-etm@openssh.com). A
# local part with no hyphen names a person, and an address of
# that shape at that domain is borrowed like any other. The one
# GitHub address is the release account's, which tag-release.yml
# tags as.
report "$(scan \
  | tag_i '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' \
  | grep -vE '@(.*\.)?example\.(com|net|org)$' \
  | grep -vE '@([a-z0-9-]+\.)*(test|invalid)$' \
  | grep -vE ' [a-z0-9]+(-[a-z0-9]+)+@openssh\.com$' \
  | grep -vE ' 334199026\+hostwarden-release@users\.noreply\.github\.com$')" \
  "an RFC 2606 example address"

# SSH targets. A hostname a command connects to may well be real
# infrastructure -- security.debian.org, time.apple.com -- and no
# pattern tells that from a borrowed example, so hostnames at
# large are a review matter. The target of an ssh or scp command
# never is: Hostwarden only ever logs into a user's machine. Both
# forms count, with a user and without.
#
# The command word must be followed by whitespace -- a tab
# separates words in a shell as well as a space -- or every
# rules/ssh-*.md reference reads as an invocation. The destination
# may be quoted. A candidate ending in a file extension is a path,
# not a host.
#
# What is left on that suffix list is file extensions only. Two
# came off it: `.example` is a reserved TLD and belongs with the
# other reserved names below, and `.local` is what an internal
# machine is actually called -- excusing it as a file extension
# was excusing exactly the target this check exists to catch. The
# rest are not plausible hostname suffixes in this corpus; a
# hostname that genuinely ends in one is a review matter, which
# is what the comment above says about hostnames at large.
#
# Only a candidate shaped like a network name is examined: this
# corpus is prose, and after the word "ssh" it usually says "key",
# "access" or "user". A dot and a letter suffix is the only thing
# that separates a host from a sentence here, so a single-label
# destination is out of reach -- see the note at the end of this
# check.
#
# Everything up to the *last* `@` is the login, so a dotted
# account name like john.doe@example.com is not read as a host.
report "$(scan \
  | grep -v '^CHANGELOG\.md: ' \
  | tag_i '(^|[^a-z0-9_.-])(ssh|scp|ssh-copy-id)[[:blank:]]+[^|;&`]*' \
  | awk '{ n = 0; out = $1
      # When the command carries a login@host, that is the
      # destination and every other dotted word on the line is an
      # operand -- the local file an scp copies, an option value.
      # Keep only the logins; fall back to the whole line when
      # there is none.
      rest = substr($0, length($1) + 1)
      # An option value is not a destination: -c names a cipher,
      # which in OpenSSH is spelled like a mail address. Only the
      # flags that actually take an argument are consumed, so a
      # bare -v does not swallow the host after it.
      gsub(/-[bcdeefijllmoopqrsww] +[^ ]+/, " ", rest)
      gsub(/[^ ]+=[^ ]+/, " ", rest)
      tmp = rest
      while (match(tmp, /[a-z0-9._%+-]+@[a-z0-9][a-z0-9.-]*/)) {
        out = out " " substr(tmp, RSTART, RLENGTH); n++
        tmp = substr(tmp, RSTART + RLENGTH)
      }
      print (n ? out : $0) }' \
  | tag '[[:blank:]="'"'"']([a-z0-9._%+-]+@)*[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+' \
  | sed -E 's#: [[:blank:]="'"'"']#: #; s#: .*@#: #' \
  | grep -E '\.[a-z]{2,}$' \
  | grep -vE '\.(md|conf|service|real|pub|txt|xz|json|ya?ml|log|key|d|bak|gz|img|sock)$' \
  | grep -vE ': ([a-z0-9-]+\.)*example\.(com|net|org)$' \
  | grep -vE ': ([a-z0-9-]+\.)*(test|invalid|example)$' \
  | grep -vE ': localhost$')" "an RFC 2606 example target"

# --- one term for an override -----------------------------------
# .claude/rules/instruction-authoring.md → For people and for the
# agent: what a user writes under memory/custom-rules/ is an
# override. A second word for it reads, to people and agent alike,
# as a second mechanism. CHANGELOG.md and its fragments record a
# rename under the old words, contrib/ speaks Heinzel's language,
# and the two files that state the rule have to name what they
# retire.
report "$(scan \
  | grep -vE "$HISTORY" \
  | grep -vE '^(contrib/[^ ]*|\.claude/rules/instruction-authoring\.md|tests/instructions(\.sh|/examples\.sh)): ' \
  | tag_i 'customi[sz]ations?|custom rules?')" "the one term, override"
