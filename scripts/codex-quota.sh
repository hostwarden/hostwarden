#!/bin/sh
# codex-quota.sh — how much of the Codex usage limits is left, read
# through the local Codex CLI without spending any of it.
#
# Usage: sh scripts/codex-quota.sh [--model <slug>]
#
# Exit status 3 is a usage error.
#
# Prints one line, one part per limit the CLI's account has. Exit
# status: 0 when the backend allows ordinary usage, 1 when it does
# not, 2 when that cannot be told (no CLI, not signed in with
# ChatGPT, no or an unreadable answer, no verdict in it). Where the
# backend gives no verdict, a limit window at 100 % still reads as
# reached; nothing reads as available without the verdict. GitHub
# reviews have a code-review limit of their own that the CLI does
# not show.
#
# With --model, the line also says when that model retires and what
# replaces it, or that a newer model of its line exists (the model
# catalog's `upgrade` field, and slugs of the form
# <family>-<version>-<line>). That never changes the exit status.
#
# The CLI's app server answers account/rateLimits/read for the
# account it is signed in to; that is a read of the account, not a
# model turn, so it costs nothing.

# A usage error exits 3, never with a verdict's status.
usage() {
  echo "usage: sh scripts/codex-quota.sh [--model <slug>]" >&2
  exit 3
}
MODEL=''
case $# in
  0) ;;
  1) case $1 in --model=?*) MODEL=${1#--model=} ;; *) usage ;; esac ;;
  2) [ "$1" = --model ] && [ -n "$2" ] || usage; MODEL=$2 ;;
  *) usage ;;
esac
export MODEL

command -v codex >/dev/null 2>&1 \
  || { echo "codex quota: unknown (no codex CLI)"; exit 2; }
command -v python3 >/dev/null 2>&1 \
  || { echo "codex quota: unknown (no python3)"; exit 2; }

exec python3 - <<'PY'
import json, os, re, subprocess, sys, threading, time

def done(msg, rc):
    print("codex quota: " + msg)
    sys.exit(rc)

def read():
    p = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                         text=True)
    # An app server that never answers must not hold the session.
    timer = threading.Timer(20, p.kill)
    timer.start()
    try:
        for m in ({"id": 1, "method": "initialize",
                   "params": {"clientInfo": {"name": "hostwarden",
                                             "version": "0"}}},
                  {"method": "initialized"},
                  {"id": 2, "method": "account/rateLimits/read"}):
            p.stdin.write(json.dumps(m) + "\n")
        p.stdin.flush()
        for line in p.stdout:
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if isinstance(msg, dict) and msg.get("id") == 2:
                return msg
    finally:
        timer.cancel()
        p.kill()
        p.wait()
    return None

def used(w):
    u = w.get("usedPercent")
    return float(u) if isinstance(u, (int, float)) else None

def window(w):
    mins = w.get("windowDurationMins")
    span = ("%dd" % (mins // 1440) if mins % 1440 == 0 else
            "%dh" % (mins // 60) if mins % 60 == 0 else
            "%d min" % mins) if isinstance(mins, int) and mins > 0 \
        else "window"
    at = w.get("resetsAt")
    reset = time.strftime("%Y-%m-%d %H:%M %Z", time.localtime(at)) \
        if isinstance(at, (int, float)) else "unknown"
    u = used(w)
    return "%s %s used, resets %s" \
        % (span, "%d%%" % u if u is not None else "?%", reset)

def windows(snap):
    return [w for w in (snap.get("primary"), snap.get("secondary"))
            if isinstance(w, dict)]

def model_note(slug):
    """Retirement or a newer model of the slug's line, or None."""
    try:
        out = subprocess.run(["codex", "debug", "models"], text=True,
                             capture_output=True, timeout=20).stdout
        models = json.loads(out)["models"]
    except Exception:
        return "model %s: catalog unreadable" % slug
    by = {m.get("slug"): m for m in models if isinstance(m, dict)}
    if slug not in by:
        return "model %s: not in the catalog" % slug
    up = by[slug].get("upgrade") or {}
    if up.get("model"):
        return "model %s retires %s, successor %s" \
            % (slug, up.get("retirement_at") or "soon", up["model"])
    pat = re.compile(r"^(.+?)-(\d+(?:\.\d+)*)-(.+)$")
    mine = pat.match(slug)
    if not mine:
        return None
    ver = lambda v: tuple(int(x) for x in v.split("."))
    newer = sorted((ver(m.group(2)), s) for s in by
                   for m in [pat.match(s or "")]
                   if m and m.group(1) == mine.group(1)
                   and m.group(3) == mine.group(3)
                   and ver(m.group(2)) > ver(mine.group(2))
                   and by[s].get("visibility") == "list")
    if newer:
        return "model %s: newer in its line: %s" % (slug, newer[-1][1])
    return None

# The app server is experimental: an answer this cannot read is
# "cannot tell", never "limit reached".
try:
    answer = read()
    if answer is None:
        done("unknown (no answer from codex app-server)", 2)
    if "error" in answer:
        err = answer["error"] if isinstance(answer["error"], dict) else {}
        done("unknown (%s)" % err.get("message", "error"), 2)
    result = answer.get("result") or {}
    # rateLimits is the shared limit reviews run on; the others are
    # model-specific and only reported.
    shared = result.get("rateLimits")
    buckets = result.get("rateLimitsByLimitId") or {"codex": shared}
    buckets = {k: v for k, v in buckets.items() if isinstance(v, dict)}
    if not isinstance(shared, dict) or not buckets:
        done("unknown (no limit in the answer; signed in with ChatGPT?)", 2)
    summary = " | ".join(
        "%s: %s" % (name, "; ".join(window(w) for w in windows(snap))
                    or "no window reported")
        for name, snap in sorted(buckets.items()))
    # Redeeming a reset credit is the person's decision; this only
    # says that one exists.
    free = (result.get("rateLimitResetCredits") or {}).get("availableCount")
    if free:
        summary += " | reset credits available: %d" % free
    if os.environ.get("MODEL"):
        note = model_note(os.environ["MODEL"])
        if note:
            summary += " | " + note
    # The backend's verdict decides: the protocol says not to infer
    # recovery from percentages or reset times. The other fields
    # count only where it gives none, and then only towards
    # "reached".
    allowed = result.get("ordinaryUsageAllowed")
    if allowed is True:
        done(summary, 0)
    if allowed is False:
        done("limit reached: " + summary, 1)
    if shared.get("rateLimitReachedType") or shared.get("spendControlReached") \
            or any((used(w) or 0) >= 100 for w in windows(shared)):
        done("limit reached: " + summary, 1)
    done("unknown (no verdict from the backend): " + summary, 2)
except Exception as e:
    done("unknown (%s: %s)" % (type(e).__name__, e), 2)
PY
