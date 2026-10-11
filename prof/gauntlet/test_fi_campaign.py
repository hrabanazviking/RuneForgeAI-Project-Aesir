#!/usr/bin/env python3
# prof/gauntlet/test_fi_campaign.py
# H186 — TEST-ONLY (PRÓF): crash-resistance fault-injection campaign.
#
# Builds on C8's VÖRÐR: runs build/vordr_cli h158-run (supervised F1
# inference under fault injection) for 60 minutes with BOTH fault
# channels C8 used: vordr's internal seeded schedule (mean 1 fault /
# 60 s) PLUS an external injector arming faults via the --fi-file
# channel (~1 fault / 30 s, seeded order) across the h158 fault classes
# (hang, regerr, dmacorrupt).
#
# vordr_cli runs under sudo: its device supervision opens the Hailo
# sysfs resource0, which requires root (C8's H158 test states the same:
# "Needs root"). Passwordless sudo is verified on Mimir.
#
# Iterations generate 96 tokens so spot-checked samples are long enough
# for the full frozen rubric (sentences_ge_3 needs real text length).
#
# Acceptance:
#   - >=100 faults injected across all classes
#   - zero process crashes (no InferChildBadExit, vordr_cli exits 0)
#   - zero unhandled faults: injected == handled per the automatic
#     cross-reconciliation of the fault log against the VÖRÐR
#     handling log (any discrepancy FAILS)
#   - output coherence maintained per the frozen coherence rubric on
#     spot-checked samples. Rubric: coherence_rubric_v1_1.json (the
#     H201-remediated freeze; v1's 2674-word list false-failed coherent
#     text — see H195. Thresholds identical, wordlist v2.)
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
N_FAULTS = 160
FI_FILE = Path("/tmp/c10-fi-h186.json")
OUT_DIR = REPO / "data" / "gauntlet" / "fi_campaign"
WORDLIST = REPO / "data" / "armvegr" / "english_wordlist_v2.txt"

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


def load_wordlist():
    words = set()
    for line in WORDLIST.read_text().splitlines():
        w = line.strip().lower()
        if w:
            words.add(w)
    return words


TERMINAL = re.compile(r"[.!?]")
# Per-prompt topic list for the h158 prompt — the same list C8's H158
# campaign recorded for this prompt (rubric: "per-prompt list").
TOPICS = ["völva", "fire", "wyrd", "spoke", "old"]


def clean_token(tok):
    t = tok.strip().lower()
    t = t.strip(".,!?;:\"'()[]{}<>-—–…«»„“”‘’/\\|@#$%^&*+=~`")
    t = t.replace("'", "").replace("’", "")
    return t


def check_coherence(text, ids, wordlist):
    """Full frozen rubric (v1.1 freeze), H138 reference semantics:
    generated_text and generated_ids are judged exactly as f1_infer
    wrote them (the field includes the prompt echo by design)."""
    fails = []
    if not all(isinstance(i, int) and 0 <= i < 32000 for i in ids):
        fails.append("valid_ids")
    parts = TERMINAL.split(text)
    n_sent = sum(1 for s in parts if re.search(r"[A-Za-z0-9]", s))
    if n_sent < 3:
        fails.append("sentences_ge_3")
    maxrun = run = 1
    for a, b in zip(ids, ids[1:]):
        run = run + 1 if a == b else 1
        maxrun = max(maxrun, run)
    if maxrun > 10:
        fails.append("no_10x_repeat")
    low = text.lower()
    if not any(w in low for w in TOPICS):
        fails.append("topic_word")
    if "\ufffd" in text:
        fails.append("no_garbage")
    good = total = 0
    for t in text.split():
        c = clean_token(t)
        if not c:
            continue
        total += 1
        if c.replace(".", "", 1).isdigit() or c in wordlist:
            good += 1
    if not (total > 0 and good / total >= 0.80):
        fails.append("english_ratio_ge_80")
    return fails


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if FI_FILE.exists():
        FI_FILE.unlink()
    # Clear stale artifacts from any earlier aborted run so the
    # reconciliation below sees only this campaign's evidence.
    for stale in OUT_DIR.glob("iter_*.json"):
        stale.unlink()
    for stale in ("events.jsonl", "scoreboard.json"):
        p = OUT_DIR / stale
        if p.exists():
            p.unlink()

    vordr = str(REPO / "build" / "vordr_cli")
    f1bin = str(REPO / "build" / "f1_infer")
    f1cfg = str(REPO / "data" / "fallback" / "f1_config.json")
    # sudo: vordr's device supervision opens sysfs resource0 (root-only),
    # exactly as in C8's H158 campaign. Internal schedule stays ON
    # (no --no-schedule): C8's design is schedule + external fi-file.
    cmd = ["sudo", "-n", vordr, "h158-run", "--out-dir", str(OUT_DIR),
           "--f1-bin", f1bin, "--f1-config", f1cfg,
           "--max-tokens", "96", "--duration-s", str(DURATION_S),
           "--fi-file", str(FI_FILE),
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
    (OUT_DIR / "vordr_stdout.log").write_text(
        "STDOUT:\n" + p.stdout + "\nSTDERR:\n" + p.stderr)
    print(f"H186: vordr_cli exited {p.returncode} after {elapsed/60:.1f} min",
          flush=True)
    if FI_FILE.exists():
        FI_FILE.unlink()

    return evaluate(p.returncode, elapsed / 60.0, rescored=False)


def evaluate(vordr_rc, elapsed_min, rescored) -> int:
    """Reconcile the campaign artifacts in OUT_DIR and write the
    scoreboard. Used by the live run and by --rescore (which re-judges
    saved artifacts after a checker fix; the fault evidence itself —
    events.jsonl — is produced by the run, never by this function)."""
    log_path = OUT_DIR / "events.jsonl"
    lines = log_path.read_text().splitlines() if log_path.exists() else []
    recs = [json.loads(l) for l in lines if l.strip()]

    injected = {}
    handled = {}
    crashes = 0
    complete = None
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
        elif k == "SupervisedRunComplete":
            complete = r

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
    if complete is not None and (complete.get("injected") != total_inj
                                 or complete.get("handled") != total_han):
        fails.append("vordr SupervisedRunComplete totals disagree with event log")
    if crashes:
        fails.append(f"{crashes} inference child crashes")
    if vordr_rc != 0:
        fails.append(f"vordr_cli exited {vordr_rc} (injected != handled)")

    # Coherence spot-check on up to 10 iteration outputs, H138 reference
    # semantics: generated_text / generated_ids judged exactly as
    # f1_infer wrote them.
    wordlist = load_wordlist()
    iters = sorted(OUT_DIR.glob("iter_*.json"))[:10]
    checked = 0
    for it in iters:
        try:
            d = json.loads(it.read_text())
        except (OSError, ValueError):
            continue
        bad = check_coherence(d.get("generated_text", ""),
                              d.get("generated_ids", []), wordlist)
        if bad:
            fails.append(f"{it.name}: coherence failures {bad}")
        checked += 1
    print(f"H186 coherence spot-checked: {checked} iterations")

    scoreboard = {
        "verdict": "PASS" if not fails else "FAIL",
        "elapsed_min": round(elapsed_min, 1),
        "rescored": rescored,
        "rubric": "f1-coherence-v1.1 (H201-remediated freeze; thresholds identical to v1, wordlist v2)",
        "vordr_invocation": "sudo -n build/vordr_cli h158-run (root required for sysfs supervision, as in C8 H158)",
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


def rescore() -> int:
    """Re-judge saved campaign artifacts (events.jsonl + iter_*.json)
    after a checker fix. The vordr exit code and elapsed time are
    recovered from the driver's own stdout log; if they cannot be
    recovered the rescore FAILS rather than guessing."""
    drv = REPO / "data" / "gauntlet" / "fi_driver_stdout.log"
    rc = None
    elapsed_min = 0.0
    if drv.exists():
        m = re.search(r"vordr_cli exited (\d+) after ([\d.]+) min",
                      drv.read_text())
        if m:
            rc = int(m.group(1))
            elapsed_min = float(m.group(2))
    if rc is None:
        print("H186 RESCORE FAIL: vordr exit code not recoverable from "
              "fi_driver_stdout.log — refusing to guess")
        return 1
    print(f"H186 rescore: vordr rc={rc}, elapsed={elapsed_min} min (from driver log)")
    return evaluate(rc, elapsed_min, rescored=True)


if __name__ == "__main__":
    if "--rescore" in sys.argv:
        sys.exit(rescore())
    sys.exit(main())
