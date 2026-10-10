#!/usr/bin/env python3
"""H118 TEST-ONLY (PROF) completeness check for the banked assault index.

Verifies:
  1. Every path listed in docs/plunder/BANKED_ASSAULT_INDEX.md exists.
  2. No banked doc (.md) contains TBD/TODO markers.

Usage: python3 prof/smidr/check_banked_index.py
Exit 0 = complete. Exit 1 = missing path or TBD/TODO found.
"""

import re
import sys
from pathlib import Path

FAILURES = []


def main():
    root = Path(__file__).resolve().parents[2]
    index = (root / "docs/plunder/BANKED_ASSAULT_INDEX.md").read_text()

    # Paths are backtick-quoted in the index.
    paths = sorted(set(re.findall(r"`([^`]+)`", index)))
    # Keep only repo-relative file paths (skip globs, commands, doc names).
    file_paths = [p for p in paths
                  if "/" in p and not p.startswith(("http", "python3"))]

    print("H118 banked-index completeness check")
    print("== path existence (%d paths) ==" % len(file_paths))
    missing = 0
    for p in file_paths:
        if (root / p).exists():
            print("  ok: " + p)
        else:
            print("  MISSING: " + p)
            FAILURES.append("missing: " + p)
            missing += 1

    print("== TBD/TODO scan (banked .md docs) ==")
    docs = [root / p for p in file_paths if p.endswith(".md")]
    tbd = 0
    for d in docs:
        if not d.exists():
            continue
        text = d.read_text()
        hits = re.findall(r"\b(TBD|TODO|FIXME|XXX)\b", text)
        if hits:
            print("  MARKER in %s: %s" % (d.name, sorted(set(hits))))
            FAILURES.append("marker in " + str(d))
            tbd += 1
        else:
            print("  ok: %s clean" % d.name)

    print()
    if FAILURES:
        print("H118 CHECK: %d FAILURES" % len(FAILURES))
        return 1
    print("H118 CHECK: COMPLETE — %d paths exist, %d docs clean"
          % (len(file_paths) - missing, len(docs)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
