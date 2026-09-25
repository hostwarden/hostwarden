---
id: 20260925-coord-lib-shared-tokenizer
status: proposed
supersedes:
superseded-by:
waiting-on:
tags: [coordination, security]
---

# A shared tokenizer replaces coord-lib.sh's hand-patches

## Context

Issue #313 collected five bypass shapes against
hostwarden_coord_is_reboot's quote-aware rewrite (#280), reverted
twice, and a third, independent attempt in this issue's own
author's session. Every review round found a different root cause,
not a variant of one: a wrapper needing a second unwrap level,
adjacent quote spans, ssh's own multi-argument join, an unquoted
`sh -c` wrapper, and a greedy single-capture restart-unit
extraction. The old, fully quote-blind splitter never had this
failure mode; making it "smarter" one case at a time kept trading
it for a new, dangerous fail-open gap.

## Decision drivers

- Fail-open (a real disruptive command goes undetected) is the
  direction that matters; a false positive is acceptable.
- Two independent hand-patches, both adversarially reviewed, each
  shipped a bypass the prior round did not have.
- awk has no shared-library mechanism across separate `awk '...'`
  invocations in one file.

## Considered options

### One shared awk tokenizer, reused by all three classifiers — chosen

`hostwarden_coord_dest`, `hostwarden_coord_is_reboot` and
`hostwarden_coord_kind` all read a command through the same
`HOSTWARDEN_COORD_AWK` text, embedded per invocation since awk
cannot link across processes: real word-boundary and
quote-removal semantics, `sudo`/`doas`/`exec`/`busybox` skipping,
and recursive unwrapping of ssh's own multi-argument remote
command and a `bash -c`/`sh -c`/`env -c` wrapper, so a reboot, a
firewall change or a restart is read from one correctly-tokenized
view instead of three ad hoc parsers kept in sync by hand.

### A sixth hand-patch against the newest reported shape

Rejected twice already: #280's own two reverted attempts, and this
issue's third. Every round found a different root cause; nothing
suggests a fourth patch would be the last one, and each prior round
cost real review time for a fix that shipped a new gap.

## Decision

`coord-lib.sh`'s three classifiers share one recursive tokenizer
instead of three separate hand-rolled parsers; a future
misclassification is fixed in that shared tokenizer, never by
patching one classifier's own pattern list again.

## Consequences

`hostwarden_coord_kind`'s interface changes: it prints one line
per disruptive kind found, since a compound command can restart
more than one unit, and `impact.sh` reads it in a loop instead of
a single value. `scripts/coord-lib-test.sh` pins the five
documented shapes and the ones found while building the tokenizer;
a tokenizer change that does not touch that matrix is incomplete
the same way a `guard-taboos.sh` change without its own fixture is
(`repo-release.md` → Guard findings).

## Confirmation

`scripts/coord-lib-test.sh` fails on any of the five documented
bypass shapes, on the false-positive controls, and on the
multi-restart-unit case; a hand-patch that reintroduces one of
them fails it directly, without a fresh adversarial review round
to find it again.
