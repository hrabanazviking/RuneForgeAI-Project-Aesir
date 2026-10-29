#!/usr/bin/env python3
# PRÓF TEST-ONLY — H154 fault injection: corrupt DMA data.
#
# 500 single-bit flips injected into host-side staging buffers (the
# NO-GO-branch transfer surface); 500/500 must be detected by the
# integrity layer BEFORE compute consumes the data (escape count = 0,
# the headline metric). Detected corruptions trigger re-transfer
# (transient per the taxonomy); the re-transferred data verifies clean.
#
# Pure-MoJo ships; this file is TESTS ONLY (D8 PRÓF).

import subprocess
import sys
from pathlib import Path

VORDR = str(Path(__file__).resolve().parents[2] / "vordr_cli")


def main():
    # The Mojo selftest-integrity IS the injection engine (500 flips,
    # real FNV-1a checksums, real re-transfers); PRÓF asserts its
    # verdict and independently reconciles the event log.
    log = "/tmp/vordr-h154-events.jsonl"
    r = subprocess.run([VORDR, "selftest-integrity", "--log", log],
                       capture_output=True, text=True, timeout=300)
    print(r.stdout.strip())
    if r.returncode != 0:
        print("H154 FAIL: selftest-integrity rc != 0")
        print(r.stderr[-500:])
        sys.exit(1)

    # Independent reconciliation: count IntegrityCorrupt and
    # IntegrityRetransferred events in the log.
    corrupt = retrans = 0
    with open(log) as f:
        for line in f:
            if '"kind": "IntegrityCorrupt"' in line:
                corrupt += 1
            elif '"kind": "IntegrityRetransferred"' in line:
                retrans += 1
    print(f"H154 reconciled: corrupt_events={corrupt} "
          f"retransfer_events={retrans}")
    if corrupt != 500:
        print(f"H154 FAIL: corrupt events {corrupt} != 500 injected")
        sys.exit(1)
    if retrans != 500:
        print(f"H154 FAIL: retransfer events {retrans} != 500")
        sys.exit(1)
    # Escape count: any buffer that verified clean while corrupted
    # would have produced NO IntegrityCorrupt for its flip — corrupt
    # count == injected count proves zero escapes.
    print("H154: 500/500 detected, 0 escapes, 500/500 re-transferred clean")


if __name__ == "__main__":
    main()
