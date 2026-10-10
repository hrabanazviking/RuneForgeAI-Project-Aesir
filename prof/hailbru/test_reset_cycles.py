#!/usr/bin/env python3
# TEST-ONLY (PRÓF) — H084: 100 consecutive PM-cycle bring-ups via the Mojo
# bring-up binary. Any single cycle failure aborts the run with the
# failing cycle's full register dump attached — failures are never hidden
# in an average. "Ready" = READY_PM per docs/hailbru/COLD_BOOT_DEFINITION.md
# option (c): D0 + vendor-mirror coherency + clean power-state cycle.
#
# Usage: python3 test_reset_cycles.py --probe /tmp/probe_c5 --bdf 0001:01:00.0 \
#            --cycles 100 --out data/hailbru/reset_cycles_100.json [--sudo]
import argparse
import json
import subprocess
import sys
import time


def run(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", required=True)
    ap.add_argument("--bdf", default="0001:01:00.0")
    ap.add_argument("--cycles", type=int, default=100)
    ap.add_argument("--out", required=True)
    ap.add_argument("--sudo", action="store_true")
    a = ap.parse_args()

    pre = ["sudo", "-n"] if a.sudo else []
    results = []
    t_start = time.monotonic()
    for i in range(a.cycles):
        log = "/tmp/c5_cycle_%04d.jsonl" % i
        t0 = time.monotonic()
        rc, out, err = run(
            pre + [a.probe, "bringup", "--bdf", a.bdf, "--log", log]
        )
        dt_ms = (time.monotonic() - t0) * 1000.0
        ok = rc == 0 and '"result": "READY_PM"' in out
        rec = {"cycle": i, "ok": ok, "wall_ms": round(dt_ms, 1), "log": log}
        results.append(rec)
        print("cycle %d: %s %.0fms" % (i, "OK" if ok else "FAIL", dt_ms),
              flush=True)
        if not ok:
            # Attach the failing cycle's full register dump, then abort.
            rc2, dump, _ = run(pre + [a.probe, "snapshot", "--bdf", a.bdf,
                                      "--state-label", "cycle_%d_failed" % i])
            rec["register_dump"] = dump if rc2 == 0 else "dump failed: %s" % dump
            rec["stderr_tail"] = err[-2000:]
            payload = {"cycles": results, "aborted_at": i,
                       "definition": "COLD_BOOT_DEFINITION.md option (c)"}
            with open(a.out, "w") as f:
                json.dump(payload, f, indent=2)
            print("ABORTED at cycle %d — dump attached to %s" % (i, a.out))
            return 1
    total_s = time.monotonic() - t_start
    walls = [r["wall_ms"] for r in results]
    payload = {
        "cycles": results,
        "count": len(results),
        "failures": 0,
        "wall_min_ms": round(min(walls), 1),
        "wall_max_ms": round(max(walls), 1),
        "wall_mean_ms": round(sum(walls) / len(walls), 1),
        "total_s": round(total_s, 1),
        "definition": "docs/hailbru/COLD_BOOT_DEFINITION.md option (c) "
                      "PM-cycle bring-up; ready = READY_PM",
    }
    with open(a.out, "w") as f:
        json.dump(payload, f, indent=2)
    print("100/100 OK  min=%.0f max=%.0f mean=%.0fms total=%.1fs"
          % (payload["wall_min_ms"], payload["wall_max_ms"],
             payload["wall_mean_ms"], total_s))
    return 0


if __name__ == "__main__":
    sys.exit(main())
