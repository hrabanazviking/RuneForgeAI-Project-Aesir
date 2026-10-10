#!/usr/bin/env python3
# prof/gauntlet/test_fi_campaign.py
# H186 — TEST-ONLY (PRÓF): crash-resistance fault-injection campaign.
#
# Builds on C8's VÖRÐR: runs build/vordr_cli h158-run (supervised F1
# inference under fault injection) for 60 minutes while a background
# thread injects >=100 faults across the h158 fault classes
# (hang, regerr, dmacorrupt) via the --fi-file channel at production
# cadence (~1 fault / 28 s, seeded order).
#
# Acceptance:
#   - >=100 faults injected across all classes
#   - zero process crashes (no InferChildBadExit, vordr_cli exits 0)
#   - zero unhandled faults: injected == handled per the automatic
#     cross-reconciliation of the fault log against the VÖRÐR
#     handling log (any discrepancy FAILS)
#   - output coherence maintained per the frozen
#     data/armvegr/coherence_rubric.json on spot-checked samples
#
# Run on Mimir from the repo root (takes ~60 min):
#   python3 prof/gauntlet/test_fi_campaign.py

import json
import random
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

DURATION_S = 3600
N_FAULTS = 120
FI_FILE = Path("/tmp/c10-fi-h186.json")
OUT_DIR = REPO / "data" / "gauntlet" / "fi_campaign"

# (fault, detail) — seeded cycle across the h158 battery.
FAULTS = [
    ("hang", ""),
    ("regerr", "0x06:0x8000"),
    ("dmacorrupt", ""),
    ("hang", ""),
    ("regerr", "0x06:0x2000"),
    ("dmacorrupt", ""),
    ("regerr", "0x06:0x0100"),
    ("hang", ""),
]


def injector(stop):
    rng = random.Random(186)
    order = [FAULTS[i % len(FAULTS)] for i in range(N_FAULTS)]
    rng.shuffle(order)
    interval = DURATION_S / N_FAULTS
    injected = 0
    for fault, detail in order:
        if stop.is_set():
            break
        # Wait for any previous descriptor to be consumed, then arm the next.
        for _ in range(60):
            if not FI_FILE.exists() or stop.is_set():
                break
            time.sleep(0.5)
        FI_FILE.write_text(json.dumps({"fault": fault, "detail": detail}))
        injected += 1
        # Pace: one fault per interval, but never slower than the run.
        time.sleep(interval)
    return injected


def check_coherence(text, ids, topics):
    """Frozen rubric data/armvegr/coherence_rubric.json (f1-coherence-v1)."""
    fails = []
    if not all(0 <= i < 32000 for i in ids):
        fails.append("valid_ids")
    sents = re.findall(r"[^.!?]+[.!?]", text)
    if len(sents) < 3:
        fails.append("sentences_ge_3")
    run = mx = 1
    for a, b in zip(ids, ids[1:]):
        run = run + 1 if a == b else 1
        mx = max(mx, run)
    if mx > 10:
        fails.append("no_10x_repeat")
    low = text.lower()
    if not any(t.lower() in low for t in topics):
        fails.append("topic_word")
    if "\ufffd" in text:
        fails.append("no_garbage")
    return fails


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if FI_FILE.exists():
        FI_FILE.unlink()

    vordr = str(REPO / "build" / "vordr_cli")
    f1bin = str(REPO / "build" / "f1_infer")
    f1cfg = str(REPO / "data" / "fallback" / "f1_config.json")
    cmd = [vordr, "h158-run", "--out-dir", str(OUT_DIR),
           "--f1-bin", f1bin, "--f1-config", f1cfg,
           "--max-tokens", "32", "--duration-s", str(DURATION_S),
           "--fi-file", str(FI_FILE), "--no-schedule",
           "--fi-seed", "186"]

    stop = threading.Event()
    thr = threading.Thread(target=injector, args=(stop,), daemon=True)
    print("H186: launching 60-min supervised run with fault injector...", flush=True)
    t0 = time.time()
    thr.start()
    p = subprocess.run(cmd, capture_output=True, text=True,
                       timeout=DURATION_S + 900, cwd=str(REPO))
    stop.set()
    thr.join(timeout=30)
    elapsed = time.time() - t0
    print(f"H186: vordr_cli exited {p.returncode} after {elapsed/60:.1f} min",
          flush=True)
    if FI_FILE.exists():
        FI_FILE.unlink()

    log_path = OUT_DIR / "events.jsonl"
    lines = log_path.read_text().splitlines() if log_path.exists() else []
    recs = [json.loads(l) for l in lines if l.strip()]

    injected = {}
    handled = {}
    crashes = 0
    for r in recs:
        k = r.get("kind")
        if k == "FaultInjected":
            f = r.get("fault", "?")
            injected[f] = injected.get(f, 0) + 1
        elif k == "FaultHandled":
            f = r.get("fault", "?")
            handled[f] = handled.get(f, 0) + 1
        elif k == "InferChildBadExit":
            crashes += 1

    total_inj = sum(injected.values())
    total_han = sum(handled.values())
    print(f"H186 injected: {injected} (total {total_inj})")
    print(f"H186 handled:  {handled} (total {total_han})")
    print(f"H186 child crashes: {crashes}")

    fails = []
    if total_inj < 100:
        fails.append(f"only {total_inj} faults injected (< 100)")
    for cls in ("hang", "regerr", "dmacorrupt"):
        if injected.get(cls, 0) == 0:
            fails.append(f"fault class '{cls}' never injected")
    if total_inj != total_han:
        fails.append(f"reconciliation mismatch: injected={total_inj} handled={total_han}")
    for f, n in injected.items():
        if handled.get(f, 0) != n:
            fails.append(f"class {f}: injected {n} != handled {handled.get(f, 0)}")
    if crashes:
        fails.append(f"{crashes} inference child crashes")
    if p.returncode != 0:
        fails.append(f"vordr_cli exited {p.returncode} (injected != handled)")

    # Coherence spot-check on up to 10 iteration outputs.
    iters = sorted(OUT_DIR.glob("iter_*.json"))[:10]
    checked = 0
    for it in iters:
        try:
            d = json.loads(it.read_text())
        except (OSError, ValueError):
            continue
        text = d.get("generated_text", "")
        ids = d.get("generated_ids", [])
        prompt = d.get("prompt_text", "")
        topics = [w for w in re.findall(r"[A-Za-z]{4,}", prompt)][:6] or ["the"]
        bad = check_coherence(text, ids, topics)
        if bad:
            fails.append(f"{it.name}: coherence failures {bad}")
        checked += 1
    print(f"H186 coherence spot-checked: {checked} iterations")

    scoreboard = {
        "verdict": "PASS" if not fails else "FAIL",
        "elapsed_min": round(elapsed / 60, 1),
        "injected": injected, "handled": handled,
        "injected_total": total_inj, "handled_total": total_han,
        "child_crashes": crashes,
        "coherence_spot_checked": checked,
        "failures": fails,
        "events_log": str(log_path),
    }
    (OUT_DIR / "scoreboard.json").write_text(json.dumps(scoreboard, indent=2))
    print(json.dumps(scoreboard, indent=2))
    print("H186-ALL-PASS" if not fails else "H186 FAIL: " + "; ".join(fails))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
