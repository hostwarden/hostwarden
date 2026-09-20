#!/bin/sh
# check-skills.sh — say so when no skill is visible.
#
# The skills live in .agents/skills/, which OpenCode and other
# AGENTS-style tools read directly. Claude Code searches only
# .claude/, so .claude/skills is a symlink to that tree. A
# checkout that supports symlinks is a prerequisite, stated in
# the README; this does not paper over a checkout that is not
# one, it only refuses to be silent about it.
#
# Where symlink support is missing — native Windows without
# Developer Mode, an archive export, a zip download — git writes
# the link as a text file and Claude Code then finds no skill at
# all: no housekeeping, no security audit. Nothing else in the
# session would mention it, and the agent would work on a
# production server without noticing what it is missing.
#
# Hence a SessionStart hook with no matcher. The fix it points
# at is the user's to make: clone again with symlink support.
set -e

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

[ -d .agents/skills ] || exit 0

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
echo "  security audit, and no warning but this one. See"
echo "  Prerequisites in the README."

exit 0
