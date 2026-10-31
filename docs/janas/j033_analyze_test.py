#!/usr/bin/env python3
"""Offline test for j033_analyze.py (J-033). Builds synthetic window
logs in the exact session format under a scratch dir, runs the
analyser on them and on the real J-023 harvest logs, and asserts the
pre-registered verdict rules fire as designed (J033_SOAK.md sec. 5).

Sets:
  flat  -- 8 identical windows -> NO DEGRADATION TREND, ceiling HELD,
           total_generated=2048.
  drift -- 8 windows, decode s/gen rising x1.06 per window (last/first
           ~1.50) -> DEGRADATION TREND (wall rule).
  real  -- the two filed J-023 harvest logs as a 2-window soak ->
           parses; w1 hit=0.258 and bytes/total_tok=362073616.9
           (the J-023/J-030 recorded values); PARTIAL SOAK label.
Scratch dir: $J033_TEST_TMP or ~/workspace/.verify-tmp/j033/test_out.
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ANALYZER = os.path.join(HERE, "j033_analyze.py")
REAL_IDLE = os.path.expanduser(
    "~/workspace/model-tests/janas/j023_harvest/run_idle.log")
REAL_LOADED = os.path.expanduser(
    "~/workspace/model-tests/janas/j023_harvest/run_loaded.log")

FAILURES = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (" " + detail if detail else ""))
    if not cond:
        FAILURES.append(name)


def write_window(d, idx, decode_s_per_gen, hit_per_mille, bytes_streamed,
                 gen=256, prompt=67, resident=532217856,
                 budget=536870912, rss_kib=1938424):
    prefill = 28.0
    decode = decode_s_per_gen * gen
    accesses = 128 * (prompt + gen)
    hits = int(accesses * hit_per_mille / 1000)
    ids = ", ".join(str(1000 + i) for i in range(gen))
    log = (
        "GGUF validated: 195 tensors, 38 metadata entries, architecture olmoe\n"
        f"[MOE] arch=olmoe layers=16 hidden=2048 experts=64 topk=8 "
        f"expert_bytes=3900702720 cache_budget_bytes={budget} context=512\n"
        f"Prompt IDs: [{', '.join(str(i) for i in range(prompt))}]\n"
        f"Generated IDs: [{ids}]\n"
        f"[CACHE] accesses={accesses} hits={hits} misses={accesses - hits} "
        f"cold_misses=950 hit_rate_per_mille={hit_per_mille} bypasses=7376 "
        f"too_large=0 admissions=1265 promotions=192 evictions=1125 "
        f"evicted_before_reuse=3387 bytes_streamed={bytes_streamed} "
        f"bytes_evicted=4275437568 bytes_resident_now={resident} "
        f"entries_now=140 budget_bytes={budget}\n"
        f"[STREAM] StreamReader(path=model.gguf, reads=25923, "
        f"bytes_read={bytes_streamed}, advice_calls=34945, "
        f"advised_bytes=44370493440)\n"
        f"TIMING prompt_tokens= {prompt}  prefill_s= {prefill}  "
        f"generated= {gen}  decode_s= {decode}\n"
    )
    with open(os.path.join(d, f"run_w{idx:02d}.log"), "w") as f:
        f.write(log)
    with open(os.path.join(d, f"run_w{idx:02d}.meta"), "w") as f:
        f.write(f"WINDOW={idx}\nRUN_EXIT=0 window={idx}\n"
                f"\tMaximum resident set size (kbytes): {rss_kib}\n")
    return os.path.join(d, f"run_w{idx:02d}.log")


def run_analyzer(paths):
    r = subprocess.run([sys.executable, ANALYZER] + paths,
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def main():
    base = os.environ.get("J033_TEST_TMP") or os.path.expanduser(
        "~/workspace/.verify-tmp/j033/test_out")
    os.makedirs(base, exist_ok=True)

    flat_dir = os.path.join(base, "flat")
    os.makedirs(flat_dir, exist_ok=True)
    flat = [write_window(flat_dir, i, 0.3912, 258, 90000000000)
            for i in range(1, 9)]
    rc, out = run_analyzer(flat)
    print(out)
    check("flat rc=0", rc == 0)
    check("flat verdict", "VERDICT: NO DEGRADATION TREND" in out)
    check("flat ceiling", "ceiling: HELD" in out)
    check("flat total", "total_generated=2048" in out)

    drift_dir = os.path.join(base, "drift")
    os.makedirs(drift_dir, exist_ok=True)
    drift = [write_window(drift_dir, i, 0.3912 * (1.06 ** (i - 1)), 258,
                          90000000000) for i in range(1, 9)]
    rc, out = run_analyzer(drift)
    print(out)
    check("drift rc=0", rc == 0)
    check("drift verdict", "VERDICT: DEGRADATION TREND" in out)

    breach_dir = os.path.join(base, "breach")
    os.makedirs(breach_dir, exist_ok=True)
    breach = [write_window(breach_dir, i, 0.3912, 258, 90000000000,
                           rss_kib=3000000) for i in range(1, 9)]
    rc, out = run_analyzer(breach)
    print(out)
    check("breach ceiling", "ceiling: BREACH" in out)
    check("breach verdict", "VERDICT: DEGRADATION TREND" in out)

    rc, out = run_analyzer([REAL_IDLE, REAL_LOADED])
    print(out)
    check("real rc=0", rc == 0)
    check("real w1 hit", "hit=0.258" in out)
    check("real w1 bytes/total_tok",
          "bytes/total_tok=362073616.9" in out)
    check("real partial", "PARTIAL SOAK" in out)
    check("real identity of counters",
          "total_generated=48" in out and "cumulative_hit=0.258" in out)

    print("RESULT: " + ("ALL PASS" if not FAILURES
                        else f"{len(FAILURES)} FAIL: {FAILURES}"))
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
