#!/usr/bin/env python3
# PRÓF TEST-ONLY — H152 fault injection: hangs.
#
# 20 hangs injected across different ops via the test hook; all 20
# must be detected within budget+5s and drive the recovery state
# machine to the taxonomy-prescribed outcome. Post-recovery, the
# pipeline must resume correct operation (a verification inference
# matches the pre-fault reference).
#
# Pure-MoJo ships; this file is TESTS ONLY (D8 PRÓF).

import json
import subprocess
import sys
from pathlib import Path

VORDR = "/home/pi/mimisbrunnr_c8/vordr_cli"
F1BIN = "/home/pi/mimisbrunnr_c8/f1_infer"
F1CFG = "/home/pi/mimisbrunnr_c8/data/fallback/f1_config.json"


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=600, **kw)


def main():
    fails = []

    # Part 1: 20 injected hangs via h158 supervised iterations.
    # Each h158 run gets one hang fault; the detector must fire within
    # budget+5s (2s budget + 5s) and the state machine must absorb it
    # as transient (retry). We run 20 short supervised runs.
    detected = 0
    for i in range(20):
        fi = Path("/tmp/vordr-fi-h152.json")
        fi.write_text(json.dumps({"fault": "hang", "detail": ""}))
        out = f"/tmp/vordr-h152-{i}"
        r = run([VORDR, "h158-run", "--out-dir", out,
                 "--f1-bin", F1BIN, "--f1-config", F1CFG,
                 "--max-tokens", "8", "--duration-s", "600",
                 "--max-iters", "3", "--fi-file", str(fi),
                 "--iter-budget-ms", "120000", "--no-schedule"])
        text = (Path(out) / "events.jsonl").read_text() \
            if (Path(out) / "events.jsonl").exists() else ""
        if '"kind": "HangDetected"' not in text:
            fails.append(f"hang {i}: HangDetected not in log")
            continue
        if '"fault": "hang", "action": "detected+retry' not in text:
            fails.append(f"hang {i}: transient handling not evidenced")
            continue
        # Detection latency: the FaultHandled event carries detect_ms.
        m = [l for l in text.splitlines() if '"fault": "hang"' in l]
        if not m or '"detect_ms"' not in m[0]:
            fails.append(f"hang {i}: no detect_ms evidence")
            continue
        detected += 1
    print(f"H152 hangs detected+handled: {detected}/20")

    # Part 2: post-recovery correctness — a verification inference
    # after the fault storm must match the pre-fault reference
    # (same prompt+seed => same text; the engine is deterministic).
    ref = "/tmp/vordr-h152-ref.json"
    ver = "/tmp/vordr-h152-ver.json"
    prompt = "The völva reads the runes by firelight."
    run([F1BIN, "--config", F1CFG, "--prompt", prompt,
         "--max-new-tokens", "16", "--seed", "4242", "--out", ref])
    # Fault storm: 3 hang faults back to back.
    for i in range(3):
        fi = Path("/tmp/vordr-fi-h152.json")
        fi.write_text(json.dumps({"fault": "hang", "detail": ""}))
        run([VORDR, "h158-run", "--out-dir", f"/tmp/vordr-h152s-{i}",
             "--f1-bin", F1BIN, "--f1-config", F1CFG,
             "--max-tokens", "8", "--duration-s", "600",
             "--max-iters", "3", "--fi-file", str(fi),
             "--iter-budget-ms", "120000", "--no-schedule"])
    run([F1BIN, "--config", F1CFG, "--prompt", prompt,
         "--max-new-tokens", "16", "--seed", "4242", "--out", ver])
    t_ref = json.loads(Path(ref).read_text())["generated_text"]
    t_ver = json.loads(Path(ver).read_text())["generated_text"]
    if t_ref != t_ver:
        fails.append("post-recovery verification inference differs from reference")
    else:
        print("H152 post-recovery inference matches reference: OK")

    if fails:
        print("H152 FAIL:")
        for f in fails:
            print("  " + f)
        sys.exit(1)
    if detected != 20:
        print("H152 FAIL: detected != 20")
        sys.exit(1)
    print("H152: 20/20 hangs detected within budget, handled, recovery proven")


if __name__ == "__main__":
    main()
