#!/bin/sh
# check-skills.sh — say so when no skill is visible.
#
# The skills live in .agents/skills/, which OpenCode and other
# AGENTS-style tools read directly. Claude Code searches only
# .claude/, so .claude/skills is a symlink to that tree. A
# checkout that supports symlinks is a prerequisite, stated in
# website/docs/getting-started/install.md; this does not paper over
# a checkout that is not one, it only refuses to be silent about it.
#
# Where symlink support is missing — a clone with
# core.symlinks=false, an archive export, a zip download — git writes
# the link as a text file and Claude Code then finds no skill at
# all: no housekeeping, no security audit. Nothing else in the
# session would mention it, and the agent would work on a
# production server without noticing what it is missing.
#
# Hence a SessionStart hook with no matcher. The fix it points
# at is the user's to make: turn on symlink support and restore
# the link (website/docs/getting-started/install.md → Symbolic
# links).
set -e

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

# This script ships beside the skill tree, so a tree that is
# gone is a broken checkout, not a repository that never had
# one -- and it costs the session every skill just as surely as
# a missing link does. Say so rather than exit quietly.
if [ ! -d .agents/skills ]; then
  echo "hostwarden: .agents/skills/ is missing, so there is no"
  echo "  skill to load at all — no housekeeping, no security"
  echo "  audit. This checkout is incomplete; clone it again."
  exit 0
fi

# The same question instructions-test.sh asks: does the link
# land on the skill tree? A link to anywhere else is somebody's
# own arrangement, and it has the same consequence here.
# -d before the comparison on purpose: a dangling link would
# make both substitutions empty, and two failures would compare
# equal and pass for healthy.
if [ -L .claude/skills ] && [ -d .claude/skills ] &&
   [ "$(cd .claude/skills && pwd -P)" \
     = "$(cd .agents/skills && pwd -P)" ]; then
  exit 0
fi

echo "hostwarden: .claude/skills does not lead to .agents/skills/,"
echo "  so Claude Code sees no skill at all — no housekeeping, no"
echo "  security audit, and no warning but this one."
echo "  https://hostwarden.github.io/docs/getting-started/install#symbolic-links"
echo "  says how to repair the link in a clone; an archive download"
echo "  has to be replaced by a clone."

exit 0
