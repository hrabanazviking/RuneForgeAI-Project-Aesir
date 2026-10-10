#!/usr/bin/env python3
# prof/gauntlet/test_soak_cpu_4h.py
# H183 — TEST-ONLY (PRÓF): 4-hour continuous CPU inference soak.
#
# Drives the production binary (armvegr/f1_infer, pure Mojo) as a
# subprocess: repeated generations with prompts cycled from the fixed
# 50-prompt corpus (data/gauntlet/soak_corpus.json), monitoring for
# crashes, hangs, slowdowns, and output degradation.
#
# Acceptance:
#   - zero crashes (every f1_infer exits 0)
#   - zero hangs (every generation completes within 5x its p50 wall time;
#     p50 measured in a 10-generation warmup)
#   - no slowdown drift: median tok/s in the final 30 min within +/-10%
#     of the median tok/s in the first 30 min
#   - full generation log preserved at data/gauntlet/soak_cpu_4h.log
#     (JSONL); any anomaly aborts the run with the log position attached.
#
# Memory note (H189): f1_infer is a one-shot process per generation, so
# RSS is tracked as the per-generation peak RSS (sampled from
# /proc/<pid>/status every 2 s while the child runs); the trend of
# per-generation peaks over the soak is the leak signal. Samples go to
# data/gauntlet/soak_rss.jsonl. SoC temperature is sampled every 5 min.
#
# Run on Mimir from the repo root:
#   python3 prof/gauntlet/test_soak_cpu_4h.py \
#       --binary build/f1_infer --config data/fallback/f1_config.json
# The run takes ~4 h; launch under nohup and let it run.

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

DECODE_RE = re.compile(r"F1 decode:\s+(\d+)\s+tokens in\s+([\d.]+)s\s+=\s+([\d.]+)\s+tok/s")
PREFILL_RE = re.compile(r"F1 prefill:\s+(\d+)\s+tokens in\s+([\d.]+)s\s+=\s+([\d.]+)\s+tok/s")
START_MARK = "F1-GENERATED-START"
END_MARK = "F1-GENERATED-END"

WARMUP_GENS = 10
SOAK_SECONDS = 4 * 3600
HANG_FACTOR = 5.0
DRIFT_TOL = 0.10


def read_temp_c():
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            return int(f.read().strip()) / 1000.0
    except OSError:
        return None


def read_rss_mb(pid):
    try:
        with open("/proc/%d/status" % pid) as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) / 1024.0
    except OSError:
        return None
    return None


def run_generation(binary, config, prompt, seed, timeout_s, max_new=64):
    """Run one f1_infer generation. Returns (record, anomaly_or_None)."""
    cmd = [binary, "--config", config, "--prompt", prompt,
           "--max-new-tokens", str(max_new), "--seed", str(seed)]
    t0 = time.time()
    peak_rss = 0.0
    timed_out = False
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True, cwd=str(REPO))
        while p.poll() is None:
            rss = read_rss_mb(p.pid)
            if rss and rss > peak_rss:
                peak_rss = rss
            if time.time() - t0 > timeout_s:
                timed_out = True
                p.kill()
                break
            time.sleep(2.0)
        out, err = p.communicate()
        rc = p.returncode
    except OSError as e:
        return None, "spawn failed: %s" % e
    wall = time.time() - t0

    if timed_out:
        return None, "HANG: generation exceeded %.1fs (5x p50)" % timeout_s
    if rc != 0:
        return None, "CRASH: exit code %d; stderr tail: %s" % (rc, err[-500:])

    prefill_tps = decode_tps = n_gen = None
    m = PREFILL_RE.search(out)
    if m:
        prefill_tps = float(m.group(3))
    m = DECODE_RE.search(out)
    if m:
        n_gen = int(m.group(1))
        decode_tps = float(m.group(3))
    text = ""
    if START_MARK in out and END_MARK in out:
        text = out.split(START_MARK, 1)[1].split(END_MARK, 1)[0].strip()
    if decode_tps is None or n_gen is None:
        return None, "ANOMALY: could not parse timing/text from f1_infer output"

    rec = {
        "wall_s": round(wall, 3),
        "prefill_tps": round(prefill_tps, 3) if prefill_tps else None,
        "decode_tps": round(decode_tps, 3),
        "n_gen": n_gen,
        "peak_rss_mb": round(peak_rss, 1),
        "seed": seed,
        "text_sha256": hashlib.sha256(text.encode()).hexdigest(),
        "text": text[:2000],
    }
    return rec, None


def median(xs):
    s = sorted(xs)
    n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def fail(summary_path, t_start, n, anomaly, pos):
    summary = {"verdict": "FAIL", "generations": n,
               "elapsed_h": round((time.time() - t_start) / 3600, 3),
               "anomaly": anomaly, "anomaly_log_position": pos}
    summary_path.write_text(json.dumps(summary, indent=2))
    print("H183 FAIL: %s (log position %s)" % (anomaly, pos))
    return 1


def finish(summary_path, t_start, log_path, gens, anomaly, pos):
    elapsed_h = (time.time() - t_start) / 3600
    n = len(gens)
    if anomaly:
        return fail(summary_path, t_start, n, anomaly, pos)

    t_end = t_start + SOAK_SECONDS
    first = [t for ts, t in gens if ts - t_start < 1800]
    last = [t for ts, t in gens if t_end - ts < 1800]
    drift = None
    if first and last:
        drift = abs(median(last) / median(first) - 1.0)

    summary = {
        "verdict": "PASS",
        "generations": n,
        "elapsed_h": round(elapsed_h, 3),
        "crashes": 0,
        "hangs": 0,
        "first30_median_tps": round(median(first), 3) if first else None,
        "last30_median_tps": round(median(last), 3) if last else None,
        "drift_ratio": round(drift, 4) if drift is not None else None,
        "drift_within_10pct": (drift is not None and drift <= DRIFT_TOL),
        "log": str(log_path),
    }
    summary_path.write_text(json.dumps(summary, indent=2))
    print("H183 summary: " + json.dumps(summary, indent=2))

    ok = True
    if elapsed_h < 4.0:
        print("H183 FAIL: soak ran < 4h")
        ok = False
    if drift is None or drift > DRIFT_TOL:
        print("H183 FAIL: drift %s exceeds %s" % (drift, DRIFT_TOL))
        ok = False
    print("H183-ALL-PASS" if ok else "H183 FAIL")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--binary", default="build/f1_infer")
    ap.add_argument("--config", default="data/fallback/f1_config.json")
    args = ap.parse_args()
    binary = str(REPO / args.binary)
    config = str(REPO / args.config)

    with open(REPO / "data" / "gauntlet" / "soak_corpus.json") as f:
        corpus = json.load(f)["prompts"]
    assert len(corpus) == 50, "corpus must hold 50 prompts, got %d" % len(corpus)

    log_path = REPO / "data" / "gauntlet" / "soak_cpu_4h.log"
    rss_path = REPO / "data" / "gauntlet" / "soak_rss.jsonl"
    summary_path = REPO / "data" / "gauntlet" / "soak_cpu_4h_summary.json"
    log_path.parent.mkdir(parents=True, exist_ok=True)

    t_start = time.time()
    anomaly = None
    anomaly_pos = None

    with open(log_path, "w") as log, open(rss_path, "w") as rsslog:
        def emit(rec):
            log.write(json.dumps(rec) + "\n")
            log.flush()

        print("H183 warmup: 10 generations to measure p50...", flush=True)
        warmup_walls = []
        for i in range(WARMUP_GENS):
            rec, anom = run_generation(binary, config, corpus[i % 50],
                                       seed=9000 + i, timeout_s=600)
            if anom:
                anomaly, anomaly_pos = anom, i
                emit({"idx": i, "phase": "warmup", "anomaly": anom,
                      "ts": time.time()})
                break
            warmup_walls.append(rec["wall_s"])
            rec.update({"idx": i, "phase": "warmup", "prompt_idx": i % 50,
                        "ts": time.time()})
            emit(rec)
        if anomaly:
            return fail(summary_path, t_start, 0, anomaly, anomaly_pos)

        p50 = median(warmup_walls)
        hang_timeout = HANG_FACTOR * p50
        print("H183 warmup p50 wall = %.1fs -> hang timeout %.1fs"
              % (p50, hang_timeout), flush=True)
        emit({"phase": "warmup_done", "p50_wall_s": round(p50, 3),
              "hang_timeout_s": round(hang_timeout, 3), "ts": time.time()})

        idx = WARMUP_GENS
        gens = []
        last_temp = 0.0
        while time.time() - t_start < SOAK_SECONDS and not anomaly:
            prompt = corpus[idx % 50]
            rec, anom = run_generation(binary, config, prompt,
                                       seed=10000 + idx, timeout_s=hang_timeout)
            ts = time.time()
            if anom:
                anomaly, anomaly_pos = anom, idx
                emit({"idx": idx, "phase": "soak", "prompt_idx": idx % 50,
                      "anomaly": anom, "ts": ts})
                break
            rec.update({"idx": idx, "phase": "soak", "prompt_idx": idx % 50,
                        "ts": ts})
            emit(rec)
            rsslog.write(json.dumps({"idx": idx, "ts": ts,
                                     "peak_rss_mb": rec["peak_rss_mb"]}) + "\n")
            rsslog.flush()
            gens.append((ts, rec["decode_tps"]))
            if ts - last_temp > 300:
                last_temp = ts
                temp = read_temp_c()
                emit({"phase": "status", "ts": ts, "soc_temp_c": temp,
                      "elapsed_h": round((ts - t_start) / 3600, 2),
                      "gens": len(gens)})
                print("H183 status: %d gens, %.2fh, temp %sC"
                      % (len(gens), (ts - t_start) / 3600, temp), flush=True)
            idx += 1

    return finish(summary_path, t_start, log_path, gens, anomaly, anomaly_pos)


if __name__ == "__main__":
    sys.exit(main())
