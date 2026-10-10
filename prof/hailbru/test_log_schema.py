#!/usr/bin/env python3
# TEST-ONLY (PRÓF) — H089: JSON-schema-style validator for the bring-up
# log schema (docs/hailbru/BRINGUP_LOG_SCHEMA.md). Rejects malformed log
# lines, accepts well-formed ones. Also validates real logs on demand.
#
# Usage: test_log_schema.py --selftest
#        test_log_schema.py --validate /tmp/bringup_01.jsonl
import argparse
import json
import sys

EVENTS = {"step_start", "step_end", "step_banked", "error", "info"}
OUTCOMES = {"running", "ok", "failed", "banked"}


def validate_line(line):
    """Return None if valid, else a reason string."""
    try:
        o = json.loads(line)
    except Exception as e:
        return "not JSON: %s" % e
    if not isinstance(o, dict):
        return "top level is not an object"
    for f in ("ts_ms", "step", "event", "outcome", "dur_ms", "detail"):
        if f not in o:
            return "missing field '%s'" % f
    if not isinstance(o["ts_ms"], int) or isinstance(o["ts_ms"], bool):
        return "ts_ms must be integer"
    if not isinstance(o["dur_ms"], int) or isinstance(o["dur_ms"], bool):
        return "dur_ms must be integer"
    for f in ("step", "event", "outcome", "detail"):
        if not isinstance(o[f], str):
            return "%s must be string" % f
    if o["event"] not in EVENTS:
        return "bad event '%s'" % o["event"]
    if o["outcome"] not in OUTCOMES:
        return "bad outcome '%s'" % o["outcome"]
    if o["event"] == "step_start" and o["outcome"] != "running":
        return "step_start must pair with running"
    if o["event"] == "step_end" and o["outcome"] != "ok":
        return "step_end must pair with ok"
    if o["event"] == "step_banked" and o["outcome"] != "banked":
        return "step_banked must pair with banked"
    return None


GOOD = [
    '{"ts_ms": 1, "step": "enter_d0", "event": "step_start", "outcome": "running", "dur_ms": 0, "detail": ""}',
    '{"ts_ms": 2, "step": "enter_d0", "event": "step_end", "outcome": "ok", "dur_ms": 50, "detail": "state=D0"}',
    '{"ts_ms": 3, "step": "firmware_load", "event": "step_banked", "outcome": "banked", "dur_ms": 0, "detail": "F3-BANKED: needs F3-4"}',
    '{"ts_ms": 4, "step": "bar_verify", "event": "error", "outcome": "failed", "dur_ms": 0, "detail": "omitted by test hook"}',
    '{"ts_ms": 5, "step": "bringup", "event": "info", "outcome": "ok", "dur_ms": 102, "detail": "{\\"result\\": \\"READY_PM\\"}"}',
]

BAD = [
    'not json at all',
    '{"ts_ms": 1, "step": "x", "event": "step_start", "outcome": "running", "dur_ms": 0}',
    '{"ts_ms": "1", "step": "x", "event": "step_start", "outcome": "running", "dur_ms": 0, "detail": ""}',
    '{"ts_ms": 1, "step": "x", "event": "launch", "outcome": "running", "dur_ms": 0, "detail": ""}',
    '{"ts_ms": 1, "step": "x", "event": "step_start", "outcome": "ok", "dur_ms": 0, "detail": ""}',
]


def selftest():
    fails = 0
    for i, g in enumerate(GOOD):
        r = validate_line(g)
        if r is not None:
            print("GOOD[%d] rejected: %s" % (i, r))
            fails += 1
    for i, b in enumerate(BAD):
        r = validate_line(b)
        if r is None:
            print("BAD[%d] accepted (should reject)" % i)
            fails += 1
        else:
            print("BAD[%d] rejected: %s" % (i, r))
    print("selftest: %d failures" % fails)
    return 1 if fails else 0


def validate_file(path):
    bad = 0
    n = 0
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            n += 1
            r = validate_line(line)
            if r is not None:
                print("line %d: %s" % (n, r))
                bad += 1
    print("%s: %d lines, %d invalid" % (path, n, bad))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--validate", default="")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if a.validate:
        return validate_file(a.validate)
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
