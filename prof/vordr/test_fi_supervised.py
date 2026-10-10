#!/usr/bin/env python3
# PRÓF TEST-ONLY — H158 30-minute supervised inference run.
#
# Launches vordr_cli h158-run for 1800s with the internal seeded fault
# schedule (mean 1 fault / 60s) PLUS external PRÓF fi-file injections
# at random times. Afterwards reconciles injected == handled, checks
# SupervisedRunComplete, and spot-checks generated text against the
# frozen coherence rubric (data/armvegr/coherence_rubric.json).
#
# Pure-MoJo ships; this file is TESTS ONLY (D8 PRÓF). Needs root.

import json
import os
import random
import subprocess
import sys
import time
from pathlib import Path

VORDR = "/home/pi/mimisbrunnr_c8/vordr_cli"
REPO = "/home/pi/mimisbrunnr_c8"
DUR = 1800
EXT_FAULTS = 5

fails = []


def kinds(log):
    out = []
    p = Path(log)
    if p.exists():
        for line in p.read_text().splitlines():
            i = line.find('"kind": "')
            if i >= 0:
                out.append(line[i + 9:].split('"')[0])
    return out


def check_rubric(text, ids, topic_words):
    """Frozen rubric items applicable to a short sample."""
    errs = []
    if any(not (0 <= i < 32000) for i in ids):
        errs.append("valid_ids")
    run = 1
    for a, b in zip(ids, ids[1:]):
        run = run + 1 if a == b else 1
        if run > 10:
            errs.append("no_10x_repeat")
            break
    low = text.lower()
    if not any(w in low for w in topic_words):
        errs.append("topic_word")
    return errs


def main():
    tmp = Path("/tmp/vordr-h158test")
    if tmp.exists():
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    out = tmp / "run"
    out.mkdir()
    fi = tmp / "fi.json"
    log = str(out / "events.jsonl")

    seed = int(time.time()) % 100000
    print(f"H158: launching 30-min supervised run (fi_seed={seed})...")
    proc = subprocess.Popen(
        [VORDR, "h158-run", "--out-dir", str(out),
         "--duration-s", str(DUR), "--fi-seed", str(seed),
         "--fi-file", str(fi), "--max-tokens", "24",
         "--prompt", "The old völva sat by the fire and spoke of wyrd."],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL)

    # PRÓF external injector: 5 faults at random times in (60, DUR-120).
    rng = random.Random(seed ^ 0x5EED)
    ext_times = sorted(rng.uniform(60, DUR - 120) for _ in range(EXT_FAULTS))
    ext_kinds = ["hang", "dmacorrupt",
                 "regerr", "hang", "dmacorrupt"]
    t0 = time.time()
    for ft, fk in zip(ext_times, ext_kinds):
        while time.time() - t0 < ft:
            if proc.poll() is not None:
                break
            time.sleep(5)
        if proc.poll() is not None:
            break
        detail = "0x06:0x8000" if fk == "regerr" else ""
        fi.write_text(json.dumps({"fault": fk, "detail": detail}))
        print(f"H158: external fault injected t+{ft:.0f}s: {fk}")

    # Wait for completion (duration + 15 min slack for slow iterations).
    try:
        proc.wait(timeout=DUR + 900)
    except subprocess.TimeoutExpired:
        proc.kill()
        fails.append("h158-run did not finish in time")
        print("H158: TIMEOUT — killed")

    ks = kinds(log)
    n_inj = ks.count("FaultInjected")
    n_hdl = ks.count("FaultHandled")
    print(f"H158: injected={n_inj} handled={n_hdl}")
    if n_inj == 0:
        fails.append("no faults were injected")
    if n_inj != n_hdl:
        fails.append(f"injected ({n_inj}) != handled ({n_hdl})")
    if "SupervisedRunComplete" not in ks:
        fails.append("missing SupervisedRunComplete")
    if "SupervisedRunHalted" in ks:
        fails.append("run halted (fatal) — unexpected in this schedule")

    # Fault rate sanity: ~1/60s over 30 min -> expect 20-45 injected.
    if not (15 <= n_inj <= 60):
        fails.append(f"fault count {n_inj} outside plausible 15..60 band")

    # Coherence spot-check: 4 completed iterations vs the frozen rubric.
    outs = sorted(out.glob("iter_*.json"))
    print(f"H158: {len(outs)} iteration outputs")
    checked = 0
    for p in outs[::max(1, len(outs) // 4)][:4]:
        try:
            d = json.loads(p.read_text())
        except Exception:
            continue
        errs = check_rubric(d.get("generated_text", ""),
                            d.get("generated_ids", []),
                            ["völva", "fire", "wyrd", "spoke", "old"])
        if errs:
            fails.append(f"{p.name}: rubric fail {errs}")
        else:
            checked += 1
    print(f"H158: coherence spot-check {checked}/4 clean")
    if checked < 3:
        fails.append("fewer than 3 coherence samples clean")

    # Long-form rubric proof: 2 × 64-token generations, full rubric
    # incl. sentences_ge_3.
    print("H158: long-form coherence probes (2 x 64 tokens)...")
    for li in range(2):
        lp = tmp / f"long{li}.json"
        r = subprocess.run(
            ["/home/pi/mimisbrunnr_c8/f1_infer", "--config",
             REPO + "/data/fallback/f1_config.json",
             "--prompt", "The old völva sat by the fire and spoke of wyrd.",
             "--max-new-tokens", "64", "--seed", str(5000 + li),
             "--out", str(lp)],
            capture_output=True, text=True, timeout=900)
        if r.returncode != 0 or not lp.exists():
            fails.append(f"long-form probe {li} failed")
            continue
        d = json.loads(lp.read_text())
        errs = check_rubric(d.get("generated_text", ""),
                            d.get("generated_ids", []),
                            ["völva", "fire", "wyrd", "spoke", "old"])
        sents = sum(d.get("generated_text", "").count(c)
                    for c in ".!?")
        if sents < 3:
            errs.append("sentences_ge_3")
        if errs:
            fails.append(f"long{li}: rubric fail {errs}")
        else:
            print(f"H158: long-form probe {li} rubric-clean ({sents} sentences)")

    print()
    if fails:
        print("H158 SUPERVISED-RUN FAIL:")
        for f in fails:
            print("  " + f)
        sys.exit(1)
    print("H158: 30-min supervised run — injected==handled, "
          "coherence holds, zero unhandled faults")


if __name__ == "__main__":
    main()
