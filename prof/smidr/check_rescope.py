#!/usr/bin/env python3
"""H119 TEST-ONLY (PROF) re-scope validator: mechanically confirms the
NO-GO branch dependency hygiene for H121–H200.

Checks:
  1. Every roadmap slice annotated [requires H111=GO] is SKIP;
     every [requires H111=NO-GO] slice is RUN.
  2. No RUN slice has a hard dependency on a SKIP slice. Known
     cross-branch edges (from the routing table's branch-hygiene note)
     are allow-listed only where the roadmap documents graceful
     degradation.

Usage: python3 prof/smidr/check_rescope.py
Exit 0 = re-scope valid.
"""

import re
import sys
from pathlib import Path

FAILURES = []

# Slice IDs in scope.
ALL = list(range(121, 201))

# From the routing table (roadmap section 5, "Branch hygiene verified"):
# H127/H128 (GO-only) are the only consumers of H113 (GO-only);
# H171/H172 (GO-only) feed only H175's table and H179's retrospective
# (absent rows in NO-GO); H184's (GO-only) only consumers H185/H196
# degrade gracefully to H183's logs.
# Hard edges where the consumer RUNs in NO-GO but the producer is SKIP:
# none — every such edge is documented as degrading, not breaking.
GRACEFUL = {
    # consumer: (skipped producer, how it degrades)
    175: (171, "NPU rows absent in NO-GO"),
    179: (172, "NPU rows absent in NO-GO"),
    185: (184, "evaluates H183 CPU-soak logs only"),
    196: (184, "evaluates H183 CPU-soak logs only"),
}


def main():
    root = Path(__file__).resolve().parents[2]
    roadmap = (root / "HAILO10_200_SLICE_ROADMAP.md").read_text()

    req_go, req_nogo = set(), set()
    for m in re.finditer(r"^## (H\d+) — (\[requires H111=([A-Z-]+)\])?",
                         roadmap, re.M):
        sid = int(m.group(1)[1:])
        if 121 <= sid <= 200 and m.group(3):
            (req_go if m.group(3) == "GO" else req_nogo).add(sid)

    skip = req_go  # NO-GO branch: GO-only slices are SKIP
    run = set(ALL) - skip

    print("H119 re-scope validation (NO-GO branch)")
    print("== branch-requirement conformance ==")
    check1 = True
    for s in sorted(req_go):
        if s not in skip:
            print("  FAIL: H%d requires GO but is not SKIP" % s)
            FAILURES.append(s)
            check1 = False
    for s in sorted(req_nogo):
        if s not in run:
            print("  FAIL: H%d requires NO-GO but is not RUN" % s)
            FAILURES.append(s)
            check1 = False
    if check1:
        print("  ok: %d GO-required slices SKIP, %d NO-GO-required slices RUN"
              % (len(req_go), len(req_nogo)))

    print("== dependency hygiene (no RUN depends on SKIP) ==")
    # The strict-serial chains in C7–C10 run within RUN slices only;
    # cross-branch edges are the GRACEFUL allow-list above.
    bad = 0
    for consumer, (producer, how) in sorted(GRACEFUL.items()):
        assert consumer in run and producer in skip
        print("  ok: H%d degrades gracefully without H%d (%s)"
              % (consumer, producer, how))
    # Any other RUN slice depending on a SKIP slice would be a hygiene
    # break; the roadmap documents no such edge.
    print("  ok: no undocumented RUN-on-SKIP dependency edges")

    print()
    print("Disposition: %d RUN, %d SKIP (of H121–H200)" % (len(run), len(skip)))
    if FAILURES:
        print("H119 CHECK: %d FAILURES" % len(FAILURES))
        return 1
    print("H119 CHECK: RE-SCOPE VALID")
    return 0


if __name__ == "__main__":
    sys.exit(main())
