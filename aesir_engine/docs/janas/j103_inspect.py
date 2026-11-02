#!/usr/bin/env python3
"""J-103 inspect: mechanically re-derive the load-bearing claims of
docs/janas/J103_MODEL_GETTING.md from this tree.

Run from the repo root (the worktree root):
    python3 aesir_engine/docs/janas/j103_inspect.py
Prints one PASS/FAIL line per check and a final tally; exit 0 iff
all PASS.

Skeleton committed with the protocol (doc section 0); the dataset and
get-surface checks are completed with the build they verify.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]  # aesir_engine/
REPO = ROOT.parent
JANAS = ROOT / "docs" / "janas"

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))


def read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


doc = read(JANAS / "J103_MODEL_GETTING.md")
check("doc exists", doc != "")
for phrase in ("0. Protocol", "pin-provenance", "DEFERRED-WITH-REASON",
               "NOT PROVEN", "T10"):
    check(f"doc states {phrase!r}", phrase in doc)

failed = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    line = ("PASS: " if ok else "FAIL: ") + name
    if detail and not ok:
        line += f" ({detail})"
    print(line)
print(f"j103_inspect: {len(checks) - len(failed)}/{len(checks)} checks PASS")
sys.exit(0 if not failed else 1)
