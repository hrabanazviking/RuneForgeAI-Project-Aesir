#!/usr/bin/env python3
# prof/gauntlet/test_gauntlet_purity.py
# H181 — GAUNTLET architectural self-test (TEST-ONLY).
#
# The hard law: GAUNTLET judges, never implements. Enforced mechanically:
# every `from X` / `import X` in gauntlet/*.mojo must reference only the
# Mojo standard library (X startswith "std"). In particular the test
# fails on any reference to repair/recovery/fix paths:
#   vordr.recovery, vordr.retry, vordr.reinit, vordr.reset_ctl,
#   vordr.degrade, hailbru.api (reset entrypoints), or the words
#   "recover", "repair", "fix_" inside gauntlet sources.
#
# Run: python3 prof/gauntlet/test_gauntlet_purity.py  (from the repo root)

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GAUNTLET = REPO / "gauntlet"

FORBIDDEN_RE = re.compile(
    r"(vordr\.(recovery|retry|reinit|reset_ctl|degrade)"
    r"|hailbru\.api"
    r"|\brecover\w*|\brepair\w*|\bfix_\w*"
    r"|reset_device|reinit_device)",
    re.IGNORECASE,
)
IMPORT_RE = re.compile(r"^\s*(?:from|import)\s+([A-Za-z0-9_.]+)", re.MULTILINE)


def main() -> int:
    files = sorted(GAUNTLET.glob("*.mojo"))
    if not files:
        print("H181 PURITY FAIL: no gauntlet/*.mojo files found")
        return 1
    failures = []
    for f in files:
        src = f.read_text()
        # Rule 1: imports must be std-only.
        for m in IMPORT_RE.finditer(src):
            mod = m.group(1)
            if not mod.startswith("std"):
                failures.append(f"{f.name}: non-std import '{mod}'")
        # Rule 2: no repair/recovery/fix references at all.
        for m in FORBIDDEN_RE.finditer(src):
            failures.append(f"{f.name}: forbidden repair-path reference '{m.group(0)}'")
    if failures:
        print("H181 PURITY FAIL:")
        for x in failures:
            print("  " + x)
        return 1
    print(f"H181 PURITY PASS: {len(files)} gauntlet modules, std-only imports, "
          "zero repair/recovery/fix references")
    return 0


if __name__ == "__main__":
    sys.exit(main())
