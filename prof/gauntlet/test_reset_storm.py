#!/usr/bin/env python3
# prof/gauntlet/test_reset_storm.py
# H187 — TEST-ONLY (PRÓF): scripted reset storms.
#
# NO-GO branch (H111 was NO-GO): 20 rapid PIPELINE restarts in
# succession. Each cycle: start a generation, SIGKILL it mid-decode
# (the "crash"), immediately respawn, and run a verification inference
# with the greedy storm config (data/gauntlet/storm_config.json,
# temperature 0.0) — the output token ids must match the pre-storm
# reference EXACTLY (greedy determinism: state truly clean, not
# approximately clean).
#
# Per-recovery timing: kill -> respawn-to-alive is the "pipeline
# restart"; it is checked against the H155 process_restart budget
# (44 ms, docs/vordr/C8_REVIEW.md). The verification inference is the
# separate correctness proof (exact id match), not part of the budget.
#
# Run on Mimir from the repo root:
#   python3 prof/gauntlet/test_reset_storm.py

import json
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BINARY = str(REPO / "build" / "f1_infer")
STORM_CFG = str(REPO / "data" / "gauntlet" / "storm_config.json")
OUT = REPO / "data" / "gauntlet" / "reset_storm.json"

N_RESTARTS = 20
RESTART_BUDGET_MS = 44.0  # H155 process_restart budget
PROMPT = "The old völva sat by the fire and spoke of wyrd."
SEED = 187
MAX_NEW = 32

IDS_RE = re.compile(r'"generated_ids":\s*\[([0-9,\s]+)\]')


def run_verify(timeout=300):
    """One verification inference; returns (ids, wall_s)."""
    t0 = time.time()
    r = subprocess.run(
        [BINARY, "--config", STORM_CFG, "--prompt", PROMPT,
         "--max-new-tokens", str(MAX_NEW), "--seed", str(SEED)],
        capture_output=True, text=True, timeout=timeout, cwd=str(REPO))
    wall = time.time() - t0
    if r.returncode != 0:
        raise RuntimeError("verify inference crashed: " + r.stderr[-300:])
    m = IDS_RE.search(r.stdout)
    if not m:
        raise RuntimeError("could not parse generated_ids")
    return [int(x) for x in m.group(1).split(",")], wall


def main() -> int:
    print("H187: pre-storm reference inference...", flush=True)
    ref_ids, _ = run_verify()
    print("H187: reference = %d ids" % len(ref_ids), flush=True)

    recoveries = []
    fails = []
    for i in range(N_RESTARTS):
        # Start a generation, kill it mid-decode, respawn immediately.
        victim = subprocess.Popen(
            [BINARY, "--config", STORM_CFG, "--prompt", PROMPT,
             "--max-new-tokens", str(MAX_NEW), "--seed", str(1000 + i)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            cwd=str(REPO))
        time.sleep(6.0)  # let it get into decode
        t_kill = time.time()
        victim.send_signal(signal.SIGKILL)
        victim.wait()
        # Respawn = the recovery. Time to the new process being alive.
        t_spawn0 = time.time()
        proc = subprocess.Popen(
            [BINARY, "--config", STORM_CFG, "--prompt", PROMPT,
             "--max-new-tokens", str(MAX_NEW), "--seed", str(SEED)],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            cwd=str(REPO))
        alive = proc.poll() is None
        t_alive = time.time()
        restart_ms = (t_alive - t_spawn0) * 1000.0
        # Verification: the respawned process must serve correctly.
        try:
            out, _ = proc.communicate(timeout=300)
            rc = proc.returncode
        except subprocess.TimeoutExpired:
            proc.kill()
            fails.append("cycle %d: verification hung" % i)
            continue
        t_done = time.time()
        if rc != 0:
            fails.append("cycle %d: verification crashed (rc=%d)" % (i, rc))
            continue
        m = IDS_RE.search(out.decode(errors="replace"))
        if not m:
            fails.append("cycle %d: unparsable output" % i)
            continue
        ids = [int(x) for x in m.group(1).split(",")]
        exact = (ids == ref_ids)
        if not exact:
            fails.append("cycle %d: output mismatch vs reference" % i)
        within = restart_ms <= RESTART_BUDGET_MS
        recoveries.append({
            "cycle": i,
            "restart_ms": round(restart_ms, 1),
            "within_budget": within,
            "verify_wall_s": round(t_done - t_kill, 1),
            "exact_match": exact,
        })
        print("H187 cycle %d: restart %.0fms (<=%.0fms: %s), exact_match=%s"
              % (i, restart_ms, RESTART_BUDGET_MS, within, exact), flush=True)

    ok_cycles = sum(1 for r in recoveries if r["exact_match"])
    budget_ok = all(r["within_budget"] for r in recoveries) if recoveries else False
    result = {
        "verdict": "PASS" if (not fails and ok_cycles == N_RESTARTS and budget_ok) else "FAIL",
        "restarts": N_RESTARTS,
        "recoveries_to_service": ok_cycles,
        "all_within_h155_budget_ms": budget_ok,
        "h155_budget_ms": RESTART_BUDGET_MS,
        "max_restart_ms": round(max(r["restart_ms"] for r in recoveries), 1) if recoveries else None,
        "failures": fails,
        "recoveries": recoveries,
    }
    OUT.write_text(json.dumps(result, indent=2))
    print(json.dumps({k: v for k, v in result.items() if k != "recoveries"}, indent=2))
    print("H187-ALL-PASS" if result["verdict"] == "PASS"
          else "H187 FAIL: " + "; ".join(fails))
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
