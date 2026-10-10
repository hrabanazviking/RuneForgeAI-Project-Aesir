#!/usr/bin/env python3
# prof/gauntlet/test_determinism.py
# H188 — TEST-ONLY (PRÓF): determinism proof.
#
# Identical prompts + greedy sampling -> identical token sequences:
#   - 10/10 identical sequences for each of 5 prompts (same process
#     launched fresh each time — every run is its own process)
#   - then 5/5 identical again after the loop (no state leakage
#     between runs; each run reloads the model from disk)
#
# NO-GO branch: no NPU backend exists, so the CPU/NPU logit comparison
# does not apply. The production binary is the F1 CPU path with the
# greedy storm config (data/gauntlet/storm_config.json, temperature 0.0).
#
# Run on Mimir from the repo root:
#   python3 prof/gauntlet/test_determinism.py

import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BINARY = str(REPO / "build" / "f1_infer")
STORM_CFG = str(REPO / "data" / "gauntlet" / "storm_config.json")
OUT = REPO / "data" / "gauntlet" / "determinism.json"

PROMPTS = [
    "The old völva sat by the fire and spoke of wyrd.",
    "A raven landed on the fence post and watched.",
    "The longship sailed at dawn toward the open sea.",
    "Snow fell softly on the quiet village.",
    "The blacksmith's forge glowed in the dark.",
]
SEED = 188
MAX_NEW = 48

IDS_RE = re.compile(r'"generated_ids":\s*\[([0-9,\s]+)\]')


def generate(prompt):
    r = subprocess.run(
        [BINARY, "--config", STORM_CFG, "--prompt", prompt,
         "--max-new-tokens", str(MAX_NEW), "--seed", str(SEED)],
        capture_output=True, text=True, timeout=300, cwd=str(REPO))
    if r.returncode != 0:
        raise RuntimeError("f1_infer crashed: " + r.stderr[-300:])
    m = IDS_RE.search(r.stdout)
    if not m:
        raise RuntimeError("unparsable output")
    return [int(x) for x in m.group(1).split(",")]


def main() -> int:
    fails = []
    detail = {}
    for pi, prompt in enumerate(PROMPTS):
        seqs = [generate(prompt) for _ in range(10)]
        identical = all(s == seqs[0] for s in seqs)
        detail["prompt_%d_10x" % pi] = {
            "identical_10_10": identical,
            "n_tokens": len(seqs[0]),
        }
        print("H188 prompt %d: 10/10 identical = %s (%d tokens)"
              % (pi, identical, len(seqs[0])), flush=True)
        if not identical:
            fails.append("prompt %d: sequences diverged across 10 runs" % pi)

    # After the loop: 5 more runs of prompt 0 (process restarted each
    # time by construction) — no state leakage between runs.
    ref = generate(PROMPTS[0])
    post = [generate(PROMPTS[0]) for _ in range(5)]
    post_ok = all(s == ref for s in post)
    detail["post_restart_5x"] = {"identical_5_5": post_ok}
    print("H188 post-restart 5/5 identical = %s" % post_ok, flush=True)
    if not post_ok:
        fails.append("post-restart sequences diverged (state leakage)")

    result = {
        "verdict": "PASS" if not fails else "FAIL",
        "match_rate": 1.0 if not fails else 0.0,
        "failures": fails,
        "detail": detail,
    }
    OUT.write_text(json.dumps(result, indent=2))
    print("H188-ALL-PASS" if not fails else "H188 FAIL: " + "; ".join(fails))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
