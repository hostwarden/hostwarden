#!/bin/sh
# codex-quota.sh — how much of the Codex usage limits is left, read
# through the local Codex CLI without spending any of it.
#
# Usage: sh scripts/codex-quota.sh
#
# Prints one line, one part per limit the CLI's account has. Exit
# status: 0 when a local run can start, 1 when the shared `codex`
# limit is reached (a model-specific one is only reported), 2 when
# it cannot be read (no CLI, not signed in with ChatGPT, no or an
# unreadable answer). GitHub reviews have a code-review limit of
# their own that the CLI does not show.
#
# The CLI's app server answers account/rateLimits/read for the
# account it is signed in to; that is a read of the account, not a
# model turn, so it costs nothing.

command -v codex >/dev/null 2>&1 \
  || { echo "codex quota: unknown (no codex CLI)"; exit 2; }
command -v python3 >/dev/null 2>&1 \
  || { echo "codex quota: unknown (no python3)"; exit 2; }

exec python3 - <<'PY'
import json, subprocess, sys, threading, time

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

def window(w):
    mins = w.get("windowDurationMins")
    span = {10080: "weekly", 300: "5h"}.get(mins) \
        or ("%s min" % mins if mins else "window")
    at = w.get("resetsAt")
    reset = time.strftime("%Y-%m-%d %H:%M %Z", time.localtime(at)) \
        if isinstance(at, (int, float)) else "unknown"
    return "%s %d%% used, resets %s" \
        % (span, float(w.get("usedPercent") or 0), reset)

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
    buckets = result.get("rateLimitsByLimitId") \
        or {"codex": result.get("rateLimits")}
    buckets = {k: v for k, v in buckets.items() if isinstance(v, dict)}
    if not buckets:
        done("unknown (no limit in the answer; signed in with ChatGPT?)", 2)
    parts, reached = [], []
    for name, snap in sorted(buckets.items()):
        wins = [w for w in (snap.get("primary"), snap.get("secondary"))
                if isinstance(w, dict)]
        parts.append("%s: %s" % (name, "; ".join(window(w) for w in wins)
                                 or "no window reported"))
        # Only the shared bucket decides: a model-specific one, such
        # as a fast model's, can be used up while reviews still run.
        # The backend's own verdict first: the protocol says not to
        # infer recovery from percentages or reset times.
        if name == "codex" and (snap.get("rateLimitReachedType")
                                or snap.get("spendControlReached")
                                or any(float(w.get("usedPercent") or 0) >= 100
                                       for w in wins)):
            reached.append(name)
    summary = " | ".join(parts)
    # Redeeming a reset credit is the person's decision; this only
    # says that one exists.
    free = (result.get("rateLimitResetCredits") or {}).get("availableCount")
    if free:
        summary += " | %d reset credit%s available" \
            % (free, "" if free == 1 else "s")
    if reached or result.get("ordinaryUsageAllowed") is False:
        done("limit reached (%s): %s"
             % (", ".join(reached) or "usage not allowed", summary), 1)
except SystemExit:
    raise
except Exception as e:
    done("unknown (%s: %s)" % (type(e).__name__, e), 2)
done(summary, 0)
PY
